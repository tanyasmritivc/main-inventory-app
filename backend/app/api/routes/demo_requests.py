import asyncio
from contextlib import asynccontextmanager
from email.errors import HeaderParseError
from email.headerregistry import Address
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.limiter import limiter
from app.services import demo_requests as inbox


@asynccontextmanager
async def lifespan(app):
    worker = asyncio.create_task(inbox.run_mail_queue())
    try:
        yield
    finally:
        worker.cancel()
        await asyncio.gather(worker, return_exceptions=True)


router = APIRouter(lifespan=lifespan)
Interest = Literal["AI inventory search", "Robotics inventory", "Fusion and STEP models", "BOM comparison"]


class DemoRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    request_id: UUID
    name: str = Field(min_length=1, max_length=120, pattern=r"^[^\x00-\x1f\x7f]+$")
    organization: str = Field(min_length=1, max_length=180, pattern=r"^[^\x00-\x1f\x7f]+$")
    email: str = Field(min_length=3, max_length=254, pattern=r"^[^\s<>@,;:]+@[^\s<>@,;:]+\.[^\s<>@,;:]+$")
    interests: list[Interest] = Field(default_factory=list, max_length=4)

    @field_validator("email")
    @classmethod
    def valid_mailbox(cls, value):
        try:
            addr = Address(addr_spec=value)
        except (ValueError, HeaderParseError) as exc:
            raise ValueError("Invalid email address") from exc
        if addr.addr_spec != value or not addr.domain or not value.isascii():
            raise ValueError("Invalid email address")
        return value.lower()


@router.post("/demo-requests", status_code=202)
@limiter.limit("6/minute")
def submit_demo_request(request: Request, body: DemoRequest):
    try:
        inbox.save(str(body.request_id), body.email, {
            "name": body.name, "organization": body.organization, "interests": sorted(set(body.interests)),
        })
    except inbox.TooManyRequests:
        raise HTTPException(429, "Too many demo requests. Please try again later.")
    except inbox.RequestConflict:
        raise HTTPException(409, "The request details changed. Please try again.")
    return {"status": "received"}
