from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile

from app.api.routes.imports import (
    _normalized_identifier,
    _parse_bom_rows,
    _resolve_analysis_target,
    _resolve_import_target,
)
from app.core.auth import AuthenticatedUser, get_current_user
from app.services.items_repo import list_items
from app.services.supabase_client import get_supabase_admin

router = APIRouter(prefix='/project-kits', tags=['project-kits'])


def _analyze(*, rows: list[dict], owner_user_id: str, location: str, kit_id: str | None = None) -> dict:
    inventory = [
        item for item in list_items(user_id=owner_user_id)
        if str(item.get('location') or 'Unsorted').strip().lower() == location.strip().lower()
    ]
    client = get_supabase_admin()
    inventory_ids = [item['item_id'] for item in inventory]
    reservations = []
    if inventory_ids:
        reservations = client.table('project_kit_reservations').select(
            'kit_id,kit_item_id,inventory_item_id,quantity').in_(
                'inventory_item_id', inventory_ids).execute().data or []
    results = []
    for row in rows:
        part_key = _normalized_identifier(row.get('part_number'))
        name_key = _normalized_identifier(row.get('name'))
        matches = [item for item in inventory if (
            (part_key and _normalized_identifier(item.get('part_number')) == part_key)
            or (not part_key and name_key and _normalized_identifier(item.get('name')) == name_key)
        )]
        match_ids = {item['item_id'] for item in matches}
        total_stock = sum(max(0, int(item.get('quantity') or 0)) for item in matches)
        reserved_for_kit = sum(int(reservation['quantity']) for reservation in reservations if (
            reservation['inventory_item_id'] in match_ids and reservation['kit_id'] == kit_id
            and reservation['kit_item_id'] == row.get('id')))
        reserved_elsewhere = sum(int(reservation['quantity']) for reservation in reservations if (
            reservation['inventory_item_id'] in match_ids and reservation['kit_id'] != kit_id))
        unreserved = max(0, total_stock - reserved_for_kit - reserved_elsewhere)
        available = reserved_for_kit + unreserved
        required = int(row['required_quantity'])
        missing = max(0, required - available)
        results.append({
            **row,
            'available_quantity': available,
            'reserved_quantity': reserved_for_kit,
            'unreserved_available_quantity': unreserved,
            'missing_quantity': missing,
            'status': 'ready' if not missing else ('partial' if available else 'missing'),
        })
    ready = sum(row['status'] == 'ready' for row in results)
    partial = sum(row['status'] == 'partial' for row in results)
    missing = sum(row['status'] == 'missing' for row in results)
    return {
        'summary': {
            'total_lines': len(results), 'ready_lines': ready,
            'partial_lines': partial, 'missing_lines': missing,
            'readiness_percent': round(ready * 100 / len(results)) if results else 0,
        },
        'items': results,
    }


def _get_authorized_kit(kit_id: str, user_id: str) -> tuple[dict, bool]:
    client = get_supabase_admin()
    response = client.table('project_kits').select('*').eq('id', kit_id).limit(1).execute()
    if not response.data:
        raise HTTPException(404, 'This project kit no longer exists.')
    kit = response.data[0]
    share_id = kit.get('share_id')
    if share_id:
        try:
            from app.services import sharing_service
            share, can_edit = sharing_service.get_share_access(
                requesting_user_id=user_id, share_id=share_id)
        except ValueError as exc:
            raise HTTPException(403, str(exc)) from exc
        owner_id = (share.get('owner_user_id') or '').strip()
        location = (share.get('share_name') or '').strip()
        if owner_id != kit['owner_user_id'] or location.lower() != kit['location'].lower():
            raise HTTPException(403, 'You no longer have access to this project kit.')
    elif kit['created_by_user_id'] != user_id:
        raise HTTPException(403, 'You do not have access to this project kit.')
    else:
        can_edit = True
    return kit, can_edit


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
    kit, can_edit = _get_authorized_kit(kit_id, user.user_id)
    items = get_supabase_admin().table('project_kit_items').select(
        'id,name,part_number,brand,required_quantity').eq('kit_id', kit_id).execute().data or []
    return {**kit, 'can_reserve': can_edit, **_analyze(rows=items, owner_user_id=kit['owner_user_id'], location=kit['location'], kit_id=kit_id)}


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
    existing = []
    if inventory_ids:
        existing = client.table('project_kit_reservations').select(
            'kit_id,inventory_item_id,quantity').in_('inventory_item_id', inventory_ids).execute().data or []
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
