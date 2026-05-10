from __future__ import annotations

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, Response, UploadFile
from fastapi import status
from fastapi.responses import StreamingResponse
import logging

from typing import Any

from pydantic import BaseModel

import io

import httpx
import anyio
import openai
from PIL import Image

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.config import get_settings
from app.core.errors import bad_gateway, bad_request, service_unavailable
from app.schemas.ai import AICommandRequest, AICommandResponse
from app.schemas.inventory import (
    AddItemRequest,
    AddItemResponse,
    DeleteItemResponse,
    ExtractFromImageResponse,
    ProcessBarcodeRequest,
    ProcessBarcodeResponse,
    BarcodeLookupRequest,
    BarcodeLookupResponse,
    SearchItemsRequest,
    SearchItemsResponse,
    UpdateItemRequest,
    UpdateItemResponse,
    BulkCreateRequest,
    BulkCreateResponse,
    MultiExtractFromImageResponse,
)
from app.schemas.documents import ListDocumentsResponse, RecentActivityResponse, UploadDocumentResponse
from app.services.items_repo import add_item, bulk_create_items, delete_item, search_items_basic, update_item
from app.services import sharing_service
from app.services.ai_agent import iter_ai_command_sse, run_ai_command
from app.services.openai_service import (
    extract_item_from_image,
    extract_items_from_image_multi,
    interpret_barcode,
    iter_assist_file_analysis_sse,
    parse_search_query_to_keywords,
    summarize_activity,
)
from app.services.documents_repo import (
    create_activity,
    create_document,
    list_documents,
    list_recent_activity,
    rename_document,
    set_document_item_link,
)
from app.services.supabase_client import get_supabase_admin
from app.services.storage import upload_document, upload_image

def _convert_to_jpeg(image_bytes: bytes, filename: str) -> tuple[bytes, str]:
    if filename.lower().endswith(".heic"):
        try:
            img = Image.open(io.BytesIO(image_bytes))
            output = io.BytesIO()
            img.convert("RGB").save(output, format="JPEG", quality=85)
            return output.getvalue(), "converted.jpg"
        except Exception:
            pass
    return image_bytes, filename


router = APIRouter(tags=["inventory"])


logger = logging.getLogger(__name__)


_INVALID_NAMES = {
    "unknown",
    "unknown item",
    "n/a",
    "na",
    "none",
    "null",
}


def is_valid_result(result: dict[str, Any] | None) -> bool:
    if not isinstance(result, dict):
        return False
    raw = (result.get("name") or "").strip()
    if not raw:
        return False
    lowered = raw.lower().strip()
    if lowered in _INVALID_NAMES:
        return False
    if lowered.startswith("unknown"):
        return False
    return True


async def lookup_go_upc(barcode: str) -> dict[str, Any] | None:
    settings = get_settings()
    api_key = (settings.go_upc_api_key or "").strip()
    if not api_key:
        return None

    b = (barcode or "").strip()
    if not b:
        return None

    url = f"https://go-upc.com/api/v1/code/{b}"
    timeout = httpx.Timeout(4.0, connect=2.0)
    async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
        res = await client.get(
            url,
            params={"format": "true"},
            headers={"Authorization": f"Bearer {api_key}", "User-Agent": "main-inventory-app/1.0"},
        )

    if res.status_code != 200:
        return None

    data = res.json() if res.content else {}
    if not isinstance(data, dict):
        return None

    product = data.get("product")
    if not isinstance(product, dict):
        return None

    out: dict[str, Any] = {
        "barcode": b,
        "name": (product.get("name") or "").strip(),
        "brand": (product.get("brand") or "").strip() or None,
        "category": (product.get("category") or "").strip() or None,
        "image_url": (product.get("imageUrl") or "").strip() or None,
    }
    return out if is_valid_result(out) else None


async def lookup_upcitemdb(barcode: str) -> dict[str, Any] | None:
    settings = get_settings()
    b = (barcode or "").strip()
    if not b:
        return None

    user_key = (settings.upcitemdb_user_key or "").strip()
    key_type = (settings.upcitemdb_key_type or "3scale").strip() or "3scale"
    if user_key:
        url = "https://api.upcitemdb.com/prod/v1/lookup"
        headers = {"user_key": user_key, "key_type": key_type, "User-Agent": "main-inventory-app/1.0"}
    else:
        url = "https://api.upcitemdb.com/prod/trial/lookup"
        headers = {"User-Agent": "main-inventory-app/1.0"}

    timeout = httpx.Timeout(4.0, connect=2.0)
    async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
        res = await client.get(url, params={"upc": b}, headers=headers)

    if res.status_code != 200:
        return None

    data = res.json() if res.content else {}
    if not isinstance(data, dict):
        return None

    items = data.get("items")
    if not isinstance(items, list) or not items:
        return None
    first = items[0]
    if not isinstance(first, dict):
        return None

    images = first.get("images")
    image_url = None
    if isinstance(images, list) and images:
        image_url = str(images[0]).strip() or None

    out: dict[str, Any] = {
        "barcode": b,
        "name": (first.get("title") or "").strip(),
        "brand": (first.get("brand") or "").strip() or None,
        "category": (first.get("category") or "").strip() or None,
        "image_url": image_url,
    }
    return out if is_valid_result(out) else None


async def lookup_openfoodfacts(barcode: str) -> dict[str, Any] | None:
    b = (barcode or "").strip()
    if not b:
        return None

    url = f"https://world.openfoodfacts.org/api/v0/product/{b}.json"
    timeout = httpx.Timeout(4.0, connect=2.0)
    async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
        res = await client.get(url, headers={"User-Agent": "main-inventory-app/1.0"})

    if res.status_code != 200:
        return None

    data = res.json() if res.content else {}
    if not isinstance(data, dict) or data.get("status") != 1:
        return None

    product = data.get("product")
    if not isinstance(product, dict):
        return None

    name = (
        product.get("product_name")
        or product.get("product_name_en")
        or product.get("generic_name")
        or product.get("generic_name_en")
        or ""
    ).strip()
    brand = (product.get("brands") or "").strip() or None
    category = (product.get("categories") or "").strip() or None
    image_url = (product.get("image_url") or product.get("image_front_url") or "").strip() or None

    out: dict[str, Any] = {
        "barcode": b,
        "name": name,
        "brand": brand,
        "category": category,
        "image_url": image_url,
    }
    return out if is_valid_result(out) else None


class RenameDocumentRequest(BaseModel):
    storage_path: str
    display_name: str


class DocumentLinkRequest(BaseModel):
    storage_path: str
    item_id: str | None = None


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
        logger.exception("OpenAI error during /search_items")
        raise bad_gateway("Search temporarily unavailable. Please try again.")


@router.delete("/delete_item", response_model=DeleteItemResponse)
def delete_item_route(item_id: str, user: AuthenticatedUser = Depends(get_current_user)) -> DeleteItemResponse:
    ok = delete_item(user_id=user.user_id, item_id=item_id)
    return DeleteItemResponse(deleted=ok)


@router.patch("/update_item", response_model=UpdateItemResponse)
def update_item_route(payload: UpdateItemRequest, user: AuthenticatedUser = Depends(get_current_user)) -> UpdateItemResponse:
    try:
        updates = payload.model_dump(exclude_none=True)
        item_id = str(updates.pop("item_id"))
        updated = update_item(user_id=user.user_id, item_id=item_id, updates=updates)
        if not updated:
            raise bad_request("No updates applied")
        return UpdateItemResponse(item=updated)
    except Exception:
        logger.exception("Unhandled error during /update_item")
        raise service_unavailable("Update temporarily unavailable. Please try again.")


@router.post("/extract_from_image", response_model=ExtractFromImageResponse)
async def extract_from_image_route(
    file: UploadFile = File(...),
    user: AuthenticatedUser = Depends(get_current_user),
) -> ExtractFromImageResponse:
    raw = await file.read()
    if not raw:
        raise bad_request("Empty file")

    stored = upload_image(user_id=user.user_id, filename=file.filename or "upload.png", content=raw)
    try:
        extracted = extract_item_from_image(filename=file.filename or "upload.png", image_bytes=raw)
    except (openai.APITimeoutError, openai.APIConnectionError) as exc:
        logger.error("Vision extraction timed out (file=%s, size=%d): %s", file.filename, len(raw), exc)
        raise bad_gateway("Analysis timed out — please try a clearer photo.")
    except Exception:
        logger.exception("Vision extraction failed (file=%s, size=%d)", file.filename, len(raw))
        raise bad_gateway("AI extraction temporarily unavailable. Please try again.")

    return ExtractFromImageResponse(extracted=extracted, image_url=stored.url)


@router.post("/inventory/extract_from_image", response_model=MultiExtractFromImageResponse)
async def inventory_extract_from_image_route(
    file: UploadFile = File(...),
    user: AuthenticatedUser = Depends(get_current_user),
) -> MultiExtractFromImageResponse:
    raw = await file.read()
    if not raw:
        raise bad_request("Empty file")

    filename = file.filename or "upload.png"
    raw, filename = _convert_to_jpeg(raw, filename)

    try:
        data = extract_items_from_image_multi(filename=filename, image_bytes=raw)
    except openai.BadRequestError as exc:
        logger.error("Vision extraction bad request (file=%s): %s", file.filename, exc)
        raise HTTPException(status_code=422, detail=f"Could not analyze image: {str(exc)}")
    except Exception as exc:
        logger.exception("Vision extraction failed (file=%s, size=%d): %s", file.filename, len(raw), exc)
        raise HTTPException(status_code=500, detail="Image analysis failed. Please try a clearer photo.")

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


@router.post("/barcode_lookup", response_model=BarcodeLookupResponse)
async def barcode_lookup_route(
    payload: BarcodeLookupRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> BarcodeLookupResponse:
    _ = user
    barcode = (payload.barcode or "").strip()
    if not barcode:
        raise bad_request("Missing barcode")

    out: dict[str, Any] | None = None

    # STEP 1: Try UPCitemDB API
    try:
        out = await lookup_upcitemdb(barcode)
    except Exception:
        logger.exception("UPCitemDB lookup failed")
        out = None

    # STEP 2: Try Go-UPC API
    if out is None:
        try:
            out = await lookup_go_upc(barcode)
        except Exception:
            logger.exception("Go-UPC lookup failed")
            out = None

    # STEP 3: Try Open Food Facts API
    if out is None:
        try:
            out = await lookup_openfoodfacts(barcode)
        except Exception:
            logger.exception("OpenFoodFacts barcode lookup failed")
            out = None

    # STEP 4: Final fallback to AI logic
    if out is None:
        try:
            ai_out = await anyio.to_thread.run_sync(lambda: interpret_barcode(barcode=barcode))
            if isinstance(ai_out, dict):
                ai_norm: dict[str, Any] = {
                    "barcode": barcode,
                    "name": (ai_out.get("name") or "").strip(),
                    "brand": (ai_out.get("brand") or "").strip() or None,
                    "category": (ai_out.get("category") or "").strip() or None,
                    "image_url": (ai_out.get("image_url") or "").strip() or None,
                    "model": (ai_out.get("model") or ai_out.get("part_number") or None),
                }
                if is_valid_result(ai_norm):
                    out = ai_norm
        except Exception:
            logger.exception("AI barcode fallback failed")
            out = None

    if not is_valid_result(out):
        return BarcodeLookupResponse(
            barcode=barcode,
            name="Unknown item",
            brand=None,
            model=None,
            category=None,
            image_url=None,
        )

    return BarcodeLookupResponse(
        barcode=barcode,
        name=(out.get("name") or "Unknown item"),
        brand=out.get("brand") or None,
        model=out.get("model") if isinstance(out, dict) else None,
        category=out.get("category") or None,
        image_url=out.get("image_url") or None,
    )


@router.post("/ai_command", response_model=AICommandResponse)
def ai_command_route(
    payload: AICommandRequest,
    request: Request,
    user: AuthenticatedUser = Depends(get_current_user),
    stream: bool = False,
) -> AICommandResponse:
    accept = (request.headers.get("accept") or "").lower()
    wants_stream = bool(stream) or ("text/event-stream" in accept)

    if wants_stream:
        try:
            def _wrap_sse(gen):
                done_sent = False
                try:
                    for chunk in gen:
                        if not done_sent and isinstance(chunk, str) and '"type": "done"' in chunk:
                            done_sent = True
                        yield chunk
                except Exception:
                    logger.exception("AI command stream generator failed")
                finally:
                    if not done_sent:
                        yield 'event: end\n'
                        yield 'data: {"type":"done","tool":null,"result":null,"assistant_message":"Let me think about that..."}\n\n'

            gen = iter_ai_command_sse(user_id=user.user_id, message=payload.message, first_name=user.first_name, conversation_history=payload.conversation_history or None)
            wrapped = _wrap_sse(gen)
            return StreamingResponse(
                wrapped,
                media_type="text/event-stream",
                headers={
                    "Cache-Control": "no-cache",
                    "Connection": "keep-alive",
                    "X-Accel-Buffering": "no",
                },
            )
        except Exception:
            logger.exception("AI command stream failed")
            raise bad_gateway("AI temporarily unavailable. Please try again.")

    try:
        out = run_ai_command(user_id=user.user_id, message=payload.message, first_name=user.first_name, conversation_history=payload.conversation_history or None)
    except Exception:
        logger.exception("AI command failed")
        raise bad_gateway("AI temporarily unavailable. Please try again.")

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
        assistant_message=out.get("assistant_message") or "Let me think about that...",
    )


@router.post("/ai_upload")
def ai_upload_route(
    request: Request,
    file: UploadFile = File(...),
    user: AuthenticatedUser = Depends(get_current_user),
) -> StreamingResponse:
    accept = (request.headers.get("accept") or "").lower()
    wants_stream = "text/event-stream" in accept
    if not wants_stream:
        raise bad_request("Streaming required")

    try:
        raw = file.file.read() if file.file is not None else b""
    except Exception:
        logger.exception("Failed to read uploaded file")
        raise bad_request("Invalid upload")

    def _wrap_sse(gen):
        done_sent = False
        try:
            for chunk in gen:
                if not done_sent and isinstance(chunk, str) and '"type": "done"' in chunk:
                    done_sent = True
                yield chunk
        except Exception:
            logger.exception("AI upload stream generator failed")
        finally:
            if not done_sent:
                yield 'event: end\n'
                yield 'data: {"type":"done","tool":null,"result":null,"assistant_message":""}\n\n'

    gen = iter_assist_file_analysis_sse(
        filename=file.filename or "upload",
        mime_type=file.content_type,
        content=raw,
    )
    wrapped = _wrap_sse(gen)
    return StreamingResponse(
        wrapped,
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@router.post("/documents/upload", response_model=UploadDocumentResponse)
async def upload_document_route(
    file: UploadFile = File(...),
    item_id: str | None = Form(None),
    user: AuthenticatedUser = Depends(get_current_user),
) -> UploadDocumentResponse:
    raw = await file.read()
    if not raw:
        raise bad_request("Empty file")

    filename = file.filename or "upload"
    content_type = (file.content_type or "").lower()
    allowed = {
        "application/pdf",
        "text/plain",
        "image/png",
        "image/jpg",
        "image/jpeg",
        "image/webp",
    }
    if content_type and content_type not in allowed:
        raise bad_request("Unsupported file type")

    try:
        stored = upload_document(user_id=user.user_id, filename=filename, content=raw)

        mime = (file.content_type or "").lower()
        file_type = "pdf" if (mime == "application/pdf" or filename.lower().endswith(".pdf")) else "image"

        doc = create_document(
            user_id=user.user_id,
            filename=filename,
            mime_type=file.content_type,
            storage_path=stored.path,
            file_type=file_type,
            size_bytes=len(raw),
            item_id=(item_id or "").strip() or None,
        )

        summary = summarize_activity(action="upload_document", details={"filename": filename, "mime_type": file.content_type})
        create_activity(user_id=user.user_id, summary=summary, metadata={"type": "upload_document", "storage_path": stored.path})

        return UploadDocumentResponse(document=doc, activity_summary=summary)
    except httpx.HTTPError:
        logger.exception("Upstream error during document upload")
        raise service_unavailable("Upload temporarily unavailable. Please try again.")
    except Exception:
        logger.exception("Unhandled error during document upload")
        raise service_unavailable("Upload temporarily unavailable. Please try again.")


@router.get("/documents", response_model=ListDocumentsResponse)
def list_documents_route(
    user: AuthenticatedUser = Depends(get_current_user),
    item_id: str | None = None,
    limit: int = 200,
) -> ListDocumentsResponse:
    docs = list_documents(user_id=user.user_id, limit=limit, item_id=item_id)
    return ListDocumentsResponse(documents=docs)


@router.patch("/documents/rename")
def rename_document_route(
    payload: RenameDocumentRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> dict:
    storage_path = (payload.storage_path or "").strip()
    display_name = (payload.display_name or "").strip()
    if not storage_path:
        raise bad_request("Missing storage_path")
    if not display_name:
        raise bad_request("Missing display_name")

    try:
        doc = rename_document(user_id=user.user_id, storage_path=storage_path, display_name=display_name)
        if not doc:
            raise bad_request("Rename failed")
        return {"document": doc}
    except httpx.HTTPError:
        logger.exception("Upstream error during document rename")
        raise service_unavailable("Rename temporarily unavailable. Please try again.")
    except Exception:
        logger.exception("Unhandled error during document rename")
        raise service_unavailable("Rename temporarily unavailable. Please try again.")


@router.patch("/documents/link")
def link_document_route(
    payload: DocumentLinkRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> dict:
    storage_path = (payload.storage_path or "").strip()
    if not storage_path:
        raise bad_request("Missing storage_path")

    try:
        doc = set_document_item_link(user_id=user.user_id, storage_path=storage_path, item_id=payload.item_id)
        if not doc:
            raise bad_request("Update failed")
        return {"document": doc}
    except httpx.HTTPError:
        logger.exception("Upstream error during document link update")
        raise service_unavailable("Update temporarily unavailable. Please try again.")
    except Exception:
        logger.exception("Unhandled error during document link update")
        raise service_unavailable("Update temporarily unavailable. Please try again.")


@router.delete("/documents", status_code=status.HTTP_204_NO_CONTENT)
def delete_document_route(
    storage_path: str,
    user: AuthenticatedUser = Depends(get_current_user),
) -> Response:
    if not storage_path or not storage_path.strip():
        raise bad_request("Missing storage_path")

    try:
        supabase = get_supabase_admin()
        supabase.storage.from_("documents").remove([storage_path])
        supabase.table("documents").delete().eq("user_id", user.user_id).eq("storage_path", storage_path).execute()
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    except httpx.HTTPError:
        logger.exception("Upstream error during document deletion")
        raise service_unavailable("Delete temporarily unavailable. Please try again.")
    except Exception:
        logger.exception("Unhandled error during document deletion")
        raise service_unavailable("Delete temporarily unavailable. Please try again.")


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


@router.post("/sharing/create")
async def create_share_route(
    request: Request,
    user: AuthenticatedUser = Depends(get_current_user),
):
    body = await request.json()
    share_name = body.get("share_name", "My Inventory")
    permission = body.get("permission", "view")
    if permission not in ("view", "edit"):
        raise HTTPException(400, "Invalid permission")
    result = sharing_service.create_share(
        user_id=user.user_id,
        share_name=share_name,
        permission=permission,
    )
    return result


@router.get("/sharing/my-shares")
def get_my_shares_route(
    user: AuthenticatedUser = Depends(get_current_user),
):
    return sharing_service.get_my_shares(user_id=user.user_id)


@router.post("/sharing/join")
async def join_share_route(
    request: Request,
    user: AuthenticatedUser = Depends(get_current_user),
):
    body = await request.json()
    share_code = (body.get("share_code") or "").strip().upper()
    if not share_code:
        raise HTTPException(400, "share_code is required")
    try:
        result = sharing_service.join_share(user_id=user.user_id, share_code=share_code)
        return result
    except ValueError as e:
        raise HTTPException(400, str(e))


@router.get("/sharing/joined")
def get_joined_shares_route(
    user: AuthenticatedUser = Depends(get_current_user),
):
    return sharing_service.get_joined_shares(user_id=user.user_id)


@router.delete("/sharing/{share_id}")
def revoke_share_route(
    share_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    sharing_service.revoke_share(user_id=user.user_id, share_id=share_id)
    return {"revoked": True}


@router.delete("/sharing/{share_id}/members/{member_id}")
def remove_member_route(
    share_id: str,
    member_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        sharing_service.remove_member(
            owner_user_id=user.user_id,
            share_id=share_id,
            member_user_id=member_id,
        )
        return {"removed": True}
    except ValueError as e:
        raise HTTPException(403, str(e))


@router.get("/sharing/{share_id}/inventory")
def get_share_inventory_route(
    share_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        items = sharing_service.get_share_inventory(
            requesting_user_id=user.user_id,
            share_id=share_id,
        )
        return items
    except ValueError as e:
        raise HTTPException(403, str(e))


@router.get("/sharing/{share_id}/members")
def get_share_members_route(
    share_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        return sharing_service.get_share_members(
            owner_user_id=user.user_id,
            share_id=share_id,
        )
    except ValueError as e:
        raise HTTPException(403, str(e))
