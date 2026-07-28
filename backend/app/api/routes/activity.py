from __future__ import annotations

import logging

import httpx
from fastapi import APIRouter, Depends, Query

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.errors import service_unavailable
from app.schemas.documents import RecentActivityResponse
from app.services.documents_repo import list_recent_activity

router = APIRouter(tags=["inventory"])

logger = logging.getLogger(__name__)


@router.get("/activity/recent", response_model=RecentActivityResponse)
def recent_activity_route(
    user: AuthenticatedUser = Depends(get_current_user),
    limit: int = Query(default=10, ge=1, le=100),
) -> RecentActivityResponse:
    try:
        activities = list_recent_activity(user_id=user.user_id, limit=limit)
        return RecentActivityResponse(activities=activities)
    except httpx.HTTPError:
        logger.exception("Upstream error during recent activity")
        raise service_unavailable("Activity temporarily unavailable. Please try again.")
    except Exception:
        logger.exception("Unhandled error during recent activity")
        raise service_unavailable("Activity temporarily unavailable. Please try again.")
