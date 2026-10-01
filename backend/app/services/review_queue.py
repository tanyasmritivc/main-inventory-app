from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any

from app.services.catalog_service import verified_catalog_id_for_identity
from app.services.items_repo import (
    _normalize_category,
    _normalize_location,
    invalidate_inventory_cache,
)
from app.services.spaces_repo import get_or_create_space
from app.services.supabase_client import get_supabase_admin


logger = logging.getLogger(__name__)

_EDITABLE_FIELDS = {
    "name",
    "category",
    "subcategory",
    "quantity",
    "brand",
    "part_number",
    "barcode",
    "tags",
    "confidence",
    "image_url",
    "notes",
    "location",
}


class ReviewItemNotFound(LookupError):
    pass


class ReviewItemConflict(ValueError):
    pass


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _review_payload(
    *, user_id: str, source_key: str, item: dict[str, Any]
) -> dict[str, Any]:
    evidence = item.get("scan_evidence")
    if not isinstance(evidence, dict):
        evidence = {}
    catalog_match = item.get("catalog_match")
    return {
        "user_id": user_id,
        "source_key": source_key,
        "source_kind": "photo_scan",
        "status": "pending",
        "name": str(item.get("name") or "Unidentified item")[:200],
        "category": str(item.get("category") or "Other")[:100],
        "subcategory": item.get("subcategory"),
        "quantity": max(0, min(100000, int(item.get("quantity") or 1))),
        "brand": item.get("brand"),
        "part_number": item.get("part_number"),
        "barcode": item.get("barcode"),
        "tags": item.get("tags"),
        "confidence": item.get("confidence"),
        "image_url": item.get("image_url"),
        "source_frame_url": item.get("source_frame_url"),
        "notes": item.get("notes"),
        "location": item.get("location"),
        "catalog_match": catalog_match if isinstance(catalog_match, dict) else None,
        "scan_evidence": evidence,
        "updated_at": _now(),
    }


def enqueue_uncertain_items(
    *, user_id: str, source_digest: str, items: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    """Persist every uncertain result and attach its durable review identity."""
    uncertain: list[tuple[int, str, dict[str, Any]]] = []
    for index, item in enumerate(items):
        evidence = item.get("scan_evidence")
        if isinstance(evidence, dict) and bool(evidence.get("needs_review")):
            source_key = f"photo:{source_digest}:{index}"
            uncertain.append((index, source_key, item))

    if not uncertain:
        return items

    client = get_supabase_admin()
    keys = [source_key for _, source_key, _ in uncertain]
    existing_result = (
        client.table("capture_reviews")
        .select("review_id, source_key, status")
        .eq("user_id", user_id)
        .in_("source_key", keys)
        .execute()
    )
    by_key = {
        str(row.get("source_key")): row
        for row in (existing_result.data or [])
        if isinstance(row, dict)
    }

    missing = [
        _review_payload(user_id=user_id, source_key=key, item=item)
        for _, key, item in uncertain
        if key not in by_key
    ]
    if missing:
        try:
            inserted = (
                client.table("capture_reviews")
                .upsert(missing, on_conflict="user_id,source_key", ignore_duplicates=True)
                .execute()
            )
            for row in inserted.data or []:
                if isinstance(row, dict):
                    by_key[str(row.get("source_key"))] = row
        except Exception:
            # A concurrent retry may have won the unique constraint. Re-read once.
            logger.info("Review queue insert raced; re-reading durable records")

        refreshed = (
            client.table("capture_reviews")
            .select("review_id, source_key, status")
            .eq("user_id", user_id)
            .in_("source_key", keys)
            .execute()
        )
        for row in refreshed.data or []:
            if isinstance(row, dict):
                by_key[str(row.get("source_key"))] = row

    if any(key not in by_key for _, key, _ in uncertain):
        raise RuntimeError("One or more review items could not be saved")

    output = [dict(item) for item in items]
    for index, key, _ in uncertain:
        record = by_key[key]
        output[index]["review_id"] = str(record["review_id"])
        output[index]["review_status"] = str(record.get("status") or "pending")
    return output


def list_review_items(*, user_id: str, limit: int = 100) -> tuple[list[dict], int]:
    client = get_supabase_admin()
    safe_limit = max(1, min(200, int(limit)))
    result = (
        client.table("capture_reviews")
        .select("*")
        .eq("user_id", user_id)
        .eq("status", "pending")
        .order("created_at", desc=True)
        .limit(safe_limit)
        .execute()
    )
    items = result.data or []
    count_result = (
        client.table("capture_reviews")
        .select("review_id", count="exact")
        .eq("user_id", user_id)
        .eq("status", "pending")
        .execute()
    )
    return items, int(count_result.count if count_result.count is not None else len(items))


def update_review_item(
    *, user_id: str, review_id: str, updates: dict[str, Any]
) -> dict[str, Any]:
    payload = {key: value for key, value in updates.items() if key in _EDITABLE_FIELDS}
    if not payload:
        raise ReviewItemConflict("No changes were provided")
    payload["updated_at"] = _now()
    result = (
        get_supabase_admin()
        .table("capture_reviews")
        .update(payload)
        .eq("review_id", review_id)
        .eq("user_id", user_id)
        .eq("status", "pending")
        .execute()
    )
    if not result.data:
        raise ReviewItemNotFound("Review item not found")
    return result.data[0]


def resolve_review_item(
    *, user_id: str, review_id: str, item: dict[str, Any]
) -> dict[str, Any]:
    client = get_supabase_admin()
    name = str(item.get("name") or "").strip()
    category = str(item.get("category") or "").strip()
    location = str(item.get("location") or "").strip()
    if not name or not category or not location:
        raise ReviewItemConflict("Name, category, and location are required")

    normalized = {
        **item,
        "name": name,
        "category": _normalize_category(category),
        "location": _normalize_location(location),
    }
    space_id = None
    if normalized["location"].lower() != "unsorted":
        space = get_or_create_space(user_id=user_id, name=normalized["location"])
        space_id = space.get("id") if space else None
    catalog_id = verified_catalog_id_for_identity(
        brand=normalized.get("brand"), part_number=normalized.get("part_number")
    )
    try:
        result = client.rpc(
            "resolve_capture_review",
            {
                "p_review_id": review_id,
                "p_user_id": user_id,
                "p_item": normalized,
                "p_space_id": space_id,
                "p_catalog_id": catalog_id,
            },
        ).execute()
    except Exception as exc:
        message = str(exc).lower()
        if "not found" in message or "no_data_found" in message:
            raise ReviewItemNotFound("Review item not found") from exc
        if "no longer pending" in message or "check_violation" in message:
            raise ReviewItemConflict("Review item is no longer pending") from exc
        raise
    data = result.data
    if isinstance(data, list):
        data = data[0] if data else None
    if not isinstance(data, dict):
        raise RuntimeError("Reviewed item was not returned")
    invalidate_inventory_cache(user_id)
    return data


def dismiss_review_item(*, user_id: str, review_id: str) -> dict[str, Any]:
    now = _now()
    result = (
        get_supabase_admin()
        .table("capture_reviews")
        .update({"status": "dismissed", "dismissed_at": now, "updated_at": now})
        .eq("review_id", review_id)
        .eq("user_id", user_id)
        .eq("status", "pending")
        .execute()
    )
    if not result.data:
        raise ReviewItemNotFound("Review item not found")
    return result.data[0]
