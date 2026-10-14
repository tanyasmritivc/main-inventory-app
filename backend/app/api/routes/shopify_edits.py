from typing import Literal
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from app.core.auth import AuthenticatedUser, get_current_user
from app.api.routes.shopify import membership, connection
from app.services import shopify_edits as service

router = APIRouter(prefix="/teams/{team_id}/shopify/{connection_id}", tags=["shopify"])


class Permissions(BaseModel):
    model_config = ConfigDict(extra="forbid")
    edit_products: bool = Field(strict=True)
    edit_inventory: bool = Field(strict=True)
    edit_access: Literal["owner", "editors"]
    expected_revision: int = Field(ge=0, strict=True)


class ProductChanges(BaseModel):
    model_config = ConfigDict(extra="forbid")
    title: str | None = Field(None, min_length=1, max_length=200)
    vendor: str | None = Field(None, max_length=200)
    productType: str | None = Field(None, max_length=200)
    tags: list[str] | None = Field(None, max_length=30)

    @field_validator("title", "vendor", "productType")
    @classmethod
    def plain(cls, value):
        if value is None:
            return value
        if any(ord(char) < 32 or ord(char) == 127 for char in value):
            raise ValueError("Use single-line product details")
        return value.strip()

    @field_validator("tags")
    @classmethod
    def tag_labels(cls, value):
        if value is None:
            return value
        if any(not tag.strip() or len(tag) > 100 or any(ord(char) < 32 for char in tag) for tag in value):
            raise ValueError("Use short, single-line tags")
        return list(dict.fromkeys(tag.strip() for tag in value))

    @model_validator(mode="after")
    def nonempty(self):
        if not self.model_dump(exclude_none=True) or self.title is not None and not self.title:
            raise ValueError("Choose at least one product detail")
        return self


class Prepare(BaseModel):
    model_config = ConfigDict(extra="forbid")
    kind: Literal["product", "inventory"]
    variant_gid: str = Field(pattern=r"^gid://shopify/ProductVariant/\d{1,20}$")
    changes: ProductChanges | None = None
    location_gid: str | None = Field(None, pattern=r"^gid://shopify/Location/\d{1,20}$")
    delta: int | None = Field(None, ge=-1000000, le=1000000, strict=True)

    @model_validator(mode="after")
    def intent(self):
        if self.kind == "product" and (self.changes is None or self.delta is not None or self.location_gid is not None):
            raise ValueError("Choose supported product fields")
        if self.kind == "inventory" and (self.changes is not None or not self.location_gid or not self.delta):
            raise ValueError("Choose a location and nonzero whole adjustment")
        return self


class Execute(BaseModel):
    model_config = ConfigDict(extra="forbid")
    confirmed: Literal[True]


class Reviewed(BaseModel):
    model_config = ConfigDict(extra="forbid")
    checked_in_shopify: Literal[True]


@router.patch("/permissions")
def permissions(team_id: UUID, connection_id: UUID, body: Permissions, user: AuthenticatedUser = Depends(get_current_user)):
    membership(team_id, user.user_id, owner=True)
    connection(team_id, connection_id)
    if body.edit_products or body.edit_inventory:
        service.writes_ready()
    saved = service.call("permissions", team=str(team_id), connection=str(connection_id), actor=user.user_id,
        products=body.edit_products, inventory=body.edit_inventory, access=body.edit_access, revision=body.expected_revision)
    try:
        external = service.reconcile_permissions(str(team_id), str(connection_id), user.user_id)
    except HTTPException:
        # Owner policy is saved even when Shopify cannot yet confirm its grant.
        external = {"needs_authorization": None, "revocation_pending": True}
    return {"saved": True, **saved, **external}


@router.post("/permissions/refresh")
def refresh(team_id: UUID, connection_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    membership(team_id, user.user_id, owner=True)
    connection(team_id, connection_id)
    return service.reconcile_permissions(str(team_id), str(connection_id), user.user_id)


@router.post("/edits/prepare")
def prepare(team_id: UUID, connection_id: UUID, body: Prepare, user: AuthenticatedUser = Depends(get_current_user)):
    membership(team_id, user.user_id)
    connection(team_id, connection_id)
    return service.prepare(str(team_id), str(connection_id), user.user_id, body.model_dump(exclude_none=True))


@router.get("/edits")
def history(team_id: UUID, connection_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    membership(team_id, user.user_id, owner=True)
    connection(team_id, connection_id)
    db = service.get_supabase_admin()
    columns = "operation_id,kind,state,intent,snapshot,receipt,created_at,dispatched_at,reviewed_at"
    recent = db.table("shopify_operations").select(columns).eq("connection_id", str(connection_id)).order("created_at", desc=True).limit(20).execute().data or []
    unresolved = db.table("shopify_operations").select(columns).eq("connection_id", str(connection_id)).in_(
        "state", ["unknown", "sending"]).is_("reviewed_at", "null").order("created_at", desc=True).limit(20).execute().data or []
    return {"operations": list({row["operation_id"]: row for row in [*unresolved, *recent]}.values())}


@router.post("/edits/{operation_id}/review-unknown")
def reviewed(team_id: UUID, connection_id: UUID, operation_id: UUID, body: Reviewed, user: AuthenticatedUser = Depends(get_current_user)):
    membership(team_id, user.user_id, owner=True)
    connection(team_id, connection_id)
    if not service.call("review_unknown", team=str(team_id), connection=str(connection_id), actor=user.user_id, operation=str(operation_id)):
        raise HTTPException(409, "This outcome cannot be acknowledged yet. Check whether a request is still in progress.")
    return {"reviewed": True, "state": "unknown"}


@router.get("/edits/{operation_id}")
def status(team_id: UUID, connection_id: UUID, operation_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    membership(team_id, user.user_id)
    return service.operation(str(team_id), str(connection_id), user.user_id, str(operation_id))


@router.post("/edits/{operation_id}/execute")
def execute(team_id: UUID, connection_id: UUID, operation_id: UUID, body: Execute, user: AuthenticatedUser = Depends(get_current_user)):
    membership(team_id, user.user_id)
    return service.execute(str(team_id), str(connection_id), user.user_id, str(operation_id))
