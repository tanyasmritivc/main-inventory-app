from fastapi import HTTPException

from app.services.supabase_client import get_supabase_raw

PUBLIC_FIELDS = ('id', 'inventory_id', 'provider', 'external_account', 'region', 'marketplace',
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
            raise HTTPException(403, 'You no longer have permission for this inventory.') from None
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


def connection(connection_id, actor, *, require_access=True):
    rows = execute(get_supabase_raw().table('commerce_connections').select('*')
                   .eq('id', str(connection_id)).eq('actor_id', actor).limit(1)) or []
    if not rows:
        raise HTTPException(404, 'Commerce connection not found.')
    if require_access:
        authorize(rows[0]['inventory_id'], actor)
    return rows[0]


def connections(inventory_id, actor):
    authorize(inventory_id, actor)
    rows = execute(get_supabase_raw().table('commerce_connections').select(','.join(PUBLIC_FIELDS))
                   .eq('actor_id', actor).eq('inventory_id', str(inventory_id)).order('created_at').limit(100)) or []
    return [public(row) for row in rows]


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
            'stock_effect': 'none', 'visibility': 'connecting_actor_only'}
