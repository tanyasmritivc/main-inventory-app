from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile

from app.api.routes.imports import (
    _normalized_identifier,
    _parse_bom_rows,
    _resolve_analysis_target,
    _resolve_import_target,
)
from app.core.auth import AuthenticatedUser, get_current_user
from app.services.items_repo import list_items
from app.services.project_kits_service import (
    _analyze,
    _get_authorized_kit,
    _list_reservations,
    get_project_readiness,
)
from app.services.supabase_client import get_supabase_admin

router = APIRouter(prefix='/project-kits', tags=['project-kits'])




@router.post('')
async def create_project_kit(
    file: UploadFile = File(...),
    name: str = Form(...),
    location: str = Form('Unsorted'),
    share_id: str | None = Form(default=None),
    user: AuthenticatedUser = Depends(get_current_user),
):
    clean_name = name.strip()
    if not clean_name or len(clean_name) > 120:
        raise HTTPException(422, 'Enter a project name between 1 and 120 characters.')
    raw = await file.read()
    if not raw or len(raw) > 10 * 1024 * 1024:
        raise HTTPException(422, 'Choose a non-empty spreadsheet smaller than 10 MB.')
    owner_id, target_location = _resolve_import_target(
        requesting_user_id=user.user_id, location=location, share_id=share_id)
    rows = _parse_bom_rows(raw=raw, filename=(file.filename or '').lower())
    client = get_supabase_admin()
    created = client.table('project_kits').insert({
        'owner_user_id': owner_id,
        'created_by_user_id': user.user_id,
        'share_id': share_id,
        'name': clean_name,
        'location': target_location,
    }).execute()
    if not created.data:
        raise HTTPException(500, 'The project kit could not be created.')
    kit = created.data[0]
    try:
        client.table('project_kit_items').insert([
            {'kit_id': kit['id'], **row} for row in rows
        ]).execute()
    except Exception as exc:
        client.table('project_kits').delete().eq('id', kit['id']).execute()
        raise HTTPException(500, 'The project kit items could not be saved.') from exc
    return {**kit, **_analyze(rows=rows, owner_user_id=owner_id, location=target_location)}


@router.get('')
def list_project_kits(
    location: str,
    share_id: str | None = None,
    user: AuthenticatedUser = Depends(get_current_user),
):
    owner_id, target_location = _resolve_analysis_target(
        requesting_user_id=user.user_id, location=location, share_id=share_id)
    query = get_supabase_admin().table('project_kits').select('*').eq(
        'owner_user_id', owner_id).ilike('location', target_location)
    query = query.eq('share_id', share_id) if share_id else query.is_('share_id', 'null').eq('created_by_user_id', user.user_id)
    kits = query.order('updated_at', desc=True).execute().data or []
    return {'kits': kits}


@router.get('/{kit_id}')
def get_project_kit(kit_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    return get_project_readiness(kit_id=kit_id, user_id=user.user_id)


@router.post('/{kit_id}/reserve')
def reserve_project_kit(kit_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    kit, can_edit = _get_authorized_kit(kit_id, user.user_id)
    if not can_edit:
        raise HTTPException(403, 'You only have view access to this project kit.')
    client = get_supabase_admin()
    rows = client.table('project_kit_items').select(
        'id,name,part_number,brand,required_quantity').eq('kit_id', kit_id).execute().data or []
    inventory = [item for item in list_items(user_id=kit['owner_user_id']) if (
        str(item.get('location') or 'Unsorted').strip().lower() == kit['location'].strip().lower())]
    inventory_ids = [item['item_id'] for item in inventory]
    inventory_id_set = set(inventory_ids)
    existing = [reservation for reservation in _list_reservations()
                if reservation['inventory_item_id'] in inventory_id_set]
    remaining = {
        item['item_id']: max(0, int(item.get('quantity') or 0) - sum(
            int(reservation['quantity']) for reservation in existing
            if reservation['inventory_item_id'] == item['item_id'] and reservation['kit_id'] != kit_id))
        for item in inventory
    }
    allocations = []
    for row in rows:
        part_key = _normalized_identifier(row.get('part_number'))
        name_key = _normalized_identifier(row.get('name'))
        matches = [item for item in inventory if (
            (part_key and _normalized_identifier(item.get('part_number')) == part_key)
            or (not part_key and name_key and _normalized_identifier(item.get('name')) == name_key))]
        needed = int(row['required_quantity'])
        for item in matches:
            quantity = min(needed, remaining[item['item_id']])
            if quantity > 0:
                allocations.append({'kit_item_id': row['id'], 'inventory_item_id': item['item_id'], 'quantity': quantity})
                remaining[item['item_id']] -= quantity
                needed -= quantity
            if needed == 0:
                break
    try:
        client.rpc('replace_project_kit_reservations', {
            'p_kit_id': kit_id, 'p_actor_user_id': user.user_id,
            'p_allocations': allocations,
        }).execute()
    except Exception as exc:
        raise HTTPException(409, 'Inventory changed while reserving. Refresh and try again.') from exc
    return get_project_kit(kit_id, user)


@router.delete('/{kit_id}/reservations')
def release_project_kit(kit_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    _, can_edit = _get_authorized_kit(kit_id, user.user_id)
    if not can_edit:
        raise HTTPException(403, 'You only have view access to this project kit.')
    try:
        get_supabase_admin().rpc('replace_project_kit_reservations', {
            'p_kit_id': kit_id, 'p_actor_user_id': user.user_id, 'p_allocations': [],
        }).execute()
    except Exception as exc:
        raise HTTPException(500, 'Reservations could not be released.') from exc
    return get_project_kit(kit_id, user)


@router.delete('/{kit_id}')
def delete_project_kit(kit_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    kit, _ = _get_authorized_kit(kit_id, user.user_id)
    if kit['created_by_user_id'] != user.user_id:
        raise HTTPException(403, 'Only the person who created this project kit can delete it.')
    get_supabase_admin().table('project_kits').delete().eq('id', kit_id).execute()
    return {'deleted': True}
