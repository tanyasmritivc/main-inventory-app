from __future__ import annotations

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
