from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.supabase_client import get_supabase_admin

router = APIRouter(tags=["inventory"])

logger = logging.getLogger(__name__)


class UpdateProfileRequest(BaseModel):
    display_name: str | None = Field(default=None, max_length=100)
    contact_email: str | None = Field(default=None, max_length=200)
    avatar_color: str | None = Field(default=None, max_length=20)


@router.patch("/profile/update")
async def update_profile(
    body: UpdateProfileRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    client = get_supabase_admin()
    updates = {}
    if body.display_name is not None:
        updates["display_name"] = body.display_name
    if body.contact_email is not None:
        updates["contact_email"] = body.contact_email
    if body.avatar_color is not None:
        updates["avatar_color"] = body.avatar_color
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
