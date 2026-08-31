from typing import Literal
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.push_notifications import send_test
from app.services.supabase_client import get_supabase_admin

router = APIRouter(prefix="/push", tags=["push-notifications"])


class RegisterDeviceRequest(BaseModel):
    device_token: str = Field(min_length=32, max_length=256, pattern=r"^[0-9a-fA-F]+$")
    environment: Literal["sandbox", "production"]


@router.post("/devices")
def register_device(body: RegisterDeviceRequest, user: AuthenticatedUser = Depends(get_current_user)):
    token = body.device_token.lower()
    rows = get_supabase_admin().table("push_devices").upsert({
        "device_token": token,
        "user_id": user.user_id,
        "platform": "ios",
        "environment": body.environment,
        "enabled": True,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }, on_conflict="device_token").execute().data or []
    if not rows:
        raise HTTPException(500, "This device could not be registered for notifications.")
    return {"registered": True}


@router.delete("/devices/{device_token}")
def unregister_device(device_token: str, user: AuthenticatedUser = Depends(get_current_user)):
    get_supabase_admin().table("push_devices").delete().eq(
        "device_token", device_token.lower()
    ).eq("user_id", user.user_id).execute()
    return {"registered": False}


@router.post("/test")
def test_push(user: AuthenticatedUser = Depends(get_current_user)):
    delivered = send_test(user.user_id)
    if delivered == 0:
        raise HTTPException(409, "No notification could be delivered to this device.")
    return {"delivered": delivered}
