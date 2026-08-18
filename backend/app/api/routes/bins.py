import logging

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.errors import bad_request, service_unavailable
from app.services.bins_repo import create_bin, delete_bin, list_bins, rename_bin


router = APIRouter(tags=["bins"])
logger = logging.getLogger(__name__)


class BinNameRequest(BaseModel):
    name: str = Field(max_length=100)


def _name_or_error(value: str) -> str:
    name = (value or "").strip()
    if not name:
        raise bad_request("Bin name is required")
    return name


@router.get("/spaces/{space_id}/bins")
def list_bins_route(space_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    try:
        return {"bins": list_bins(user_id=user.user_id, space_id=space_id)}
    except Exception:
        logger.exception("Failed to list bins")
        raise service_unavailable("Could not load bins. Please try again.")


@router.post("/spaces/{space_id}/bins")
def create_bin_route(
    space_id: str,
    payload: BinNameRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        return {"bin": create_bin(user_id=user.user_id, space_id=space_id, name=_name_or_error(payload.name))}
    except LookupError:
        raise HTTPException(404, "Space not found")
    except HTTPException:
        raise
    except Exception:
        logger.exception("Failed to create bin")
        raise service_unavailable("Could not create bin. Please try again.")


@router.patch("/bins/{bin_id}")
def rename_bin_route(
    bin_id: str,
    payload: BinNameRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        updated = rename_bin(user_id=user.user_id, bin_id=bin_id, name=_name_or_error(payload.name))
        if not updated:
            raise HTTPException(404, "Bin not found")
        return {"bin": updated}
    except HTTPException:
        raise
    except Exception:
        logger.exception("Failed to rename bin")
        raise service_unavailable("Could not rename bin. Please try again.")


@router.delete("/bins/{bin_id}")
def delete_bin_route(bin_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    try:
        return {"deleted": delete_bin(user_id=user.user_id, bin_id=bin_id)}
    except Exception:
        logger.exception("Failed to delete bin")
        raise service_unavailable("Could not delete bin. Please try again.")
