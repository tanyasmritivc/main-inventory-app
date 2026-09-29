import io
import logging
from urllib.parse import unquote, urlsplit
from uuid import uuid4

from PIL import Image, ImageOps

from app.core.config import get_settings
from app.services.item_events_repo import log_event
from app.services.items_repo import update_item
from app.services.storage import delete_image, upload_image
from app.services.supabase_client import get_supabase_admin


logger = logging.getLogger(__name__)

MAX_ITEM_PHOTO_BYTES = 10 * 1024 * 1024
MAX_ITEM_PHOTO_PIXELS = 25_000_000
MAX_ITEM_PHOTOS = 10


def _get_item(*, user_id: str, item_id: str) -> dict:
    rows = (
        get_supabase_admin()
        .table("items")
        .select("*")
        .eq("user_id", user_id)
        .eq("item_id", item_id)
        .limit(1)
        .execute()
        .data
        or []
    )
    if not rows:
        raise LookupError("Item not found")
    return rows[0]


def _photo_events(*, user_id: str, item_id: str) -> list[dict]:
    return (
        get_supabase_admin()
        .table("item_events")
        .select("event_id,image_url,created_at")
        .eq("user_id", user_id)
        .eq("item_id", item_id)
        .eq("event_type", "photo")
        .order("created_at", desc=True)
        .limit(MAX_ITEM_PHOTOS + 10)
        .execute()
        .data
        or []
    )


def _photos_for_item(*, item: dict, events: list[dict]) -> list[dict]:
    primary_url = str(item.get("image_url") or "").strip()
    photos: list[dict] = []
    seen: set[str] = set()

    for event in events:
        image_url = str(event.get("image_url") or "").strip()
        event_id = str(event.get("event_id") or "").strip()
        if not image_url or not event_id or image_url in seen:
            continue
        seen.add(image_url)
        photos.append(
            {
                "photo_id": event_id,
                "image_url": image_url,
                "is_primary": image_url == primary_url,
                "created_at": event.get("created_at"),
            }
        )

    if primary_url and primary_url not in seen:
        photos.insert(
            0,
            {
                "photo_id": "primary",
                "image_url": primary_url,
                "is_primary": True,
                "created_at": item.get("created_at"),
            },
        )
    elif primary_url:
        photos.sort(key=lambda photo: not photo["is_primary"])

    return photos[:MAX_ITEM_PHOTOS]


def list_item_photos(*, user_id: str, item_id: str) -> tuple[dict, list[dict]]:
    item = _get_item(user_id=user_id, item_id=item_id)
    events = _photo_events(user_id=user_id, item_id=item_id)
    return item, _photos_for_item(item=item, events=events)


def _jpeg_bytes(raw: bytes) -> bytes:
    if not raw:
        raise ValueError("Choose a photo that is not empty.")
    if len(raw) > MAX_ITEM_PHOTO_BYTES:
        raise ValueError("Choose a photo smaller than 10 MB.")
    try:
        with Image.open(io.BytesIO(raw)) as source:
            if source.width * source.height > MAX_ITEM_PHOTO_PIXELS:
                raise ValueError("Choose a smaller photo.")
            source.load()
            image = ImageOps.exif_transpose(source)
            image.thumbnail((2048, 2048), Image.Resampling.LANCZOS)
            output = io.BytesIO()
            image.convert("RGB").save(output, format="JPEG", quality=84)
            return output.getvalue()
    except ValueError:
        raise
    except Exception as exc:
        raise ValueError("Choose a valid photo.") from exc


def _ensure_primary_event(*, user_id: str, item: dict, events: list[dict]) -> None:
    primary_url = str(item.get("image_url") or "").strip()
    if not primary_url:
        return
    if any(str(event.get("image_url") or "").strip() == primary_url for event in events):
        return
    log_event(
        user_id=user_id,
        item_id=str(item["item_id"]),
        event_type="photo",
        image_url=primary_url,
    )


def _delete_event(*, user_id: str, item_id: str, event_id: str) -> None:
    deleted = (
        get_supabase_admin()
        .table("item_events")
        .delete()
        .eq("user_id", user_id)
        .eq("item_id", item_id)
        .eq("event_id", event_id)
        .eq("event_type", "photo")
        .execute()
        .data
        or []
    )
    if not deleted:
        raise LookupError("Photo not found")


def _storage_path(*, user_id: str, image_url: str) -> str | None:
    bucket = get_settings().supabase_storage_bucket
    path = urlsplit(image_url).path
    markers = (
        f"/storage/v1/object/public/{bucket}/",
        f"/storage/v1/object/sign/{bucket}/",
        f"/storage/v1/object/{bucket}/",
    )
    for marker in markers:
        if marker not in path:
            continue
        candidate = unquote(path.split(marker, 1)[1]).lstrip("/")
        if candidate.startswith(f"{user_id}/"):
            return candidate
    return None


def _image_url_is_referenced(*, user_id: str, image_url: str) -> bool:
    client = get_supabase_admin()
    items = (
        client.table("items")
        .select("item_id")
        .eq("user_id", user_id)
        .eq("image_url", image_url)
        .limit(1)
        .execute()
        .data
        or []
    )
    if items:
        return True
    events = (
        client.table("item_events")
        .select("event_id")
        .eq("user_id", user_id)
        .eq("event_type", "photo")
        .eq("image_url", image_url)
        .limit(1)
        .execute()
        .data
        or []
    )
    return bool(events)


def add_item_photo(
    *, user_id: str, item_id: str, filename: str, content: bytes
) -> tuple[dict, list[dict]]:
    item = _get_item(user_id=user_id, item_id=item_id)
    events = _photo_events(user_id=user_id, item_id=item_id)
    photos = _photos_for_item(item=item, events=events)
    if len(photos) >= MAX_ITEM_PHOTOS:
        raise ValueError(f"Each item can have up to {MAX_ITEM_PHOTOS} photos.")

    _ensure_primary_event(user_id=user_id, item=item, events=events)
    jpeg = _jpeg_bytes(content)
    stored = upload_image(
        user_id=user_id,
        filename=f"item-{item_id}-{uuid4().hex}.jpg",
        content=jpeg,
    )
    event: dict | None = None
    try:
        event = log_event(
            user_id=user_id,
            item_id=item_id,
            event_type="photo",
            image_url=stored.url,
        )
        updated = update_item(
            user_id=user_id,
            item_id=item_id,
            updates={"image_url": stored.url},
        )
        if not updated:
            raise LookupError("Item not found")
    except Exception:
        if event and event.get("event_id"):
            try:
                _delete_event(
                    user_id=user_id,
                    item_id=item_id,
                    event_id=str(event["event_id"]),
                )
            except Exception:
                logger.exception("Could not roll back item photo event")
        try:
            delete_image(path=stored.path)
        except Exception:
            logger.exception("Could not roll back uploaded item photo")
        raise

    _, photo_list = list_item_photos(user_id=user_id, item_id=item_id)
    return updated, photo_list


def delete_item_photo(
    *, user_id: str, item_id: str, photo_id: str
) -> tuple[dict, list[dict]]:
    item = _get_item(user_id=user_id, item_id=item_id)
    events = _photo_events(user_id=user_id, item_id=item_id)
    photos = _photos_for_item(item=item, events=events)
    target = next((photo for photo in photos if photo["photo_id"] == photo_id), None)
    if target is None:
        raise LookupError("Photo not found")

    if photo_id != "primary":
        _delete_event(user_id=user_id, item_id=item_id, event_id=photo_id)

    remaining_events = _photo_events(user_id=user_id, item_id=item_id)
    remaining = [
        photo
        for photo in _photos_for_item(item={**item, "image_url": None}, events=remaining_events)
        if photo["image_url"] != target["image_url"]
    ]

    updated = item
    if target["is_primary"]:
        next_url = remaining[0]["image_url"] if remaining else None
        updated = update_item(
            user_id=user_id,
            item_id=item_id,
            updates={"image_url": next_url},
        )
        if not updated:
            raise LookupError("Item not found")

    storage_path = _storage_path(user_id=user_id, image_url=target["image_url"])
    if storage_path:
        try:
            if not _image_url_is_referenced(
                user_id=user_id,
                image_url=target["image_url"],
            ):
                delete_image(path=storage_path)
        except Exception:
            logger.exception(
                "Item photo record was deleted but safe storage cleanup failed for %s",
                storage_path,
            )

    _, photo_list = list_item_photos(user_id=user_id, item_id=item_id)
    return updated, photo_list
