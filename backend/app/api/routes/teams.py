"""
Team management endpoints.

POST   /teams                              — create team, caller becomes owner
POST   /teams/join                         — join by 6-char code (idempotent)
GET    /teams                              — list caller's teams with role
GET    /teams/{team_id}/members            — roster (member+ only)
PATCH  /teams/{team_id}/members/{user_id}  — change role (owner/mentor only)
DELETE /teams/{team_id}/members/{user_id}  — remove member (owner/mentor only)
"""

import logging
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.core.auth import AuthenticatedUser, get_current_user
from app.services import teams_repo

router = APIRouter(prefix="/teams", tags=["teams"])
logger = logging.getLogger(__name__)


class CreateTeamRequest(BaseModel):
    name: str = Field(max_length=100)
    program: Literal["ftc", "frc", "vex", "fll"]


class JoinTeamRequest(BaseModel):
    code: str = Field(min_length=6, max_length=6)


class UpdateRoleRequest(BaseModel):
    role: Literal["mentor", "member", "viewer"]


@router.post("")
def create_team_route(
    payload: CreateTeamRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        team = teams_repo.create_team(
            user_id=user.user_id,
            name=payload.name,
            program=payload.program,
        )
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
        return {"removed": True}
    except PermissionError as exc:
        msg = str(exc)
        if "CANNOT_REMOVE_OWNER" in msg:
            raise HTTPException(403, "Cannot remove the team owner")
        raise HTTPException(403, "Insufficient permissions")
    except Exception:
        logger.exception("Failed to remove member team=%s target=%s", team_id, target_user_id)
        raise HTTPException(500, "Could not remove member. Please try again.")
