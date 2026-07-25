from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, Request

from app.core.auth import AuthenticatedUser, get_current_user
from app.services import sharing_service
from app.services.supabase_client import get_supabase_admin
from app.services.usage_service import check_limit

router = APIRouter(tags=["inventory"])

logger = logging.getLogger(__name__)


@router.post("/sharing/create")
async def create_share_route(
    request: Request,
    user: AuthenticatedUser = Depends(get_current_user),
):
    body = await request.json()
    share_name = body.get("share_name", "My Inventory")
    permission = body.get("permission", "view")
    if permission not in ("view", "edit"):
        raise HTTPException(400, "Invalid permission")
    limit_check = await check_limit(user.user_id, "share_space")
    if not limit_check["allowed"]:
        raise HTTPException(
            status_code=429,
            detail={
                "error": "limit_exceeded",
                "feature": "share_space",
                "feature_label": limit_check["feature_label"],
                "current": limit_check["current"],
                "limit": limit_check["limit"],
                "message": f"Free plan allows {limit_check['limit']} active share. Upgrade for unlimited sharing.",
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
    request: Request,
    user: AuthenticatedUser = Depends(get_current_user),
):
    body = await request.json()
    share_code = (body.get("share_code") or "").strip().upper()
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


@router.post("/sharing/{share_id}/invite")
async def invite_member_by_email(
    share_id: str,
    body: dict,
    user: AuthenticatedUser = Depends(get_current_user),
):
    import resend
    import os
    resend.api_key = os.environ.get("RESEND_API_KEY", "")

    email = body.get("email", "").strip()
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
    except Exception as e:
        raise HTTPException(500, f"Email failed: {str(e)}")

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
