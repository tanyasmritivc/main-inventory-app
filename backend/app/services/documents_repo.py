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


def create_document(*, user_id: str, filename: str, mime_type: str | None, storage_path: str, url: str | None) -> dict:
    supabase = get_supabase_admin()
    now = datetime.now(timezone.utc).isoformat()

    mime = (mime_type or "").lower()
    file_type = "pdf" if (mime == "application/pdf" or filename.lower().endswith(".pdf")) else "image"

    payload = {
        "document_id": str(uuid4()),
        "user_id": user_id,
        "filename": filename,
        "file_type": file_type,   # ✅ REQUIRED
        "mime_type": mime_type,
        "storage_path": storage_path,
        "url": url,
        "created_at": now,
    }

    resp = _execute_with_retry(lambda: supabase.table("documents").insert(payload).execute())
    return (resp.data or [payload])[0]


def list_documents(*, user_id: str, limit: int = 50) -> list[dict]:
    supabase = get_supabase_admin()
    resp = _execute_with_retry(
        lambda: supabase.table("documents")
        .select("document_id,user_id,filename,file_type,mime_type,storage_path,url,created_at")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .limit(limit)
        .execute()
    )
    return resp.data or []


def upsert_document_text(
    *,
    user_id: str,
    document_id: str,
    filename: str,
    file_type: str | None,
    mime_type: str | None,
    extracted_text: str,
    truncated: bool,
) -> None:
    supabase = get_supabase_admin()
    now = datetime.now(timezone.utc).isoformat()

    payload = {
        "document_id": document_id,
        "user_id": user_id,
        "filename": filename,
        "file_type": file_type,
        "mime_type": mime_type,
        "extracted_text": extracted_text,
        "truncated": truncated,
        "updated_at": now,
    }

    try:
        _execute_with_retry(lambda: supabase.table("documents_text").upsert(payload).execute())
    except Exception:
        logger.exception("Failed to upsert documents_text")


def get_document_texts_by_id(*, user_id: str, document_ids: list[str]) -> dict[str, dict]:
    if not document_ids:
        return {}
    supabase = get_supabase_admin()

    try:
        resp = _execute_with_retry(
            lambda: supabase.table("documents_text")
            .select("document_id,filename,file_type,mime_type,extracted_text,truncated,updated_at")
            .eq("user_id", user_id)
            .in_("document_id", document_ids)
            .execute()
        )
    except Exception:
        logger.exception("Failed to fetch documents_text")
        return {}

    rows = resp.data or []
    out: dict[str, dict] = {}
    for r in rows:
        if isinstance(r, dict) and r.get("document_id"):
            out[str(r.get("document_id"))] = r
    return out



def create_activity(*, user_id: str, summary: str, metadata: dict | None = None, actor_name: str | None = None) -> dict:
    supabase = get_supabase_admin()
    now = datetime.now(timezone.utc).isoformat()

    md = metadata or {}
    event_type = md.get("type") or "unknown"

    payload = {
        "activity_id": str(uuid4()),
        "user_id": user_id,
        "event_type": event_type,
        "summary": summary,
        "metadata": md,
        "created_at": now,
    }

    if actor_name is not None and actor_name.strip():
        payload["actor_name"] = actor_name.strip()

    try:
        resp = _execute_with_retry(lambda: supabase.table("activity_log").insert(payload).execute())
        return (resp.data or [payload])[0]
    except Exception:
        if "actor_name" in payload:
            payload.pop("actor_name", None)
            resp = _execute_with_retry(lambda: supabase.table("activity_log").insert(payload).execute())
            return (resp.data or [payload])[0]
        raise




def list_recent_activity(*, user_id: str, limit: int = 10) -> list[dict]:
    supabase = get_supabase_admin()
    resp = _execute_with_retry(
        lambda: supabase.table("activity_log").select("*").eq("user_id", user_id).order("created_at", desc=True).limit(limit).execute()
    )
    return resp.data or []
