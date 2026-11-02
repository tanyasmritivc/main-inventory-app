"""Explicit inventory creation backed by an atomic, repeatable database result."""
from fastapi import HTTPException
from postgrest.exceptions import APIError

from app.services.inventory_scope import current_inventory
from app.services.limits import resolve_effective_limits
from app.services.supabase_client import get_supabase_raw


def create_selected_space(name: str) -> dict:
    scope = current_inventory.get()
    if scope is None:
        raise HTTPException(422, 'Select an inventory before creating a Space.')
    if not scope.can_edit:
        raise HTTPException(403, 'You have view-only access to this inventory.')
    name = name.strip()
    if not 1 <= len(name) <= 100:
        raise HTTPException(422, 'Use a Space name between 1 and 100 characters.')
    limits, _ = resolve_effective_limits(scope.owner_id)
    try:
        result = get_supabase_raw().rpc('findez_get_or_create_inventory_space', {
            'p_actor': scope.actor_id, 'p_inventory': scope.inventory_id,
            'p_name': name, 'p_limit': limits['spaces'],
        }).execute().data
    except APIError as exc:
        if exc.code == '42501':
            raise HTTPException(403, 'You no longer have permission to create Spaces here.') from None
        if exc.code == '23514' and 'space_limit_reached' in str(exc):
            raise HTTPException(409, 'The Space allowance for this inventory owner has been reached.') from None
        raise HTTPException(503, 'The Space could not be confirmed saved. Retry with the same name.') from None
    if (not isinstance(result, dict) or not result.get('id') or result.get('confirmed') is not True
            or result.get('inventory_id') != scope.inventory_id
            or str(result.get('name', '')).casefold() != name.casefold()):
        raise HTTPException(503, 'The Space could not be confirmed saved. Retry with the same name.')
    return result
