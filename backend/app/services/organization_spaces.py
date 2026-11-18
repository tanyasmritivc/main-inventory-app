"""Two-level organisation/Space API, preserving legacy storage identities."""
from uuid import UUID
from fastapi import HTTPException
from postgrest.exceptions import APIError
from app.services.supabase_client import get_supabase_raw


def organization_id(actor, world):
    if world == 'personal':
        value = get_supabase_raw().rpc('findez_ensure_personal_organization', {'p_actor': actor}).execute().data
        if not isinstance(value, str):
            raise HTTPException(503, 'Your organisation could not be verified.')
        return str(UUID(value))
    return str(UUID(world))


def directory(actor, world):
    from app.api.routes.collaboration import organization
    from app.api.routes.inventory_workspaces import _inventory
    org_id = organization_id(actor, world)
    org = organization(org_id, actor)
    raw = get_supabase_raw()
    rows, offset = [], 0
    while True:
        batch = raw.table('app_inventories').select('inventory_id').eq('organization_id', org_id).order('inventory_id').range(offset, offset + 99).execute().data or []
        rows.extend(batch)
        if len(batch) < 100:
            break
        offset += len(batch)
    inventories = []
    for candidate in rows:
        inv = _inventory(candidate['inventory_id'], actor)
        total = raw.table('items').select('item_id', count='exact', head=True).eq('inventory_id', inv['inventory_id']).execute().count
        inventories.append({'inventory_id': inv['inventory_id'], 'name': inv['name'],
                            'workspace_id': inv.get('team_id') or 'personal',
                            'workspace_name': org['name'], 'organization_id': org_id,
                            'role': inv['role'], 'can_edit': inv['can_edit'], 'item_count': total or 0})
    return {'world': world, 'organization': org, 'hierarchy': 'organization_spaces',
            'inventories': inventories, 'workspaces': [],
            'can_create_space': org['role'] in ('owner', 'admin') or any(i['can_edit'] for i in inventories),
            'has_items': any(i['item_count'] for i in inventories)}


def create_space(actor, world, name):
    from app.api.routes.collaboration import organization
    org_id = organization_id(actor, world)
    organization(org_id, actor)
    limits = space_limits(actor, world)
    try:
        saved = get_supabase_raw().rpc('findez_create_organization_space', {
            'p_actor': actor, 'p_organization': org_id, 'p_name': name.strip(), 'p_space_limits': limits,
        }).execute().data
    except APIError as exc:
        if exc.code == '42501':
            raise HTTPException(403, 'You have view-only access to this organisation.') from None
        if exc.code == '23514':
            raise HTTPException(409, 'Your Space limit was reached. Review your plan before creating another Space.') from None
        if exc.code == '23505':
            raise HTTPException(409, 'A Space with this name already exists in this organisation.') from None
        raise
    if not isinstance(saved, dict) or not saved.get('id') or saved.get('organization_id') != org_id:
        raise HTTPException(503, 'Saving could not be confirmed. Refresh Spaces before trying again.')
    return {'space': saved}


def owner_limits(actor, world):
    from app.services.limits import resolve_effective_limits
    known = directory(actor, world)
    owners = {known['organization']['owner_user_id']}
    ids = [i['inventory_id'] for i in known['inventories']]
    if ids:
        owners.update(row['owner_user_id'] for row in get_supabase_raw().table('app_inventories').select('owner_user_id').in_('inventory_id', ids).execute().data or [])
    return {owner: resolve_effective_limits(owner)[0] for owner in owners}


def space_limits(actor, world):
    return {owner: limits.get('spaces') for owner, limits in owner_limits(actor, world).items()}
