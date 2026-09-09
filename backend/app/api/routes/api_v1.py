import logging
from datetime import datetime, timezone
from typing import Annotated
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from postgrest.types import CountMethod, ReturnMethod
from postgrest.exceptions import APIError
from pydantic import BaseModel, Field, field_validator

from app.core.api_key_auth import (
    APIKeyPrincipal,
    api_error,
    generate_api_key,
    hash_api_key,
    require_api_scope,
    validate_scopes,
)
from app.core.auth import AuthenticatedUser, get_current_user
from app.core.config import get_settings
from app.services.api_key_client import create_api_key_rls_client
from app.services.supabase_client import get_supabase_admin

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1", tags=["integration-api"])


class CreateKeyRequest(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    workspace_id: UUID | None = None
    scopes: list[str] = Field(min_length=1, max_length=8)
    expires_at: datetime | None = None

    @field_validator("name")
    @classmethod
    def clean_name(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("name is required")
        return value


class APIItemCreate(BaseModel):
    workspace_id: UUID | None = None
    name: str = Field(min_length=1, max_length=200)
    category: str = Field(default="Other", min_length=1, max_length=100)
    quantity: int = Field(default=1, ge=0, le=100000)
    location: str = Field(min_length=1, max_length=200)
    image_url: str | None = Field(default=None, max_length=2000)
    barcode: str | None = Field(default=None, max_length=100)
    purchase_source: str | None = Field(default=None, max_length=200)
    notes: str | None = Field(default=None, max_length=2000)
    brand: str | None = Field(default=None, max_length=100)
    part_number: str | None = Field(default=None, max_length=100)
    source_system: str | None = Field(default=None, max_length=100)
    external_id: str | None = Field(default=None, max_length=200)

    @field_validator("name", "category", "location")
    @classmethod
    def clean_required_text(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("must not be blank")
        return value


class APIItemPatch(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    category: str | None = Field(default=None, min_length=1, max_length=100)
    quantity: int | None = Field(default=None, ge=0, le=100000)
    location: str | None = Field(default=None, min_length=1, max_length=200)
    image_url: str | None = Field(default=None, max_length=2000)
    barcode: str | None = Field(default=None, max_length=100)
    purchase_source: str | None = Field(default=None, max_length=200)
    notes: str | None = Field(default=None, max_length=2000)
    brand: str | None = Field(default=None, max_length=100)
    part_number: str | None = Field(default=None, max_length=100)
    source_system: str | None = Field(default=None, max_length=100)
    external_id: str | None = Field(default=None, max_length=200)


class APIBulkItem(APIItemCreate):
    source_system: str = Field(min_length=1, max_length=100)
    external_id: str = Field(min_length=1, max_length=200)

    @field_validator("source_system", "external_id")
    @classmethod
    def clean_external_identity(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("must not be blank")
        return value


class APIBulkRequest(BaseModel):
    items: list[APIBulkItem] = Field(min_length=1)


ITEM_COLUMNS = (
    "item_id,workspace_id,name,category,quantity,location,image_url,barcode,"
    "purchase_source,notes,brand,part_number,source_system,external_id,created_at"
)


def _assert_workspace_owned(request: Request, user_id: str, workspace_id: str) -> None:
    rows = get_supabase_admin().table("teams").select("team_id").eq(
        "team_id", workspace_id
    ).eq("owner_user_id", user_id).limit(1).execute().data or []
    if not rows:
        raise api_error(request, 403, "workspace_access_denied", "You do not own this workspace.")


def _assert_org_exists(request: Request, user_id: str) -> None:
    rows = get_supabase_admin().table("teams").select("team_id").eq(
        "owner_user_id", user_id
    ).limit(1).execute().data or []
    if not rows:
        raise api_error(request, 403, "organization_required", "Create or own a team before creating an organization key.")


@router.post("/keys", status_code=201)
def create_key(payload: CreateKeyRequest, request: Request, user: AuthenticatedUser = Depends(get_current_user)):
    workspace_id = str(payload.workspace_id) if payload.workspace_id else None
    try:
        scopes = validate_scopes(workspace_id=workspace_id, scopes=payload.scopes)
    except ValueError as exc:
        raise api_error(request, 400, str(exc), "Scopes do not match the requested key type.")
    if payload.expires_at:
        expires_at = payload.expires_at
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if expires_at <= datetime.now(timezone.utc):
            raise api_error(request, 400, "invalid_expiration", "expires_at must be in the future.")
    else:
        expires_at = None

    if workspace_id:
        _assert_workspace_owned(request, user.user_id, workspace_id)
    else:
        _assert_org_exists(request, user.user_id)

    environment = "live" if get_settings().env == "production" else "test"
    raw_key = generate_api_key(environment)
    record = {
        "workspace_id": workspace_id,
        "org_id": user.user_id,
        "name": payload.name,
        "key_prefix": raw_key[:20],
        "key_hash": hash_api_key(raw_key),
        "scopes": sorted(scopes),
        "created_by": user.user_id,
        "expires_at": expires_at.isoformat() if expires_at else None,
    }
    try:
        created = get_supabase_admin().table("api_keys").insert(record).execute().data[0]
    except Exception:
        logger.exception("Could not create API key for org=%s", user.user_id)
        raise api_error(request, 503, "key_creation_unavailable", "The API key could not be created.")
    created.pop("key_hash", None)
    return {**created, "key": raw_key}


@router.get("/keys")
def list_keys(request: Request, user: AuthenticatedUser = Depends(get_current_user)):
    try:
        rows = get_supabase_admin().table("api_keys").select(
            "id,workspace_id,name,key_prefix,scopes,created_at,last_used_at,expires_at,revoked_at"
        ).eq("org_id", user.user_id).order("created_at", desc=True).execute().data or []
        return {"keys": rows}
    except Exception:
        logger.exception("Could not list API keys for org=%s", user.user_id)
        raise api_error(request, 503, "key_list_unavailable", "API keys could not be loaded.")


@router.delete("/keys/{key_id}")
def revoke_key(key_id: UUID, request: Request, user: AuthenticatedUser = Depends(get_current_user)):
    now = datetime.now(timezone.utc).isoformat()
    try:
        rows = get_supabase_admin().table("api_keys").update({"revoked_at": now}).eq(
            "id", str(key_id)
        ).eq("org_id", user.user_id).is_("revoked_at", "null").execute().data or []
    except Exception:
        logger.exception("Could not revoke API key id=%s", key_id)
        raise api_error(request, 503, "key_revocation_unavailable", "The API key could not be revoked.")
    if not rows:
        raise api_error(request, 404, "key_not_found", "The API key was not found or was already revoked.")
    return {"revoked": True, "id": str(key_id), "revoked_at": now}


def _write_workspace(request: Request, principal: APIKeyPrincipal, requested: UUID | None) -> str:
    requested_id = str(requested) if requested else None
    if principal.workspace_id:
        if requested_id and requested_id != principal.workspace_id:
            raise api_error(request, 403, "workspace_access_denied", "The key cannot access that workspace.")
        return principal.workspace_id
    if not requested_id:
        raise api_error(request, 400, "workspace_required", "workspace_id is required for an organization key write.")
    return requested_id


def _item_payload(item: APIItemCreate, principal: APIKeyPrincipal, request: Request) -> dict:
    workspace_id = _write_workspace(request, principal, item.workspace_id)
    data = item.model_dump(exclude={"workspace_id"}, exclude_none=True)
    data.update({"workspace_id": workspace_id, "user_id": principal.key_id})
    return data


def _data_failure(request: Request, action: str, error: Exception) -> HTTPException:
    logger.exception("Integration API %s failed correlation_id=%s", action, getattr(request.state, "correlation_id", "unknown"))
    if isinstance(error, APIError) and str(getattr(error, "code", "")) == "42501":
        return api_error(request, 403, "workspace_access_denied", "The key cannot access that workspace.")
    return api_error(request, 503, "database_unavailable", "The inventory service is temporarily unavailable.")


@router.get("/items")
def get_items(
    request: Request,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 50,
    principal: APIKeyPrincipal = Depends(require_api_scope("items:read")),
):
    try:
        client = create_api_key_rls_client(principal)
        query = client.table("items").select(ITEM_COLUMNS, count="exact")
        if principal.workspace_id:
            query = query.eq("workspace_id", principal.workspace_id)
        start = (page - 1) * page_size
        result = query.order("created_at", desc=True).range(start, start + page_size - 1).execute()
        return {"items": result.data or [], "page": page, "page_size": page_size, "total": result.count or 0}
    except HTTPException:
        raise
    except Exception as exc:
        raise _data_failure(request, "list items", exc)


@router.post("/items", status_code=201)
def post_item(
    payload: APIItemCreate,
    request: Request,
    principal: APIKeyPrincipal = Depends(require_api_scope("items:write")),
):
    try:
        record = _item_payload(payload, principal, request)
        record["item_id"] = str(uuid4())
        create_api_key_rls_client(principal).table("items").insert(
            record, returning=ReturnMethod.minimal
        ).execute()
        return {"item": {key: value for key, value in record.items() if key != "user_id"}}
    except HTTPException:
        raise
    except Exception as exc:
        raise _data_failure(request, "create item", exc)


@router.post("/items/bulk")
def bulk_items(
    payload: APIBulkRequest,
    request: Request,
    principal: APIKeyPrincipal = Depends(require_api_scope("import:write", bulk=True)),
):
    if len(payload.items) > get_settings().api_key_bulk_max_items:
        raise api_error(request, 413, "bulk_payload_too_large", "The bulk payload contains too many items.")
    try:
        records = [_item_payload(item, principal, request) for item in payload.items]
        create_api_key_rls_client(principal).table("items").upsert(
            records,
            on_conflict="workspace_id,source_system,external_id",
            returning=ReturnMethod.minimal,
        ).execute()
        return {"processed": len(records)}
    except HTTPException:
        raise
    except Exception as exc:
        raise _data_failure(request, "bulk upsert", exc)


@router.patch("/items/{item_id}")
def patch_item(
    item_id: UUID,
    payload: APIItemPatch,
    request: Request,
    principal: APIKeyPrincipal = Depends(require_api_scope("items:write")),
):
    changes = payload.model_dump(exclude_unset=True)
    if not changes:
        raise api_error(request, 400, "empty_update", "At least one field must be supplied.")
    try:
        result = create_api_key_rls_client(principal).table("items").update(
            changes, count=CountMethod.exact, returning=ReturnMethod.minimal
        ).eq(
            "item_id", str(item_id)
        ).execute()
        if not result.count:
            raise api_error(request, 404, "item_not_found", "The item was not found.")
        return {"updated": True, "item_id": str(item_id)}
    except HTTPException:
        raise
    except Exception as exc:
        raise _data_failure(request, "update item", exc)


@router.get("/spaces")
def get_spaces(
    request: Request,
    principal: APIKeyPrincipal = Depends(require_api_scope("workspace:read")),
):
    try:
        result = create_api_key_rls_client(principal).rpc("api_distinct_locations", {
            "p_workspace_id": principal.workspace_id,
        }).execute()
        return {"spaces": result.data or []}
    except Exception as exc:
        raise _data_failure(request, "list spaces", exc)


@router.get("/workspaces/summary")
def get_workspace_summary(
    request: Request,
    principal: APIKeyPrincipal = Depends(require_api_scope("workspace:read")),
):
    try:
        result = create_api_key_rls_client(principal).rpc("api_workspace_summary").execute()
        return {"workspaces": result.data or []}
    except Exception as exc:
        raise _data_failure(request, "workspace summary", exc)
