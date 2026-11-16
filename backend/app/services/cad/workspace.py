"""Read-only, single-inventory Fusion sessions. Tokens never authorize app APIs."""
from collections import defaultdict
from datetime import datetime, timezone
import hashlib
import secrets
import re

from fastapi import HTTPException
from app.api.routes.inventory_workspaces import _inventory
from app.services.supabase_client import get_supabase_raw
from .repository import read_inventory
from .comparison import count, normalized

ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'


def digest(value):
    return hashlib.sha256(value.encode('ascii')).hexdigest()


def start():
    device = secrets.token_urlsafe(48)
    code = ''.join(secrets.choice(ALPHABET) for _ in range(10))
    # Only hashes of bearer credentials are persisted. Browser receives the code,
    # never the device secret or the resulting restricted token.
    get_supabase_raw().table('cad_device_grants').insert({
        'device_hash': digest(device), 'user_code': code}).execute()
    return {'device_code': device, 'user_code': code, 'interval': 5, 'expires_in': 600,
            'verification_uri': 'https://www.findez.ai/cad/fusion/connect'}


def approve(code, inventory, actor):
    _inventory(inventory, actor)
    result = get_supabase_raw().rpc('findez_cad_device_approve', {
        'p_code': code, 'p_actor': actor, 'p_inventory': inventory}).execute().data
    if result is not True:
        raise HTTPException(409, 'This connection expired or was already used. Start again in Fusion.')
    return {'approved': True}


def exchange(device):
    token = secrets.token_urlsafe(48)
    result = get_supabase_raw().rpc('findez_cad_device_exchange', {
        'p_device': digest(device), 'p_token': digest(token)}).execute().data
    if not isinstance(result, dict) or result.get('status') not in ('pending', 'expired', 'connected'):
        raise HTTPException(503, 'The Fusion connection could not be completed.')
    if result['status'] != 'connected':
        return {'status': result['status']}
    return {'status': 'connected', 'access_token': token, 'expires_in': result['expires_in']}


def authorize(token):
    if not re.fullmatch(r'[A-Za-z0-9_-]{64}', token or ''):
        raise HTTPException(401, 'Connect FindEZ from Fusion again.')
    rows = get_supabase_raw().table('cad_device_grants').select(
        'id,actor_id,inventory_id,session_expires_at,revoked_at').eq('token_hash', digest(token)).limit(1).execute().data or []
    now = datetime.now(timezone.utc)
    if not rows or rows[0]['revoked_at'] or datetime.fromisoformat(rows[0]['session_expires_at'].replace('Z', '+00:00')) <= now:
        raise HTTPException(401, 'Connect FindEZ from Fusion again.')
    row = rows[0]
    role = get_supabase_raw().rpc('findez_inventory_role', {'p_inventory': row['inventory_id'], 'p_actor': row['actor_id']}).execute().data
    if role not in ('owner', 'admin', 'editor', 'viewer'):
        raise HTTPException(403, 'Your inventory access changed. Reconnect FindEZ.')
    inventory = _inventory(row['inventory_id'], row['actor_id'])
    return {**row, 'inventory_name': inventory['name'], 'workspace_name': inventory['workspace']['name']}


def revoke(session):
    get_supabase_raw().table('cad_device_grants').update({'revoked_at': datetime.now(timezone.utc).isoformat()}).eq('id', session['id']).execute()
    return {'disconnected': True}


def browse(session, query='', offset=0, location=None):
    inventory = session['inventory_id']
    items, reservations, checkouts = read_inventory(inventory, session['actor_id'])
    reserved, checked, uncertain = defaultdict(int), defaultdict(int), set()
    for entries, target in ((reservations, reserved), (checkouts, checked)):
        for entry in entries:
            key = str(entry.get('inventory_item_id') or entry.get('item_id'))
            quantity = entry.get('quantity')
            if type(quantity) is not int or quantity <= 0:
                uncertain.add(key)
            else:
                target[key] += quantity
    result = []
    for item in items:
        if location is not None and str(item.get('location') or '') != location:
            continue
        if query and normalized(query) not in ' '.join(normalized(item.get(k)) for k in ('name','brand','part_number','barcode','location')):
            continue
        key = str(item['item_id'])
        known = type(item.get('quantity')) is int and 0 <= item['quantity'] <= 1_000_000_000 and key not in uncertain
        result.append({k: item.get(k) for k in ('item_id','name','brand','part_number','barcode','location')} | {
            'on_hand': count(item.get('quantity')) if type(item.get('quantity')) is int and 0 <= item['quantity'] <= 1_000_000_000 else None, 'reserved': reserved[key], 'checked_out': checked[key],
            'available': max(0, count(item.get('quantity'))-reserved[key]-checked[key]) if known else 0,
            'availability_known': known, 'on_order': None,
            'cad_model': None})
    result.sort(key=lambda r: (normalized(r['name']), str(r['item_id'])))
    return {'inventory_id': inventory, 'inventory_name': session['inventory_name'],
            'locations': sorted({str(i.get('location') or '') for i in items}),
            'items': result[offset:offset+50], 'total': len(result), 'offset': offset,
            'next_offset': offset+50 if len(result)>offset+50 else None,
            'stock_basis': 'recorded_not_physically_verified'}


def catalog(query='', offset=0):
    # Global catalog rows contain no team ownership/quantity. Search only public
    # manufacturer-verified identities; never promote community guesses.
    db = get_supabase_raw()
    request = db.table('parts_catalog').select(
        'catalog_id,canonical_name,brand,part_number,specifications,product_url,source_url,verification_status', count='exact').eq('verification_status','verified')
    if query:
        # ilike value, not PostgREST grammar interpolation. Escape wildcard chars.
        escaped = query.replace('\\','\\\\').replace('%','\\%').replace('_','\\_')
        request = request.ilike('canonical_name', '%'+escaped+'%')
    response = request.order('canonical_name').order('catalog_id').range(offset,offset+49).execute()
    rows = response.data or []
    return {'parts': [{**r,'cad_model':None,'price':None} for r in rows], 'offset':offset,
            'next_offset':offset+50 if response.count is not None and offset+50<response.count else None,
            'total':response.count, 'source':'global_catalog_not_owned_stock'}
