import json
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field, ConfigDict, model_validator, field_validator

from app.core.auth import AuthenticatedUser, get_current_user
from app.api.routes.shopify import membership
from app.services import physical_memory as service

router = APIRouter(prefix="/teams/{team_id}/physical", tags=["physical-memory"])


class Confirmation(BaseModel):
    model_config = ConfigDict(extra="forbid")
    request_id: UUID
    native_label: str = Field(min_length=1, max_length=200)
    memory_id: UUID | None = None
    connection_id: UUID | None = None
    variant_gid: str | None = Field(None, pattern=r"^gid://shopify/ProductVariant/\d{1,20}$")
    placement_id: UUID | None = None
    expected_revision: int = Field(ge=0, strict=True)
    space_id: UUID | None = None
    bin_id: UUID | None = None
    observed_count: int | None = Field(None, ge=0, le=2147483647, strict=True)
    barcode: str | None = Field(None, min_length=1, max_length=255)
    action: str = Field("confirm", pattern="^(confirm|remove)$")

    @field_validator("native_label")
    @classmethod
    def clean_label(cls, value):
        value = value.strip()
        if not value or any(ord(ch) < 32 or ord(ch) == 127 for ch in value):
            raise ValueError("Use a single-line name")
        return value

    @model_validator(mode="after")
    def identity(self):
        if bool(self.connection_id) != bool(self.variant_gid) or not (self.memory_id or self.connection_id) or (self.memory_id and self.connection_id):
            raise ValueError("Choose a memory or catalog variant")
        if self.action == "confirm" and not self.space_id:
            raise ValueError("Choose a Space")
        if self.action == "remove" and not self.placement_id:
            raise ValueError("Choose a saved location")
        return self


class Lookup(BaseModel):
    model_config = ConfigDict(extra="forbid")
    question: str = Field(min_length=1, max_length=4000)
    barcode: str | None = Field(None, min_length=1, max_length=255)
    memory_id: UUID | None = None
    connection_id: UUID | None = None
    variant_gid: str | None = Field(None, pattern=r"^gid://shopify/ProductVariant/\d{1,20}$")

    @model_validator(mode="after")
    def identity(self):
        if bool(self.connection_id) != bool(self.variant_gid) or (self.memory_id and self.connection_id):
            raise ValueError("Select one record")
        return self


def access(team, user):
    member = membership(str(team), user.user_id)
    if not service.enabled():
        raise HTTPException(503, "Physical memory is not enabled yet.")
    return member


@router.get("/options")
def options(team_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    access(team_id, user)
    return service.call("options", team=str(team_id), actor=user.user_id)


@router.post("/confirm")
def confirm(team_id: UUID, body: Confirmation, user: AuthenticatedUser = Depends(get_current_user)):
    member = access(team_id, user)
    if member["role"] == "viewer":
        raise HTTPException(403, "You have view-only access to this Team.")
    payload = body.model_dump(mode="json", exclude={"request_id"})
    return service.call("confirm", team=str(team_id), actor=user.user_id, request=str(body.request_id), payload=payload)


@router.post("/ask")
def ask(team_id: UUID, body: Lookup, stream: bool = False, user: AuthenticatedUser = Depends(get_current_user)):
    access(team_id, user)
    answer = service.answer(str(team_id), user.user_id, body.model_dump(mode="json"))
    if not stream:
        return answer
    # Same read-only path in JSON and streaming. Never enter the general agent's
    # mutable inventory tools or copy Team context into personal chat memory.
    access(team_id, user)
    def events():
        yield "data: " + json.dumps({"type": "delta", "delta": answer["assistant_message"]}) + "\n\n"
        yield "data: " + json.dumps({"type": "done", **answer}) + "\n\n"
        yield "data: [DONE]\n\n"
    return StreamingResponse(events(), media_type="text/event-stream", headers={"Cache-Control": "no-store"})


@router.get("/placements/{placement_id}/history")
def history(team_id: UUID, placement_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    access(team_id, user)
    return service.call("history", team=str(team_id), actor=user.user_id, placement=str(placement_id))
