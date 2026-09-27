from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.supabase_client import get_supabase_admin

router = APIRouter(prefix="/workspaces", tags=["workspaces"])


class CreateWorkspaceRequest(BaseModel):
    name: str = Field(min_length=1, max_length=200)


def _personal_workspace(user_id: str) -> dict:
    client = get_supabase_admin()
    rows = client.table("workspaces").select("*").eq(
        "owner_user_id", user_id
    ).eq("kind", "personal").limit(1).execute().data or []
    if rows:
        return rows[0]
    try:
        created = client.table("workspaces").insert({
            "name": "My inventory", "kind": "personal", "owner_user_id": user_id,
        }).execute().data or []
    except Exception:
        concurrent = client.table("workspaces").select("*").eq(
            "owner_user_id", user_id
        ).eq("kind", "personal").limit(1).execute().data or []
        if concurrent:
            return concurrent[0]
        raise
    if not created:
        raise HTTPException(503, "Could not open your workspace. Please try again.")
    workspace = created[0]
    return workspace


@router.get("")
def list_workspaces(user: AuthenticatedUser = Depends(get_current_user)):
    personal = _personal_workspace(user.user_id)
    client = get_supabase_admin()
    memberships = client.table("workspace_members").select(
        "workspace_id,role"
    ).eq("user_id", user.user_id).execute().data or []
    ids = [row["workspace_id"] for row in memberships]
    rows = client.table("workspaces").select("*").in_(
        "workspace_id", ids
    ).order("created_at").execute().data or []
    roles = {row["workspace_id"]: row["role"] for row in memberships}
    return {"workspaces": [
        {**row, "role": roles[row["workspace_id"]]} for row in rows
    ], "default_workspace_id": personal["workspace_id"]}


@router.post("")
def create_workspace(
    payload: CreateWorkspaceRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    name = payload.name.strip()
    if not name:
        raise HTTPException(422, "Enter a workspace name.")
    client = get_supabase_admin()
    created = client.table("workspaces").insert({
        "name": name, "kind": "shared", "owner_user_id": user.user_id,
    }).execute().data or []
    if not created:
        raise HTTPException(503, "Could not create the workspace. Please try again.")
    workspace = created[0]
    return {"workspace": {**workspace, "role": "owner"}}
