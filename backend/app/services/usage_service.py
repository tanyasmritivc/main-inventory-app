from __future__ import annotations

from datetime import datetime

from app.services.supabase_client import get_supabase_admin, supabase_execute_with_retry

FREE_ITEM_LIMIT = 30
FREE_SCAN_LIMIT = 5


def get_current_month() -> str:
    return datetime.utcnow().strftime("%Y-%m")


def is_pro_user(user_id: str) -> bool:
    """Check if the user has an active Pro subscription via profiles.is_pro."""
    try:
        client = get_supabase_admin()
        result = supabase_execute_with_retry(
            lambda: client.table("profiles")
            .select("is_pro")
            .eq("id", user_id)
            .execute()
        )
        return bool(result.data and result.data[0].get("is_pro", False))
    except Exception:
        return False


def check_item_limit(user_id: str) -> dict:
    """Return {allowed, current, limit} for the item count free-tier gate."""
    if is_pro_user(user_id):
        return {"allowed": True, "current": 0, "limit": -1}
    try:
        client = get_supabase_admin()
        result = supabase_execute_with_retry(
            lambda: client.table("items")
            .select("item_id", count="exact")
            .eq("user_id", user_id)
            .execute()
        )
        current = result.count or 0
    except Exception:
        current = 0
    return {
        "allowed": current < FREE_ITEM_LIMIT,
        "current": current,
        "limit": FREE_ITEM_LIMIT,
    }


def check_and_increment_scan(user_id: str) -> dict:
    """Check the monthly photo-scan limit and increment the counter if allowed.

    Returns {allowed, current, limit}.
    On Supabase errors the counter read defaults to 0 (permissive),
    but the gate still blocks once a persisted count >= FREE_SCAN_LIMIT.
    """
    if is_pro_user(user_id):
        return {"allowed": True, "current": 0, "limit": -1}

    month = get_current_month()
    client = get_supabase_admin()

    try:
        result = supabase_execute_with_retry(
            lambda: client.table("usage_counters")
            .select("count")
            .eq("user_id", user_id)
            .eq("feature", "photo_scan")
            .eq("month", month)
            .execute()
        )
        current = result.data[0]["count"] if result.data else 0
    except Exception:
        current = 0

    if current >= FREE_SCAN_LIMIT:
        return {"allowed": False, "current": current, "limit": FREE_SCAN_LIMIT}

    try:
        supabase_execute_with_retry(
            lambda: client.table("usage_counters")
            .upsert(
                {
                    "user_id": user_id,
                    "feature": "photo_scan",
                    "month": month,
                    "count": current + 1,
                    "updated_at": datetime.utcnow().isoformat(),
                },
                on_conflict="user_id,feature,month",
            )
            .execute()
        )
    except Exception as e:
        print(f"Failed to increment scan counter: {e}")

    return {"allowed": True, "current": current + 1, "limit": FREE_SCAN_LIMIT}
