
import mimetypes
from dataclasses import dataclass
from urllib.parse import urlsplit, urlunsplit

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

    bucket = supabase.storage.from_("documents")
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


def create_document_signed_url(*, storage_path: str) -> str:
    """Create a short-lived document URL using the service role.

    Access authorization happens in the API route against the documents table;
    this also works for objects migrated from the old Storage ownership model.
    """
    settings = get_settings()
    signed = get_supabase_admin().storage.from_("documents").create_signed_url(
        storage_path,
        settings.supabase_storage_signed_url_ttl_seconds,
    )
    url = signed.get("signedURL") or signed.get("signedUrl")
    if not url:
        raise RuntimeError("Storage did not return a document URL")
    if settings.supabase_public_url:
        public = urlsplit(str(settings.supabase_public_url))
        internal = urlsplit(url)
        url = urlunsplit((
            public.scheme,
            public.netloc,
            "/" + internal.path.lstrip("/"),
            internal.query,
            internal.fragment,
        ))
    return url
