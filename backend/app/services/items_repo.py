from __future__ import annotations

from datetime import datetime, timezone
import logging
import re
import time
from uuid import uuid4

import httpx

from app.services.supabase_client import get_supabase_admin


logger = logging.getLogger(__name__)


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


def _normalize_location(raw: str) -> str:
    s = (raw or "").strip()
    if not s:
        return ""
    return s.title()


def _normalize_category(raw: str) -> str:
    s = (raw or "").strip().lower()
    if not s:
        return "Other"
    
    # Food
    if any(keyword in s for keyword in ['food', 'grocery', 'beverage', 'snack']):
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
    if any(keyword in s for keyword in ['cleaning', 'household', 'supply', 'adhesive', 'tool']):
        return "Supplies"
    
    # Toys
    if any(keyword in s for keyword in ['toy', 'game', 'hobby']):
        return "Toys"
    
    # Accessories -> Other
    if any(keyword in s for keyword in ['accessories', 'accessory']):
        return "Other"
    
    return "Other"


def _first_existing_match_by_normalized_name(*, user_id: str, normalized_name: str) -> dict | None:
    if not normalized_name:
        return None
    try:
        existing = list_items(user_id=user_id)
    except Exception:
        return None
    for it in existing or []:
        if not isinstance(it, dict):
            continue
        name = (it.get("name") or "").strip()
        if _normalize_item_name(name) == normalized_name:
            return it
    return None


def _execute_with_retry(fn, *, retries: int = 2, base_sleep: float = 0.2):
    last_exc: Exception | None = None
    for attempt in range(retries + 1):
        try:
            return fn()
        except httpx.RemoteProtocolError as e:
            last_exc = e
            logger.warning("Supabase connection dropped (RemoteProtocolError), attempt=%s", attempt + 1)
            time.sleep(base_sleep * (attempt + 1))
        except httpx.HTTPError as e:
            last_exc = e
            logger.warning("Supabase HTTP error, attempt=%s", attempt + 1)
            time.sleep(base_sleep * (attempt + 1))
        except Exception as e:
            last_exc = e
            break

    if last_exc:
        raise last_exc


def list_items(*, user_id: str) -> list[dict]:
    supabase = get_supabase_admin()
    resp = _execute_with_retry(
        lambda: supabase.table("items").select("*").eq("user_id", user_id).order("created_at", desc=True).execute()
    )
    return resp.data or []


def bulk_create_items(*, user_id: str, items: list[dict]) -> tuple[list[dict], list[dict]]:
    supabase = get_supabase_admin()
    inserted: list[dict] = []
    failures: list[dict] = []

    existing_items = list_items(user_id=user_id)
    existing_by_norm: dict[str, dict] = {}
    for it in existing_items or []:
        if not isinstance(it, dict):
            continue
        n = _normalize_item_name(str(it.get("name") or ""))
        if n and n not in existing_by_norm:
            existing_by_norm[n] = it

    now = datetime.now(timezone.utc).isoformat()
    payloads: list[dict] = []

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
                "barcode": it.get("barcode"),
                "purchase_source": it.get("purchase_source"),
                "notes": it.get("notes"),
            }
            aggregated_qty[norm] = 0
            aggregated_first_idx[norm] = idx

        aggregated_qty[norm] = int(aggregated_qty.get(norm, 0)) + int(quantity)

    for norm, base in aggregated.items():
        qty = int(aggregated_qty.get(norm, 0))
        if qty < 0:
            qty = 0

        existing = existing_by_norm.get(norm)
        if existing and isinstance(existing, dict):
            item_id = str(existing.get("item_id") or "")
            if not item_id:
                failures.append({"index": aggregated_first_idx.get(norm, 0), "reason": "missing item_id"})
                continue

            try:
                existing_qty = int(existing.get("quantity") or 0)
            except Exception:
                existing_qty = 0

            updated = update_item(user_id=user_id, item_id=item_id, updates={"quantity": existing_qty + qty})
            inserted.append(updated or {**existing, "quantity": existing_qty + qty})
            continue

        payloads.append(
            {
                "item_id": str(uuid4()),
                "user_id": user_id,
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
                "image_url": base.get("image_url"),
                "barcode": base.get("barcode"),
                "purchase_source": base.get("purchase_source"),
                "notes": base.get("notes"),
            }
        )

    if not payloads:
        return (inserted, failures)

    resp = _execute_with_retry(lambda: supabase.table("items").insert(payloads).execute())
    inserted = inserted + (resp.data or [])

    return (inserted, failures)


def add_item(*, user_id: str, item: dict) -> dict:
    supabase = get_supabase_admin()

    name = (item.get("name") or "").strip()
    norm = _normalize_item_name(name)
    existing = _first_existing_match_by_normalized_name(user_id=user_id, normalized_name=norm)
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

            updated = update_item(user_id=user_id, item_id=item_id, updates={"quantity": existing_qty + quantity_in})
            return updated or {**existing, "quantity": existing_qty + quantity_in}

    now = datetime.now(timezone.utc).isoformat()
    payload = {
        **item,
        "item_id": str(uuid4()),
        "user_id": user_id,
        "created_at": now,
    }
    
    # Normalize location field
    if "location" in payload and payload["location"] is not None:
        payload["location"] = _normalize_location(str(payload["location"]))
    
    # Normalize category field
    if "category" in payload and payload["category"] is not None:
        payload["category"] = _normalize_category(str(payload["category"]))

    resp = _execute_with_retry(lambda: supabase.table("items").insert(payload).execute())
    return (resp.data or [payload])[0]


def delete_item(*, user_id: str, item_id: str) -> bool:
    supabase = get_supabase_admin()
    resp = _execute_with_retry(lambda: supabase.table("items").delete().eq("user_id", user_id).eq("item_id", item_id).execute())
    return bool(resp.data)


def update_item(*, user_id: str, item_id: str, updates: dict) -> dict | None:
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
        "image_url",
        "barcode",
        "purchase_source",
        "notes",
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

    try:
        resp = _execute_with_retry(
            lambda: supabase.table("items").update(payload).eq("user_id", user_id).eq("item_id", item_id).execute()
        )

        data = resp.data or []
        return data[0] if data else None
    except Exception:
        logger.exception("Failed to update item (select fallback)")
        _execute_with_retry(lambda: supabase.table("items").update(payload).eq("user_id", user_id).eq("item_id", item_id).execute())
        resp = _execute_with_retry(
            lambda: supabase.table("items").select("*").eq("user_id", user_id).eq("item_id", item_id).maybe_single().execute()
        )
        return resp.data if isinstance(resp.data, dict) else None


def search_items_basic(*, user_id: str, q: str) -> list[dict]:
    q = (q or "").strip()
    if not q:
        return list_items(user_id=user_id)

    supabase = get_supabase_admin()
    pattern = f"%{q}%"

    resp = _execute_with_retry(
        lambda: supabase.table("items")
        .select("*")
        .eq("user_id", user_id)
        .or_(
            f"name.ilike.{pattern},category.ilike.{pattern},location.ilike.{pattern},notes.ilike.{pattern},purchase_source.ilike.{pattern},barcode.ilike.{pattern}"
        )
        .order("created_at", desc=True)
        .execute()
    )

    return resp.data or []
