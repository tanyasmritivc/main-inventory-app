"""Bounded, authorized saved-gallery evidence for a model-selected item read."""
import io
from uuid import UUID
from pydantic import BaseModel, ConfigDict
from PIL import Image, ImageOps
from fastapi import HTTPException


class ItemPhotoQuery(BaseModel):
    model_config = ConfigDict(extra='forbid')
    inventory_id: str
    item_id: str


def inspect_item(actor, key, args):
    from app.services import world_chat as world
    from app.services.item_photos import list_item_photos
    from app.services.saved_photo_search import storage_path, _authorized
    from app.services.chat_vision import image_part
    from app.services.supabase_client import get_supabase_raw
    from app.core.config import get_settings
    query = ItemPhotoQuery.model_validate(args, strict=True)
    inventory_id, item_id = str(UUID(query.inventory_id)), str(UUID(query.item_id))
    with world.in_inventory(actor, key, inventory_id) as inv:
        try:
            item, photos = list_item_photos(user_id=inv['owner_user_id'], item_id=item_id)
        except LookupError:
            raise HTTPException(404, 'This item is no longer available.') from None
        parts, read_paths = [], []
        for photo in photos[:4]:
            path = storage_path(photo.get('image_url'))
            if not path or not _authorized(actor, path):
                continue
            try:
                content = get_supabase_raw().storage.from_(get_settings().supabase_storage_bucket).download(path)
                if not content or len(content) > 10 * 1024 * 1024:
                    continue
                with Image.open(io.BytesIO(content)) as source:
                    if source.width * source.height > 25_000_000:
                        continue
                    image = ImageOps.exif_transpose(source).convert('RGB')
                    image.thumbnail((1280, 1280))
                    encoded = io.BytesIO()
                    image.save(encoded, format='JPEG', quality=85)
                parts.append(image_part(encoded.getvalue()))
                read_paths.append(path)
            except (OSError, ValueError):
                continue
        # Recheck membership/gallery after I/O; a replaced photo must not leak
        # into a different record or account through a stale search result.
        world.inventory_scope(actor, key, inventory_id)
        _, fresh = list_item_photos(user_id=inv['owner_user_id'], item_id=item_id)
        current = {storage_path(p.get('image_url')) for p in fresh}
        parts = [part for path, part in zip(read_paths, parts)
                 if path in current and _authorized(actor, path)]
        fields = ('item_id', 'name', 'part_number', 'category', 'brand', 'location', 'quantity', 'description')
        return {'items': [{k: item.get(k) for k in fields} | {'inventory_id': inventory_id}],
                'photos_available': len(photos), 'photos_shown': len(parts),
                'complete': len(parts) == len(photos),
                'note': 'These are the saved gallery pixels, not an inferred picture of the saved name. A photo match can coexist with incorrect saved metadata. If images are unavailable, say you could not compare them. Similar appearance alone cannot verify dimensions or a specific physical unit.',
                '_image_parts': parts}
