from __future__ import annotations

import mimetypes
from dataclasses import dataclass

from app.core.config import get_settings
from app.services.supabase_client import get_supabase_admin


@dataclass
class StoredImage:
    path: str
    url: str


def _guess_content_type(filename: str) -> str:
    ct, _ = mimetypes.guess_type(filename)
    return ct or "application/octet-stream"


def upload_image(*, user_id: str, filename: str, content: bytes) -> StoredImage:
    settings = get_settings()
    supabase = get_supabase_admin()

    safe_filename = filename.replace("/", "_").replace("\\", "_")
    path = f"{user_id}/{safe_filename}"

    bucket = supabase.storage.from_(settings.supabase_storage_bucket)
    bucket.upload(
        path,
        content,
        file_options={"content-type": _guess_content_type(filename), "x-upsert": "true"},
    )

    if settings.supabase_storage_public:
        url = bucket.get_public_url(path)
        return StoredImage(path=path, url=url)

    signed = bucket.create_signed_url(path, settings.supabase_storage_signed_url_ttl_seconds)
    url = signed.get("signedURL") or signed.get("signedUrl")
    return StoredImage(path=path, url=url)


def upload_document(*, user_id: str, filename: str, content: bytes) -> StoredImage:
    settings = get_settings()
    supabase = get_supabase_admin()

    safe_filename = filename.replace("/", "_").replace("\\", "_")
    path = f"{user_id}/docs/{safe_filename}"

    bucket = supabase.storage.from_(settings.supabase_storage_bucket)
    bucket.upload(
        path,
        content,
        file_options={"content-type": _guess_content_type(filename), "x-upsert": "true"},
    )

    if settings.supabase_storage_public:
        url = bucket.get_public_url(path)
        return StoredImage(path=path, url=url)

    signed = bucket.create_signed_url(path, settings.supabase_storage_signed_url_ttl_seconds)
    url = signed.get("signedURL") or signed.get("signedUrl")
    return StoredImage(path=path, url=url)
