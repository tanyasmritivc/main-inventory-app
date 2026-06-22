from __future__ import annotations

from datetime import datetime

from app.services.supabase_client import get_supabase_admin

# Free tier limits
FREE_LIMITS = {
    "ai_chat": 20,           # messages per month
    "photo_scan": 5,         # photo uploads per month
    "spreadsheet_import": 2, # imports per month
    "barcode_scan": 10,      # scans per month
    "share_space": 1,        # active shares total (not monthly)
    "spaces": 3,             # total spaces (not monthly)
}

FEATURE_LABELS = {
    "ai_chat": "AI chat messages",
    "photo_scan": "photo scans",
    "spreadsheet_import": "spreadsheet imports",
    "barcode_scan": "barcode scans",
    "share_space": "active shares",
    "spaces": "spaces",
}


def get_current_period() -> str:
    now = datetime.utcnow()
    return f"{now.year}-{now.month:02d}"


async def get_user_plan(user_id: str) -> str:
    """Returns 'free' or 'pro'"""
    try:
        supabase = get_supabase_admin()
        res = supabase.table("user_plan").select("plan").eq("user_id", user_id).single().execute()
        return res.data.get("plan", "free") if res.data else "free"
    except Exception:
        return "free"


async def get_usage_count(user_id: str, feature: str) -> int:
    """Get current usage count for a feature this month"""
    try:
        supabase = get_supabase_admin()
        # Total limits (not monthly)
        if feature in ("spaces", "share_space"):
            if feature == "spaces":
                # Count unique locations from items
                res = supabase.table("items").select("location").eq("user_id", user_id).execute()
                locations = set(i["location"] for i in (res.data or []) if i.get("location"))
                return len(locations)
            else:
                # Count active shares
                res = supabase.table("team_shares").select("share_id").eq("owner_user_id", user_id).eq("is_active", True).execute()
                return len(res.data or [])

        # Monthly limits
        period = get_current_period()
        res = supabase.table("usage_limits").select("count").eq("user_id", user_id).eq("feature", feature).eq("period", period).execute()
        if res.data:
            return res.data[0].get("count", 0)
        return 0
    except Exception:
        return 0


async def check_limit(user_id: str, feature: str) -> dict:
    """
    Check if user has hit their limit.
    Returns: { allowed: bool, current: int, limit: int, feature_label: str }
    """
    plan = await get_user_plan(user_id)
    if plan == "pro":
        return {"allowed": True, "current": 0, "limit": -1, "feature_label": FEATURE_LABELS.get(feature, feature)}

    limit = FREE_LIMITS.get(feature, 999)
    current = await get_usage_count(user_id, feature)

    return {
        "allowed": current < limit,
        "current": current,
        "limit": limit,
        "feature_label": FEATURE_LABELS.get(feature, feature),
        "plan": plan,
    }


async def increment_usage(user_id: str, feature: str) -> int:
    """Increment usage count. Returns new count."""
    try:
        # Total limits don't need incrementing (they're derived from real data)
        if feature in ("spaces", "share_space"):
            return await get_usage_count(user_id, feature)

        supabase = get_supabase_admin()
        period = get_current_period()

        # Upsert usage record
        existing = supabase.table("usage_limits").select("id,count").eq("user_id", user_id).eq("feature", feature).eq("period", period).execute()

        if existing.data:
            new_count = existing.data[0]["count"] + 1
            supabase.table("usage_limits").update({
                "count": new_count,
                "updated_at": datetime.utcnow().isoformat(),
            }).eq("id", existing.data[0]["id"]).execute()
            return new_count
        else:
            supabase.table("usage_limits").insert({
                "user_id": user_id,
                "feature": feature,
                "count": 1,
                "period": period,
            }).execute()
            return 1
    except Exception as e:
        print(f"Usage increment error: {e}")
        return 0


async def get_all_usage(user_id: str) -> dict:
    """Get all usage counts for a user — used by frontend to show limits"""
    plan = await get_user_plan(user_id)
    result: dict = {}
    for feature, limit in FREE_LIMITS.items():
        current = await get_usage_count(user_id, feature)
        result[feature] = {
            "current": current,
            "limit": limit if plan == "free" else -1,
            "allowed": current < limit if plan == "free" else True,
            "feature_label": FEATURE_LABELS.get(feature, feature),
        }
    result["plan"] = plan
    return result


# ── Backward-compat shims (used by existing sync routes) ─────────────────────

FREE_ITEM_LIMIT = 30
FREE_SCAN_LIMIT = FREE_LIMITS["photo_scan"]


def get_current_month() -> str:
    return get_current_period()


def is_pro_user(user_id: str) -> bool:
    """Stripe not wired yet — all users are free tier."""
    return False


def check_item_limit(user_id: str) -> dict:
    """Sync item count check for add_item_route."""
    try:
        supabase = get_supabase_admin()
        result = supabase.table("items").select("item_id", count="exact").eq("user_id", user_id).execute()
        current = result.count or 0
    except Exception:
        current = 0
    return {
        "allowed": current < FREE_ITEM_LIMIT,
        "current": current,
        "limit": FREE_ITEM_LIMIT,
    }
