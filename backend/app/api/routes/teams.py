"""
Team management endpoints.

POST   /teams                              — create team, caller becomes owner
POST   /teams/join                         — join by 6-char code (idempotent)
GET    /teams                              — list caller's teams with role
GET    /teams/{team_id}/members            — roster (member+ only)
PATCH  /teams/{team_id}/members/{user_id}  — change role (owner/mentor only)
DELETE /teams/{team_id}/members/{user_id}  — remove member (owner/mentor only)
DELETE /teams/{team_id}/leave              — leave a joined team (non-owner)
"""

import html
import logging
from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.config import get_settings
from app.services import teams_repo
from app.services.email_delivery import send_transactional_email
from app.services.supabase_client import get_supabase_admin
from app.services.push_notifications import enqueue_notifications

router = APIRouter(prefix="/teams", tags=["teams"])
logger = logging.getLogger(__name__)


class CreateTeamRequest(BaseModel):
    name: str = Field(max_length=100)
    program: Literal[
        "robotics", "ftc", "frc", "vex", "fll",
        "education", "makerspace", "club", "business", "other",
    ]
    rookie: bool = False  # if True, set plan='free_rookie', allowed once per owner


class JoinTeamRequest(BaseModel):
    code: str = Field(min_length=6, max_length=6)


class UpdateRoleRequest(BaseModel):
    role: Literal["mentor", "member", "viewer"]


class InviteTeamRequest(BaseModel):
    email: str = Field(min_length=3, max_length=254)


def _season_expires_at() -> str:
    """Next Aug 31 23:59:59 UTC — end of the robotics season."""
    now = datetime.now(timezone.utc)
    year = now.year
    aug31 = datetime(year, 8, 31, 23, 59, 59, tzinfo=timezone.utc)
    if now > aug31:
        aug31 = datetime(year + 1, 8, 31, 23, 59, 59, tzinfo=timezone.utc)
    return aug31.isoformat()


def _record_team_activity(
    *,
    team_id: str,
    actor_id: str,
    action: str,
    summary: str,
    metadata: dict,
    recipient_ids: list[str],
) -> None:
    client = get_supabase_admin()
    inserted = client.table("team_activity").insert({
        "team_id": team_id,
        "actor_id": actor_id,
        "action": action,
        "summary": summary,
        "metadata": metadata,
    }).execute().data or []
    members = client.table("team_memberships").select("user_id").eq(
        "team_id", team_id
    ).execute().data or []
    recipients = list({
        user_id
        for user_id in [*(row.get("user_id") for row in members), *recipient_ids]
        if user_id
    })
    if inserted and recipients:
        client.table("team_notification_recipients").insert([
            {"activity_id": inserted[0]["activity_id"], "user_id": user_id, "reason": action}
            for user_id in recipients
        ]).execute()
    enqueue_notifications(team_id, actor_id, summary, action, recipients)


@router.post("")
def create_team_route(
    payload: CreateTeamRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    if payload.rookie:
        # Rookie plan: free, once per owner account.
        existing = teams_repo.list_user_teams(user_id=user.user_id)
        if any(t.get("role") == "owner" for t in existing):
            raise HTTPException(
                status_code=409,
                detail={
                    "error": "ALREADY_HAS_TEAM",
                    "message": "You already have a team. The rookie plan is allowed once per account.",
                },
            )

    try:
        team = teams_repo.create_team(
            user_id=user.user_id,
            name=payload.name,
            program=payload.program,
        )
        if payload.rookie:
            expires_at = _season_expires_at()
            supabase = get_supabase_admin()
            supabase.table("teams").update({
                "plan": "free_rookie",
                "plan_expires_at": expires_at,
            }).eq("team_id", team["team_id"]).execute()
            team = {**team, "plan": "free_rookie", "plan_expires_at": expires_at}
        return {"team": team}
    except ValueError as exc:
        raise HTTPException(400, str(exc))
    except Exception:
        logger.exception("Failed to create team for user=%s", user.user_id)
        raise HTTPException(500, "Could not create team. Please try again.")


@router.post("/join")
def join_team_route(
    payload: JoinTeamRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        membership = teams_repo.join_team(user_id=user.user_id, code=payload.code)
        newly_joined = membership.pop("newly_joined", False)
        if newly_joined:
            managers = get_supabase_admin().table("team_memberships").select(
                "user_id"
            ).eq("team_id", membership["team_id"]).in_(
                "role", ["owner", "mentor"]
            ).execute().data or []
            _record_team_activity(
                team_id=membership["team_id"],
                actor_id=user.user_id,
                action="member_joined",
                summary="A new member joined the team",
                metadata={"user_id": user.user_id},
                recipient_ids=[row["user_id"] for row in managers],
            )
        return {"membership": membership}
    except ValueError as exc:
        if "NOT_FOUND" in str(exc):
            raise HTTPException(404, "Invalid join code")
        raise HTTPException(400, str(exc))
    except Exception:
        logger.exception("Failed to join team user=%s code=%s", user.user_id, payload.code)
        raise HTTPException(500, "Could not join team. Please try again.")


@router.get("")
def list_teams_route(user: AuthenticatedUser = Depends(get_current_user)):
    teams = teams_repo.list_user_teams(user_id=user.user_id)
    return {"teams": teams}


@router.post("/{team_id}/join-code/rotate")
def rotate_join_code_route(
    team_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        code = teams_repo.rotate_join_code(
            requesting_user_id=user.user_id,
            team_id=team_id,
        )
        return {"join_code": code}
    except PermissionError:
        raise HTTPException(403, "Only the team owner or a manager can reset the invite code.")
    except ValueError:
        raise HTTPException(404, "This team no longer exists.")


def _invite_details(team_id: str, user_id: str) -> dict:
    try:
        team = teams_repo.get_team_invitation(
            requesting_user_id=user_id,
            team_id=team_id,
        )
    except PermissionError:
        raise HTTPException(403, "Only the team owner or a manager can invite members.")
    except ValueError:
        raise HTTPException(404, "This team no longer exists.")
    code = team.get("join_code", "")
    if not code:
        raise HTTPException(409, "This team does not have an active invite code.")
    base_url = get_settings().frontend_url.rstrip("/")
    return {
        "team_id": team_id,
        "team_name": team.get("name") or "FindEZ Team",
        "program": team.get("program") or "other",
        "join_code": code,
        "invite_url": f"{base_url}/join/team/{code}",
    }


@router.get("/{team_id}/invite")
def get_team_invite_route(
    team_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    return _invite_details(team_id, user.user_id)


@router.post("/{team_id}/invite")
def email_team_invite_route(
    team_id: str,
    payload: InviteTeamRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    email = payload.email.strip().lower()
    if "@" not in email or email.startswith("@") or email.endswith("@"):
        raise HTTPException(400, "Enter a valid email address.")
    details = _invite_details(team_id, user.user_id)
    try:
        team_name = html.escape(details["team_name"])
        invite_url = html.escape(details["invite_url"], quote=True)
        join_code = html.escape(details["join_code"])
        send_transactional_email(
            to=email,
            subject=f"Join {details['team_name']} on FindEZ",
            text=(
                f"You are invited to join {details['team_name']} on FindEZ. "
                f"Open {details['invite_url']} or enter join code {details['join_code']}."
            ),
            html=f"""
            <div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#090a0d;color:#f5f5f7;padding:40px 24px;">
              <div style="max-width:520px;margin:auto;background:#171719;border:1px solid #303034;border-radius:22px;padding:32px;">
                <p style="margin:0 0 10px;color:#a1a1aa;font-size:13px;letter-spacing:.08em;text-transform:uppercase;">FindEZ team invitation</p>
                <h1 style="margin:0 0 12px;font-size:26px;line-height:1.2;">Join {team_name}</h1>
                <p style="margin:0 0 26px;color:#b6b6bd;font-size:16px;line-height:1.55;">Open FindEZ to join the team. If you do not have the app yet, the link will take you to the download page.</p>
                <a href="{invite_url}" style="display:block;padding:14px 20px;border-radius:999px;background:#f5f5f7;color:#111113;text-align:center;text-decoration:none;font-weight:700;">Open invitation</a>
                <p style="margin:24px 0 6px;color:#8e8e93;font-size:12px;text-align:center;">JOIN CODE</p>
                <p style="margin:0;color:#f5f5f7;font-size:25px;letter-spacing:.22em;text-align:center;font-weight:700;">{join_code}</p>
              </div>
            </div>
            """,
        )
    except HTTPException:
        raise
    except Exception:
        logger.exception("Failed to send team invitation team=%s email=%s", team_id, email)
        raise HTTPException(500, "Could not send the invitation. Please try again.")
    return {**details, "sent": True, "email": email}


@router.delete("/{team_id}/leave")
def leave_team_route(
    team_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        left = teams_repo.leave_team(user_id=user.user_id, team_id=team_id)
        if left:
            _record_team_activity(
                team_id=team_id,
                actor_id=user.user_id,
                action="member_left",
                summary="Left the team",
                metadata={"user_id": user.user_id},
                recipient_ids=[],
            )
        return {"left": left}
    except PermissionError:
        raise HTTPException(
            403,
            "Team owners cannot leave. Transfer ownership or delete the team instead.",
        )
    except Exception:
        logger.exception("Failed to leave team=%s user=%s", team_id, user.user_id)
        raise HTTPException(500, "Could not leave the team. Please try again.")


@router.delete("/{team_id}")
def delete_team_route(
    team_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        deleted = teams_repo.delete_team(
            requesting_user_id=user.user_id,
            team_id=team_id,
        )
        return {"deleted": deleted}
    except PermissionError:
        raise HTTPException(403, "Only the team owner can delete this team.")


@router.get("/{team_id}/members")
def list_members_route(
    team_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        members = teams_repo.list_team_members(user_id=user.user_id, team_id=team_id)
        return {"members": members}
    except PermissionError:
        raise HTTPException(403, "Not a member of this team")
    except Exception:
        logger.exception("Failed to list members team=%s", team_id)
        raise HTTPException(500, "Could not load members. Please try again.")


@router.patch("/{team_id}/members/{target_user_id}")
def update_member_role_route(
    team_id: str,
    target_user_id: str,
    payload: UpdateRoleRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        updated = teams_repo.update_member_role(
            requesting_user_id=user.user_id,
            team_id=team_id,
            target_user_id=target_user_id,
            new_role=payload.role,
        )
        _record_team_activity(
            team_id=team_id,
            actor_id=user.user_id,
            action="member_role_changed",
            summary=f"Changed a team member's role to {payload.role}",
            metadata={"user_id": target_user_id, "role": payload.role},
            recipient_ids=[target_user_id],
        )
        return {"member": updated}
    except PermissionError as exc:
        msg = str(exc)
        if "CANNOT_CHANGE_OWNER" in msg:
            raise HTTPException(403, "Cannot change the team owner's role")
        if "ONLY_OWNER_CAN_GRANT_MENTOR" in msg:
            raise HTTPException(403, "Only the team owner can grant the mentor role")
        raise HTTPException(403, "Insufficient permissions")
    except ValueError as exc:
        raise HTTPException(400, str(exc))
    except Exception:
        logger.exception("Failed to update role team=%s target=%s", team_id, target_user_id)
        raise HTTPException(500, "Could not update role. Please try again.")


@router.delete("/{team_id}/members/{target_user_id}")
def remove_member_route(
    team_id: str,
    target_user_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        teams_repo.remove_member(
            requesting_user_id=user.user_id,
            team_id=team_id,
            target_user_id=target_user_id,
        )
        _record_team_activity(
            team_id=team_id,
            actor_id=user.user_id,
            action="member_removed",
            summary="Removed a member from the team",
            metadata={"user_id": target_user_id},
            recipient_ids=[target_user_id],
        )
        return {"removed": True}
    except PermissionError as exc:
        msg = str(exc)
        if "CANNOT_REMOVE_OWNER" in msg:
            raise HTTPException(403, "Cannot remove the team owner")
        raise HTTPException(403, "Insufficient permissions")
    except Exception:
        logger.exception("Failed to remove member team=%s target=%s", team_id, target_user_id)
        raise HTTPException(500, "Could not remove member. Please try again.")
