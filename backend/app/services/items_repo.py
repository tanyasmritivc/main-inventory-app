
from datetime import datetime, timezone
import logging
import re
import threading as _threading
import time
from uuid import uuid4

import httpx

from app.services.supabase_client import get_supabase_admin
from app.services.spaces_repo import SpaceLimitExceeded, count_spaces, get_or_create_space


logger = logging.getLogger(__name__)

_INVENTORY_CACHE: dict[str, tuple[list, float]] = {}
_CACHE_LOCK = _threading.Lock()
_CACHE_TTL = 60  # seconds


def _scope(query, *, user_id: str, workspace_id: str | None):
    return query.eq("workspace_id", workspace_id) if workspace_id else query.eq("user_id", user_id)


def _get_cached_inventory(user_id: str) -> list | None:
    with _CACHE_LOCK:
        entry = _INVENTORY_CACHE.get(user_id)
        if entry and (time.time() - entry[1]) < _CACHE_TTL:
            return entry[0]
    return None


def _set_cached_inventory(user_id: str, items: list) -> None:
    with _CACHE_LOCK:
        _INVENTORY_CACHE[user_id] = (items, time.time())


def invalidate_inventory_cache(user_id: str) -> None:
    with _CACHE_LOCK:
        _INVENTORY_CACHE.pop(user_id, None)


def _singularize_word(word: str) -> str:
    w = (word or "").strip().lower()
    if len(w) <= 3:
        return w
    if w.endswith("ies") and len(w) > 3:
        return w[:-3] + "y"
    if w.endswith("ches") or w.endswith("shes"):
        return w[:-2]
    if w.endswith("xes") or w.endswith("ses") or w.endswith("zes"):
        if not w.endswith("sses"):
            return w[:-2]
    if w.endswith("s") and not w.endswith("ss"):
        return w[:-1]
    return w


def _normalize_item_name(raw: str) -> str:
    s = (raw or "").strip().lower()
    if not s:
        return ""
    s = re.sub(r"\s+", " ", s)
    parts = s.split(" ")
    if not parts:
        return ""
    parts[-1] = _singularize_word(parts[-1])
    return " ".join(p for p in parts if p).strip()


def _has_identity(name: str) -> bool:
    return name.strip().lower() not in {
        "", "unknown", "unknown item", "unidentified item", "not recognised",
    }


def _capture_identity_source(item: dict) -> str:
    if item.get("barcode"):
        return "barcode"
    if item.get("catalog_id"):
        return "catalog"
    evidence = item.get("scan_evidence") or {}
    if isinstance(evidence, dict) and evidence.get("ocr_text"):
        return "ocr"
    return "vlm"


def _normalize_location(raw: str) -> str:
    s = (raw or "").strip()
    if not s:
        return ""
    return s.title()


def _normalize_category(raw: str) -> str:
    s = (raw or "").strip().lower()
    if not s or s == "unsorted":
        return "Other"

    if any(keyword in s for keyword in [
        "robot", "drivetrain", "gearbox", "motor controller", "mecanum",
        "sprocket", "pulley", "servo", "actuator",
    ]):
        return "Robot Parts"

    if any(keyword in s for keyword in ["hardware", "fastener", "bearing", "shaft"]):
        return "Hardware"

    if any(keyword in s for keyword in ["raw material", "extrusion", "sheet metal", "stock"]):
        return "Raw Materials"

    if any(keyword in s for keyword in ["battery", "charger"]):
        return "Batteries"

    if any(keyword in s for keyword in ["safety", "ppe", "goggle", "glove"]):
        return "Safety"

    if "tool" in s:
        return "Tools"
    
    # Food
    if any(keyword in s for keyword in [
        'food', 'grocery', 'beverage', 'snack', 'snacks',
        'nut', 'nuts', 'bar', 'bars', 'kirkland', 'cashew', 'almond', 'pecan',
    ]):
        return "Food"
    
    # Cosmetics
    if any(keyword in s for keyword in ['cosmetic', 'beauty', 'makeup', 'skincare']):
        return "Cosmetics"
    
    # Electronics
    if any(keyword in s for keyword in ['electronic', 'tech', 'gadget', 'computer', 'phone', 'appliance']):
        return "Electronics"
    
    # Clothing
    if any(keyword in s for keyword in ['clothing', 'apparel', 'fashion', 'shoe']):
        return "Clothing"
    
    # Health
    if any(keyword in s for keyword in ['health', 'medicine', 'pharma', 'supplement', 'medication']):
        return "Health"
    
    # Home
    if any(keyword in s for keyword in ['home', 'kitchen', 'furniture', 'decor', 'appliance']):
        return "Home"
    
    # Office
    if any(keyword in s for keyword in ['book', 'media', 'office', 'stationery']):
        return "Office"
    
    # Supplies
    if any(keyword in s for keyword in ['cleaning', 'household', 'supply', 'adhesive']):
        return "Supplies"
    
    # Toys
    if any(keyword in s for keyword in ['toy', 'game', 'hobby']):
        return "Toys"
    
    # Accessories -> Other
    if any(keyword in s for keyword in ['accessories', 'accessory']):
        return "Other"
    
    return "Other"


def _resolve_space_id(*, user_id: str, location: str, workspace_id: str | None = None) -> str | None:
    """Return the space id for location, creating the space row if needed."""
    loc = (location or "").strip()
    if not loc or loc.lower() == "unsorted":
        return None
    try:
        space = get_or_create_space(user_id=user_id, name=loc, workspace_id=workspace_id)
        return space.get("id") if space else None
    except SpaceLimitExceeded:
        raise
    except Exception:
        logger.exception("Failed to resolve space for location %s", loc)
        if workspace_id:
            raise
        return None


def _validate_bin(*, user_id: str, bin_id: str | None, space_id: str | None,
                  workspace_id: str | None = None) -> None:
    if not bin_id:
        return
    if not space_id:
        raise ValueError("Choose a space before choosing a bin.")
    result = _scope(
        get_supabase_admin().table("bins").select("id").eq("id", bin_id),
        user_id=user_id, workspace_id=workspace_id,
    ).eq("space_id", space_id).maybe_single().execute()
    if not result.data:
        raise ValueError("That bin does not belong to this space.")


def _first_existing_match_by_normalized_name(
    *, user_id: str, normalized_name: str, location: str,
    workspace_id: str | None = None,
) -> dict | None:
    if not normalized_name:
        return None
    words = normalized_name.split()
    if not words:
        return None
    first_word = words[0]
    try:
        supabase = get_supabase_admin()
        resp = _execute_with_retry(
            lambda: _scope(supabase.table("items")
            .select("item_id, name, quantity, location, space_id"),
            user_id=user_id, workspace_id=workspace_id)
            .ilike("name", f"%{first_word}%")
            .execute()
        )
        candidates = resp.data or []
        target_location = _normalize_location(location).lower()
        for it in candidates:
            if (
                isinstance(it, dict)
                and _normalize_item_name(str(it.get("name") or "")) == normalized_name
                and _normalize_location(str(it.get("location") or "")).lower() == target_location
            ):
                return it
    except Exception:
        logger.exception("Duplicate check query failed")
    return None


def _execute_with_retry(fn, max_attempts: int = 3):
    last_error = None
    for attempt in range(1, max_attempts + 1):
        try:
            result = fn()
            return result
        except Exception as e:
            last_error = e
            if attempt < max_attempts:
                wait = 2 ** (attempt - 1)  # 1s, 2s, 4s
                logger.warning("Supabase error attempt=%d, retrying in %ss: %s", attempt, wait, e)
                time.sleep(wait)
            else:
                logger.error("Supabase failed after %d attempts: %s", max_attempts, e)
    raise last_error


def list_items(*, user_id: str, workspace_id: str | None = None) -> list[dict]:
    cache_key = workspace_id or user_id
    cached = _get_cached_inventory(cache_key)
    if cached is not None:
        return cached
    supabase = get_supabase_admin()
    resp = _execute_with_retry(
        lambda: _scope(supabase.table("items").select("*"),
                       user_id=user_id, workspace_id=workspace_id)
        .order("created_at", desc=True).execute()
    )
    items = resp.data or []
    _set_cached_inventory(cache_key, items)
    return items


def bulk_create_items(
    *, user_id: str, items: list[dict], actor_user_id: str | None = None,
    cause: str = "photo", workspace_id: str | None = None,
) -> tuple[list[dict], list[dict]]:
    supabase = get_supabase_admin()
    inserted: list[dict] = []
    failures: list[dict] = []

    existing_items = list_items(user_id=user_id, workspace_id=workspace_id)
    existing_by_norm: dict[str, dict] = {}
    for it in existing_items or []:
        if not isinstance(it, dict):
            continue
        n = _normalize_item_name(str(it.get("name") or ""))
        if n:
            key = f"{n}::{(it.get('location') or '').strip().lower()}"
            if key not in existing_by_norm:
                existing_by_norm[key] = it

    now = datetime.now(timezone.utc).isoformat()
    payloads: list[dict] = []
    source_frames_by_item_id: dict[str, str] = {}

    aggregated: dict[str, dict] = {}
    aggregated_qty: dict[str, int] = {}
    aggregated_first_idx: dict[str, int] = {}

    for idx, it in enumerate(items or []):
        name = (it.get("name") or "").strip()
        category = (it.get("category") or "").strip()
        location = (it.get("location") or "").strip()

        if not name or not category or not location:
            failures.append({"index": idx, "reason": "name, category, and location are required"})
            continue

        quantity = it.get("quantity")
        if quantity is None:
            quantity = 1
        try:
            quantity = int(quantity)
        except Exception:
            failures.append({"index": idx, "reason": "invalid quantity"})
            continue

        if quantity < 0:
            quantity = 0

        norm = _normalize_item_name(name)
        if not norm:
            failures.append({"index": idx, "reason": "invalid name"})
            continue

        if norm not in aggregated:
            aggregated[norm] = {
                "name": name,
                "category": category,
                "subcategory": it.get("subcategory"),
                "brand": it.get("brand"),
                "part_number": it.get("part_number"),
                "tags": it.get("tags"),
                "confidence": it.get("confidence"),
                "location": location,
                "image_url": it.get("image_url"),
                "source_frame_url": it.get("source_frame_url"),
                "barcode": it.get("barcode"),
                "purchase_source": it.get("purchase_source"),
                "notes": it.get("notes"),
                "catalog_id": None,
                "bin_id": it.get("bin_id"),
                "container": it.get("container"),
                "scan_evidence": it.get("scan_evidence"),
            }
            aggregated_qty[norm] = 0
            aggregated_first_idx[norm] = idx

        aggregated_qty[norm] = int(aggregated_qty.get(norm, 0)) + int(quantity)

    # Resolve spaces for all distinct locations before any DB writes so that
    # SpaceLimitExceeded fires before any rows are inserted.
    distinct_locations = {
        (base.get("location") or "").strip()
        for base in aggregated.values()
        if (base.get("location") or "").strip()
    }
    space_ids: dict[str, str] = {}
    for loc in distinct_locations:
        if loc.lower() == "unsorted":
            continue
        sid = _resolve_space_id(user_id=user_id, location=loc, workspace_id=workspace_id)
        if sid:
            space_ids[loc.lower()] = sid

    for norm, base in aggregated.items():
        qty = int(aggregated_qty.get(norm, 0))
        if qty < 0:
            qty = 0

        loc_key = (base.get("location") or "").strip().lower()
        resolved_space_id = space_ids.get(loc_key)
        _validate_bin(
            user_id=user_id,
            bin_id=base.get("bin_id"),
            space_id=resolved_space_id,
            workspace_id=workspace_id,
        )

        # Verification is server-owned. Never trust catalog_match/catalog_id
        # supplied by a client, even if it originated in a prior scan response.
        from app.services.catalog_service import (
            link_verified_barcode_alias,
            verified_catalog_id_for_identity,
        )
        base["catalog_id"] = verified_catalog_id_for_identity(
            brand=base.get("brand"),
            part_number=base.get("part_number"),
        )
        if base.get("catalog_id") and base.get("barcode"):
            link_verified_barcode_alias(
                barcode=str(base["barcode"]),
                catalog_id=str(base["catalog_id"]),
            )

        base["identity_confirmed"] = _has_identity(base["name"])
        base["named_by"] = _capture_identity_source(base)

        existing = existing_by_norm.get(f"{norm}::{loc_key}")
        if existing and isinstance(existing, dict):
            item_id = str(existing.get("item_id") or "")
            if not item_id:
                failures.append({"index": aggregated_first_idx.get(norm, 0), "reason": "missing item_id"})
                continue

            try:
                existing_qty = int(existing.get("quantity") or 0)
            except Exception:
                existing_qty = 0

            qty_updates: dict = {"quantity": existing_qty + qty}
            if base["identity_confirmed"]:
                qty_updates["identity_confirmed"] = True
                qty_updates["named_by"] = base["named_by"]
            if not existing.get("space_id") and resolved_space_id:
                qty_updates["space_id"] = resolved_space_id
            if not existing.get("catalog_id") and base.get("catalog_id"):
                qty_updates["catalog_id"] = base.get("catalog_id")
            if base.get("image_url"):
                qty_updates["image_url"] = base["image_url"]
            updated = update_item(
                user_id=user_id, item_id=item_id, updates=qty_updates,
                actor_user_id=actor_user_id, cause=cause,
                workspace_id=workspace_id,
            )
            if base.get("source_frame_url"):
                from app.services.item_events_repo import log_event
                log_event(
                    user_id=actor_user_id or user_id, item_id=item_id,
                    event_type="photo", image_url=base["source_frame_url"],
                    quantity_delta=0, quantity_before=existing_qty + qty,
                    quantity_after=existing_qty + qty, cause="photo",
                )
            inserted.append(updated or {**existing, "quantity": existing_qty + qty})
            continue

        new_item_id = str(uuid4())
        if base.get("source_frame_url"):
            source_frames_by_item_id[new_item_id] = base["source_frame_url"]
        payloads.append(
            {
                "item_id": new_item_id,
                "user_id": user_id,
                **({"workspace_id": workspace_id} if workspace_id else {}),
                "created_at": now,
                "name": base.get("name") or "",
                "category": base.get("category") or "",
                "subcategory": base.get("subcategory"),
                "brand": base.get("brand"),
                "part_number": base.get("part_number"),
                "tags": base.get("tags"),
                "confidence": base.get("confidence"),
                "quantity": qty,
                "location": base.get("location") or "",
                "space_id": resolved_space_id,
                "image_url": base.get("image_url"),
                "barcode": base.get("barcode"),
                "purchase_source": base.get("purchase_source"),
                "notes": base.get("notes"),
                "catalog_id": base.get("catalog_id"),
                "bin_id": base.get("bin_id"),
                "container": base.get("container"),
                "identity_confirmed": base["identity_confirmed"],
                "named_by": base["named_by"],
            }
        )

    if not payloads:
        return (inserted, failures)

    resp = _execute_with_retry(lambda: supabase.table("items").insert(payloads).execute())
    inserted = inserted + (resp.data or [])
    from app.services.item_events_repo import log_event
    for item in resp.data or []:
        log_event(
            user_id=actor_user_id or user_id,
            item_id=item["item_id"],
            event_type="photo" if cause == "photo" else "restock",
            quantity_delta=int(item.get("quantity") or 0),
            quantity_before=0,
            quantity_after=int(item.get("quantity") or 0),
            cause=cause,
            image_url=source_frames_by_item_id.get(item["item_id"]),
        )
    invalidate_inventory_cache(workspace_id or user_id)
    return (inserted, failures)


def add_item(
    *, user_id: str, item: dict, actor_user_id: str | None = None,
    workspace_id: str | None = None,
) -> dict:
    supabase = get_supabase_admin()

    name = (item.get("name") or "").strip()
    norm = _normalize_item_name(name)
    location = (item.get("location") or "").strip()
    existing = _first_existing_match_by_normalized_name(
        user_id=user_id,
        normalized_name=norm,
        location=location,
        workspace_id=workspace_id,
    )
    if existing and isinstance(existing, dict):
        item_id = str(existing.get("item_id") or "")
        if item_id:
            try:
                existing_qty = int(existing.get("quantity") or 0)
            except Exception:
                existing_qty = 0
            quantity_in = item.get("quantity")
            if quantity_in is None:
                quantity_in = 1
            try:
                quantity_in = int(quantity_in)
            except Exception:
                quantity_in = 1
            if quantity_in < 0:
                quantity_in = 0

            qty_updates: dict = {"quantity": existing_qty + quantity_in}
            if _has_identity(name):
                qty_updates["identity_confirmed"] = True
                qty_updates["named_by"] = "barcode" if item.get("barcode") else "manual_entry"
            # Backfill space_id if the matched item is missing it.
            # SpaceLimitExceeded is swallowed here: the quantity bump must
            # succeed even if the space backfill cannot run.
            if not existing.get("space_id"):
                loc = (existing.get("location") or "").strip()
                if loc:
                    try:
                        space_id = _resolve_space_id(user_id=user_id, location=loc,
                                                     workspace_id=workspace_id)
                    except SpaceLimitExceeded:
                        space_id = None
                    if space_id:
                        qty_updates["space_id"] = space_id
            updated = update_item(
                user_id=user_id, item_id=item_id, updates=qty_updates,
                actor_user_id=actor_user_id,
                cause="barcode" if item.get("barcode") else "manual",
                workspace_id=workspace_id,
            )
            return updated or {**existing, "quantity": existing_qty + quantity_in}

    now = datetime.now(timezone.utc).isoformat()
    payload = {
        **item,
        "item_id": str(uuid4()),
        "user_id": user_id,
        **({"workspace_id": workspace_id} if workspace_id else {}),
        "created_at": now,
        "identity_confirmed": _has_identity(name),
        "named_by": "barcode" if item.get("barcode") else "manual_entry",
    }

    # Normalize location field
    if "location" in payload and payload["location"] is not None:
        payload["location"] = _normalize_location(str(payload["location"]))

    # Normalize category field
    if "category" in payload and payload["category"] is not None:
        payload["category"] = _normalize_category(str(payload["category"]))

    # Resolve space_id from location
    if not payload.get("space_id"):
        loc = (payload.get("location") or "").strip()
        if loc:
            space_id = _resolve_space_id(user_id=user_id, location=loc,
                                         workspace_id=workspace_id)
            if space_id:
                payload["space_id"] = space_id

    _validate_bin(
        user_id=user_id,
        bin_id=payload.get("bin_id"),
        space_id=payload.get("space_id"),
        workspace_id=workspace_id,
    )

    from app.services.catalog_service import verified_catalog_id_for_identity
    payload["catalog_id"] = verified_catalog_id_for_identity(
        brand=payload.get("brand"),
        part_number=payload.get("part_number"),
    )

    resp = _execute_with_retry(lambda: supabase.table("items").insert(payload).execute())
    created = (resp.data or [payload])[0]
    from app.services.item_events_repo import log_event
    log_event(
        user_id=actor_user_id or user_id,
        item_id=created["item_id"],
        event_type="restock",
        quantity_delta=int(created.get("quantity") or 0),
        quantity_before=0,
        quantity_after=int(created.get("quantity") or 0),
        cause="barcode" if item.get("barcode") else "manual",
    )
    invalidate_inventory_cache(workspace_id or user_id)
    return created


def delete_item(*, user_id: str, item_id: str, workspace_id: str | None = None) -> bool:
    supabase = get_supabase_admin()
    resp = _execute_with_retry(lambda: _scope(supabase.table("items").delete(),
        user_id=user_id, workspace_id=workspace_id).eq("item_id", item_id).execute())
    deleted = bool(resp.data)
    if deleted:
        invalidate_inventory_cache(workspace_id or user_id)
    return deleted


def update_item(
    *, user_id: str, item_id: str, updates: dict,
    actor_user_id: str | None = None, cause: str = "manual",
    workspace_id: str | None = None,
) -> dict | None:
    supabase = get_supabase_admin()

    allowed = {
        "name",
        "category",
        "subcategory",
        "brand",
        "part_number",
        "tags",
        "confidence",
        "quantity",
        "location",
        "space_id",
        "image_url",
        "barcode",
        "purchase_source",
        "notes",
        "bin_id",
        "container",
        "reorder_point",
        "identity_confirmed",
        "named_by",
    }

    payload = {k: v for k, v in (updates or {}).items() if k in allowed}
    if not payload:
        return None

    # Normalize location field if present
    if "location" in payload and payload["location"] is not None:
        payload["location"] = _normalize_location(str(payload["location"]))

    # Normalize category field if present
    if "category" in payload and payload["category"] is not None:
        payload["category"] = _normalize_category(str(payload["category"]))

    if "name" in payload and _has_identity(str(payload["name"])):
        payload.setdefault("identity_confirmed", True)
        payload.setdefault("named_by", "manual_entry")

    # When location changes, keep space_id consistent unless caller already set it
    if "location" in payload and "space_id" not in payload:
        loc = (payload.get("location") or "").strip()
        if loc and loc.lower() != "unsorted":
            space_id = _resolve_space_id(user_id=user_id, location=loc,
                                         workspace_id=workspace_id)
            payload["space_id"] = space_id
        else:
            payload["space_id"] = None
        if "bin_id" not in payload:
            payload["bin_id"] = None
            payload["container"] = None

    if "bin_id" in payload and payload["bin_id"] is None and "container" not in payload:
        payload["container"] = None

    if payload.get("bin_id"):
        target_space_id = payload.get("space_id")
        if not target_space_id:
            current = (
                _scope(supabase.table("items").select("space_id"),
                       user_id=user_id, workspace_id=workspace_id).eq("item_id", item_id)
                .maybe_single().execute()
            )
            target_space_id = (current.data or {}).get("space_id")
        _validate_bin(
            user_id=user_id,
            bin_id=payload["bin_id"],
            space_id=target_space_id,
            workspace_id=workspace_id,
        )

    if "brand" in payload and "part_number" in payload:
        from app.services.catalog_service import verified_catalog_id_for_identity
        payload["catalog_id"] = verified_catalog_id_for_identity(
            brand=payload.get("brand"),
            part_number=payload.get("part_number"),
        )

    before = None
    if "quantity" in payload or "location" in payload:
        before_result = (
            _scope(supabase.table("items").select("quantity,location"),
                   user_id=user_id, workspace_id=workspace_id).eq("item_id", item_id)
            .maybe_single().execute()
        )
        before = before_result.data

    try:
        resp = _execute_with_retry(
            lambda: _scope(supabase.table("items").update(payload),
                user_id=user_id, workspace_id=workspace_id).eq("item_id", item_id).execute()
        )

        data = resp.data or []
        result = data[0] if data else None
    except Exception:
        logger.exception("Failed to update item (select fallback)")
        _execute_with_retry(lambda: _scope(supabase.table("items").update(payload),
            user_id=user_id, workspace_id=workspace_id).eq("item_id", item_id).execute())
        resp = _execute_with_retry(
            lambda: _scope(supabase.table("items").select("*"),
                user_id=user_id, workspace_id=workspace_id).eq("item_id", item_id).maybe_single().execute()
        )
        result = resp.data if isinstance(resp.data, dict) else None

    # Flywheel: save confirmed barcode data to parts_catalog
    try:
        if updates.get("barcode"):
            from app.services.catalog_service import save_to_catalog
            save_to_catalog(
                barcode=updates["barcode"],
                data={k: updates.get(k) for k in ["name", "brand", "category", "subcategory", "part_number"]},
                source="user"
            )
    except Exception:
        pass

    if result and before:
        old_count = int(before.get("quantity") or 0)
        new_count = int(result.get("quantity") or 0)
        moved = before.get("location") != result.get("location")
        if old_count != new_count or moved:
            from app.services.item_events_repo import log_event
            delta = new_count - old_count
            log_event(
                user_id=actor_user_id or user_id,
                item_id=item_id,
                event_type="restock" if delta > 0 else "usage" if delta < 0 else "note",
                content=(
                    f"Moved from {before.get('location')} to {result.get('location')}"
                    if moved else None
                ),
                quantity_delta=delta,
                quantity_before=old_count,
                quantity_after=new_count,
                cause=cause,
            )
    invalidate_inventory_cache(workspace_id or user_id)
    return result


def search_items_basic(*, user_id: str, q: str, workspace_id: str | None = None) -> list[dict]:
    q = (q or "").strip()
    if not q:
        if workspace_id:
            return list_items(user_id=user_id, workspace_id=workspace_id)
        return list_items(user_id=user_id)

    supabase = get_supabase_admin()
    pattern = f"%{q}%"

    resp = _execute_with_retry(
        lambda: _scope(supabase.table("items").select("*"),
                       user_id=user_id, workspace_id=workspace_id)
        .or_(
            f"name.ilike.{pattern},"
            f"part_number.ilike.{pattern},"
            f"brand.ilike.{pattern},"
            f"category.ilike.{pattern},"
            f"subcategory.ilike.{pattern},"
            f"location.ilike.{pattern},"
            f"notes.ilike.{pattern},"
            f"purchase_source.ilike.{pattern},"
            f"barcode.ilike.{pattern}"
        )
        .order("created_at", desc=True)
        .execute()
    )

    return resp.data or []


def _merge_by_item_id(primary: list[dict], secondary: list[dict]) -> list[dict]:
    """Append secondary items that are not already in primary, deduplicating by item_id."""
    seen = {i["item_id"] for i in primary if i.get("item_id")}
    return primary + [i for i in secondary if i.get("item_id") not in seen]
