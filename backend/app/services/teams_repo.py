"""
Team database operations for the program-team plan model.
Uses team_memberships (NOT team_members, which belongs to the old sharing system).
All functions are synchronous (supabase-py is blocking).
Exactly-one-owner invariant is enforced here, not in the DB.
"""

import logging
import random
from datetime import datetime, timezone

from app.services.supabase_client import get_supabase_admin, supabase_execute_with_retry

logger = logging.getLogger(__name__)

# join_code charset: A-Z minus I/O; 0-9 minus 0/1 → 32 unambiguous chars
_CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

VALID_PROGRAMS = frozenset(("ftc", "frc", "vex", "fll"))
VALID_PLANS = frozenset(("free_rookie", "ftc_season", "frc_season", "district"))
VALID_ROLES = frozenset(("owner", "mentor", "member", "viewer"))


def _gen_join_code() -> str:
    return "".join(random.choices(_CODE_CHARS, k=6))


def _unique_join_code() -> str:
    supabase = get_supabase_admin()
    for _ in range(10):
        code = _gen_join_code()
        resp = supabase_execute_with_retry(
            lambda c=code: supabase.table("teams")
            .select("team_id")
            .eq("join_code", c)
            .execute()
        )
        if not (resp.data or []):
            return code
    raise RuntimeError("Could not generate a unique join code after 10 attempts")


# ── CRUD ───────────────────────────────────────────────────────────────────────

def create_team(*, user_id: str, name: str, program: str) -> dict:
    """Create a team and insert the caller as owner. Returns the team row."""
    name = (name or "").strip()
    program = (program or "").lower().strip()
    if not name:
        raise ValueError("Team name is required")
    if program not in VALID_PROGRAMS:
        raise ValueError(f"Invalid program '{program}'; must be one of {sorted(VALID_PROGRAMS)}")

    supabase = get_supabase_admin()
    join_code = _unique_join_code()

    team_resp = supabase_execute_with_retry(
        lambda: supabase.table("teams").insert({
            "name": name,
            "owner_user_id": user_id,
            "program": program,
            "join_code": join_code,
        }).execute()
    )
    team = (team_resp.data or [{}])[0]
    team_id = team["team_id"]

    supabase_execute_with_retry(
        lambda: supabase.table("team_memberships").insert({
            "team_id": team_id,
            "user_id": user_id,
            "role": "owner",
        }).execute()
    )
    return team


def join_team(*, user_id: str, code: str) -> dict:
    """
    Join a team by 6-char code. Idempotent — returns existing membership if
    already a member. Raises ValueError("NOT_FOUND") on bad code.
    """
    code = (code or "").strip().upper()
    supabase = get_supabase_admin()

    team_resp = supabase_execute_with_retry(
        lambda: supabase.table("teams")
        .select("team_id, name, program, plan, plan_expires_at, owner_user_id")
        .eq("join_code", code)
        .execute()
    )
    if not (team_resp.data or []):
        raise ValueError("NOT_FOUND")
    team = team_resp.data[0]
    team_id = team["team_id"]

    existing = supabase_execute_with_retry(
        lambda: supabase.table("team_memberships")
        .select("member_id, role, joined_at")
        .eq("team_id", team_id)
        .eq("user_id", user_id)
        .execute()
    )
    if existing.data:
        return {**team, **existing.data[0]}

    member_resp = supabase_execute_with_retry(
        lambda: supabase.table("team_memberships").insert({
            "team_id": team_id,
            "user_id": user_id,
            "role": "member",
        }).execute()
    )
    return {**team, **(member_resp.data or [{}])[0]}


def list_user_teams(*, user_id: str) -> list[dict]:
    """Return all teams the user belongs to, with their role."""
    supabase = get_supabase_admin()
    members_resp = supabase_execute_with_retry(
        lambda: supabase.table("team_memberships")
        .select("team_id, role, joined_at")
        .eq("user_id", user_id)
        .execute()
    )
    if not (members_resp.data or []):
        return []

    team_ids = [m["team_id"] for m in members_resp.data]
    teams_resp = supabase_execute_with_retry(
        lambda: supabase.table("teams")
        .select("team_id, name, program, plan, plan_expires_at, join_code, owner_user_id, created_at")
        .in_("team_id", team_ids)
        .execute()
    )
    team_map = {t["team_id"]: t for t in (teams_resp.data or [])}

    result = []
    for m in members_resp.data:
        t = team_map.get(m["team_id"])
        if t:
            result.append({**t, "role": m["role"], "joined_at": m["joined_at"]})
    return result


def list_team_members(*, user_id: str, team_id: str) -> list[dict]:
    """
    Return all members of a team. Caller must be a member (any role).
    Raises PermissionError("NOT_MEMBER") if not.
    """
    supabase = get_supabase_admin()
    caller_resp = supabase_execute_with_retry(
        lambda: supabase.table("team_memberships")
        .select("role")
        .eq("team_id", team_id)
        .eq("user_id", user_id)
        .execute()
    )
    if not (caller_resp.data or []):
        raise PermissionError("NOT_MEMBER")

    resp = supabase_execute_with_retry(
        lambda: supabase.table("team_memberships")
        .select("member_id, user_id, role, joined_at")
        .eq("team_id", team_id)
        .order("joined_at")
        .execute()
    )
    return resp.data or []


def update_member_role(
    *, requesting_user_id: str, team_id: str, target_user_id: str, new_role: str
) -> dict:
    """
    Change a member's role. Rules:
    - Only owner can grant 'mentor'.
    - owner/mentor can change member↔viewer.
    - Cannot demote the owner.
    Raises PermissionError or ValueError with a status key as message.
    """
    if new_role not in ("mentor", "member", "viewer"):
        raise ValueError("INVALID_ROLE")

    supabase = get_supabase_admin()

    caller_resp = supabase_execute_with_retry(
        lambda: supabase.table("team_memberships")
        .select("role")
        .eq("team_id", team_id)
        .eq("user_id", requesting_user_id)
        .execute()
    )
    if not (caller_resp.data or []):
        raise PermissionError("NOT_MEMBER")
    caller_role = caller_resp.data[0]["role"]

    target_resp = supabase_execute_with_retry(
        lambda: supabase.table("team_memberships")
        .select("member_id, role")
        .eq("team_id", team_id)
        .eq("user_id", target_user_id)
        .execute()
    )
    if not (target_resp.data or []):
        raise ValueError("TARGET_NOT_MEMBER")
    target_row = target_resp.data[0]

    if target_row["role"] == "owner":
        raise PermissionError("CANNOT_CHANGE_OWNER")
    if caller_role not in ("owner", "mentor"):
        raise PermissionError("INSUFFICIENT_ROLE")
    if new_role == "mentor" and caller_role != "owner":
        raise PermissionError("ONLY_OWNER_CAN_GRANT_MENTOR")

    resp = supabase_execute_with_retry(
        lambda: supabase.table("team_memberships")
        .update({"role": new_role})
        .eq("member_id", target_row["member_id"])
        .execute()
    )
    return (resp.data or [{}])[0]


def remove_member(*, requesting_user_id: str, team_id: str, target_user_id: str) -> bool:
    """
    Remove a member. owner/mentor can remove member/viewer; owner cannot be removed.
    Returns False (idempotent) if target is already gone.
    Raises PermissionError with a status key as message.
    """
    supabase = get_supabase_admin()

    caller_resp = supabase_execute_with_retry(
        lambda: supabase.table("team_memberships")
        .select("role")
        .eq("team_id", team_id)
        .eq("user_id", requesting_user_id)
        .execute()
    )
    if not (caller_resp.data or []):
        raise PermissionError("NOT_MEMBER")
    caller_role = caller_resp.data[0]["role"]

    target_resp = supabase_execute_with_retry(
        lambda: supabase.table("team_memberships")
        .select("member_id, role")
        .eq("team_id", team_id)
        .eq("user_id", target_user_id)
        .execute()
    )
    if not (target_resp.data or []):
        return False  # already gone — idempotent

    target_row = target_resp.data[0]
    if target_row["role"] == "owner":
        raise PermissionError("CANNOT_REMOVE_OWNER")
    if caller_role not in ("owner", "mentor"):
        raise PermissionError("INSUFFICIENT_ROLE")

    supabase_execute_with_retry(
        lambda: supabase.table("team_memberships")
        .delete()
        .eq("member_id", target_row["member_id"])
        .execute()
    )
    return True


# ── License redemption ─────────────────────────────────────────────────────────

def apply_license_to_team(*, team_id: str, owner_user_id: str, code: str) -> dict:
    """
    Redeem a license code and apply its plan to the team.
    Raises:
      PermissionError("OWNER_ONLY")        — caller is not the team owner
      ValueError("TEAM_NOT_FOUND")
      ValueError("NOT_FOUND")              — no license with this code
      ValueError("ALREADY_REDEEMED")       — license has been redeemed
      ValueError("EXPIRED")               — license.expires_at is in the past
    Returns the updated license row.
    """
    supabase = get_supabase_admin()

    team_resp = supabase_execute_with_retry(
        lambda: supabase.table("teams")
        .select("team_id, owner_user_id")
        .eq("team_id", team_id)
        .execute()
    )
    if not (team_resp.data or []):
        raise ValueError("TEAM_NOT_FOUND")
    if team_resp.data[0]["owner_user_id"] != owner_user_id:
        raise PermissionError("OWNER_ONLY")

    lic_resp = supabase_execute_with_retry(
        lambda: supabase.table("licenses")
        .select("*")
        .eq("code", code)
        .execute()
    )
    if not (lic_resp.data or []):
        raise ValueError("NOT_FOUND")
    lic = lic_resp.data[0]

    if lic.get("redeemed_by"):
        raise ValueError("ALREADY_REDEEMED")

    now = datetime.now(timezone.utc)
    expires_at_str = lic.get("expires_at") or ""
    if expires_at_str and expires_at_str < now.isoformat():
        raise ValueError("EXPIRED")

    supabase_execute_with_retry(
        lambda: supabase.table("teams").update({
            "plan": lic["plan"],
            "plan_expires_at": expires_at_str,
        }).eq("team_id", team_id).execute()
    )
    now_iso = now.isoformat()
    supabase_execute_with_retry(
        lambda: supabase.table("licenses").update({
            "redeemed_by": team_id,
            "redeemed_at": now_iso,
        }).eq("code", code).execute()
    )
    return {**lic, "redeemed_by": team_id, "redeemed_at": now_iso}


# ── Helpers used by limit checks ───────────────────────────────────────────────

def get_active_team_plan(*, user_id: str) -> tuple[str | None, str | None]:
    """
    Return (plan, team_id) for the first team the user belongs to that has a
    non-null plan with plan_expires_at > now(). Returns (None, None) if none.
    """
    supabase = get_supabase_admin()
    now_iso = datetime.now(timezone.utc).isoformat()

    members_resp = supabase_execute_with_retry(
        lambda: supabase.table("team_memberships")
        .select("team_id")
        .eq("user_id", user_id)
        .execute()
    )
    team_ids = [m["team_id"] for m in (members_resp.data or [])]
    if not team_ids:
        return None, None

    teams_resp = supabase_execute_with_retry(
        lambda: supabase.table("teams")
        .select("team_id, plan, plan_expires_at")
        .in_("team_id", team_ids)
        .not_.is_("plan", "null")
        .execute()
    )
    for team in (teams_resp.data or []):
        plan = team.get("plan")
        expires_at = team.get("plan_expires_at") or ""
        if plan and expires_at > now_iso:
            return plan, team["team_id"]
    return None, None


def is_viewer_in_any_team(*, user_id: str) -> bool:
    """True if the user has role='viewer' in any team_memberships row."""
    supabase = get_supabase_admin()
    resp = supabase_execute_with_retry(
        lambda: supabase.table("team_memberships")
        .select("member_id")
        .eq("user_id", user_id)
        .eq("role", "viewer")
        .limit(1)
        .execute()
    )
    return bool(resp.data)
