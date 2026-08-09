"""
Single source of truth for tier-based usage limits.

Tiers: free, pro, team_member
All functions are synchronous (supabase-py is blocking).
"""

import logging
from datetime import datetime, timedelta, timezone

from app.services.supabase_client import get_supabase_admin, supabase_execute_with_retry

logger = logging.getLogger(__name__)


# ── Tier configuration ─────────────────────────────────────────────────────────

LIMITS: dict[str, dict] = {
    "free": {
        "items": 30,
        "spaces": 3,
        "chats_per_month": 20,
        "scans_per_month": 10,
        "scans_per_day": None,      # no daily cap on free tier
    },
    "pro": {
        "items": None,              # unlimited
        "spaces": None,
        "chats_per_month": 1_000,
        "scans_per_month": 300,
        "scans_per_day": 30,
    },
    "team_member": {
        "items": None,
        "spaces": None,
        "chats_per_month": 1_000,
        "scans_per_month": 300,
        "scans_per_day": 30,
    },
}


# ── Exceptions ─────────────────────────────────────────────────────────────────

class ChatLimitExceeded(Exception):
    def __init__(self, resets_at: str, current: int, limit: int):
        self.resets_at = resets_at
        self.current = current
        self.limit = limit
        super().__init__(f"Monthly chat limit {limit} reached ({current} used); resets {resets_at}")


class ScanLimitExceeded(Exception):
    def __init__(self, resets_at: str, current: int, limit: int, daily: bool = False):
        self.resets_at = resets_at
        self.current = current
        self.limit = limit
        self.daily = daily
        super().__init__(
            f"{'Daily' if daily else 'Monthly'} scan limit {limit} reached ({current} used); "
            f"resets {resets_at}"
        )


# ── Internal helpers ────────────────────────────────────────────────────────────

def _current_period() -> str:
    now = datetime.now(timezone.utc)
    return f"{now.year}-{now.month:02d}"


def _month_resets_at() -> str:
    now = datetime.now(timezone.utc)
    if now.month == 12:
        nxt = datetime(now.year + 1, 1, 1, tzinfo=timezone.utc)
    else:
        nxt = datetime(now.year, now.month + 1, 1, tzinfo=timezone.utc)
    return nxt.isoformat()


def _day_resets_at() -> str:
    now = datetime.now(timezone.utc)
    tomorrow = (now + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
    return tomorrow.isoformat()


def _get_usage_counters(user_id: str, period: str) -> dict:
    """Read usage_counters row for this period; returns zeros if missing."""
    try:
        supabase = get_supabase_admin()
        resp = supabase_execute_with_retry(
            lambda: supabase.table("usage_counters")
            .select("chats_used, scans_used, scans_today, today")
            .eq("user_id", user_id)
            .eq("period", period)
            .execute()
        )
        if resp.data:
            row = resp.data[0]
            today_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
            scans_today = row.get("scans_today", 0) if str(row.get("today", "")) == today_str else 0
            return {
                "chats_used": row.get("chats_used", 0),
                "scans_used": row.get("scans_used", 0),
                "scans_today": scans_today,
            }
    except Exception as exc:
        logger.error("_get_usage_counters failed for user_id=%s: %s", user_id, exc)
    return {"chats_used": 0, "scans_used": 0, "scans_today": 0}


def _rpc_increment_chat(user_id: str, period: str) -> int:
    """Atomically increment chats_used. Returns new count."""
    try:
        supabase = get_supabase_admin()
        result = supabase.rpc(
            "increment_chat_usage",
            {"p_user_id": user_id, "p_period": period},
        ).execute()
        data = result.data
        if isinstance(data, list) and data:
            row = data[0]
            return int(row.get("chats_used", 0) if isinstance(row, dict) else row)
        return 0
    except Exception as exc:
        logger.error("_rpc_increment_chat failed for user_id=%s: %s", user_id, exc)
        return 0


def _rpc_increment_scan(user_id: str, period: str) -> dict:
    """Atomically increment scans_used + scans_today (reset today if date changed)."""
    try:
        supabase = get_supabase_admin()
        result = supabase.rpc(
            "increment_scan_usage",
            {"p_user_id": user_id, "p_period": period},
        ).execute()
        data = result.data
        if isinstance(data, list) and data:
            row = data[0]
            if isinstance(row, dict):
                return {
                    "scans_used": int(row.get("scans_used", 0)),
                    "scans_today": int(row.get("scans_today", 0)),
                }
        return {"scans_used": 0, "scans_today": 0}
    except Exception as exc:
        logger.error("_rpc_increment_scan failed for user_id=%s: %s", user_id, exc)
        return {"scans_used": 0, "scans_today": 0}


# ── Public API ─────────────────────────────────────────────────────────────────

def get_user_tier(user_id: str) -> str:
    """
    Read profiles.tier. Falls back to deriving from is_pro, then 'free'.
    Failure is logged and returns 'free' (safe default).
    """
    try:
        profile = supabase_execute_with_retry(
            lambda: get_supabase_admin()
            .table("profiles")
            .select("tier, is_pro")
            .eq("id", user_id)
            .execute()
        )
        if not profile.data:
            return "free"
        row = profile.data[0]
        tier = (row.get("tier") or "").strip()
        if tier in LIMITS:
            return tier
        return "pro" if row.get("is_pro") else "free"
    except Exception as exc:
        logger.error("get_user_tier failed for user_id=%s: %s", user_id, exc)
        return "free"


def check_and_increment_chat(user_id: str) -> None:
    """
    Check monthly chat limit then atomically increment.
    Raises ChatLimitExceeded if the cap is reached.
    Increments before the AI call to keep the optimistic-lock simple;
    failed calls are counted (acceptable at these volumes).
    """
    tier = get_user_tier(user_id)
    monthly_cap = LIMITS[tier]["chats_per_month"]
    period = _current_period()

    if monthly_cap is not None:
        counters = _get_usage_counters(user_id, period)
        if counters["chats_used"] >= monthly_cap:
            raise ChatLimitExceeded(
                resets_at=_month_resets_at(),
                current=counters["chats_used"],
                limit=monthly_cap,
            )

    _rpc_increment_chat(user_id, period)


def check_and_increment_scan(user_id: str) -> None:
    """
    Check monthly + daily scan limits then atomically increment.
    Raises ScanLimitExceeded if either cap is reached.
    """
    tier = get_user_tier(user_id)
    tier_limits = LIMITS[tier]
    monthly_cap = tier_limits["scans_per_month"]
    daily_cap = tier_limits["scans_per_day"]
    period = _current_period()

    counters = _get_usage_counters(user_id, period)

    if monthly_cap is not None and counters["scans_used"] >= monthly_cap:
        raise ScanLimitExceeded(
            resets_at=_month_resets_at(),
            current=counters["scans_used"],
            limit=monthly_cap,
            daily=False,
        )
    if daily_cap is not None and counters["scans_today"] >= daily_cap:
        raise ScanLimitExceeded(
            resets_at=_day_resets_at(),
            current=counters["scans_today"],
            limit=daily_cap,
            daily=True,
        )

    _rpc_increment_scan(user_id, period)


def check_item_limit(user_id: str) -> dict:
    """
    Count-based item limit check. Uses count(*) — never fetches rows.
    Returns {"allowed": bool, "current": int, "limit": int | None}.
    """
    tier = get_user_tier(user_id)
    max_items = LIMITS[tier]["items"]
    if max_items is None:
        return {"allowed": True, "current": 0, "limit": None}
    try:
        supabase = get_supabase_admin()
        result = supabase_execute_with_retry(
            lambda: supabase.table("items")
            .select("item_id", count="exact")
            .eq("user_id", user_id)
            .execute()
        )
        current = result.count or 0
    except Exception as exc:
        logger.error("check_item_limit: count query failed for user_id=%s: %s", user_id, exc)
        current = 0
    return {
        "allowed": current < max_items,
        "current": current,
        "limit": max_items,
    }


def get_limits_summary(user_id: str) -> dict:
    """
    Full limits snapshot for GET /me/limits.
    Uses count queries only — never fetches item rows.
    """
    from app.services.spaces_repo import count_spaces  # local import to avoid circular dep

    tier = get_user_tier(user_id)
    tier_limits = LIMITS[tier]
    period = _current_period()

    # Item count
    try:
        supabase = get_supabase_admin()
        item_resp = supabase_execute_with_retry(
            lambda: supabase.table("items")
            .select("item_id", count="exact")
            .eq("user_id", user_id)
            .execute()
        )
        item_count = item_resp.count or 0
    except Exception:
        item_count = 0

    # Space count
    try:
        space_count = count_spaces(user_id=user_id)
    except Exception:
        space_count = 0

    counters = _get_usage_counters(user_id, period)

    # Subscription plan info (best-effort — absence is not an error)
    plan_info: dict | None = None
    try:
        sub_resp = supabase_execute_with_retry(
            lambda: get_supabase_admin()
            .table("profiles")
            .select("subscription_plan, subscription_renews_at")
            .eq("id", user_id)
            .execute()
        )
        if sub_resp.data:
            row = sub_resp.data[0]
            sub_plan = row.get("subscription_plan")
            sub_renews_at = row.get("subscription_renews_at")
            if sub_plan:
                plan_info = {"name": sub_plan, "renews_at": sub_renews_at}
    except Exception:
        pass

    result: dict = {
        "tier": tier,
        "items": {
            "used": item_count,
            "max": tier_limits["items"],
        },
        "spaces": {
            "used": space_count,
            "max": tier_limits["spaces"],
        },
        "chats": {
            "used": counters["chats_used"],
            "max": tier_limits["chats_per_month"],
            "resets_at": _month_resets_at(),
        },
        "scans": {
            "used": counters["scans_used"],
            "max": tier_limits["scans_per_month"],
            "daily_used": counters["scans_today"],
            "daily_max": tier_limits["scans_per_day"],
            "resets_at": _month_resets_at(),
        },
    }
    if plan_info is not None:
        result["plan"] = plan_info
    return result
