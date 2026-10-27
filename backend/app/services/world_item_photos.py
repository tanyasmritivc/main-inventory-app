"""Load fresh authorized inventory gallery pixels for multimodal chat."""
import io
from uuid import UUID
from PIL import Image, ImageOps
from pydantic import BaseModel, ConfigDict, Field
from app.services import saved_photo_search as gallery
from app.services.chat_vision import image_part
from app.services.supabase_client import get_supabase_raw
from app.core.config import get_settings


class PhotoArguments(BaseModel):
    model_config = ConfigDict(extra='forbid')
    inventory_id: str
    query: str = Field(default='', max_length=200)
    item_ids: list[str] = Field(default_factory=list, max_length=20)
    offset: int = Field(default=0, ge=0, le=10000)


def read(actor, world, inventory_id, query='', item_ids=None, offset=0):
    from app.services.world_chat import in_inventory
    from app.services.ai_agent import _current_items
    wanted = {str(UUID(value)) for value in (item_ids or [])}
    images, photos, unavailable = [], [], 0
    with in_inventory(actor, world, inventory_id) as scope:
        items = _current_items(user_id=scope['owner_user_id'], q=query)
        if wanted:
            items = [item for item in items if str(item['item_id']) in wanted]
        by_id = {str(item['item_id']): item for item in items}
        refs = gallery.references(items)
        selected = refs[offset:offset + 4]
        for item_id, path in selected:
            if item_id not in by_id or not gallery._authorized(actor, path):
                unavailable += 1
                continue
            try:
                content = get_supabase_raw().storage.from_(get_settings().supabase_storage_bucket).download(path)
                if not content or len(content) > gallery.MAX_BYTES:
                    raise ValueError('Unsupported image size')
                with Image.open(io.BytesIO(content)) as original:
                    if original.width * original.height > gallery.MAX_PIXELS:
                        raise ValueError('Unsupported dimensions')
                    image = ImageOps.exif_transpose(original).convert('RGB')
                    image.thumbnail((1600, 1600))
                    output = io.BytesIO()
                    image.save(output, format='JPEG', quality=90)
                # A deleted/replaced photo must not survive into the model request.
                if (item_id, path) not in gallery.references([by_id[item_id]]) or not gallery._authorized(actor, path):
                    unavailable += 1
                    continue
                item = by_id[item_id]
                label = {'item_id': item_id, 'name': item.get('name'), 'quantity': item.get('quantity'),
                         'location': item.get('location'), 'inventory_id': inventory_id, 'photo_number': len(photos) + 1}
                photos.append(label)
                import json
                images.extend([{'type': 'text', 'text': 'Saved record for this photo: ' + json.dumps(label)}, image_part(output.getvalue())])
            except Exception:
                unavailable += 1
        # Reauthorize after image downloads too; do not retain pixels across calls.
        from app.services.world_chat import inventory_scope
        inventory_scope(actor, world, inventory_id)
    return {'photos': photos, 'photos_available': len(refs), 'photos_read': len(photos),
        'unavailable': unavailable, 'next_offset': offset + 4 if offset + 4 < len(refs) else None,
        'complete': offset == 0 and len(refs) <= 4 and unavailable == 0,
        'note': 'Photos are visual evidence, not proof of hidden contents or current physical quantity. Multiple photos can show the same objects; do not add their counts. Coverage applies only to this inventory and query.',
        '_image_parts': images}
