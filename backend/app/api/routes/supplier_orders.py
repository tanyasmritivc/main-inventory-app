"""Organization supplier-order imports, evidence and explicit receipts."""

import base64
import json
from typing import Annotated
from urllib.parse import quote
from uuid import UUID

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    Response,
    UploadFile,
)

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.commerce import supplier_orders as orders
from app.services.commerce.repository import authorize_scope

router = APIRouter(prefix="/organizations/{org}/orders", tags=["orders"])
User = Annotated[AuthenticatedUser, Depends(get_current_user)]


def read_source(file):
    return file.file.read(orders.MAX_BYTES + 1)


def json_form(value, kind):
    if value is None:
        return None
    try:
        result = json.loads(value)
    except ValueError:
        result = None
    if not isinstance(result, kind):
        raise HTTPException(422, "Review the file column assignments.")
    return result


@router.post("/preview")
def preview(
    org: UUID,
    user: User,
    file: UploadFile = File(...),
    space_id: UUID | None = Form(None),
    assignments: str | None = Form(None, max_length=50000),
    pasted: str | None = Form(None, max_length=500000),
):
    authorize_scope("organization", org, (user.actor_id or user.user_id))
    source = orders.isolated_preview(
        read_source(file),
        file.filename,
        json_form(assignments, list),
        json_form(pasted, dict),
    )

    if space_id:
        source["space_review"] = orders.rpc(
            user.actor_id or user.user_id,
            org,
            "preview",
            {
                "space_id": str(space_id),
                "digest": source["digest"],
                "rows": [{"sku": r["sku"], "name": r["name"]} for r in source["rows"]],
            },
        )
    return source


@router.post("/import")
def confirm(
    org: UUID,
    user: User,
    file: UploadFile = File(...),
    space_id: UUID | None = Form(None),
    supplier: str = Form(min_length=1, max_length=120),
    pasted: str | None = Form(None, max_length=500000),
    historical: bool = Form(...),
    assignments: str = Form(max_length=50000),
    rows: str = Form(max_length=500000),
    digest: str = Form(min_length=64, max_length=64),
):
    authorize_scope("organization", org, (user.actor_id or user.user_id))
    data = read_source(file)
    source = orders.isolated_preview(
        data, file.filename, json_form(assignments, list), json_form(pasted, dict)
    )
    if digest != source["digest"] or not supplier.strip():
        raise HTTPException(
            422, "Review this file and enter its supplier before importing."
        )
    try:
        selected = json.loads(rows)
    except ValueError:
        raise HTTPException(422, "Review the order lines before importing.") from None
    if not isinstance(selected, list):
        raise HTTPException(422, "Provide a list of reviewed order lines.")
    return orders.rpc(
        (user.actor_id or user.user_id),
        org,
        "import",
        {
            "rows": orders.reviewed(selected, source),
            "space_id": str(space_id) if space_id else None,
            "historical": historical,
            "supplier": supplier,
            "digest": digest,
            "filename": source["filename"],
            "content": base64.b64encode(data).decode("ascii"),
        },
    )


@router.get("")
def search(
    org: UUID,
    user: User,
    query: str = Query("", max_length=200),
    offset: int = Query(0, ge=0),
    space_id: UUID | None = None,
):
    return orders.evidence(
        (user.actor_id or user.user_id), str(org), query, offset, space_id
    )


@router.get("/items")
def destinations(
    org: UUID,
    inventory_id: UUID,
    user: User,
    space_id: UUID | None = None,
    query: str = Query("", max_length=200),
    offset: int = Query(0, ge=0),
):
    return orders.rpc(
        (user.actor_id or user.user_id),
        org,
        "items",
        {
            "inventory_id": str(inventory_id),
            "space_id": str(space_id) if space_id else None,
            "query": query,
            "offset": offset,
        },
    )


@router.get("/{line_id}/fields")
def original_fields(org: UUID, line_id: UUID, user: User):
    return orders.rpc(
        (user.actor_id or user.user_id), org, "fields", {"id": str(line_id)}
    )


@router.get("/sources/{document_id}")
def download(org: UUID, document_id: UUID, user: User):
    doc = orders.rpc(
        (user.actor_id or user.user_id), org, "source", {"id": str(document_id)}
    )
    return Response(
        base64.b64decode(doc["content"]),
        media_type="application/octet-stream",
        headers={
            "Cache-Control": "private, no-store",
            "X-Content-Type-Options": "nosniff",
            "Content-Disposition": "attachment; filename*=UTF-8''"
            + quote(doc["filename"], safe=""),
        },
    )


@router.post("/{line_id}/receipts")
def record(org: UUID, line_id: UUID, receipt: orders.Receipt, user: User):
    return orders.rpc(
        (user.actor_id or user.user_id),
        org,
        "receipt",
        {**receipt.model_dump(mode="json"), "line_id": str(line_id)},
    )
