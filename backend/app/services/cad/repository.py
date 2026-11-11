"""Explicitly scoped fresh reads; no new table or stock writer."""

from fastapi import HTTPException
from app.api.routes.inventory_workspaces import _inventory
from app.services.supabase_client import get_supabase_raw
from app.services.inventory_scope import current_inventory


def authorize_inventory(inventory_id: str, actor_id: str):
    scope = current_inventory.get()
    if scope and (scope.actor_id != actor_id or scope.inventory_id != inventory_id
                  or getattr(scope, 'chat_space_id', None)):
        raise HTTPException(403, 'Open CAD from the selected inventory to compare this assembly.')
    _inventory(inventory_id, actor_id)


def read_inventory(inventory_id: str, actor_id: str):
    authorize_inventory(inventory_id, actor_id)
    client = get_supabase_raw()

    def pages(table, fields, primary_key, active=False):
        result = []
        for offset in range(0, 50001, 500):
            query = client.table(table).select(fields).eq('inventory_id', inventory_id)
            if active:
                query = query.eq('is_active', True)
            page = query.order(primary_key).range(offset, offset + 499).execute().data or []
            result.extend(page)
            if len(result) > 50000:
                raise HTTPException(413, 'This inventory exceeds the prototype comparison limit.')
            if len(page) < 500:
                return result
        raise HTTPException(413, 'This inventory exceeds the prototype comparison limit.')

    items = pages('items', 'item_id,name,brand,part_number,barcode,quantity,location', 'item_id')
    reservations = pages('project_kit_reservations', 'id,inventory_item_id,quantity', 'id')
    checkouts = pages('checkouts', 'checkout_id,item_id,quantity', 'checkout_id', active=True)
    # Revocation during paging must not publish results from the earlier grant.
    _inventory(inventory_id, actor_id)
    return items, reservations, checkouts
