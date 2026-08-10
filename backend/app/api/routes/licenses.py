"""
POST /licenses/redeem — apply a license code to a team (owner only).
Returns 410 if the code is already redeemed or has expired.
"""

import logging

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.core.auth import AuthenticatedUser, get_current_user
from app.services import teams_repo

router = APIRouter(prefix="/licenses", tags=["teams"])
logger = logging.getLogger(__name__)


class RedeemRequest(BaseModel):
    code: str = Field(min_length=1, max_length=20)
    team_id: str


@router.post("/redeem")
def redeem_license_route(
    payload: RedeemRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    code = (payload.code or "").strip().upper()
    try:
        result = teams_repo.apply_license_to_team(
            team_id=payload.team_id,
            owner_user_id=user.user_id,
            code=code,
        )
        return {"license": result}
    except PermissionError as exc:
        msg = str(exc)
        if "OWNER_ONLY" in msg:
            raise HTTPException(403, "Only the team owner can redeem licenses")
        raise HTTPException(403, "Insufficient permissions")
    except ValueError as exc:
        msg = str(exc)
        if "ALREADY_REDEEMED" in msg or "EXPIRED" in msg:
            raise HTTPException(410, f"License is no longer valid: {msg.lower()}")
        if "NOT_FOUND" in msg:
            raise HTTPException(404, "License code not found")
        raise HTTPException(400, msg)
    except Exception:
        logger.exception("Failed to redeem license code=%s team=%s", code, payload.team_id)
        raise HTTPException(500, "Could not redeem license. Please try again.")
