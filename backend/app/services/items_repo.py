from __future__ import annotations

from datetime import datetime, timezone
import logging
import time
from uuid import uuid4

import httpx

from app.services.supabase_client import get_supabase_admin


logger = logging.getLogger(__name__)


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

    now = datetime.now(timezone.utc).isoformat()
    payloads: list[dict] = []

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

        payloads.append(
            {
                "item_id": str(uuid4()),
                "user_id": user_id,
                "created_at": now,
                "name": name,
                "category": category,
                "subcategory": it.get("subcategory"),
                "brand": it.get("brand"),
                "part_number": it.get("part_number"),
                "tags": it.get("tags"),
                "confidence": it.get("confidence"),
                "quantity": quantity,
                "location": location,
                "image_url": it.get("image_url"),
                "barcode": it.get("barcode"),
                "purchase_source": it.get("purchase_source"),
                "notes": it.get("notes"),
            }
        )

    if not payloads:
        return ([], failures)

    resp = _execute_with_retry(lambda: supabase.table("items").insert(payloads).execute())
    inserted = resp.data or []

    return (inserted, failures)


def add_item(*, user_id: str, item: dict) -> dict:
    supabase = get_supabase_admin()

    now = datetime.now(timezone.utc).isoformat()
    payload = {
        **item,
        "item_id": str(uuid4()),
        "user_id": user_id,
        "created_at": now,
    }

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

    try:
        resp = _execute_with_retry(
            lambda: supabase.table("items").update(payload).eq("user_id", user_id).eq("item_id", item_id).select("*").execute()
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
