
from datetime import datetime, timezone
from uuid import uuid4

from app.services.supabase_client import get_supabase_admin

_VALID_EVENT_TYPES = {'usage', 'note', 'failure', 'success', 'restock', 'photo'}


def log_event(
    *,
    user_id: str,
    item_id: str,
    event_type: str,
    content: str | None = None,
    quantity_delta: int | None = None,
    image_url: str | None = None,
    quantity_before: int | None = None,
    quantity_after: int | None = None,
    cause: str | None = None,
) -> dict:
    if event_type not in _VALID_EVENT_TYPES:
        raise ValueError(f"Invalid event_type '{event_type}'. Must be one of {_VALID_EVENT_TYPES}")

    client = get_supabase_admin()
    payload: dict = {
        "event_id": str(uuid4()),
        "item_id": item_id,
        "user_id": user_id,
        "event_type": event_type,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    if content is not None:
        payload["content"] = content
    if quantity_delta is not None:
        payload["quantity_delta"] = quantity_delta
    if image_url is not None:
        payload["image_url"] = image_url
    if quantity_before is not None:
        payload["quantity_before"] = quantity_before
    if quantity_after is not None:
        payload["quantity_after"] = quantity_after
    if cause is not None:
        payload["cause"] = cause

    result = client.table("item_events").insert(payload).execute()
    if not result.data:
        raise RuntimeError("Failed to insert item event")
    return result.data[0]


def get_events_for_item(*, user_id: str, item_id: str, limit: int = 20) -> list[dict]:
    client = get_supabase_admin()
    result = (
        client.table("item_events")
        .select("*")
        .eq("user_id", user_id)
        .eq("item_id", item_id)
        .order("created_at", desc=True)
        .limit(limit)
        .execute()
    )
    return result.data or []


def get_recent_events(*, user_id: str, limit: int = 10) -> list[dict]:
    client = get_supabase_admin()
    result = (
        client.table("item_events")
        .select("*")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .limit(limit)
        .execute()
    )
    return result.data or []


def get_item_history(*, requesting_user_id: str, item_id: str, limit: int = 50) -> list[dict]:
    client = get_supabase_admin()
    item_result = (
        client.table("items").select("item_id,user_id,workspace_id")
        .eq("item_id", item_id).maybe_single().execute()
    )
    item = item_result.data
    if not item:
        raise LookupError("Object not found")
    if item["user_id"] != requesting_user_id:
        workspace_id = item.get("workspace_id")
        membership = (
            client.table("team_memberships").select("user_id")
            .eq("team_id", workspace_id).eq("user_id", requesting_user_id)
            .limit(1).execute()
            if workspace_id else None
        )
        if not membership or not membership.data:
            raise LookupError("Object not found")
    result = (
        client.table("item_events").select("*")
        .eq("item_id", item_id).order("created_at", desc=True)
        .limit(limit).execute()
    )
    events = result.data or []
    actor_ids = list({event["user_id"] for event in events if event.get("user_id")})
    profiles = (
        client.table("profiles").select("id,display_name,first_name,last_name")
        .in_("id", actor_ids).execute().data or []
        if actor_ids else []
    )
    names = {
        profile["id"]: (
            profile.get("display_name")
            or " ".join(filter(None, [profile.get("first_name"), profile.get("last_name")]))
            or None
        )
        for profile in profiles
    }
    return [{**event, "actor_display_name": names.get(event.get("user_id"))} for event in events]
