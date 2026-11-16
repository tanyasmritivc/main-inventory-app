"""Explicit, immutable BOM saves. Comparison alone never creates a project."""
import hashlib
import json
import os
from fastapi import HTTPException
from app.services.supabase_client import get_supabase_raw
from .repository import authorize_inventory, read_inventory
from .comparison import compare
from . import corrections


def enabled():
    return os.getenv('CAD_BOM_ENABLED') == 'true'


def require_enabled():
    if not enabled():
        raise HTTPException(503, 'Saved CAD projects are not enabled yet.')


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()).hexdigest()


def writable(inventory, actor, grant=None):
    require_enabled()
    authorize_inventory(inventory, actor)
    allowed = get_supabase_raw().rpc('findez_cad_can_write', {
        'p_actor': actor, 'p_inventory': inventory, 'p_grant': grant}).execute().data
    if allowed is not True:
        raise HTTPException(403, 'Reconnect with permission to save CAD work. Inventory editing access is required.')


def receipt(value):
    if not isinstance(value, dict):
        raise HTTPException(503, 'The CAD save could not be confirmed. Retry the same request.')
    if value.get('error'):
        code = {'forbidden': 403, 'conflict': 409, 'limit': 429}.get(value['error'], 503)
        raise HTTPException(code, {'forbidden': 'Your CAD editing permission changed.',
            'conflict': 'This request was already used for different CAD data.',
            'limit': 'The saved CAD work limit has been reached.'}.get(value['error'], 'The CAD save could not be confirmed.'))
    return value


def evaluate(snapshot, inventory, actor):
    items, reserved, checked = read_inventory(inventory, actor)
    try:
        result = compare(snapshot, items, reserved, checked, corrections.load(snapshot, inventory, actor))
    except ValueError:
        raise HTTPException(409, 'Inventory changed during comparison. Compare again.') from None
    authorize_inventory(inventory, actor)
    return {'inventory_id': inventory, **result}


def save(snapshot, inventory, actor, request_id, grant=None):
    writable(inventory, actor, grant)
    if not snapshot.document.external_id.strip() or snapshot.document.external_id.startswith('unsaved:'):
        raise HTTPException(422, 'Save the design to a Fusion project before saving BOM versions.')
    raw = snapshot.model_dump(mode='json')
    # A fresh extraction UUID does not change an otherwise identical retry.
    stable = {k: v for k, v in raw.items() if k != 'extraction_id'}
    source = digest([snapshot.provider, snapshot.document.external_id, snapshot.revision.configuration])
    result = evaluate(snapshot, inventory, actor)
    saved = receipt(get_supabase_raw().rpc('findez_cad_save_version', {
        'p_actor': actor, 'p_inventory': inventory, 'p_grant': grant,
        'p_source': source, 'p_name': snapshot.document.name.strip() or 'Fusion design',
        'p_request': str(request_id), 'p_hash': digest(stable), 'p_snapshot': raw,
        'p_comparison': result}).execute().data)
    authorize_inventory(inventory, actor)
    return {'inventory_id': inventory, **saved}


def versions(inventory, actor, offset=0):
    require_enabled()
    authorize_inventory(inventory, actor)
    rows = get_supabase_raw().table('cad_bom_versions').select(
        'id,project_id,version,created_at,comparison->document,comparison->revision,comparison->summary').eq(
        'inventory_id', inventory).order('created_at', desc=True).order('id').range(offset, offset + 49).execute().data or []
    authorize_inventory(inventory, actor)
    return {'inventory_id': inventory, 'versions': rows, 'offset': offset,
            'next_offset': offset + 50 if len(rows) == 50 else None}


def version(inventory, actor, version_id):
    require_enabled()
    authorize_inventory(inventory, actor)
    rows = get_supabase_raw().table('cad_bom_versions').select('id,project_id,version,created_at,comparison').eq(
        'inventory_id', inventory).eq('id', str(version_id)).limit(1).execute().data or []
    authorize_inventory(inventory, actor)
    if not rows:
        raise HTTPException(404, 'This BOM version is unavailable in this inventory.')
    return {'inventory_id': inventory, **rows[0], 'historical': True}
