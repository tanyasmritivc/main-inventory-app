from fastapi import HTTPException

from app.services.supabase_client import get_supabase_raw

PUBLIC_FIELDS = ('id', 'inventory_id', 'scope_type', 'organization_id', 'provider', 'external_account', 'region', 'marketplace',
                 'status', 'scopes', 'last_sync_at', 'last_error', 'created_at', 'updated_at')


def public(connection):
    return {key: connection.get(key) for key in PUBLIC_FIELDS}


def execute(query):
    try:
        return query.execute().data
    except Exception as exc:
        code = getattr(exc, 'code', '')
        if code == '23505':
            raise HTTPException(409, 'This account already has a connection. Disconnect it before reconnecting.') from None
        if code == '42501':
            raise HTTPException(403, 'You no longer have permission for these connections.') from None
        if code == 'P0002':
            raise HTTPException(404, 'Commerce connection not found.') from None
        if code == '40001':
            raise HTTPException(409, 'Connection changed, is busy, or authorization expired. Refresh and try again.') from None
        raise HTTPException(503, 'Commerce storage is unavailable. No success was confirmed.') from None


def authorize(inventory_id, actor):
    from app.api.routes.inventory_workspaces import _inventory
    context = _inventory(str(inventory_id), actor)
    if not context['can_edit']:
        raise HTTPException(403, 'Editing access is required for commerce connections.')


def authorize_scope(scope_type, organization_id, actor):
    if scope_type == 'personal' and organization_id is None:
        return
    if scope_type != 'organization' or not organization_id:
        raise HTTPException(422, 'Choose Personal or an organization.')
    rows = execute(get_supabase_raw().table('app_organization_members').select('role')
                   .eq('organization_id', str(organization_id)).eq('user_id', actor).limit(1)) or []
    if not rows or rows[0]['role'] not in ('owner', 'admin'):
        raise HTTPException(403, 'Organization owner or administrator access is required.')


def connection(connection_id, actor, *, require_access=True):
    rows = execute(get_supabase_raw().table('commerce_connections').select('*')
                   .eq('id', str(connection_id)).limit(1)) or []
    if not rows:
        raise HTTPException(404, 'Commerce connection not found.')
    c = rows[0]
    scope = c.get('scope_type', 'legacy_inventory')
    if scope == 'organization':
        authorize_scope(scope, c.get('organization_id'), actor)
    elif (c.get('owner_user_id') if scope == 'personal' else c.get('actor_id')) != actor:
        raise HTTPException(404, 'Commerce connection not found.')
    elif scope == 'legacy_inventory' and require_access:
        authorize(c['inventory_id'], actor)
    return c


def connections(inventory_id, actor, scope_type='personal', organization_id=None):
    query = get_supabase_raw().table('commerce_connections').select(','.join(PUBLIC_FIELDS))
    if inventory_id:
        authorize(inventory_id, actor)
        query = query.eq('actor_id', actor).eq('inventory_id', str(inventory_id))
    else:
        authorize_scope(scope_type, organization_id, actor)
        query = query.eq('scope_type', scope_type).eq('organization_id', str(organization_id)) if scope_type == 'organization' else query.eq('owner_user_id', actor)
    rows = execute(query.order('created_at').order('id').limit(100)) or []
    return [public(row) for row in rows]


def start_scoped(actor, scope_type, organization_id, provider, account, region, marketplace, state_hash):
    return execute(get_supabase_raw().rpc('findez_commerce_start_scoped', {
        'p_actor': actor, 'p_scope': scope_type, 'p_organization': str(organization_id) if organization_id else None,
        'p_provider': provider, 'p_account': account, 'p_region': region,
        'p_marketplace': marketplace, 'p_state_hash': state_hash}))


def start(actor, inventory_id, provider, account, region, marketplace, state_hash):
    return execute(get_supabase_raw().rpc('findez_commerce_start', {
        'p_actor': actor, 'p_inventory': str(inventory_id), 'p_provider': provider,
        'p_account': account, 'p_region': region, 'p_marketplace': marketplace, 'p_state_hash': state_hash}))


def transition(actor, connection_id, action, payload=None):
    return execute(get_supabase_raw().rpc('findez_commerce_transition', {
        'p_actor': actor, 'p_connection': str(connection_id), 'p_action': action, 'p_payload': payload or {}}))


def records(connection_id, actor, offset, limit):
    c = connection(connection_id, actor)
    rows = execute(get_supabase_raw().table('commerce_source_records').select('kind,external_id,resource,data,observed_at')
                   .eq('connection_id', c['id']).order('kind').order('external_id').range(offset, offset + limit)) or []
    return {'connection': public(c), 'records': rows[:limit],
            'next_offset': offset + limit if len(rows) > limit else None,
            'stock_effect': 'none', 'visibility': 'organization_administrators' if c.get('scope_type') == 'organization' else 'personal_only'}
