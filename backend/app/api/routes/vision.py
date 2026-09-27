from fastapi import APIRouter, Depends, HTTPException

from app.core.auth import AuthenticatedUser, get_current_user


router = APIRouter(prefix="/vision", tags=["vision"])


@router.get("/observe/status")
def observe_status(
    _user: AuthenticatedUser = Depends(get_current_user),
) -> dict:
    return {
        "available": False,
        "reason": "Live recognition is unavailable. Use Photo to remember this scene.",
    }


@router.post("/observe")
def observe_frame(
    _user: AuthenticatedUser = Depends(get_current_user),
) -> None:
    raise HTTPException(
        status_code=503,
        detail="Live recognition is unavailable. Use Photo to remember this scene.",
    )
