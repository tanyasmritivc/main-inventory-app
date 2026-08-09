
import logging
from datetime import datetime

from fastapi import HTTPException

from app.services.supabase_client import get_supabase_admin, supabase_execute_with_retry

logger = logging.getLogger(__name__)

# Free tier limits (keyed by feature name used in usage_limits table)
FREE_LIMITS = {
    "ai_chat": 20,           # messages per month
    "photo_scan": 10,        # photo uploads per month
    "spreadsheet_import": 2, # imports per month
    "barcode_scan": 10,      # scans per month
    "share_space": 1,        # active shares total (not monthly)
    "spaces": 3,             # total spaces (not monthly)
}

# Pro tier limits for features tracked via usage_limits (not via usage_counters)
PRO_LIMITS = {
    "ai_chat": 1_000,
    "photo_scan": 300,
    "spreadsheet_import": 20,
    "barcode_scan": None,    # unlimited
    "share_space": None,     # unlimited
    "spaces": None,          # unlimited
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
    Raises HTTPException(503) if the is_pro DB check fails after retries,
    so callers receive a clear service-unavailable signal rather than
    silently being treated as free-tier.
    """
    # FIX 1: retry is_pro query up to 3x (via supabase_execute_with_retry);
    # log and raise 503 on final failure instead of silently demoting to free.
    try:
        profile = supabase_execute_with_retry(
            lambda: get_supabase_admin()
                .table("profiles")
                .select("is_pro")
                .eq("id", user_id)
                .execute()
        )
        is_pro = profile.data[0].get("is_pro", False) if profile.data else False
    except Exception as exc:
        logger.error(
            "check_limit: is_pro query failed for user_id=%s after retries — returning 503. "
            "Error: %s",
            user_id, exc,
        )
        raise HTTPException(
            status_code=503,
            detail={
                "error": "usage_check_failed",
                "detail": "Unable to verify subscription status. Please try again in a moment.",
            },
        )

    if is_pro:
        pro_limit = PRO_LIMITS.get(feature)
        if pro_limit is None:
            # truly unlimited
            return {
                "allowed": True,
                "is_pro": True,
                "current": 0,
                "limit": None,
                "feature_label": FEATURE_LABELS.get(feature, feature),
            }
        current = await get_usage_count(user_id, feature)
        return {
            "allowed": current < pro_limit,
            "is_pro": True,
            "current": current,
            "limit": pro_limit,
            "feature_label": FEATURE_LABELS.get(feature, feature),
        }

    plan = await get_user_plan(user_id)
    if plan == "pro":
        pro_limit = PRO_LIMITS.get(feature)
        if pro_limit is None:
            return {"allowed": True, "current": 0, "limit": None, "feature_label": FEATURE_LABELS.get(feature, feature)}
        current = await get_usage_count(user_id, feature)
        return {"allowed": current < pro_limit, "current": current, "limit": pro_limit, "feature_label": FEATURE_LABELS.get(feature, feature)}

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
    """
    Increment usage count. Returns new count.
    FIX 3: uses atomic DB function (increment_usage_count RPC) to avoid the
    read-modify-write race where two concurrent requests both read N and both
    write N+1. Falls back to the old read-modify-write if the RPC is not yet
    deployed (logs a warning so the gap is visible).
    """
    # Don't track usage for Pro users
    try:
        client = get_supabase_admin()
        profile = client.table("profiles").select("is_pro").eq("id", user_id).execute()
        is_pro = profile.data[0].get("is_pro", False) if profile.data else False
        if is_pro:
            return 0
    except Exception:
        pass

    try:
        # Total limits don't need incrementing (they're derived from real data)
        if feature in ("spaces", "share_space"):
            return await get_usage_count(user_id, feature)

        period = get_current_period()
        supabase = get_supabase_admin()

        result = supabase.rpc(
            "increment_usage_count",
            {"p_user_id": user_id, "p_feature": feature, "p_period": period},
        ).execute()

        data = result.data
        if isinstance(data, int):
            return data
        if isinstance(data, list) and data:
            first = data[0]
            if isinstance(first, int):
                return first
            if isinstance(first, dict):
                return int(next(iter(first.values()), 0))
        return 0

    except Exception as exc:
        # RPC not yet deployed — fall back to read-modify-write and warn loudly.
        # Run migration 007_atomic_usage_increment.sql to eliminate this path.
        logger.warning(
            "increment_usage: RPC increment_usage_count failed for user_id=%s feature=%s "
            "— falling back to non-atomic read-modify-write. "
            "Apply migration 007_atomic_usage_increment.sql to fix this. Error: %s",
            user_id, feature, exc,
        )
        try:
            supabase = get_supabase_admin()
            period = get_current_period()
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
        except Exception as e2:
            logger.error("increment_usage: fallback read-modify-write also failed: %s", e2)
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
    """
    Compatibility shim: returns True for 'pro' and 'team_member' tiers.
    Reads profiles.tier (added in migration 010); falls back to profiles.is_pro.
    """
    from app.services.limits import get_user_tier
    return get_user_tier(user_id) in ("pro", "team_member")


def check_item_limit(user_id: str) -> dict:
    """Sync item count check — delegates to limits.check_item_limit."""
    from app.services.limits import check_item_limit as _limits_check_item
    return _limits_check_item(user_id)
