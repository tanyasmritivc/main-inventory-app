from __future__ import annotations

from datetime import datetime

from app.services.supabase_client import get_supabase_admin, supabase_execute_with_retry

FREE_ITEM_LIMIT = 30
FREE_SCAN_LIMIT = 5


def get_current_month() -> str:
    return datetime.utcnow().strftime("%Y-%m")


def is_pro_user(user_id: str) -> bool:
    """Stripe not wired yet — all users are free tier."""
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


def get_usage_status(user_id: str) -> dict:
    """Full usage summary for a user."""
    pro = is_pro_user(user_id)
    client = get_supabase_admin()

    try:
        item_result = supabase_execute_with_retry(
            lambda: client.table("items")
            .select("item_id", count="exact")
            .eq("user_id", user_id)
            .execute()
        )
        item_count = item_result.count or 0
    except Exception:
        item_count = 0

    month = get_current_month()
    try:
        scan_result = supabase_execute_with_retry(
            lambda: client.table("usage_counters")
            .select("count")
            .eq("user_id", user_id)
            .eq("feature", "photo_scan")
            .eq("month", month)
            .execute()
        )
        scan_count = scan_result.data[0]["count"] if scan_result.data else 0
    except Exception:
        scan_count = 0

    return {
        "is_pro": pro,
        "items": {
            "current": item_count,
            "limit": -1 if pro else FREE_ITEM_LIMIT,
            "remaining": -1 if pro else max(0, FREE_ITEM_LIMIT - item_count),
        },
        "photo_scans": {
            "current": scan_count,
            "limit": -1 if pro else FREE_SCAN_LIMIT,
            "remaining": -1 if pro else max(0, FREE_SCAN_LIMIT - scan_count),
            "month": month,
        },
    }
