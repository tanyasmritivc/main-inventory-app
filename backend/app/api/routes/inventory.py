from __future__ import annotations

from fastapi import APIRouter, Depends, File, UploadFile
import logging

import httpx

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.errors import bad_request, service_unavailable
from app.schemas.ai import AICommandRequest, AICommandResponse
from app.schemas.inventory import (
    AddItemRequest,
    AddItemResponse,
    DeleteItemResponse,
    ExtractFromImageResponse,
    ProcessBarcodeRequest,
    ProcessBarcodeResponse,
    SearchItemsRequest,
    SearchItemsResponse,
    UpdateItemRequest,
    UpdateItemResponse,
    BulkCreateRequest,
    BulkCreateResponse,
    MultiExtractFromImageResponse,
)
from app.schemas.documents import RecentActivityResponse, UploadDocumentResponse
from app.services.items_repo import add_item, bulk_create_items, delete_item, search_items_basic, update_item
from app.services.ai_agent import run_ai_command
from app.services.openai_service import (
    extract_item_from_image,
    extract_items_from_image_multi,
    interpret_barcode,
    parse_search_query_to_keywords,
    summarize_activity,
)
from app.services.documents_repo import create_activity, create_document, list_recent_activity
from app.services.storage import upload_document, upload_image

router = APIRouter(tags=["inventory"])


logger = logging.getLogger(__name__)


@router.post("/add_item", response_model=AddItemResponse)
def add_item_route(payload: AddItemRequest, user: AuthenticatedUser = Depends(get_current_user)) -> AddItemResponse:
    created = add_item(user_id=user.user_id, item=payload.model_dump())
    return AddItemResponse(item=created)


@router.post("/search_items", response_model=SearchItemsResponse)
def search_items_route(payload: SearchItemsRequest, user: AuthenticatedUser = Depends(get_current_user)) -> SearchItemsResponse:
    try:
        parsed = parse_search_query_to_keywords(query=payload.query)
        q = (parsed.get("text") or payload.query or "").strip()

        items = search_items_basic(user_id=user.user_id, q=q)

        category = parsed.get("category")
        location = parsed.get("location")
        if category:
            items = [i for i in items if (i.get("category") or "").lower() == str(category).lower()]
        if location:
            items = [i for i in items if (i.get("location") or "").lower() == str(location).lower()]

        try:
            create_activity(
                user_id=user.user_id,
                summary=f"Searched inventory: {payload.query}",
                metadata={"type": "search_items", "query": payload.query, "parsed": parsed, "results": len(items)},
            )
        except Exception:
            logger.exception("Failed to write search activity")

        return SearchItemsResponse(items=items, parsed=parsed)
    except httpx.HTTPError:
        logger.exception("Upstream error during /search_items")
        raise service_unavailable("Search temporarily unavailable. Please try again.")
    except Exception:
        logger.exception("Unhandled error during /search_items")
        raise service_unavailable("Search temporarily unavailable. Please try again.")


@router.delete("/delete_item", response_model=DeleteItemResponse)
def delete_item_route(item_id: str, user: AuthenticatedUser = Depends(get_current_user)) -> DeleteItemResponse:
    ok = delete_item(user_id=user.user_id, item_id=item_id)
    return DeleteItemResponse(deleted=ok)


@router.patch("/update_item", response_model=UpdateItemResponse)
def update_item_route(payload: UpdateItemRequest, user: AuthenticatedUser = Depends(get_current_user)) -> UpdateItemResponse:
    updates = payload.model_dump(exclude_none=True)
    item_id = str(updates.pop("item_id"))
    updated = update_item(user_id=user.user_id, item_id=item_id, updates=updates)
    if not updated:
        raise bad_request("No updates applied")
    return UpdateItemResponse(item=updated)


@router.post("/extract_from_image", response_model=ExtractFromImageResponse)
async def extract_from_image_route(
    file: UploadFile = File(...),
    user: AuthenticatedUser = Depends(get_current_user),
) -> ExtractFromImageResponse:
    raw = await file.read()
    if not raw:
        raise bad_request("Empty file")

    stored = upload_image(user_id=user.user_id, filename=file.filename or "upload.png", content=raw)
    extracted = extract_item_from_image(filename=file.filename or "upload.png", image_bytes=raw)

    return ExtractFromImageResponse(extracted=extracted, image_url=stored.url)


@router.post("/inventory/extract_from_image", response_model=MultiExtractFromImageResponse)
async def inventory_extract_from_image_route(
    file: UploadFile = File(...),
    user: AuthenticatedUser = Depends(get_current_user),
) -> MultiExtractFromImageResponse:
    raw = await file.read()
    if not raw:
        raise bad_request("Empty file")

    try:
        data = extract_items_from_image_multi(filename=file.filename or "upload.png", image_bytes=raw)
    except Exception:
        logger.exception("Vision extraction failed")
        raise service_unavailable("AI extraction temporarily unavailable. Please try again.")

    items = data.get("items") or []
    summary = data.get("summary") or {"total_detected": len(items), "categories": {}}

    if not isinstance(summary, dict):
        summary = {"total_detected": len(items), "categories": {}}

    if "total_detected" not in summary:
        summary["total_detected"] = len(items)
    if "categories" not in summary:
        summary["categories"] = {}

    try:
        create_activity(
            user_id=user.user_id,
            summary=f"Scanned image for inventory items ({len(items)} detected)",
            metadata={"type": "scan_image", "filename": file.filename, "total_detected": len(items)},
        )
    except Exception:
        logger.exception("Failed to write scan activity")

    return MultiExtractFromImageResponse(items=items, summary=summary)


@router.post("/inventory/bulk_create", response_model=BulkCreateResponse)
def inventory_bulk_create_route(
    payload: BulkCreateRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> BulkCreateResponse:
    try:
        inserted, failures = bulk_create_items(user_id=user.user_id, items=[i.model_dump() for i in payload.items])

        try:
            create_activity(
                user_id=user.user_id,
                summary=f"Saved {len(inserted)} scanned items to inventory",
                metadata={"type": "bulk_create", "inserted": len(inserted), "failures": len(failures)},
            )
        except Exception:
            logger.exception("Failed to write bulk create activity")

        return BulkCreateResponse(inserted=inserted, failures=failures)
    except httpx.HTTPError:
        logger.exception("Upstream error during bulk create")
        raise service_unavailable("Bulk insert temporarily unavailable. Please try again.")
    except Exception:
        logger.exception("Unhandled error during bulk create")
        raise service_unavailable("Bulk insert temporarily unavailable. Please try again.")


@router.post("/process_barcode", response_model=ProcessBarcodeResponse)
def process_barcode_route(
    payload: ProcessBarcodeRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> ProcessBarcodeResponse:
    guess = interpret_barcode(barcode=payload.barcode)
    return ProcessBarcodeResponse(result=guess)


@router.post("/ai_command", response_model=AICommandResponse)
def ai_command_route(
    payload: AICommandRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> AICommandResponse:
    out = run_ai_command(user_id=user.user_id, message=payload.message)

    try:
        create_activity(
            user_id=user.user_id,
            summary="Used Assist",
            metadata={"type": "ai_chat", "tool": out.get("tool"), "message": payload.message},
        )
    except Exception:
        logger.exception("Failed to write ai_chat activity")

    return AICommandResponse(
        tool=out.get("tool"),
        result=out.get("result"),
        assistant_message=out.get("assistant_message") or "",
    )


@router.post("/documents/upload", response_model=UploadDocumentResponse)
async def upload_document_route(
    file: UploadFile = File(...),
    user: AuthenticatedUser = Depends(get_current_user),
) -> UploadDocumentResponse:
    raw = await file.read()
    if not raw:
        raise bad_request("Empty file")

    filename = file.filename or "upload"
    content_type = (file.content_type or "").lower()
    allowed = {
        "application/pdf",
        "image/png",
        "image/jpg",
        "image/jpeg",
        "image/webp",
    }
    if content_type and content_type not in allowed:
        raise bad_request("Unsupported file type")

    try:
        stored = upload_document(user_id=user.user_id, filename=filename, content=raw)
        doc = create_document(
            user_id=user.user_id,
            filename=filename,
            mime_type=file.content_type,
            storage_path=stored.path,
            url=stored.url,
        )

        summary = summarize_activity(action="upload_document", details={"filename": filename, "mime_type": file.content_type})
        create_activity(user_id=user.user_id, summary=summary, metadata={"type": "upload_document", "document_id": doc.get("document_id")})

        return UploadDocumentResponse(document=doc, activity_summary=summary)
    except httpx.HTTPError:
        logger.exception("Upstream error during document upload")
        raise service_unavailable("Upload temporarily unavailable. Please try again.")
    except Exception:
        logger.exception("Unhandled error during document upload")
        raise service_unavailable("Upload temporarily unavailable. Please try again.")


@router.get("/activity/recent", response_model=RecentActivityResponse)
def recent_activity_route(
    user: AuthenticatedUser = Depends(get_current_user),
    limit: int = 10,
) -> RecentActivityResponse:
    try:
        activities = list_recent_activity(user_id=user.user_id, limit=limit)
        return RecentActivityResponse(activities=activities)
    except httpx.HTTPError:
        logger.exception("Upstream error during recent activity")
        raise service_unavailable("Activity temporarily unavailable. Please try again.")
    except Exception:
        logger.exception("Unhandled error during recent activity")
        raise service_unavailable("Activity temporarily unavailable. Please try again.")
