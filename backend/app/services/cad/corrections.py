"""Inventory-scoped human decisions, invalidated when either identity changes."""
from fastapi import HTTPException

from app.services.supabase_client import get_supabase_raw
from .onshape import digest
from .security import configured, seal, unseal
from .repository import authorize_inventory, read_inventory
from .snapshot import requirements


def rows_for(snapshot):
    return snapshot.requirements()[0] if hasattr(snapshot, 'requirements') else requirements(snapshot)[0]


def identity(row):
    return digest({k: row.get(k, '') for k in ('name', 'part_number', 'manufacturer', 'barcode',
        'source_document', 'source_token', 'configuration', 'procurement_policy')})


def item_identity(item):
    return digest({k: str(item.get(k) or '').strip().casefold() for k in ('name', 'part_number', 'brand', 'barcode')})


def load(snapshot, inventory, actor):
    if not configured():
        return {}
    authorize_inventory(inventory, actor)
    hashes = list({identity(row) for row in rows_for(snapshot)})
    result = {}
    for start in range(0, len(hashes), 100):
        records = get_supabase_raw().table('cad_match_corrections').select('identity_hash,item_id,item_fingerprint,decision').eq('inventory_id', inventory).in_('identity_hash', hashes[start:start + 100]).execute().data or []
        result.update({r['identity_hash']: r for r in records})
    return result


def annotate(result, snapshot, inventory, actor):
    if not configured():
        return result
    source = {r['key']: r for r in rows_for(snapshot)}
    for line in result['items']:
        line['review_token'] = seal('cad_review', {'actor': actor, 'inventory': inventory,
            'identity': identity(source[line['key']])})
    result['saved_corrections_enabled'] = True
    return result


def save(inventory, actor, token, decision, item_id):
    receipt = unseal('cad_review', token, ttl=3600)
    if receipt.get('actor') != actor or receipt.get('inventory') != inventory:
        raise HTTPException(403, 'This review belongs to another account or inventory.')
    from app.api.routes.inventory_workspaces import _inventory
    authorize_inventory(inventory, actor)
    if not _inventory(inventory, actor)['can_edit']:
        raise HTTPException(403, 'Editing permission is required to save a team correction.')
    fingerprint = None
    if decision == 'match':
        items, _, _ = read_inventory(inventory, actor)
        item = next((i for i in items if str(i['item_id']) == item_id), None)
        if item is None:
            raise HTTPException(404, 'Choose an item in this inventory.')
        fingerprint = item_identity(item)
    elif item_id is not None:
        raise HTTPException(422, 'Only a confirmed match can include an inventory item.')
    result = get_supabase_raw().rpc('findez_cad_save_correction', {'p_actor': actor,
        'p_inventory': inventory, 'p_identity': receipt['identity'], 'p_decision': decision,
        'p_item': item_id, 'p_fingerprint': fingerprint}).execute().data
    if result is not True:
        raise HTTPException(409, 'The match could not be saved. Check your access and compare again.')
    return {'saved': True, 'inventory_id': inventory}
