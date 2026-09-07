
import logging
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from pydantic import BaseModel, Field

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.supabase_client import get_supabase_admin
from app.services.storage import create_profile_photo_signed_url

router = APIRouter(tags=["inventory"])

logger = logging.getLogger(__name__)


class UpdateProfileRequest(BaseModel):
    display_name: str | None = Field(default=None, max_length=100)
    contact_email: str | None = Field(default=None, max_length=200)
    avatar_color: str | None = Field(default=None, max_length=20)
    organization: str | None = Field(default=None, max_length=120)
    profile_role: str | None = Field(default=None, max_length=120)


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
    if body.organization is not None:
        updates["organization"] = body.organization.strip()
    if body.profile_role is not None:
        updates["profile_role"] = body.profile_role.strip()
    if not updates:
        raise HTTPException(400, "Nothing to update")
    client.table("profiles").upsert({"id": user.user_id, **updates}).execute()
    return {"updated": True}


@router.post("/profile/photo")
async def upload_profile_photo(
    photo: UploadFile = File(...),
    user: AuthenticatedUser = Depends(get_current_user),
):
    content_type = (photo.content_type or "").lower()
    if content_type not in {"image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"}:
        raise HTTPException(400, "Choose a JPEG, PNG, WebP, or HEIC image")
    content = await photo.read()
    if not content or len(content) > 5 * 1024 * 1024:
        raise HTTPException(400, "Profile photo must be smaller than 5 MB")

    extension = Path(photo.filename or "avatar.jpg").suffix.lower()
    if extension not in {".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif"}:
        extension = ".jpg"
    path = f"{user.user_id}/avatar{extension}"
    client = get_supabase_admin()
    client.storage.from_("profile-photos").upload(
        path,
        content,
        file_options={"content-type": content_type, "x-upsert": "true"},
    )
    client.table("profiles").upsert({"id": user.user_id, "avatar_path": path}).execute()
    return {"avatar_url": create_profile_photo_signed_url(storage_path=path)}


@router.delete("/profile/photo")
async def delete_profile_photo(
    user: AuthenticatedUser = Depends(get_current_user),
):
    client = get_supabase_admin()
    profile = client.table("profiles").select("avatar_path").eq("id", user.user_id).execute()
    path = (profile.data[0].get("avatar_path") if profile.data else None)
    if path:
        client.storage.from_("profile-photos").remove([path])
    client.table("profiles").upsert({"id": user.user_id, "avatar_path": None}).execute()
    return {"deleted": True}


@router.get("/profile/me")
async def get_my_profile(
    user: AuthenticatedUser = Depends(get_current_user),
):
    client = get_supabase_admin()
    profile = client.table("profiles").select("*").eq("id", user.user_id).execute()
    u = client.auth.admin.get_user_by_id(user.user_id)
    email = u.user.email if u and u.user else ""
    data = profile.data[0] if profile.data else {}
    avatar_url = ""
    if data.get("avatar_path"):
        try:
            avatar_url = create_profile_photo_signed_url(storage_path=data["avatar_path"])
        except Exception:
            logger.exception("Could not sign profile photo for %s", user.user_id)
    return {
        "user_id": user.user_id,
        "email": email,
        "display_name": data.get("display_name") or email.split("@")[0],
        "contact_email": data.get("contact_email") or "",
        "avatar_color": data.get("avatar_color") or "#636366",
        "avatar_url": avatar_url,
        "organization": data.get("organization") or "",
        "profile_role": data.get("profile_role") or "",
        "is_pro": data.get("is_pro", False),
    }
