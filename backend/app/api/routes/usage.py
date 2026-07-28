
import logging

from fastapi import APIRouter, Depends, HTTPException, Request

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.usage_service import (
    FREE_ITEM_LIMIT,
    FREE_SCAN_LIMIT,
    check_limit,
    get_all_usage,
    increment_usage,
)

router = APIRouter(tags=["inventory"])

logger = logging.getLogger(__name__)


@router.get("/usage/status")
async def get_usage_status_endpoint(user: AuthenticatedUser = Depends(get_current_user)):
    """Return current free-tier usage counts for the authenticated user."""
    try:
        return await get_all_usage(user.user_id)
    except Exception as e:
        return {
            "is_pro": False,
            "error": str(e),
            "items": {"current": 0, "limit": FREE_ITEM_LIMIT, "remaining": FREE_ITEM_LIMIT},
            "photo_scans": {"current": 0, "limit": FREE_SCAN_LIMIT, "remaining": FREE_SCAN_LIMIT},
        }


@router.get("/usage")
async def get_usage(user: AuthenticatedUser = Depends(get_current_user)):
    """Get all usage limits for current user"""
    usage = await get_all_usage(user.user_id)
    return usage


@router.post("/usage/check")
async def check_usage_limit(request: Request, user: AuthenticatedUser = Depends(get_current_user)):
    """Check if a specific feature is allowed"""
    body = await request.json()
    feature = body.get("feature")
    if not feature:
        raise HTTPException(status_code=400, detail="feature required")
    result = await check_limit(user.user_id, feature)
    return result


@router.post("/usage/increment")
async def increment_usage_count(request: Request, user: AuthenticatedUser = Depends(get_current_user)):
    """Increment usage count for a feature after successful use"""
    body = await request.json()
    feature = body.get("feature")
    if not feature:
        raise HTTPException(status_code=400, detail="feature required")
    new_count = await increment_usage(user.user_id, feature)
    return {"count": new_count, "feature": feature}
