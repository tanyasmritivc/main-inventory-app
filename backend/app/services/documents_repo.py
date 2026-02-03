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


def create_document(
    *,
    user_id: str,
    filename: str,
    mime_type: str | None,
    storage_path: str,
    file_type: str | None,
    size_bytes: int,
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

    resp = _execute_with_retry(lambda: supabase.table("documents").insert(payload).execute())
    data = (resp.data or [payload])[0]
    if isinstance(data, dict):
        data.setdefault("storage_path", storage_path)
    return data


def list_documents(*, user_id: str, limit: int = 50) -> list[dict]:
    supabase = get_supabase_admin()
    try:
        resp = _execute_with_retry(
            lambda: supabase.table("documents")
            .select("user_id,filename,storage_path,mime_type,file_type,size_bytes,created_at,ai_access_granted,ai_access_granted_at")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        return resp.data or []
    except Exception:
        resp = _execute_with_retry(
            lambda: supabase.table("documents")
            .select("user_id,filename,storage_path,mime_type,file_type,size_bytes,created_at")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        return resp.data or []


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
