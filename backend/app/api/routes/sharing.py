
import logging
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.core.auth import AuthenticatedUser, get_current_user
from app.services import sharing_service
from app.services.supabase_client import get_supabase_admin
from app.services.usage_service import check_limit, resolve_effective_plan

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


@router.post("/sharing/{share_id}/invite")
async def invite_member_by_email(
    share_id: str,
    body: InviteMemberRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    import resend
    import os
    resend.api_key = os.environ.get("RESEND_API_KEY", "")

    email = body.email.strip()
    if not email:
        raise HTTPException(400, "Email required")

    client = get_supabase_admin()
    share = client.table('team_shares').select('*').eq('share_id', share_id).eq('owner_user_id', user.user_id).execute()
    if not share.data:
        raise HTTPException(403, "Not your share")

    s = share.data[0]
    share_code = s['share_code']
    share_name = s.get('share_name') or 'a space'

    join_link = f"https://www.findez.ai/join?code={share_code}"

    try:
        resend.Emails.send({
            "from": "FindEZ <noreply@findez.ai>",
            "to": [email],
            "subject": f"You've been invited to view '{share_name}' on FindEZ",
            "html": f"""
            <div style="font-family: sans-serif; background: #000; color: #fff; padding: 40px; max-width: 500px; margin: auto; border-radius: 16px;">
              <h2 style="font-size: 22px; margin-bottom: 8px;">You're invited to FindEZ</h2>
              <p style="color: rgba(255,255,255,0.6); font-size: 15px;">Someone shared their inventory space <strong style="color:#fff">'{share_name}'</strong> with you.</p>
              <div style="margin: 32px 0; background: rgba(255,255,255,0.06); border-radius: 12px; padding: 20px; text-align: center;">
                <p style="color: rgba(255,255,255,0.5); font-size: 12px; letter-spacing: 2px; margin-bottom: 8px;">JOIN CODE</p>
                <p style="font-size: 32px; font-weight: 700; letter-spacing: 8px; color: #fff; margin: 0;">{share_code}</p>
              </div>
              <a href="{join_link}" style="display: block; background: #fff; color: #000; text-align: center; padding: 14px; border-radius: 99px; font-weight: 600; font-size: 15px; text-decoration: none;">Open FindEZ &amp; Join</a>
              <p style="color: rgba(255,255,255,0.3); font-size: 12px; margin-top: 24px; text-align: center;">Or enter code manually in the app: {share_code}</p>
            </div>
            """
        })
    except Exception:
        logger.exception("Invite email send failed")
        raise HTTPException(500, "Failed to send invitation email. Please try again.")

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
