"""Private founder operations and capability-scoped prospect scheduling."""
from contextlib import contextmanager, closing
import json
import os
from typing import Annotated, Literal
from uuid import UUID

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, ConfigDict, Field, HttpUrl, field_validator

from app.core.config import get_settings
from app.core.limiter import limiter
from app.services import demo_requests as inbox, demo_sales as sales


def private_response(response: Response):
    response.headers["Cache-Control"] = "private, no-store"


router = APIRouter(dependencies=[Depends(private_response)], include_in_schema=False)
bearer = HTTPBearer(auto_error=False)


async def founder_access(credentials: HTTPAuthorizationCredentials | None = Depends(bearer)):
    if not credentials or len(credentials.credentials) > 8192:
        raise HTTPException(401, "Sign in to the founder dashboard.")
    try:
        async with httpx.AsyncClient(timeout=5, trust_env=False) as client:
            result = await client.get("http://127.0.0.1:8031/dashboard/v1/demo-access",
                                      headers={"Authorization": "Bearer " + credentials.credentials})
        if result.status_code in (401, 403):
            raise HTTPException(result.status_code, "Founder access required.")
        result.raise_for_status()
        return str(UUID(result.json()["id"]))
    except (httpx.HTTPError, ValueError, KeyError, TypeError):
        raise HTTPException(503, "Founder verification is unavailable.") from None


@contextmanager
def mapped_errors():
    try:
        yield
    except sales.Missing:
        raise HTTPException(404, "This record or scheduling link is unavailable.") from None
    except sales.Conflict as exc:
        raise HTTPException(409, str(exc)) from None
    except ValueError as exc:
        raise HTTPException(422, str(exc)) from None


class Model(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class Link(Model):
    token: str = Field(min_length=40, max_length=64, pattern=r"^[a-zA-Z0-9_-]+$")


class Cancel(Link):
    revision: int = Field(ge=1)


class Book(Cancel):
    starts: int = Field(gt=0, le=253402300799)
    zone: str = Field(min_length=1, max_length=100)


@router.post("/demo-scheduling/view")
@limiter.limit("60/minute")
def slots(request: Request, body: Link):
    with mapped_errors():
        return sales.view_slots(body.token)


@router.post("/demo-scheduling/book")
@limiter.limit("15/minute")
def reserve(request: Request, body: Book):
    with mapped_errors():
        sales.book(body.token, body.revision, body.starts, body.zone)
        return sales.view_slots(body.token)


@router.post("/demo-scheduling/cancel")
@limiter.limit("15/minute")
def cancel(request: Request, body: Cancel):
    with mapped_errors(), inbox.delivery_lock(), sales.transaction() as db:
        sales.cancel(db, sales.public_meeting(db, body.token), body.revision, "prospect")
    return sales.view_slots(body.token)


def integrations():
    cfg = get_settings()
    return {"Email": "SMTP configured" if cfg.brevo_smtp_password and cfg.brevo_smtp_username else
            "Resend configured" if os.environ.get("RESEND_API_KEY") else "Unconfigured",
            "Briefings": "AI gateway configured" if cfg.findez_agent_key else "Template fallback",
            "Calendar": "Founder-provided availability and calendar invitations",
            "Google Calendar / Meet": "No authorized provider connection"}


@router.get("/internal/demo-sales")
def prospects(search: str = Query("", max_length=180), status: str = Query("", max_length=64),
              category: str = Query("", max_length=180), upcoming: bool = False, offset: int = Query(0, ge=0),
              actor: str = Depends(founder_access)):
    with closing(inbox.connect()) as db:
        return {**sales.list_requests(db, search, status, category, upcoming, offset),
                "metrics": sales.metrics(db), "statuses": sales.STATUSES, "integrations": integrations()}


@router.get("/internal/demo-sales/{rid}")
def prospect(rid: UUID, actor: str = Depends(founder_access)):
    with mapped_errors(), closing(inbox.connect()) as db:
        return sales.detail(db, str(rid))


class Offer(Model):
    starts: list[Annotated[int, Field(gt=0, le=253402300799)]] = Field(min_length=1, max_length=12)
    minutes: int = Field(ge=5, le=180)
    zone: str = Field(min_length=1, max_length=100)
    location: HttpUrl

    @field_validator("location")
    @classmethod
    def secure_link(cls, url):
        if url.scheme != "https" or url.username or url.password:
            raise ValueError("Enter a secure meeting link.")
        return url


@router.post("/internal/demo-sales/{rid}/offer")
def offer_times(rid: UUID, body: Offer, actor: str = Depends(founder_access)):
    with mapped_errors():
        sales.offer(str(rid), actor, body.starts, body.minutes, body.zone, str(body.location))
    return {"ok": True}


class Entry(Model):
    action: Literal["note", "owner", "status"]
    value: str = Field(min_length=1, max_length=4000)


class Pilot(Model):
    action: Literal["pilot"]
    scope: str = Field("", max_length=2000)
    use_case: str = Field("", max_length=2000)
    participants: str = Field("", max_length=2000)
    onboarding: str = Field("", max_length=2000)
    next_action: str = Field("", max_length=2000)


class Command(Model):
    action: Literal["response", "briefing"]


class CancelMeeting(Model):
    action: Literal["cancel"]
    revision: int = Field(ge=1)


class Draft(Model):
    action: Literal["draft"]
    scenario: Literal["General", "Pilot", "No response"]


class Approve(Model):
    action: Literal["approve"]
    id: UUID
    subject: str = Field(min_length=1, max_length=200, pattern=r"^[^\r\n]+$")
    body: str = Field(min_length=1, max_length=12000)
    due: int = Field(default=0, ge=0, le=253402300799)


class RetryMail(Model):
    action: Literal["retry_mail"]
    kind: str = Field(min_length=1, max_length=128)


class Withdraw(Model):
    action: Literal["withdraw"]
    id: UUID


Action = Annotated[Entry | Pilot | Command | CancelMeeting | Draft | Approve | Withdraw | RetryMail, Field(discriminator="action")]


@router.post("/internal/demo-sales/{rid}/action")
def manage(rid: UUID, body: Action, actor: str = Depends(founder_access)):
    key = str(rid)
    with mapped_errors(), inbox.delivery_lock(), sales.transaction() as db:
        sales.lead(db, key)
        if body.action == "note":
            sales.event(db, key, actor, "Internal note", body.value)
        elif body.action == "status":
            sales.update_status(db, key, actor, body.value)
        elif body.action == "owner":
            db.execute("UPDATE sales SET owner=? WHERE request_id=?", (body.value, key))
            sales.event(db, key, actor, "Owner assigned", body.value)
        elif body.action == "pilot":
            fields = body.model_dump(exclude={"action"})
            db.execute("UPDATE sales SET pilot=? WHERE request_id=?", (json.dumps(fields), key))
            sales.event(db, key, actor, "Pilot details updated")
        elif body.action == "response":
            sales.stop_followups(db, key, "No response")
            sales.event(db, key, actor, "Response recorded")
        elif body.action == "briefing":
            db.execute("UPDATE sales SET brief_state='pending',brief_due=0,brief_lease=NULL WHERE request_id=? AND brief_state!='generating'", (key,))
            sales.event(db, key, actor, "Briefing requested")
        elif body.action == "cancel":
            m = sales.meeting(db, key)
            if not m:
                raise sales.Missing()
            sales.cancel(db, m, body.revision, actor)
        elif body.action == "draft":
            sales.draft_followup(db, key, actor, body.scenario)
        elif body.action == "approve":
            sales.approve_followup(db, key, actor, str(body.id), body.subject, body.body, body.due)
        elif body.action == "retry_mail":
            # Only an exhausted, still-active job is eligible. Retain its stable Message-ID.
            changed = db.execute("UPDATE mail SET attempts=0,due=? WHERE request_id=? AND kind=? "
                                 "AND sent IS NULL AND cancelled IS NULL AND attempts>=8",
                                 (sales.now(), key, body.kind)).rowcount
            if not changed:
                raise sales.Conflict("This email is no longer eligible for a retry.")
            sales.event(db, key, actor, "Email retry authorized", body.kind)
        elif body.action == "withdraw":
            changed = db.execute("UPDATE demo_followups SET state='cancelled' WHERE id=? AND request_id=? AND state IN ('draft','queued')", (str(body.id), key)).rowcount
            if not changed:
                raise sales.Conflict("This follow-up can no longer be withdrawn.")
            sales.cancel_pending(db, key, "followup/"+str(body.id))
            sales.event(db, key, actor, "Follow-up withdrawn")
        return sales.detail(db, key)
