import logging
import time

from app.services.limits import LIMITS, get_user_tier
from app.services.supabase_client import get_supabase_admin
from app.services.inventory_scope import current_inventory
from fastapi import HTTPException

logger = logging.getLogger(__name__)


class SpaceLimitExceeded(Exception):
    """Raised when a free-tier user tries to create a fourth named space."""


def _execute_with_retry(fn, max_attempts: int = 3):
    last_error = None
    for attempt in range(1, max_attempts + 1):
        try:
            return fn()
        except Exception as e:
            last_error = e
            if attempt < max_attempts:
                wait = 2 ** (attempt - 1)
                logger.warning("Supabase error attempt=%d, retrying in %ss: %s", attempt, wait, e)
                time.sleep(wait)
            else:
                logger.error("Supabase failed after %d attempts: %s", max_attempts, e)
    raise last_error


def count_spaces(*, user_id: str) -> int:
    """Count real named spaces for the user, excluding any 'Unsorted' rows."""
    supabase = get_supabase_admin()
    if current_inventory.get():
        supabase = supabase.raw
    resp = _execute_with_retry(
        lambda: supabase.table("spaces")
        .select("id, name")
        .eq("user_id", user_id)
        .execute()
    )
    return sum(
        1 for row in (resp.data or [])
        if (row.get("name") or "").strip().lower() != "unsorted"
    )


def _find_space_by_name(*, user_id: str, name: str) -> dict | None:
    """Return the user's space whose name matches exactly (case-insensitive)."""
    supabase = get_supabase_admin()
    resp = _execute_with_retry(
        lambda: supabase.table("spaces")
        .select("id, name, created_at")
        .eq("user_id", user_id)
        .execute()
    )
    target = (name or "").strip().lower()
    matches = [row for row in resp.data or [] if (row.get('name') or '').strip().lower()==target]
    if len(matches)>1:
        raise HTTPException(409,'More than one Space uses this name. Choose its inventory on the website.')
    return matches[0] if matches else None


def space_exists(*, user_id: str, name: str) -> bool:
    """Case-insensitive check whether a space with this name exists for the user."""
    name = (name or "").strip()
    if not name:
        return False
    return _find_space_by_name(user_id=user_id, name=name) is not None



def list_spaces(*, user_id: str) -> list[dict]:
    """Return all spaces for user with item_count derived from items.space_id."""
    supabase = get_supabase_admin()
    scope=current_inventory.get()
    if scope:
        rows=[]
        while True:
            page=supabase.raw.table('app_inventory_space_summaries').select('id,name,created_at,item_count').eq('inventory_id',scope.inventory_id).order('name').order('id').range(len(rows),len(rows)+499).execute().data or []
            rows.extend(page)
            if len(page)<500:
                return rows
    spaces_resp = _execute_with_retry(
        lambda: supabase.table("spaces")
        .select("id, name, created_at")
        .eq("user_id", user_id)
        .order("name")
        .execute()
    )
    spaces = spaces_resp.data or []
    if not spaces:
        return []

    # Count items per space in one query, group in Python
    items_resp = _execute_with_retry(
        lambda: supabase.table("items")
        .select("space_id")
        .eq("user_id", user_id)
        .not_.is_("space_id", "null")
        .execute()
    )
    counts: dict[str, int] = {}
    for row in (items_resp.data or []):
        sid = row.get("space_id")
        if sid:
            counts[sid] = counts.get(sid, 0) + 1

    return [
        {
            "id": s["id"],
            "name": s["name"],
            "created_at": s.get("created_at"),
            "item_count": counts.get(s["id"], 0),
        }
        for s in spaces
    ]


def get_or_create_space(*, user_id: str, name: str) -> dict:
    """Case-insensitive lookup by name; insert if missing. Returns the space row."""
    name = (name or "").strip()
    if not name:
        raise ValueError("Space name is required")

    supabase = get_supabase_admin()

    existing = _find_space_by_name(user_id=user_id, name=name)
    if existing:
        return existing

    # Space does not exist — enforce space limit before creating (team plan = unlimited)
    from app.services.limits import resolve_effective_limits
    eff_limits, _ = resolve_effective_limits(user_id)
    max_spaces = eff_limits["spaces"]
    if max_spaces is not None and count_spaces(user_id=user_id) >= max_spaces:
        raise SpaceLimitExceeded(
            f"Space limit of {max_spaces} reached."
        )

    try:
        resp = _execute_with_retry(
            lambda: supabase.table("spaces")
            .insert({"user_id": user_id, "name": name})
            .execute()
        )
        return (resp.data or [{}])[0]
    except Exception:
        # Race condition — another request created it first; re-read
        logger.warning("Space insert conflict for user=%s name=%s, re-reading", user_id, name)
        existing = _find_space_by_name(user_id=user_id, name=name)
        if existing:
            return existing
        raise


def rename_space(*, user_id: str, space_id: str, new_name: str) -> dict:
    """Rename a space and sync items.location for all items in that space."""
    new_name = (new_name or "").strip()
    if not new_name:
        raise ValueError("New name is required")

    supabase = get_supabase_admin()
    # Local import avoids the items_repo -> spaces_repo import cycle. Every
    # reader of the cached inventory, including shared inventory, must see the
    # updated legacy location immediately after this mutation.
    from app.services.items_repo import invalidate_inventory_cache

    try:
        resp = _execute_with_retry(
            lambda: supabase.table("spaces")
            .update({"name": new_name})
            .eq("user_id", user_id)
            .eq("id", space_id)
            .execute()
        )

        # Sync all owned items, independent of a client's category filter.
        _execute_with_retry(
            lambda: supabase.table("items")
            .update({"location": new_name})
            .eq("user_id", user_id)
            .eq("space_id", space_id)
            .execute()
        )

        return (resp.data or [{}])[0]
    finally:
        # Also clear a cached snapshot after an upstream failure: the first
        # database write may already have succeeded. Never hide that failure.
        invalidate_inventory_cache(user_id)


def delete_space(*, user_id: str, space_id: str) -> bool:
    """Delete the Space, saved items and bound review records through FK cascades."""
    supabase = get_supabase_admin()
    from app.services.inventory_scope import current_inventory
    from app.services.permissions import require_inventory_action
    from app.services.resource_access import request_actor
    from app.services.supabase_client import get_supabase_raw
    scope = current_inventory.get()
    if scope is not None:
        require_inventory_action(scope.role, 'delete_space')
    elif request_actor.get() is not None:
        raw = get_supabase_raw()
        records = raw.table('spaces').select('inventory_id').eq('id', space_id).limit(1).execute().data or []
        if records:
            role = raw.rpc('findez_inventory_role', {
                'p_inventory': records[0]['inventory_id'], 'p_actor': request_actor.get().actor_id,
            }).execute().data
            require_inventory_action(role, 'delete_space')
    from app.services.items_repo import invalidate_inventory_cache

    try:
        resp = _execute_with_retry(
            lambda: supabase.table("spaces")
            .delete()
            .eq("user_id", user_id)
            .eq("id", space_id)
            .execute()
        )
        return bool(resp.data)
    finally:
        # Space deletion cascades to items, so it invalidates the same cache.
        invalidate_inventory_cache(user_id)
