
import mimetypes
from dataclasses import dataclass
from urllib.parse import unquote, urlsplit, urlunsplit
from uuid import uuid4

from app.core.config import get_settings
from app.services.supabase_client import get_supabase_admin
from app.services.inventory_scope import current_inventory


@dataclass
class StoredImage:
    path: str
    url: str


def document_path_in_scope(path: str, prefix: str) -> bool:
    """Reject foreign or traversal paths, including percent-encoded segments."""
    decoded = path
    for _ in range(5):
        expanded = unquote(decoded)
        if expanded == decoded:
            break
        decoded = expanded
    else:
        return False
    return (
        path.startswith(prefix)
        and decoded.startswith(prefix)
        and "\\" not in decoded
        and all(segment not in ("", ".", "..") for segment in decoded.split("/"))
    )


def _external_storage_url(url: str, public_base_url: str | None) -> str:
    if not public_base_url:
        return url
    public = urlsplit(str(public_base_url))
    internal = urlsplit(url)
    return urlunsplit((
        public.scheme, public.netloc, internal.path, internal.query,
        internal.fragment,
    ))


def _guess_content_type(filename: str) -> str:
    ct, _ = mimetypes.guess_type(filename)
    return ct or "application/octet-stream"


def upload_image(*, user_id: str, filename: str, content: bytes) -> StoredImage:
    settings = get_settings()
    supabase = get_supabase_admin()

    safe_filename = filename.replace("/", "_").replace("\\", "_").replace("%", "_")
    path = f"{user_id}/{uuid4().hex}-{safe_filename}"
    scope = current_inventory.get()
    if scope:
        path = f"{user_id}/{scope.inventory_id}-{uuid4().hex}-{safe_filename}"

    bucket = supabase.storage.from_(settings.supabase_storage_bucket)
    bucket.upload(
        path,
        content,
        file_options={"content-type": _guess_content_type(filename), "x-upsert": "true"},
    )

    # Preview grants are private to the requesting actor and are consumed when
    # the image is attached to an item/review. Stored URLs remain stable locators.
    from app.services.resource_access import request_actor
    from app.services.supabase_client import get_supabase_raw
    actor = request_actor.get()
    if actor:
        registered = get_supabase_raw().rpc('findez_register_image_preview', {
            'p_actor': actor.actor_id, 'p_inventory': scope.inventory_id if scope else None, 'p_path': path,
        }).execute().data
        if registered is not True:
            raise RuntimeError('Private image preview could not be registered')
    # Stable locator only: even legacy values use authenticated image delivery.
    # Never issue a bearer signed Storage link for an inventory photo.
    return StoredImage(path=path, url=_external_storage_url(bucket.get_public_url(path),settings.supabase_public_url))


def delete_image(*, path: str) -> None:
    settings = get_settings()
    get_supabase_admin().storage.from_(settings.supabase_storage_bucket).remove(
        [path]
    )


def upload_document(*, user_id: str, filename: str, content: bytes) -> StoredImage:
    settings = get_settings()
    supabase = get_supabase_admin()

    safe_filename = filename.replace("/", "_").replace("\\", "_").replace("%", "_")
    path = f"{user_id}/docs/{safe_filename}"
    scope = current_inventory.get()
    if scope:
        path = f"{user_id}/docs/{scope.inventory_id}-{uuid4().hex}-{safe_filename}"

    bucket = supabase.storage.from_("documents")
    bucket.upload(
        path,
        content,
        file_options={"content-type": _guess_content_type(filename), "x-upsert": "true"},
    )

    # Documents remain private independently of the public image bucket flag.
    return StoredImage(path=path,url=create_document_signed_url(storage_path=path))


def upload_team_document(
    *, team_id: str, user_id: str, filename: str, content: bytes
) -> StoredImage:
    settings = get_settings()
    supabase = get_supabase_admin()

    safe_filename = filename.replace("/", "_").replace("\\", "_").replace("%", "_")
    path = f"teams/{team_id}/{user_id}/{uuid4().hex}_{safe_filename}"

    bucket = supabase.storage.from_("documents")
    bucket.upload(
        path,
        content,
        file_options={
            "content-type": _guess_content_type(filename),
            "x-upsert": "false",
        },
    )

    return StoredImage(path=path,url=create_document_signed_url(storage_path=path))


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


def create_profile_photo_signed_url(*, storage_path: str) -> str:
    settings = get_settings()
    signed = get_supabase_admin().storage.from_("profile-photos").create_signed_url(
        storage_path, settings.supabase_storage_signed_url_ttl_seconds
    )
    url = signed.get("signedURL") or signed.get("signedUrl")
    if not url:
        raise RuntimeError("Storage did not return a profile photo URL")
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
