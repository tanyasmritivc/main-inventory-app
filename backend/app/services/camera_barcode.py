"""Resolve FindEZ labels privately before any public product lookup."""
from uuid import UUID
from urllib.parse import urlparse
from fastapi import HTTPException


def internal_item_id(code):
    value = code.strip()
    try:
        return str(UUID(value))
    except ValueError:
        pass
    parsed = urlparse(value)
    if parsed.scheme == 'findez' or parsed.hostname in ('findez.ai', 'www.findez.ai'):
        parts = ([parsed.netloc] if parsed.scheme == 'findez' else []) + parsed.path.strip('/').split('/')
        if parts and parts[0] in ('item', 'items'):
            try:
                return str(UUID(parts[-1]))
            except ValueError:
                pass
        raise HTTPException(422, 'This FindEZ label is not an item label.')
    return None


def resolve_internal_item(actor, world_key, code):
    """Return a fresh authorized item, never a new capture or public query."""
    item_id = internal_item_id(code)
    if item_id is None:
        return None
    from app.services import world_chat as world
    from app.services.supabase_client import get_supabase_raw
    world.authorize(actor, world_key)
    rows = get_supabase_raw().table('items').select('inventory_id').eq('item_id', item_id).limit(1).execute().data or []
    if not rows or not rows[0].get('inventory_id'):
        raise HTTPException(404, 'This item is not available in the selected organization.')
    try:
        resolved = world.resolve_resource(actor, world_key, rows[0]['inventory_id'], 'item', item_id)
    except HTTPException as error:
        if error.status_code in (403, 404):
            raise HTTPException(404, 'This item is not available in the selected organization.') from None
        raise
    item = resolved['resource']
    return {'found_in_inventory': True, 'inventory_id': resolved['inventory_id'],
            'existing_item': {key: item.get(key) for key in
                ('item_id', 'name', 'quantity', 'location', 'category', 'image_url')}}
