import re
from typing import Literal

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.limiter import limiter
from app.services.email_service import (
    render_custom_message,
    render_team_invitation,
    send_transactional_email,
)
from app.services.supabase_client import get_supabase_admin

router = APIRouter(prefix="/email", tags=["email"])
_IDEMPOTENCY_RE = re.compile(r"^[A-Za-z0-9._:-]{8,128}$")


class SendEmailRequest(BaseModel):
    template: Literal["team_invitation", "custom"]
    recipient: str = Field(min_length=3, max_length=254)
    variables: dict[str, str] = Field(default_factory=dict)
    subject: str | None = Field(default=None, max_length=200)
    body: str | None = Field(default=None, max_length=20_000)


@router.post("/send", status_code=202)
@limiter.limit("10/minute")
async def send_email(
    request: Request,
    body: SendEmailRequest,
    user: AuthenticatedUser = Depends(get_current_user),
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
):
    if not idempotency_key or not _IDEMPOTENCY_RE.fullmatch(idempotency_key):
        raise HTTPException(status_code=400, detail="Valid Idempotency-Key required")
    if body.template == "custom":
        if body.variables:
            raise HTTPException(
                status_code=400,
                detail="custom email does not accept variables",
            )
        subject, text, html = render_custom_message(
            subject=body.subject or "", body=body.body or "",
        )
    else:
        if body.subject is not None or body.body is not None:
            raise HTTPException(
                status_code=400,
                detail="Template email does not accept subject or body",
            )
        share_id = body.variables.get("share_id", "").strip()
        if not share_id or set(body.variables) != {"share_id"}:
            raise HTTPException(status_code=400, detail="team_invitation requires only share_id")
        result = (
            get_supabase_admin()
            .table("team_shares")
            .select("share_name,share_code")
            .eq("share_id", share_id)
            .eq("owner_user_id", user.user_id)
            .maybe_single()
            .execute()
        )
        share = result.data if result and isinstance(result.data, dict) else None
        if not share:
            raise HTTPException(status_code=403, detail="Not authorized for this share")
        subject, text, html = render_team_invitation(
            share_name=share.get("share_name") or "a space",
            share_code=share["share_code"],
        )
    return await send_transactional_email(
        user_id=user.user_id,
        idempotency_key=idempotency_key,
        template=body.template,
        recipient=body.recipient,
        subject=subject,
        text=text,
        html=html,
    )
