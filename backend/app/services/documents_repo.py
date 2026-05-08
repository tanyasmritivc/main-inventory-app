from __future__ import annotations

from datetime import datetime, timezone
import logging
import time
from uuid import uuid4

import httpx

from app.services.supabase_client import get_supabase_admin


logger = logging.getLogger(__name__)


_DOC_SELECT_FIELDS_PRIMARY = (
    "user_id,filename,storage_path,mime_type,file_type,size_bytes,created_at,ai_access_granted,ai_access_granted_at,item_id"
)
_DOC_SELECT_FIELDS_FALLBACK = "user_id,filename,storage_path,mime_type,file_type,size_bytes,created_at"


def _is_missing_display_name_column_error(exc: Exception) -> bool:
    msg = str(exc).lower()
    return ("display_name" in msg) and ("does not exist" in msg)


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
                logger.warning(f"Supabase error attempt={attempt}, retrying in {wait}s: {e}")
                time.sleep(wait)
            else:
                logger.error(f"Supabase failed after {max_attempts} attempts: {e}")
    raise last_error


def create_document(
    *,
    user_id: str,
    filename: str,
    mime_type: str | None,
    storage_path: str,
    file_type: str | None,
    size_bytes: int,
    item_id: str | None = None,
) -> dict:
    supabase = get_supabase_admin()
    payload = {
        "user_id": user_id,
        "filename": filename,
        "storage_path": storage_path,
        "mime_type": mime_type,
        "file_type": file_type,
        "size_bytes": size_bytes,
    }
    if item_id:
        payload["item_id"] = item_id

    resp = _execute_with_retry(lambda: supabase.table("documents").insert(payload).execute())
    data = (resp.data or [payload])[0]
    if isinstance(data, dict):
        data.setdefault("storage_path", storage_path)
    return data


def list_documents(*, user_id: str, limit: int = 50, item_id: str | None = None) -> list[dict]:
    supabase = get_supabase_admin()

    def _q(fields: str):
        q = supabase.table("documents").select(fields).eq("user_id", user_id)
        if item_id:
            q = q.eq("item_id", item_id)
        return q.order("created_at", desc=True).limit(limit).execute()

    try:
        resp = _execute_with_retry(lambda: _q("document_id,user_id,filename,storage_path,mime_type,created_at"))
        return resp.data or []
    except Exception as e:
        if not _is_missing_display_name_column_error(e):
            raise
        resp = _execute_with_retry(lambda: _q(_DOC_SELECT_FIELDS_FALLBACK))
        return resp.data or []


def _get_document(*, user_id: str, storage_path: str) -> dict | None:
    supabase = get_supabase_admin()
    if not storage_path or not storage_path.strip():
        return None

    try:
        resp = _execute_with_retry(
            lambda: supabase.table("documents")
            .select(_DOC_SELECT_FIELDS_PRIMARY)
            .eq("user_id", user_id)
            .eq("storage_path", storage_path)
            .maybe_single()
            .execute()
        )
        return resp.data if isinstance(resp.data, dict) else None
    except Exception as e:
        if not _is_missing_display_name_column_error(e):
            raise
        resp = _execute_with_retry(
            lambda: supabase.table("documents")
            .select(_DOC_SELECT_FIELDS_FALLBACK)
            .eq("user_id", user_id)
            .eq("storage_path", storage_path)
            .maybe_single()
            .execute()
        )
        return resp.data if isinstance(resp.data, dict) else None


def rename_document(*, user_id: str, storage_path: str, display_name: str) -> dict | None:
    supabase = get_supabase_admin()
    clean = (display_name or "").strip()
    if not storage_path or not storage_path.strip():
        return None
    if not clean:
        return None

    _execute_with_retry(
        lambda: supabase.table("documents")
        .update({"filename": clean})
        .eq("user_id", user_id)
        .eq("storage_path", storage_path)
        .execute()
    )
    return _get_document(user_id=user_id, storage_path=storage_path)


def set_document_item_link(*, user_id: str, storage_path: str, item_id: str | None) -> dict | None:
    supabase = get_supabase_admin()
    if not storage_path or not storage_path.strip():
        return None
    clean_item_id = (item_id or "").strip() or None

    try:
        _execute_with_retry(
            lambda: supabase.table("documents")
            .update({"item_id": clean_item_id})
            .eq("user_id", user_id)
            .eq("storage_path", storage_path)
            .execute()
        )
    except Exception:
        logger.exception("Failed to update document item link")
        return None

    return _get_document(user_id=user_id, storage_path=storage_path)


def get_ai_access_granted(*, user_id: str, storage_path: str) -> bool:
    supabase = get_supabase_admin()
    try:
        resp = _execute_with_retry(
            lambda: supabase.table("documents")
            .select("ai_access_granted")
            .eq("user_id", user_id)
            .eq("storage_path", storage_path)
            .maybe_single()
            .execute()
        )
        data = resp.data if isinstance(resp.data, dict) else None
        return bool((data or {}).get("ai_access_granted"))
    except Exception:
        return False


def grant_ai_access(*, user_id: str, storage_path: str) -> bool:
    supabase = get_supabase_admin()
    try:
        now = datetime.now(timezone.utc).isoformat()
        _execute_with_retry(
            lambda: supabase.table("documents")
            .update({"ai_access_granted": True, "ai_access_granted_at": now})
            .eq("user_id", user_id)
            .eq("storage_path", storage_path)
            .execute()
        )
        return True
    except Exception:
        logger.exception("Failed to grant ai access")
        return False



def create_activity(*, user_id: str, summary: str, metadata: dict | None = None) -> dict:
    """Create activity log entry. Non-blocking - returns dummy data on failure to prevent upload flow issues."""
    try:
        supabase = get_supabase_admin()
        now = datetime.now(timezone.utc).isoformat()

        md = metadata or {}

        # Only use columns that exist in production schema
        payload = {
            "user_id": user_id,
            "event_type": md.get("type") or "unknown",
            "summary": summary,
            "metadata": md,
            "created_at": now,
        }

        resp = _execute_with_retry(lambda: supabase.table("activity_log").insert(payload).execute())
        return (resp.data or [payload])[0]
    except Exception as e:
        # Non-blocking: log warning but don't break the upload flow
        logger.warning(f"Activity logging failed (non-blocking): {e}")
        # Return dummy activity data to maintain API contract
        return {
            "activity_id": str(uuid4()),
            "user_id": user_id,
            "event_type": (metadata or {}).get("type") or "unknown",
            "summary": summary,
            "metadata": metadata or {},
            "created_at": datetime.now(timezone.utc).isoformat(),
        }




def list_recent_activity(*, user_id: str, limit: int = 10) -> list[dict]:
    supabase = get_supabase_admin()
    resp = _execute_with_retry(
        lambda: supabase.table("activity_log").select("*").eq("user_id", user_id).order("created_at", desc=True).limit(limit).execute()
    )
    return resp.data or []
