from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.supabase_client import get_supabase_admin

router = APIRouter(tags=["inventory"])

logger = logging.getLogger(__name__)


@router.patch("/profile/update")
async def update_profile(
    body: dict,
    user: AuthenticatedUser = Depends(get_current_user),
):
    client = get_supabase_admin()
    updates = {}
    if "display_name" in body:
        updates["display_name"] = body["display_name"]
    if "contact_email" in body:
        updates["contact_email"] = body["contact_email"]
    if "avatar_color" in body:
        updates["avatar_color"] = body["avatar_color"]
    if not updates:
        raise HTTPException(400, "Nothing to update")
    client.table("profiles").upsert({"id": user.user_id, **updates}).execute()
    return {"updated": True}


@router.get("/profile/me")
async def get_my_profile(
    user: AuthenticatedUser = Depends(get_current_user),
):
    client = get_supabase_admin()
    profile = client.table("profiles").select("*").eq("id", user.user_id).execute()
    u = client.auth.admin.get_user_by_id(user.user_id)
    email = u.user.email if u and u.user else ""
    data = profile.data[0] if profile.data else {}
    return {
        "user_id": user.user_id,
        "email": email,
        "display_name": data.get("display_name") or email.split("@")[0],
        "contact_email": data.get("contact_email") or "",
        "avatar_color": data.get("avatar_color") or "#636366",
        "is_pro": data.get("is_pro", False),
    }
