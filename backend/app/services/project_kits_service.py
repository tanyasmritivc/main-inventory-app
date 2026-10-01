import re

from fastapi import HTTPException

from app.services.items_repo import list_items
from app.services.supabase_client import get_supabase_admin


def _normalized_identifier(value: object) -> str:
    return re.sub(r'[^a-z0-9]', '', str(value or '').lower())


def _list_reservations() -> list[dict]:
    """Read reservations in bounded pages; never encode a large inventory ID list in a URL."""
    client = get_supabase_admin()
    reservations: list[dict] = []
    page_size = 1000
    offset = 0
    while True:
        page = client.table('project_kit_reservations').select(
            'kit_id,kit_item_id,inventory_item_id,quantity').range(
                offset, offset + page_size - 1).execute().data or []
        reservations.extend(page)
        if len(page) < page_size:
            return reservations
        offset += page_size


def _analyze(*, rows: list[dict], owner_user_id: str, location: str, kit_id: str | None = None) -> dict:
    inventory = [
        item for item in list_items(user_id=owner_user_id)
        if str(item.get('location') or 'Unsorted').strip().lower() == location.strip().lower()
    ]
    inventory_ids = [item['item_id'] for item in inventory]
    inventory_id_set = set(inventory_ids)
    reservations = [reservation for reservation in _list_reservations()
                    if reservation['inventory_item_id'] in inventory_id_set]
    reserved_by_item = {
        item['item_id']: sum(int(reservation['quantity']) for reservation in reservations
                            if reservation['inventory_item_id'] == item['item_id'])
        for item in inventory
    }
    remaining_unreserved = {
        item['item_id']: max(0, int(item.get('quantity') or 0) - reserved_by_item[item['item_id']])
        for item in inventory
    }
    results = []
    for row in rows:
        part_key = _normalized_identifier(row.get('part_number'))
        name_key = _normalized_identifier(row.get('name'))
        matches = [item for item in inventory if (
            (part_key and _normalized_identifier(item.get('part_number')) == part_key)
            or (not part_key and name_key and _normalized_identifier(item.get('name')) == name_key)
        )]
        reserved_for_kit = 0
        for item in matches:
            item_id = item['item_id']
            own = sum(int(reservation['quantity']) for reservation in reservations if (
                reservation['inventory_item_id'] == item_id and reservation['kit_id'] == kit_id
                and reservation['kit_item_id'] == row.get('id')))
            # A later stock reduction must not make an old reservation look like
            # physical stock that still exists.
            reserved_for_kit += min(own, max(0, int(item.get('quantity') or 0) - (reserved_by_item[item_id] - own)))
        unreserved = sum(remaining_unreserved[item['item_id']] for item in matches)
        available = reserved_for_kit + unreserved
        required = int(row['required_quantity'])
        missing = max(0, required - available)
        needed = max(0, required - reserved_for_kit)
        # A physical unit cannot satisfy two requirement rows in the same kit.
        for item in matches:
            item_id = item['item_id']
            take = min(needed, remaining_unreserved[item_id])
            remaining_unreserved[item_id] -= take
            needed -= take
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


def get_project_readiness(*, kit_id: str, user_id: str) -> dict:
    """Use the same authorization and reservation-aware quantities for Ask and kits."""
    kit, can_edit = _get_authorized_kit(kit_id, user_id)
    items = get_supabase_admin().table('project_kit_items').select(
        'id,name,part_number,brand,required_quantity').eq('kit_id', kit_id).execute().data or []
    return {**kit, 'can_reserve': can_edit, **_analyze(
        rows=items, owner_user_id=kit['owner_user_id'], location=kit['location'], kit_id=kit_id)}
