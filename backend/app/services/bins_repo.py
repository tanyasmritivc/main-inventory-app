import logging
import time

from app.services.supabase_client import get_supabase_admin


logger = logging.getLogger(__name__)


def _execute_with_retry(fn, max_attempts: int = 3):
    last_error = None
    for attempt in range(1, max_attempts + 1):
        try:
            return fn()
        except Exception as exc:
            last_error = exc
            if attempt < max_attempts:
                wait = 2 ** (attempt - 1)
                logger.warning("Supabase error attempt=%d, retrying in %ss", attempt, wait)
                time.sleep(wait)
    raise last_error


def list_bins(*, user_id: str, space_id: str) -> list[dict]:
    response = _execute_with_retry(
        lambda: get_supabase_admin().table("bins")
        .select("id, space_id, name, created_at")
        .eq("user_id", user_id)
        .eq("space_id", space_id)
        .order("name")
        .execute()
    )
    return response.data or []


def create_bin(*, user_id: str, space_id: str, name: str) -> dict:
    # Do not let a caller create a bin in another user's space, even if they
    # somehow obtain that space UUID. The service role bypasses RLS.
    space = _execute_with_retry(
        lambda: get_supabase_admin().table("spaces")
        .select("id")
        .eq("user_id", user_id)
        .eq("id", space_id)
        .maybe_single()
        .execute()
    )
    if not space.data:
        raise LookupError("Space not found")
    response = _execute_with_retry(
        lambda: get_supabase_admin().table("bins")
        .insert({"user_id": user_id, "space_id": space_id, "name": name})
        .execute()
    )
    return (response.data or [{}])[0]


def rename_bin(*, user_id: str, bin_id: str, name: str) -> dict | None:
    response = _execute_with_retry(
        lambda: get_supabase_admin().table("bins")
        .update({"name": name})
        .eq("user_id", user_id)
        .eq("id", bin_id)
        .execute()
    )
    return (response.data or [None])[0]


def delete_bin(*, user_id: str, bin_id: str) -> bool:
    response = _execute_with_retry(
        lambda: get_supabase_admin().table("bins")
        .delete()
        .eq("user_id", user_id)
        .eq("id", bin_id)
        .execute()
    )
    return bool(response.data)
