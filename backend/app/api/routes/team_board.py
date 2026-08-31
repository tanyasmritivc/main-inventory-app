from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.supabase_client import get_supabase_admin
from app.services.push_notifications import enqueue_team_activity

router = APIRouter(prefix="/teams/{team_id}/board", tags=["team-board"])


class CreateBoardTask(BaseModel):
    title: str = Field(min_length=1, max_length=160)
    description: str = Field(default="", max_length=2000)
    task_type: Literal["task", "part_request", "checklist"] = "task"
    priority: Literal["normal", "high", "urgent"] = "normal"
    assigned_to: str | None = None
    inventory_item_id: str | None = None
    project_kit_id: str | None = None
    due_at: datetime | None = None


class UpdateBoardTask(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=160)
    description: str | None = Field(default=None, max_length=2000)
    status: Literal["todo", "doing", "done"] | None = None
    priority: Literal["normal", "high", "urgent"] | None = None
    assigned_to: str | None = None
    clear_assignee: bool = False
    due_at: datetime | None = None


def _membership(team_id: str, user_id: str) -> dict:
    rows = get_supabase_admin().table("team_memberships").select(
        "member_id,role").eq("team_id", team_id).eq("user_id", user_id).limit(1).execute().data or []
    if not rows:
        raise HTTPException(403, "You are not a member of this team.")
    return rows[0]


def _require_editor(team_id: str, user_id: str) -> dict:
    membership = _membership(team_id, user_id)
    if membership["role"] == "viewer":
        raise HTTPException(403, "You have view-only access to this team board.")
    return membership


def _validate_assignee(team_id: str, assigned_to: str | None) -> None:
    if not assigned_to:
        return
    rows = get_supabase_admin().table("team_memberships").select("member_id").eq(
        "team_id", team_id).eq("user_id", assigned_to).limit(1).execute().data or []
    if not rows:
        raise HTTPException(422, "Choose a current team member as the assignee.")


def _record(team_id: str, actor_id: str, action: str, summary: str, metadata: dict) -> None:
    get_supabase_admin().table("team_activity").insert({
        "team_id": team_id,
        "actor_id": actor_id,
        "action": action,
        "summary": summary,
        "metadata": metadata,
    }).execute()
    enqueue_team_activity(team_id, actor_id, summary, action)


@router.get("")
def list_board_tasks(team_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    membership = _membership(team_id, user.user_id)
    tasks = get_supabase_admin().table("team_board_tasks").select("*").eq(
        "team_id", team_id).order("updated_at", desc=True).execute().data or []
    return {"tasks": tasks, "role": membership["role"]}


@router.post("")
def create_board_task(
    team_id: str,
    body: CreateBoardTask,
    user: AuthenticatedUser = Depends(get_current_user),
):
    _require_editor(team_id, user.user_id)
    if not body.title.strip():
        raise HTTPException(422, "Enter a task title.")
    _validate_assignee(team_id, body.assigned_to)
    payload = body.model_dump(mode="json")
    payload.update({
        "team_id": team_id,
        "created_by": user.user_id,
        "title": body.title.strip(),
        "description": body.description.strip(),
    })
    created = get_supabase_admin().table("team_board_tasks").insert(payload).execute().data or []
    if not created:
        raise HTTPException(500, "The team task could not be created.")
    _record(
        team_id,
        user.user_id,
        "task_created",
        f"Added {body.title.strip()} to the Team Board",
        {
            "task_id": created[0]["task_id"],
            "assigned_to": body.assigned_to,
            "task_type": body.task_type,
            "title": body.title.strip(),
        },
    )
    return {"task": created[0]}


@router.patch("/{task_id}")
def update_board_task(
    team_id: str,
    task_id: str,
    body: UpdateBoardTask,
    user: AuthenticatedUser = Depends(get_current_user),
):
    _require_editor(team_id, user.user_id)
    existing = get_supabase_admin().table("team_board_tasks").select("task_id").eq(
        "task_id", task_id).eq("team_id", team_id).limit(1).execute().data or []
    if not existing:
        raise HTTPException(404, "This team task no longer exists.")
    updates = body.model_dump(exclude_none=True, exclude={"clear_assignee"}, mode="json")
    if body.clear_assignee:
        updates["assigned_to"] = None
    _validate_assignee(team_id, updates.get("assigned_to"))
    if "title" in updates:
        updates["title"] = updates["title"].strip()
        if not updates["title"]:
            raise HTTPException(422, "Enter a task title.")
    if "description" in updates:
        updates["description"] = updates["description"].strip()
    updates["updated_at"] = datetime.now(timezone.utc).isoformat()
    changed = get_supabase_admin().table("team_board_tasks").update(updates).eq(
        "task_id", task_id).eq("team_id", team_id).execute().data or []
    if not changed:
        raise HTTPException(500, "The team task could not be updated.")
    completed = updates.get("status") == "done"
    _record(
        team_id,
        user.user_id,
        "task_completed" if completed else "task_updated",
        f"{'Completed' if completed else 'Updated'} {changed[0]['title']}",
        {
            "task_id": task_id,
            "assigned_to": changed[0].get("assigned_to"),
            "task_type": changed[0].get("task_type"),
            "title": changed[0]["title"],
        },
    )
    return {"task": changed[0]}


@router.delete("/{task_id}")
def delete_board_task(
    team_id: str,
    task_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    membership = _require_editor(team_id, user.user_id)
    rows = get_supabase_admin().table("team_board_tasks").select("created_by,title,task_type").eq(
        "task_id", task_id).eq("team_id", team_id).limit(1).execute().data or []
    if not rows:
        return {"deleted": True}
    if rows[0]["created_by"] != user.user_id and membership["role"] not in ("owner", "mentor"):
        raise HTTPException(403, "Only the creator, owner, or mentor can delete this team task.")
    get_supabase_admin().table("team_board_tasks").delete().eq(
        "task_id", task_id).eq("team_id", team_id).execute()
    _record(
        team_id,
        user.user_id,
        "task_deleted",
        f"Deleted {rows[0]['title']}",
        {
            "task_id": task_id,
            "task_type": rows[0].get("task_type"),
            "title": rows[0]["title"],
        },
    )
    return {"deleted": True}
