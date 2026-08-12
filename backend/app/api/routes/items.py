import io
import logging
import re
from typing import Any

import anyio
import httpx
import openai
from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from openai import OpenAI
from PIL import Image

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.config import get_settings
from app.core.errors import bad_gateway, bad_request, service_unavailable
from app.schemas.inventory import (
    AddItemRequest,
    AddItemResponse,
    BarcodeLookupRequest,
    BarcodeLookupResponse,
    BulkCreateRequest,
    BulkCreateResponse,
    DeleteItemResponse,
    ExtractFromImageResponse,
    MultiExtractFromImageResponse,
    ProcessBarcodeRequest,
    ProcessBarcodeResponse,
    SearchItemsRequest,
    SearchItemsResponse,
    UpdateItemRequest,
    UpdateItemResponse,
)
from app.services.catalog_service import lookup_in_catalog, save_to_catalog
from app.services.documents_repo import create_activity
from app.services.items_repo import (
    add_item,
    bulk_create_items,
    delete_item,
    search_items_basic,
    update_item,
)
from app.services.limits import (
    ChatLimitExceeded,
    ScanLimitExceeded,
    TeamSoftCapExceeded,
    check_and_increment_scan,
    check_item_limit,
)
from app.services.spaces_repo import SpaceLimitExceeded
from app.services.openai_service import (
    extract_item_from_image,
    extract_items_from_image_multi,
    interpret_barcode,
    parse_search_query_to_keywords,
)
from app.core.limiter import limiter
from app.services.storage import upload_image
from app.services.supabase_client import get_supabase_admin
from app.services.usage_service import (
    check_limit,
    increment_usage,
)

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


def _check_not_viewer_for_team_write(requesting_user_id: str, target_user_id: str) -> None:
    """
    If target_user_id differs from requesting_user_id (i.e. write resolves to another
    user's space) AND requesting_user_id holds a viewer role in any team, raise 403.
    Fails open on DB error so a connectivity blip never blocks a non-viewer.
    """
    if target_user_id == requesting_user_id:
        return
    try:
        from app.services.teams_repo import is_viewer_in_any_team
        if is_viewer_in_any_team(user_id=requesting_user_id):
            raise HTTPException(
                status_code=403,
                detail={
                    "error": "VIEWER_ROLE",
                    "message": "Your team role is view-only and cannot add items to shared spaces.",
                },
            )
    except HTTPException:
        raise
    except Exception:
        logger.exception("Failed to check viewer write permission for user=%s", requesting_user_id)


def _resolve_owner_for_joined_space(requesting_user_id: str, location: str) -> str:
    """Return the space owner's user_id if location is a joined edit-access space, else requesting_user_id."""
    if not location or not location.strip():
        return requesting_user_id
    try:
        client = get_supabase_admin()
        memberships = client.table("team_members").select("share_id").eq(
            "member_user_id", requesting_user_id
        ).execute()
        share_ids = [m["share_id"] for m in (memberships.data or [])]
        if not share_ids:
            return requesting_user_id
        shares = client.table("team_shares").select(
            "owner_user_id, share_name, permission"
        ).in_("share_id", share_ids).eq("is_active", True).execute()
        location_lower = location.strip().lower()
        for share in (shares.data or []):
            name = (share.get("share_name") or "").strip().lower()
            perm = share.get("permission") or ""
            if name == location_lower and perm == "edit":
                owner_id = share.get("owner_user_id")
                if owner_id:
                    return owner_id
    except Exception:
        logger.exception("Failed to resolve owner for joined space")
    return requesting_user_id


@router.post("/add_item", response_model=AddItemResponse)
def add_item_route(payload: AddItemRequest, user: AuthenticatedUser = Depends(get_current_user)) -> AddItemResponse:
    limit_check = check_item_limit(user.user_id)
    if not limit_check["allowed"]:
        raise HTTPException(
            status_code=403,
            detail={
                "error": "item_limit_reached",
                "message": f"Item limit of {limit_check['limit']} reached.",
                "current": limit_check["current"],
                "limit": limit_check["limit"],
                "upgrade_required": True,
            },
        )
    try:
        item_dict = payload.model_dump()
        location = (item_dict.get("location") or "").strip()
        target_user_id = _resolve_owner_for_joined_space(user.user_id, location)
        _check_not_viewer_for_team_write(user.user_id, target_user_id)
        created = add_item(user_id=target_user_id, item=item_dict)
        return AddItemResponse(item=created)
    except SpaceLimitExceeded:
        raise HTTPException(403, "FREE_TIER_SPACE_LIMIT")


@router.post("/search_items", response_model=SearchItemsResponse)
@limiter.limit("30/minute")
def search_items_route(request: Request, payload: SearchItemsRequest, user: AuthenticatedUser = Depends(get_current_user)) -> SearchItemsResponse:
    try:
        raw_query = (payload.query or "").strip()
        if not raw_query:
            parsed = {"text": "", "category": None, "location": None}
        else:
            parsed = parse_search_query_to_keywords(query=raw_query)
        q = (parsed.get("text") or raw_query).strip()

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
    except SpaceLimitExceeded:
        raise HTTPException(403, "FREE_TIER_SPACE_LIMIT")
    except Exception:
        logger.exception("Unhandled error during /update_item")
        raise service_unavailable("Update temporarily unavailable. Please try again.")


@router.post("/extract_from_image", response_model=ExtractFromImageResponse)
@limiter.limit("10/minute")
async def extract_from_image_route(
    request: Request,
    file: UploadFile = File(...),
    user: AuthenticatedUser = Depends(get_current_user),
) -> ExtractFromImageResponse:
    raw = await file.read()
    if not raw:
        raise bad_request("Empty file")

    try:
        check_and_increment_scan(user.user_id)
    except TeamSoftCapExceeded as exc:
        raise HTTPException(
            status_code=403,
            detail={
                "error": "TEAM_SOFT_CAP",
                "feature": exc.feature,
                "current": exc.current,
                "limit": exc.limit,
                "resets_at": exc.resets_at,
                "message": f"Your team has used {exc.current} of {exc.limit} {exc.feature} for this period.",
            },
        )
    except ScanLimitExceeded as exc:
        raise HTTPException(
            status_code=403,
            detail={
                "error": "SCAN_LIMIT_REACHED",
                "daily": exc.daily,
                "current": exc.current,
                "limit": exc.limit,
                "resets_at": exc.resets_at,
                "message": (
                    f"You've reached today's {exc.limit} photo scan limit."
                    if exc.daily else
                    f"You've used all {exc.limit} photo scans for this month."
                ),
            },
        )

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
@limiter.limit("10/minute")
async def inventory_extract_from_image_route(
    request: Request,
    file: UploadFile = File(...),
    user: AuthenticatedUser = Depends(get_current_user),
) -> MultiExtractFromImageResponse:
    raw = await file.read()
    if not raw:
        raise bad_request("Empty file")

    try:
        check_and_increment_scan(user.user_id)
    except TeamSoftCapExceeded as exc:
        raise HTTPException(
            status_code=403,
            detail={
                "error": "TEAM_SOFT_CAP",
                "feature": exc.feature,
                "current": exc.current,
                "limit": exc.limit,
                "resets_at": exc.resets_at,
                "message": f"Your team has used {exc.current} of {exc.limit} {exc.feature} for this period.",
            },
        )
    except ScanLimitExceeded as exc:
        raise HTTPException(
            status_code=403,
            detail={
                "error": "SCAN_LIMIT_REACHED",
                "daily": exc.daily,
                "current": exc.current,
                "limit": exc.limit,
                "resets_at": exc.resets_at,
                "message": (
                    f"You've reached today's {exc.limit} photo scan limit."
                    if exc.daily else
                    f"You've used all {exc.limit} photo scans for this month."
                ),
            },
        )

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
    items_to_insert = [i.model_dump() for i in payload.items]
    if not is_pro_user(user.user_id):
        try:
            count_result = get_supabase_admin().table("items").select("item_id", count="exact").eq("user_id", user.user_id).execute()
            current = count_result.count or 0
        except Exception:
            current = 0
        slots_remaining = FREE_ITEM_LIMIT - current
        if slots_remaining <= 0:
            raise HTTPException(
                status_code=403,
                detail={
                    "error": "item_limit_reached",
                    "message": "Free plan limit of 30 items reached.",
                    "upgrade_required": True,
                },
            )
        items_to_insert = items_to_insert[:slots_remaining]
    # Resolve target user_id for joined spaces (all items share one location in photo-upload flow)
    bulk_location = ""
    for it in items_to_insert:
        loc = (it.get("location") or "").strip()
        if loc:
            bulk_location = loc
            break
    target_user_id = _resolve_owner_for_joined_space(user.user_id, bulk_location)

    try:
        inserted, failures = bulk_create_items(user_id=target_user_id, items=items_to_insert)

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
async def process_barcode_route(
    payload: ProcessBarcodeRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> ProcessBarcodeResponse:
    limit_check = await check_limit(user.user_id, "barcode_scan")
    if not limit_check["allowed"]:
        raise HTTPException(
            status_code=403,
            detail={
                "error": "FREE_TIER_BARCODE_LIMIT",
                "used": limit_check["current"],
                "max": limit_check["limit"],
            },
        )
    guess = interpret_barcode(barcode=payload.barcode)
    await increment_usage(user.user_id, "barcode_scan")
    return ProcessBarcodeResponse(result=guess)


@router.post("/barcode_lookup", response_model=BarcodeLookupResponse)
async def barcode_lookup_route(
    payload: BarcodeLookupRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> BarcodeLookupResponse:
    import re
    barcode = (payload.barcode or "").strip()
    if not barcode:
        raise bad_request("Missing barcode")

    # STEP -1: UUID → FindEZ QR code, look up by item_id directly
    _UUID_RE = re.compile(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        re.IGNORECASE,
    )
    if _UUID_RE.match(barcode):
        client = get_supabase_admin()
        qr_item = client.table("items").select(
            "item_id, name, quantity, location, category, image_url"
        ).eq("item_id", barcode).eq("user_id", user.user_id).execute()
        if qr_item.data:
            d = qr_item.data[0]
            return BarcodeLookupResponse(
                barcode=barcode,
                name=d.get("name"),
                category=d.get("category"),
                image_url=d.get("image_url"),
                found_in_inventory=True,
                existing_item={
                    "item_id": d.get("item_id"),
                    "name": d.get("name"),
                    "quantity": d.get("quantity"),
                    "location": d.get("location"),
                    "category": d.get("category"),
                    "image_url": d.get("image_url"),
                },
            )
        return BarcodeLookupResponse(
            barcode=barcode,
            name="Unknown QR Code",
            found_in_inventory=False,
        )

    limit_check = await check_limit(user.user_id, "barcode_scan")
    if not limit_check["allowed"]:
        raise HTTPException(
            status_code=403,
            detail={
                "error": "FREE_TIER_BARCODE_LIMIT",
                "used": limit_check["current"],
                "max": limit_check["limit"],
            },
        )

    client = get_supabase_admin()
    inv_check = client.table("items").select(
        "item_id, name, quantity, location, category, image_url"
    ).eq("user_id", user.user_id).eq("barcode", barcode).execute()
    if inv_check.data:
        existing = inv_check.data[0]
        return BarcodeLookupResponse(
            barcode=barcode,
            name=existing.get("name"),
            brand=None,
            model=None,
            category=existing.get("category"),
            image_url=existing.get("image_url"),
            found_in_inventory=True,
            existing_item={
                "item_id": existing.get("item_id"),
                "name": existing.get("name"),
                "quantity": existing.get("quantity"),
                "location": existing.get("location"),
                "category": existing.get("category"),
                "image_url": existing.get("image_url"),
            },
        )

    out: dict[str, Any] | None = None

    # STEP 0: Check internal parts_catalog first
    catalog_result = lookup_in_catalog(barcode)
    if catalog_result:
        return BarcodeLookupResponse(
            barcode=barcode,
            name=(catalog_result.get("name") or "Unknown item"),
            brand=catalog_result.get("brand") or None,
            model=catalog_result.get("part_number") or None,
            category=catalog_result.get("category") or None,
            image_url=None,
        )

    # STEP 1: Try UPCitemDB API
    try:
        out = await lookup_upcitemdb(barcode)
        if is_valid_result(out):
            save_to_catalog(barcode=barcode, data=out, source="upcitemdb")
    except Exception:
        logger.exception("UPCitemDB lookup failed")
        out = None

    # STEP 2: Try Go-UPC API
    if out is None:
        try:
            out = await lookup_go_upc(barcode)
            if is_valid_result(out):
                save_to_catalog(barcode=barcode, data=out, source="go_upc")
        except Exception:
            logger.exception("Go-UPC lookup failed")
            out = None

    # STEP 3: Try Open Food Facts API
    if out is None:
        try:
            out = await lookup_openfoodfacts(barcode)
            if is_valid_result(out):
                save_to_catalog(barcode=barcode, data=out, source="openfoodfacts")
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
                    save_to_catalog(barcode=barcode, data=out, source="ai")
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

    await increment_usage(user.user_id, "barcode_scan")
    return BarcodeLookupResponse(
        barcode=barcode,
        name=(out.get("name") or "Unknown item"),
        brand=out.get("brand") or None,
        model=out.get("model") if isinstance(out, dict) else None,
        category=out.get("category") or None,
        image_url=out.get("image_url") or None,
    )


@router.get("/items/{item_id}/history")
def get_item_history(
    item_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    from app.services.item_events_repo import get_events_for_item
    events = get_events_for_item(user_id=user.user_id, item_id=item_id, limit=50)
    return {"events": events}
