import logging

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.errors import bad_request, service_unavailable
from app.services.spaces_repo import (
    delete_space,
    get_or_create_space,
    list_spaces,
    rename_space,
)

router = APIRouter(tags=["spaces"])
logger = logging.getLogger(__name__)


class CreateSpaceRequest(BaseModel):
    name: str


class RenameSpaceRequest(BaseModel):
    name: str


@router.get("/spaces")
def list_spaces_route(user: AuthenticatedUser = Depends(get_current_user)):
    try:
        return {"spaces": list_spaces(user_id=user.user_id)}
    except Exception:
        logger.exception("Failed to list spaces")
        raise service_unavailable("Could not load spaces. Please try again.")


@router.post("/spaces")
def create_space_route(
    payload: CreateSpaceRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    name = (payload.name or "").strip()
    if not name:
        raise bad_request("Space name is required")
    try:
        space = get_or_create_space(user_id=user.user_id, name=name)
        return {"space": space}
    except Exception:
        logger.exception("Failed to create space")
        raise service_unavailable("Could not create space. Please try again.")


@router.patch("/spaces/{space_id}")
def rename_space_route(
    space_id: str,
    payload: RenameSpaceRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    new_name = (payload.name or "").strip()
    if not new_name:
        raise bad_request("New name is required")
    try:
        updated = rename_space(user_id=user.user_id, space_id=space_id, new_name=new_name)
        return {"space": updated}
    except Exception:
        logger.exception("Failed to rename space %s", space_id)
        raise service_unavailable("Could not rename space. Please try again.")


@router.delete("/spaces/{space_id}")
def delete_space_route(
    space_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        ok = delete_space(user_id=user.user_id, space_id=space_id)
        return {"deleted": ok}
    except Exception:
        logger.exception("Failed to delete space %s", space_id)
        raise service_unavailable("Could not delete space. Please try again.")
