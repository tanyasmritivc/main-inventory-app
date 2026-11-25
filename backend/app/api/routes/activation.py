"""Campaign-specific opt-out, account controls, and authenticated provider receipts."""
from datetime import datetime, timezone
import os
from secrets import compare_digest
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, ConfigDict, Field, StrictBool

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.account_memory import actor_id
from app.services.supabase_client import get_supabase_raw

router = APIRouter(prefix="/activation", tags=["activation"])
PRIVATE = {"Cache-Control": "no-store", "Referrer-Policy": "no-referrer",
           "Content-Security-Policy": "default-src 'none'; form-action 'self'; frame-ancestors 'none'"}


@router.get("/unsubscribe/{token}", response_class=HTMLResponse)
def unsubscribe_page(token: UUID):
    # Mail scanners may prefetch links. Only an explicit POST changes the preference.
    return HTMLResponse('<title>FindEZ setup reminders</title><h1>FindEZ setup reminders</h1>'
                        '<form method="post"><button>Unsubscribe from setup emails</button></form>',
                        headers=PRIVATE)


@router.post("/unsubscribe/{token}", response_class=HTMLResponse)
def unsubscribe(token: UUID):
    get_supabase_raw().table("activation_accounts").update({"email_enabled": False}).eq(
        "unsubscribe_token", str(token)).execute()
    return HTMLResponse("<title>FindEZ</title><p>Your request to stop setup emails has been processed.</p>",
                        headers=PRIVATE)


class EmailPreference(BaseModel):
    model_config = ConfigDict(extra="forbid")
    email_enabled: StrictBool


@router.get("/preferences")
def preferences(user: AuthenticatedUser = Depends(get_current_user)):
    rows = get_supabase_raw().table("activation_accounts").select("email_enabled").eq(
        "user_id", actor_id(user)).limit(1).execute().data
    return {"enrolled": bool(rows), "email_enabled": bool(rows and rows[0]["email_enabled"])}


@router.put("/preferences")
def change_preference(body: EmailPreference, user: AuthenticatedUser = Depends(get_current_user)):
    get_supabase_raw().table("activation_accounts").update(body.model_dump()).eq(
        "user_id", actor_id(user)).execute()
    return preferences(user)


class BrevoReceipt(BaseModel):
    event: str
    correlation: str | None = Field(None, alias="X-Mailin-custom", max_length=160)


@router.post("/brevo-events")
def brevo_event(body: BrevoReceipt, authorization: str = Header(default="")):
    secret = os.getenv("FINDEZ_ACTIVATION_BREVO_TOKEN", "")
    if not secret or not compare_digest(authorization.encode(), f"Bearer {secret}".encode()):
        raise HTTPException(403, "Unauthorized callback")
    correlation = body.correlation or ""
    if correlation.startswith("activation:"):
        try:
            reminder_id = str(UUID(correlation.removeprefix("activation:")))
        except ValueError:
            return {"received": True}
        client = get_supabase_raw()
        if body.event in {"unsubscribed", "unsubscribe", "hard_bounce", "hardBounce", "spam"}:
            result = client.table("activation_reminders").select("user_id").eq(
                "id", reminder_id).eq("channel", "email").not_.is_("submitted_at", "null").limit(1).execute().data
            if result:
                client.table("activation_accounts").update({"email_enabled": False}).eq(
                    "user_id", result[0]["user_id"]).execute()
        field = {"delivered": "delivered_at", "opened": "opened_at", "unique_opened": "opened_at"}.get(body.event)
        if field:
            client.table("activation_reminders").update({field: datetime.now(timezone.utc).isoformat()}).eq(
                "id", reminder_id).eq("channel", "email").not_.is_("submitted_at", "null").is_(field, "null").execute()
    return {"received": True}
