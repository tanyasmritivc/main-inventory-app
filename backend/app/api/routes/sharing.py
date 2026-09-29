
import logging
import uuid
from typing import Literal

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from pydantic import BaseModel, Field

from app.core.auth import AuthenticatedUser, get_current_user
from app.services import sharing_service
from app.services.supabase_client import get_supabase_admin
from app.services.email_service import render_team_invitation, send_transactional_email
from app.services.usage_service import check_limit, resolve_effective_plan
from app.schemas.inventory import ItemPhotoMutationResponse, ItemPhotosResponse
from app.services.item_photos import (
    MAX_ITEM_PHOTO_BYTES,
    add_item_photo,
    delete_item_photo,
    list_item_photos,
)

router = APIRouter(tags=["inventory"])
logger = logging.getLogger(__name__)

class CreateShareRequest(BaseModel):
    share_name: str = Field(default="My Inventory", max_length=100)
    permission: Literal["view", "edit"] = "view"


class JoinShareRequest(BaseModel):
    share_code: str = Field(max_length=20)


class InviteMemberRequest(BaseModel):
    email: str = Field(max_length=200)


class UpdateSharedItemRequest(BaseModel):
    name: str | None = Field(default=None, max_length=200)
    category: str | None = Field(default=None, max_length=100)
    quantity: int | None = Field(default=None, ge=0, le=100000)
    image_url: str | None = Field(default=None, max_length=2000)
    barcode: str | None = Field(default=None, max_length=100)
    purchase_source: str | None = Field(default=None, max_length=200)
    notes: str | None = Field(default=None, max_length=2000)


@router.post("/sharing/create")
async def create_share_route(
    body: CreateShareRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    share_name = body.share_name
    permission = body.permission
    if permission not in ("view", "edit"):
        raise HTTPException(400, "Invalid permission")
    # Team-covered users are exempt from the free-tier share cap.
    _, team_id = resolve_effective_plan(user.user_id)
    if team_id is None:
        limit_check = await check_limit(user.user_id, "share_space")
        if not limit_check["allowed"]:
            raise HTTPException(
                status_code=403,
                detail={
                    "error": "FREE_TIER_SHARE_LIMIT",
                    "used": limit_check["current"],
                    "max": limit_check["limit"],
                },
            )
    result = sharing_service.create_share(
        user_id=user.user_id,
        share_name=share_name,
        permission=permission,
    )
    return result


@router.get("/sharing/my-shares")
def get_my_shares_route(
    user: AuthenticatedUser = Depends(get_current_user),
):
    return sharing_service.get_my_shares(user_id=user.user_id)


@router.post("/sharing/join")
async def join_share_route(
    body: JoinShareRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    share_code = body.share_code.strip().upper()
    if not share_code:
        raise HTTPException(400, "share_code is required")
    try:
        result = sharing_service.join_share(user_id=user.user_id, share_code=share_code)
        return result
    except ValueError as e:
        raise HTTPException(400, str(e))


@router.get("/sharing/joined")
def get_joined_shares_route(
    user: AuthenticatedUser = Depends(get_current_user),
):
    return sharing_service.get_joined_shares(user_id=user.user_id)


@router.delete("/sharing/{share_id}")
def revoke_share_route(
    share_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    sharing_service.revoke_share(user_id=user.user_id, share_id=share_id)
    return {"revoked": True}


@router.delete("/sharing/{share_id}/members/{member_id}")
def remove_member_route(
    share_id: str,
    member_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        sharing_service.remove_member(
            owner_user_id=user.user_id,
            share_id=share_id,
            member_user_id=member_id,
        )
        return {"removed": True}
    except ValueError as e:
        raise HTTPException(403, str(e))


@router.delete("/sharing/{share_id}/leave")
async def leave_share(
    share_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    client = get_supabase_admin()
    client.table("team_members").delete().eq(
        "share_id", share_id
    ).eq("member_user_id", user.user_id).execute()
    return {"left": True}


@router.get("/sharing/{share_id}/inventory")
def get_share_inventory_route(
    share_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        items = sharing_service.get_share_inventory(
            requesting_user_id=user.user_id,
            share_id=share_id,
        )
        return items
    except ValueError as e:
        raise HTTPException(403, str(e))


@router.patch("/sharing/{share_id}/items/{item_id}")
def update_shared_item_route(
    share_id: str,
    item_id: str,
    body: UpdateSharedItemRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        updated = sharing_service.update_share_item(
            requesting_user_id=user.user_id,
            share_id=share_id,
            item_id=item_id,
            updates=body.model_dump(exclude_none=True),
        )
        if not updated:
            raise HTTPException(400, "No updates applied")
        return {"item": updated}
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(403, str(e))


@router.get(
    "/sharing/{share_id}/items/{item_id}/photos",
    response_model=ItemPhotosResponse,
)
def list_shared_item_photos_route(
    share_id: str,
    item_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
) -> ItemPhotosResponse:
    try:
        _, owner_user_id = sharing_service.get_share_item_access(
            requesting_user_id=user.user_id,
            share_id=share_id,
            item_id=item_id,
        )
        _, photos = list_item_photos(user_id=owner_user_id, item_id=item_id)
        return ItemPhotosResponse(photos=photos)
    except LookupError as exc:
        raise HTTPException(404, "Item not found") from exc
    except ValueError as exc:
        raise HTTPException(403, str(exc)) from exc


@router.post(
    "/sharing/{share_id}/items/{item_id}/photos",
    response_model=ItemPhotoMutationResponse,
)
async def add_shared_item_photo_route(
    share_id: str,
    item_id: str,
    file: UploadFile = File(...),
    user: AuthenticatedUser = Depends(get_current_user),
) -> ItemPhotoMutationResponse:
    try:
        _, owner_user_id = sharing_service.get_share_item_access(
            requesting_user_id=user.user_id,
            share_id=share_id,
            item_id=item_id,
            write=True,
        )
        item, photos = add_item_photo(
            user_id=owner_user_id,
            item_id=item_id,
            filename=file.filename or "photo.jpg",
            content=await file.read(MAX_ITEM_PHOTO_BYTES + 1),
        )
        return ItemPhotoMutationResponse(item=item, photos=photos)
    except LookupError as exc:
        raise HTTPException(404, "Item not found") from exc
    except ValueError as exc:
        message = str(exc)
        status_code = (
            400 if message.startswith("Choose") or "photos" in message else 403
        )
        raise HTTPException(status_code, message) from exc
    except Exception as exc:
        logger.exception("Shared item photo upload failed")
        raise HTTPException(503, "Photo could not be saved. Try again.") from exc


@router.delete(
    "/sharing/{share_id}/items/{item_id}/photos/{photo_id}",
    response_model=ItemPhotoMutationResponse,
)
def delete_shared_item_photo_route(
    share_id: str,
    item_id: str,
    photo_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
) -> ItemPhotoMutationResponse:
    try:
        _, owner_user_id = sharing_service.get_share_item_access(
            requesting_user_id=user.user_id,
            share_id=share_id,
            item_id=item_id,
            write=True,
        )
        item, photos = delete_item_photo(
            user_id=owner_user_id,
            item_id=item_id,
            photo_id=photo_id,
        )
        return ItemPhotoMutationResponse(item=item, photos=photos)
    except LookupError as exc:
        raise HTTPException(404, "Photo not found") from exc
    except ValueError as exc:
        raise HTTPException(403, str(exc)) from exc
    except Exception as exc:
        logger.exception("Shared item photo deletion failed")
        raise HTTPException(503, "Photo could not be deleted. Try again.") from exc


@router.post("/sharing/{share_id}/invite")
async def invite_member_by_email(
    share_id: str,
    body: InviteMemberRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    email = body.email.strip()
    if not email:
        raise HTTPException(400, "Email required")

    client = get_supabase_admin()
    share = (
        client.table("team_shares")
        .select("*")
        .eq("share_id", share_id)
        .eq("owner_user_id", user.user_id)
        .execute()
    )
    if not share.data:
        raise HTTPException(403, "Not your share")

    s = share.data[0]
    share_code = s["share_code"]
    share_name = s.get("share_name") or "a space"

    subject, text, html = render_team_invitation(
        share_name=share_name,
        share_code=share_code,
    )
    await send_transactional_email(
        user_id=user.user_id,
        idempotency_key=f"legacy-invite:{uuid.uuid4()}",
        template="team_invitation",
        recipient=email,
        subject=subject,
        text=text,
        html=html,
    )

    return {"sent": True, "email": email, "share_code": share_code}


@router.get("/sharing/{share_id}/members")
def get_share_members_route(
    share_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        return sharing_service.get_share_members(
            owner_user_id=user.user_id,
            share_id=share_id,
        )
    except ValueError as e:
        raise HTTPException(403, str(e))


@router.get("/sharing/{share_id}/items/{item_id}/history")
def get_share_item_history(
    share_id: str,
    item_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    from app.services.sharing_service import get_share_item_events
    try:
        events = get_share_item_events(
            requesting_user_id=user.user_id,
            share_id=share_id,
            item_id=item_id,
        )
    except ValueError as e:
        raise HTTPException(status_code=403, detail=str(e))
    return {"events": events}
