import asyncio
from contextlib import asynccontextmanager
from email.errors import HeaderParseError
from email.headerregistry import Address
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

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
Interest = Literal["AI inventory search", "Robotics inventory", "Fusion and STEP models", "BOM comparison", "Parts and equipment management", "Organization-wide inventory visibility", "Other"]


class DemoRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    form_version: Literal[1, 2] = 1
    request_id: UUID
    name: str = Field(min_length=1, max_length=120, pattern=r"^[^\x00-\x1f\x7f]+$")
    organization: str = Field(min_length=1, max_length=180, pattern=r"^[^\x00-\x1f\x7f]+$")
    email: str = Field(min_length=3, max_length=254, pattern=r"^[^\s<>@,;:]+@[^\s<>@,;:]+\.[^\s<>@,;:]+$")
    interests: list[Interest] = Field(default_factory=list, max_length=7)

    # Older forms submitted contact details and interests only.
    role: str | None = Field(default=None, max_length=180)
    organization_type: Literal[
        "Robotics team", "Robotics company", "Hardware startup", "Engineering or manufacturing company",
        "Engineering company", "Manufacturing", "Research and development", "Educational institution",
        "University or research lab", "Makerspace or workshop", "School", "Other",
    ] | None = None
    team_size: Literal["1 to 10", "11 to 50", "51 to 200", "201 to 1,000", "1,000+"] | None = None
    referral: str | None = Field(default=None, max_length=1000)
    other_interest: str | None = Field(default=None, max_length=1000)
    cad_software: Literal["Autodesk Fusion", "Onshape", "SolidWorks", "Other", "We don't use CAD"] | None = None
    comments: str | None = Field(default=None, max_length=2000)
    problem: str | None = Field(default=None, max_length=4000)

    @model_validator(mode="after")
    def contact_required(self):
        if self.form_version == 2 and not (self.role and self.organization_type):
            raise ValueError("Role and organization type are required.")
        return self

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
        details = body.model_dump(exclude={"request_id", "email", "form_version"}, exclude_none=True)
        details["interests"] = sorted(set(body.interests))
        if "Other" not in body.interests:
            details.pop("other_interest", None)
        inbox.save(str(body.request_id), body.email, details)
    except inbox.TooManyRequests:
        raise HTTPException(429, "Too many demo requests. Please try again later.")
    except inbox.RequestConflict:
        raise HTTPException(409, "The request details changed. Please try again.")
    return {"status": "received"}
