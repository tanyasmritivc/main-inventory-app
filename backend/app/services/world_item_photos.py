"""Load fresh authorized inventory gallery pixels for multimodal chat."""
import io
from uuid import UUID
from PIL import Image, ImageOps
from pydantic import BaseModel, ConfigDict, Field
from app.services import saved_photo_search as gallery
from app.services.chat_vision import image_part
from app.services.supabase_client import get_supabase_raw
from app.core.config import get_settings


PHOTO_GUIDANCE = 'Read current item photos and attachment history. Use include_images=false for which items have or lack photos: returns exact matching totals and up to 25 item statuses per page, without downloading images. Use include_images=true to inspect actual pixels (four photos per page). Empty query checks the entire inventory; item_ids narrows it. Follow next_offset for more. Photos may be added after import; never infer absence from original import records. Unknown attachment dates remain unknown; image content and counts may be uncertain.'


class PhotoArguments(BaseModel):
    model_config = ConfigDict(extra='forbid')
    inventory_id: str
    query: str = Field(default='', max_length=200)
    item_ids: list[str] = Field(default_factory=list, max_length=20)
    offset: int = Field(default=0, ge=0, le=10000)
    include_images: bool = True


def read(actor, world, inventory_id, query='', item_ids=None, offset=0, include_images=True):
    from app.services.world_chat import in_inventory, inventory_scope
    with in_inventory(actor, world, inventory_id) as scope:
        result = read_current(actor, scope['owner_user_id'], inventory_id, query, item_ids, offset, include_images)
        inventory_scope(actor, world, inventory_id)
        return result


def read_scoped(user_id, **args):
    from app.services.inventory_scope import current_inventory
    from app.services.resource_access import request_actor
    scope = current_inventory.get()
    actor = scope.actor_id if scope else (request_actor.get().actor_id if request_actor.get() else user_id)
    return read_current(actor, user_id, scope.inventory_id if scope else None, **args)


def read_current(actor, user_id, inventory_id=None, query='', item_ids=None, offset=0, include_images=True):
    from app.services.ai_agent import _current_items
    wanted = {str(UUID(value)) for value in (item_ids or [])}
    items = _current_items(user_id=user_id, q=query)
    if wanted: items = [i for i in items if str(i['item_id']) in wanted]
    catalog = gallery.photo_catalog(items)
    by_id = {str(i['item_id']): i for i in catalog}
    refs = [(str(i['item_id']), p) for i in catalog for p in i['photos']]
    with_photos = sum(bool(i['photos']) for i in catalog)
    result = {'items_checked': len(catalog), 'items_with_photos': with_photos,
        'items_without_photos': len(catalog)-with_photos, 'photos_available': len(refs),
        'coverage': 'selected inventory and query only',
        'note': 'Attachment event time is when this photo was added, not camera capture time. Unknown timing stays unknown. An image added later does not change the original import. Visible evidence cannot prove hidden contents or exact physical quantity; never sum multiple views of the same objects.'}
    if not include_images:
        result.update(page_kind='items', next_offset=offset+25 if offset+25 < len(catalog) else None,
            complete=offset == 0 and len(catalog) <= 25, photos_read=0, items=[{
            'item_id': i['item_id'], 'name': i.get('name'), 'part_number': i.get('part_number'),
            'location': i.get('location'), 'quantity': i.get('quantity'),
            'item_created_at': i['item_created_at'], 'has_photo': bool(i['photos']),
            'photo_count': len(i['photos']), 'photos': [{k:v for k,v in p.items() if k != 'path'} for p in i['photos']],
        } for i in catalog[offset:offset+25]])
        return result
    images, photos, unavailable = [], [], 0
    for item_id, photo in refs[offset:offset+4]:
        path = photo['path']
        if not path or not gallery._authorized(actor, path):
            unavailable += 1
            continue
        try:
            content = get_supabase_raw().storage.from_(get_settings().supabase_storage_bucket).download(path)
            if not content or len(content) > gallery.MAX_BYTES: raise ValueError('Unsupported image size')
            with Image.open(io.BytesIO(content)) as original:
                if original.width * original.height > gallery.MAX_PIXELS: raise ValueError('Unsupported dimensions')
                image = ImageOps.exif_transpose(original).convert('RGB')
                image.thumbnail((1600, 1600))
                output = io.BytesIO(); image.save(output, format='JPEG', quality=90)
            if (item_id, path) not in gallery.references([by_id[item_id]]) or not gallery._authorized(actor, path):
                unavailable += 1
                continue
            item = by_id[item_id]
            label = {'item_id': item_id, 'name': item.get('name'), 'quantity': item.get('quantity'),
                'location': item.get('location'), 'inventory_id': inventory_id, 'photo_number': len(photos)+1,
                'item_created_at': item['item_created_at'], **{k:v for k,v in photo.items() if k != 'path'}}
            photos.append(label)
            import json
            images.extend([{'type':'text','text':'Saved record for this photo: '+json.dumps(label)}, image_part(output.getvalue())])
        except Exception:
            unavailable += 1
    result.update(page_kind='photos', photos=photos, photos_read=len(photos), unavailable=unavailable,
        next_offset=offset+4 if offset+4 < len(refs) else None,
        complete=offset == 0 and len(refs) <= 4 and unavailable == 0, _image_parts=images)
    return result
