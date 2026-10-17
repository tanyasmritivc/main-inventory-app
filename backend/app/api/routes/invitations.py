"""Read-only, authenticated invitation previews. A preview never joins a user."""

from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel, Field

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.supabase_client import get_supabase_admin
from app.services.sharing_service import invitation_is_current

router = APIRouter(prefix="/invitations", tags=["invitations"])


class InvitationRequest(BaseModel):
    kind: Literal["space", "team"]
    code: str = Field(pattern=r"^[A-Z0-9]{6}$")


@router.post("/preview")
def preview_invitation(
    body: InvitationRequest,
    response: Response,
    user: AuthenticatedUser = Depends(get_current_user),
):
    response.headers["Cache-Control"] = "no-store"
    client = get_supabase_admin()
    if body.kind == "space":
        rows = client.table("team_shares").select(
            "share_id,share_name,owner_user_id,permission,expires_at"
        ).eq("share_code", body.code).eq("is_active", True).limit(1).execute().data or []
        if not rows or not invitation_is_current(rows[0]):
            raise HTTPException(404, "This invitation is no longer available. Ask the owner for a new link.")
        share = rows[0]
        owner = share["owner_user_id"] == user.user_id
        members = [] if owner else client.table("team_members").select("member_id").eq(
            "share_id", share["share_id"]
        ).eq("member_user_id", user.user_id).limit(1).execute().data or []
        return {
            "kind": "space", "name": share.get("share_name") or "Shared space",
            "target_id": share["share_id"], "already_joined": owner or bool(members),
            "permission": "edit" if owner else share.get("permission", "view"),
        }
    rows = client.table("teams").select("team_id,name").eq(
        "join_code", body.code
    ).limit(1).execute().data or []
    if not rows:
        raise HTTPException(404, "This invitation is no longer available. Ask the owner for a new link.")
    team = rows[0]
    members = client.table("team_memberships").select("role").eq(
        "team_id", team["team_id"]
    ).eq("user_id", user.user_id).limit(1).execute().data or []
    return {
        "kind": "team", "name": team.get("name") or "FindEZ team",
        "target_id": team["team_id"], "already_joined": bool(members),
        "permission": members[0]["role"] if members else "member",
    }
