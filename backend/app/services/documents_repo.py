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

    print("DOCUMENT PAYLOAD >>>", payload)  # ✅ TEMP DEBUG

    resp = _execute_with_retry(lambda: supabase.table("documents").insert(payload).execute())
    return (resp.data or [payload])[0]



def create_activity(*, user_id: str, summary: str, metadata: dict | None = None) -> dict:
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

    resp = _execute_with_retry(lambda: supabase.table("activity_log").insert(payload).execute())
    return (resp.data or [payload])[0]




def list_recent_activity(*, user_id: str, limit: int = 10) -> list[dict]:
    supabase = get_supabase_admin()
    resp = _execute_with_retry(
        lambda: supabase.table("activity_log").select("*").eq("user_id", user_id).order("created_at", desc=True).limit(limit).execute()
    )
    return resp.data or []
