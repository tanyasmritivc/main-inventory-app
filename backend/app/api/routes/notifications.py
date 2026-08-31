from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.supabase_client import get_supabase_admin

router = APIRouter(prefix="/notifications", tags=["notifications"])
NOTIFICATION_HISTORY_DAYS = 14


def _history_cutoff() -> str:
    return (datetime.now(timezone.utc) - timedelta(days=NOTIFICATION_HISTORY_DAYS)).isoformat()


def _team_ids(user_id: str) -> list[str]:
    rows = get_supabase_admin().table("team_memberships").select("team_id").eq(
        "user_id", user_id
    ).execute().data or []
    return [row["team_id"] for row in rows]


def _task_title_from_summary(summary: str) -> str:
    for prefix, suffix in (
        ("Added ", " to the Team Board"),
        ("Completed ", ""),
        ("Updated ", ""),
    ):
        if summary.startswith(prefix) and (not suffix or summary.endswith(suffix)):
            end = -len(suffix) if suffix else None
            return summary[len(prefix):end].strip()
    return ""


def _presentation(row: dict, actor_name: str, task: dict | None) -> tuple[str, str]:
    action = row.get("action", "")
    metadata = row.get("metadata") or {}
    if action.startswith("task_"):
        task_type = metadata.get("task_type") or (task or {}).get("task_type") or "task"
        label = {
            "task": "Task",
            "part_request": "Part Request",
            "checklist": "Checklist",
        }.get(task_type, "Team Board")
        title = (
            metadata.get("title")
            or (task or {}).get("title")
            or _task_title_from_summary(row.get("summary", ""))
        )
        verb = {
            "task_created": "created",
            "task_updated": "updated",
            "task_completed": "completed",
            "task_deleted": "deleted",
        }.get(action, "updated")
        subject = f"the {label.lower()}"
        text = f"{actor_name} {verb} {subject}"
        if title:
            text += f": {title}"
        return label, text
    label = "Team"
    if action.startswith("space_"):
        label = "Space"
    elif action.startswith("item_"):
        label = "Inventory"
    elif action.startswith("member_"):
        label = "People"
    summary = (row.get("summary") or "updated the team").strip()
    described = summary[:1].lower() + summary[1:] if summary else "updated the team"
    return label, f"{actor_name} {described}"


@router.get("")
def list_notifications(user: AuthenticatedUser = Depends(get_current_user)):
    team_ids = _team_ids(user.user_id)
    if not team_ids:
        return {"notifications": [], "unread_count": 0}
    client = get_supabase_admin()
    activity = client.table("team_activity").select("*").in_(
        "team_id", team_ids
    ).gte("created_at", _history_cutoff()).order(
        "created_at", desc=True
    ).limit(100).execute().data or []
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
    task_ids = list({
        (row.get("metadata") or {}).get("task_id")
        for row in activity
        if row.get("action", "").startswith("task_")
        and (row.get("metadata") or {}).get("task_id")
    })
    board_tasks = []
    if task_ids:
        board_tasks = client.table("team_board_tasks").select(
            "task_id,title,task_type"
        ).in_("task_id", task_ids).execute().data or []
    tasks_by_id = {row["task_id"]: row for row in board_tasks}
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
        actor_name = "You" if is_own else actor_names.get(row.get("actor_id"), "Team member")
        task_id = (row.get("metadata") or {}).get("task_id")
        activity_type, display_text = _presentation(
            row, actor_name, tasks_by_id.get(task_id)
        )
        result.append({
            **row,
            "team_name": team_names.get(row["team_id"], "Team"),
            "actor_name": actor_name,
            "activity_type": activity_type,
            "display_text": display_text,
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
    ).in_("team_id", team_ids).neq(
        "actor_id", user.user_id
    ).gte("created_at", _history_cutoff()).execute().data or []
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
