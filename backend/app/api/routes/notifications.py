from datetime import datetime, timezone

from fastapi import APIRouter, Depends

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.supabase_client import get_supabase_admin

router = APIRouter(prefix="/notifications", tags=["notifications"])


def _team_ids(user_id: str) -> list[str]:
    rows = get_supabase_admin().table("team_memberships").select("team_id").eq(
        "user_id", user_id
    ).execute().data or []
    return [row["team_id"] for row in rows]


@router.get("")
def list_notifications(user: AuthenticatedUser = Depends(get_current_user)):
    team_ids = _team_ids(user.user_id)
    if not team_ids:
        return {"notifications": [], "unread_count": 0}
    client = get_supabase_admin()
    activity = client.table("team_activity").select("*").in_(
        "team_id", team_ids
    ).order("created_at", desc=True).limit(100).execute().data or []
    teams = client.table("teams").select("team_id,name").in_(
        "team_id", team_ids
    ).execute().data or []
    team_names = {row["team_id"]: row["name"] for row in teams}
    actor_ids = list({row.get("actor_id") for row in activity if row.get("actor_id")})
    profiles = []
    if actor_ids:
        profiles = client.table("profiles").select(
            "id,display_name,first_name,last_name"
        ).in_("id", actor_ids).execute().data or []
    actor_names = {}
    for profile in profiles:
        fallback = " ".join(
            part for part in (profile.get("first_name"), profile.get("last_name")) if part
        ).strip()
        actor_names[profile["id"]] = profile.get("display_name") or fallback or "Team member"
    activity_ids = [row["activity_id"] for row in activity]
    reads = []
    if activity_ids:
        reads = client.table("team_notification_reads").select("activity_id").eq(
            "user_id", user.user_id
        ).in_("activity_id", activity_ids).execute().data or []
    read_ids = {row["activity_id"] for row in reads}
    result = []
    unread = 0
    for row in activity:
        is_own = row.get("actor_id") == user.user_id
        is_read = is_own or row["activity_id"] in read_ids
        if not is_read:
            unread += 1
        result.append({
            **row,
            "team_name": team_names.get(row["team_id"], "Team"),
            "actor_name": "You" if is_own else actor_names.get(row.get("actor_id"), "Team member"),
            "is_read": is_read,
        })
    return {"notifications": result, "unread_count": unread}


@router.post("/read")
def mark_notifications_read(user: AuthenticatedUser = Depends(get_current_user)):
    team_ids = _team_ids(user.user_id)
    if not team_ids:
        return {"marked_read": 0}
    activity = get_supabase_admin().table("team_activity").select(
        "activity_id,actor_id"
    ).in_("team_id", team_ids).neq("actor_id", user.user_id).execute().data or []
    rows = [{
        "user_id": user.user_id,
        "activity_id": row["activity_id"],
        "read_at": datetime.now(timezone.utc).isoformat(),
    } for row in activity]
    if rows:
        get_supabase_admin().table("team_notification_reads").upsert(
            rows, on_conflict="user_id,activity_id"
        ).execute()
    return {"marked_read": len(rows)}
