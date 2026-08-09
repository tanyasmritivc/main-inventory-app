
import logging

from fastapi import APIRouter, Depends

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.limits import get_limits_summary

router = APIRouter(tags=["inventory"])

logger = logging.getLogger(__name__)


@router.get("/me/limits")
def get_my_limits(user: AuthenticatedUser = Depends(get_current_user)):
    """
    Return tier and usage limits for the authenticated user.
    All counts use DB count queries — no row fetching.
    """
    return get_limits_summary(user.user_id)
