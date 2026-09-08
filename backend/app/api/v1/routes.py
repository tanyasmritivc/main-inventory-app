from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response

from app.api.v1.auth import APIAccess, KeyManager, key_manager, require_api_scope
from app.api.v1.crypto import create_secret
from app.api.v1.errors import APIError, IntegrationRoute
from app.api.v1.models import BulkRequest, ItemCreate, ItemPatch, KeyCreate
from app.core.config import get_settings

router = APIRouter(prefix="/api/v1", route_class=IntegrationRoute, tags=["Integrations"])
ITEM_COLUMNS = "item_id,workspace_id,name,category,quantity,location,notes,barcode,source_system,external_id,created_at"


@router.post("/keys", status_code=201)
async def create_key(body: KeyCreate, manager: KeyManager = Depends(key_manager)):
    raw, prefix, hashed = await create_secret(get_settings().api_keys_environment)
    key_id = await manager.conn.fetchval(
        "SELECT api_private.create_key($1,$2,$3,$4,$5,$6,$7)",
        manager.org_id, body.workspace_id, body.name, prefix, hashed, body.scopes, body.expires_at)
    return {"id": key_id, "key": raw, "key_prefix": prefix, "name": body.name,
            "workspace_id": body.workspace_id, "scopes": body.scopes, "expires_at": body.expires_at}


@router.get("/keys")
async def list_keys(manager: KeyManager = Depends(key_manager)):
    return {"data": [dict(row) for row in await manager.conn.fetch(
        "SELECT * FROM api_private.list_keys($1)", manager.org_id)]}


@router.delete("/keys/{key_id}", status_code=204)
async def revoke_key(key_id: UUID, manager: KeyManager = Depends(key_manager)):
    if not await manager.conn.fetchval("SELECT api_private.revoke_key($1,$2)", manager.org_id, key_id):
        raise APIError(404, "key_not_found", "Key was not found.")
    return Response(status_code=204)


def destination(access: APIAccess, requested: UUID | None) -> UUID:
    if access.principal.workspace_id:
        if requested and requested != access.principal.workspace_id:
            raise APIError(403, "workspace_forbidden", "Key cannot access that workspace.")
        return access.principal.workspace_id
    if not requested:
        raise APIError(422, "workspace_required", "Global writes require workspace_id.")
    return requested


@router.get("/items")
async def list_items(workspace_id: UUID | None = None, after: UUID | None = None,
                     limit: int = Query(50, ge=1, le=200),
                     access: APIAccess = Depends(require_api_scope("items:read"))):
    rows = await access.conn.fetch(f"SELECT {ITEM_COLUMNS} FROM public.items "
        "WHERE ($1::uuid IS NULL OR workspace_id=$1) AND ($2::uuid IS NULL OR item_id>$2) "
        "ORDER BY item_id LIMIT $3", workspace_id, after, limit + 1)
    return {"data": [dict(r) for r in rows[:limit]],
            "next_cursor": str(rows[limit-1]["item_id"]) if len(rows)>limit else None}


async def insert_item(access: APIAccess, body: ItemCreate, *, upsert=False):
    workspace = destination(access, body.workspace_id)
    # Identifiers below are constants, never request input. RLS enforces destination.
    sql = "INSERT INTO public.items(user_id,workspace_id,name,category,quantity,location,notes,barcode,source_system,external_id) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)"
    if upsert:
        sql += " ON CONFLICT(workspace_id,source_system,external_id) DO UPDATE SET name=excluded.name,category=excluded.category,quantity=excluded.quantity,location=excluded.location,notes=excluded.notes,barcode=excluded.barcode"
    row = await access.conn.fetchrow(sql + f" RETURNING {ITEM_COLUMNS}",
        access.principal.created_by, workspace, body.name, body.category, body.quantity,
        body.location, body.notes, body.barcode, body.source_system, body.external_id)
    return dict(row)


@router.post("/items", status_code=201)
async def create_item(body: ItemCreate, access: APIAccess = Depends(require_api_scope("items:write"))):
    return await insert_item(access, body)


@router.patch("/items/{item_id}")
async def update_item(item_id: UUID, body: ItemPatch,
                      access: APIAccess = Depends(require_api_scope("items:write"))):
    fields = body.model_dump(exclude_unset=True)
    assignments = ",".join(f"{name}=${i}" for i, name in enumerate(fields, 2))
    row = await access.conn.fetchrow(f"UPDATE public.items SET {assignments} WHERE item_id=$1 RETURNING {ITEM_COLUMNS}",
                                     item_id, *fields.values())
    if row is None:
        raise APIError(404, "item_not_found", "Item was not found.")
    return dict(row)


@router.post("/items/bulk")
async def bulk_items(body: BulkRequest, access: APIAccess = Depends(require_api_scope("import:write", bulk=True))):
    # One dependency transaction: the entire batch rolls back on any error.
    return {"data": [await insert_item(access, item, upsert=True) for item in body.items]}


@router.get("/spaces")
async def list_spaces(workspace_id: UUID | None = None,
                      access: APIAccess = Depends(require_api_scope("workspace:read"))):
    rows = await access.conn.fetch("SELECT DISTINCT workspace_id,location FROM public.items "
        "WHERE ($1::uuid IS NULL OR workspace_id=$1) ORDER BY workspace_id,location", workspace_id)
    return {"data": [dict(r) for r in rows]}


@router.get("/workspaces/summary")
async def workspace_summary(access: APIAccess = Depends(require_api_scope("workspace:read"))):
    rows = await access.conn.fetch("SELECT w.id,w.org_id,w.name,w.created_at,count(i.item_id) AS item_count,"
        "coalesce(sum(i.quantity),0)::bigint AS total_parts,count(DISTINCT i.location) AS space_count "
        "FROM public.workspaces w LEFT JOIN public.items i ON i.workspace_id=w.id "
        "GROUP BY w.id ORDER BY w.id")
    return {"data": [dict(r) for r in rows]}
