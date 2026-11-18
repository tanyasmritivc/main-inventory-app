"""World reads canonical inventory and stores only presentation and game metadata."""
from datetime import datetime, timezone
import hashlib
import secrets
from fastapi import HTTPException
from postgrest.exceptions import APIError
from httpx import HTTPError
from storage3.utils import StorageException
from app.services.supabase_client import get_supabase_raw
from app.services import world_rules as rules

ITEM_FIELDS = 'item_id,name,category,quantity,image_url,space_id,bin_id,location,inventory_id,user_id,reorder_enabled,reorder_threshold'


def rpc(name, **params):
    try:
        return get_supabase_raw().rpc(name, params).execute().data
    except APIError as exc:
        messages = {'42501': (403, 'You no longer have permission to do that.'),
                    '23514': (422, 'This World action is not available. Refresh and check its requirements.'),
                    '40001': (409, 'This room changed. Reload before saving again.'),
                    '23503': (409, 'An item or storage area changed. Reload this room.'),
                    '23505': (409, 'This change is already saved. Refresh to see it.')}
        if exc.code in messages:
            code, message = messages[exc.code]
            raise HTTPException(code, message) from None
        raise HTTPException(503, 'World could not confirm this request. Refresh before retrying.') from None


def pages(table, columns='*', **equals):
    client, rows, offset = get_supabase_raw(), [], 0
    while True:
        query = client.table(table).select(columns)
        for k, v in equals.items():
            query = query.eq(k, v)
        # Stable primary-key ordering is supplied for the bounded World tables.
        keys = {'spaces': 'id', 'bins': 'id', 'world_storage_areas': 'id',
                'world_item_places': 'item_id', 'app_organization_members': 'organization_id'}
        if table in keys:
            query = query.order(keys[table])
        batch = query.range(offset, offset + 399).execute().data or []
        rows.extend(batch)
        if len(batch) < 400:
            return rows
        offset += 400


def authorize(actor, space_id, write=False):
    role = rpc('findez_world_space_role', p_actor=actor, p_space=str(space_id))
    if role not in ('owner', 'admin', 'editor', 'viewer'):
        raise HTTPException(404, 'Space not found or access was removed.')
    if write and role not in ('owner', 'admin', 'editor'):
        raise HTTPException(403, 'You have view-only access to this Space.')
    return role


def clean_item(item, bins, areas, placements):
    placement = placements.get(item['item_id'], {})
    area = areas.get(placement.get('area_id'), {})
    bin_row = bins.get(item.get('bin_id'), {})
    threshold = item.get('reorder_threshold')
    return {'id': item['item_id'], 'name': item.get('name') or 'Unnamed item',
            'quantity': item.get('quantity'), 'category': item.get('category'),
            'photo': item.get('image_url'), 'space_id': item['space_id'],
            'location': item.get('location') or '', 'bin_id': bin_row.get('id'),
            'bin': bin_row.get('name'), 'area_id': area.get('id'), 'container': area.get('name'),
            'running_low': bool(item.get('reorder_enabled') and threshold is not None
                                and item.get('quantity') is not None and item['quantity'] <= threshold)}


def room(actor, space, role=None):
    sid = space['id']
    role = role or authorize(actor, sid)
    raw = get_supabase_raw()
    bins = {b['id']: b for b in pages('bins', 'id,space_id,name', space_id=sid)}
    areas = {a['id']: a for a in pages('world_storage_areas', 'id,space_id,name,kind,parent_id', space_id=sid)}
    placements = {p['item_id']: p for p in pages('world_item_places', 'item_id,space_id,area_id', space_id=sid)}
    query = raw.table('items').select(ITEM_FIELDS, count='exact').eq('space_id', sid).eq('inventory_id', space['inventory_id']).order('item_id').limit(400).execute()
    layouts = raw.table('world_layouts').select('layout,revision,updated_at').eq('space_id', sid).limit(1).execute().data or []
    layout = layouts[0] if layouts else {'layout': None, 'revision': 0, 'updated_at': None}
    inventory = raw.table('app_inventories').select('organization_id').eq('inventory_id', space['inventory_id']).limit(1).execute().data or []
    return {'id': sid, 'name': space['name'], 'inventory_id': space['inventory_id'],
            'organization_id': inventory[0]['organization_id'] if inventory else None,
            'can_edit': role in ('owner', 'admin', 'editor'), 'bins': list(bins.values()),
            'storage_areas': list(areas.values()), 'items': [clean_item(i, bins, areas, placements) for i in query.data or []],
            'item_count': query.count if query.count is not None else len(query.data or []),
            'capped': (query.count or 0) > 400, **layout}


def spaces(actor):
    result = []
    # Do not derive rooms from names: the same name can legitimately appear in two organizations.
    for space in pages('spaces', 'id,name,inventory_id'):
        role = rpc('findez_world_space_role', p_actor=actor, p_space=space['id'])
        if role in ('owner', 'admin', 'editor', 'viewer'):
            result.append(room(actor, space, role))
    memberships = pages('app_organization_members', 'organization_id', user_id=actor)
    return {'spaces': result, 'scopes': [m['organization_id'] for m in memberships] or [actor]}


def me(actor):
    raw = get_supabase_raw()
    now = datetime.now(timezone.utc)
    seasons = raw.table('world_seasons').select('*').lte('starts_at', now.isoformat()).gt('ends_at', now.isoformat()).order('starts_at', desc=True).limit(1).execute().data or []
    if not seasons:
        raise HTTPException(503, 'The next World season is being prepared. Please try again later.')
    season = seasons[0]
    records = raw.table('world_progress').select('*').eq('user_id', actor).limit(1).execute().data or []
    progress = records[0] if records else {'lifetime_xp': 0, 'best_level': 1, 'streak': 0, 'tour_done': False}
    rows = raw.table('world_season_xp').select('xp').eq('user_id', actor).eq('season_id', season['id']).limit(1).execute().data or []
    xp = rows[0]['xp'] if rows else 0
    level = rules.level(xp)
    quests = {q['quest_id']: q for q in pages('world_quest_progress', 'quest_id,progress,claimed_at', user_id=actor, season_id=season['id'])}
    streak = progress['streak']
    if progress.get('last_xp_day') and (now.date() - datetime.fromisoformat(progress['last_xp_day']).date()).days > 1:
        streak = 0
    return {'season': season, 'xp': xp, 'level': level,
            'xp_to_next_level': rules.LEVELS[level] - xp if level < len(rules.LEVELS) else 0,
            'lifetime_xp': progress['lifetime_xp'], 'lifetime_rank': 1 + progress['lifetime_xp'] // 500,
            'streak': streak, 'best_level': progress['best_level'], 'tour_done': progress['tour_done'],
            'quests': [{**q, 'progress': min(q['goal'], quests.get(q['id'], {}).get('progress', 0)),
                        'claimed': quests.get(q['id'], {}).get('claimed_at') is not None} for q in rules.QUESTS],
            'unlocks': rules.unlocks(progress['best_level']), 'rules': rules.transaction_rules()}


def award(actor, kind, ref, value=None):
    result = rpc('findez_world_award', p_actor=actor, p_kind=kind, p_ref=str(ref),
                 p_value=value or {}, p_rules=rules.transaction_rules())
    before = rules.unlocks(result.get('previous_best_level', result['level']))
    after = rules.unlocks(result.get('best_level', result['level']))
    result['new_unlocks'] = {key: [x for x in after[key] if x not in before[key]] for key in after}
    return result


def save_layout(actor, space_id, body):
    return rpc('findez_world_save_layout', p_actor=actor, p_space=str(space_id),
               p_revision=body.revision, p_layout=body.layout.model_dump(mode='json'), p_rules=rules.transaction_rules())


def create_area(actor, space_id, body):
    return {'area': rpc('findez_world_area', p_actor=actor, p_space=str(space_id), p_data=body.model_dump(mode='json'))}


def place(actor, item_id, body):
    result = rpc('findez_world_place', p_actor=actor, p_item=str(item_id),
                 p_area=str(body.area_id) if body.area_id else None,
                 p_expected_area=str(body.expected_area_id) if body.expected_area_id else None,
                 p_bin=str(body.bin_id) if body.bin_id else None,
                 p_expected_bin=str(body.expected_bin_id) if body.expected_bin_id else None)
    from app.services.items_repo import invalidate_inventory_cache
    rows = get_supabase_raw().table('items').select('user_id').eq('item_id', str(item_id)).limit(1).execute().data or []
    if rows:
        invalidate_inventory_cache(rows[0]['user_id'])
    return result


def daily(actor, scope_id=None):
    if scope_id is None:
        memberships = pages('app_organization_members', 'organization_id', user_id=actor)
        scope_id = memberships[0]['organization_id'] if memberships else actor
    result = rpc('findez_world_daily', p_actor=actor, p_scope=str(scope_id))
    targets = result.pop('targets')
    items = []
    if targets:
        records = get_supabase_raw().table('items').select('item_id,name,space_id,location').in_('item_id', targets).execute().data or []
        indexed = {r['item_id']: r for r in records}
        for ident in targets:
            item = indexed.get(ident)
            if item and rpc('findez_world_space_role', p_actor=actor, p_space=item['space_id']):
                items.append({'id': ident, 'name': item['name'], 'space_id': item['space_id'], 'location': item['location']})
    return {**result, 'targets': items, 'available': len(items) == 5}


def score(actor, body):
    result = rpc('findez_world_score', p_actor=actor, p_scope=str(body.scope_id), p_seconds=body.seconds, p_rules=rules.transaction_rules())
    before, after = rules.unlocks(result.get('previous_best_level', 1)), rules.unlocks(result.get('best_level', 1))
    return {**result, 'new_unlocks': {k: [v for v in after[k] if v not in before[k]] for k in after}}


def leaderboard(actor, scope_id):
    day = daily(actor, scope_id)
    rows = get_supabase_raw().table('world_daily_scores').select('user_id,seconds').eq('scope_id', day['scope_id']).eq('day', day['day']).order('seconds').order('user_id').limit(20).execute().data or []
    ids = [r['user_id'] for r in rows]
    profiles = get_supabase_raw().table('profiles').select('id,first_name').in_('id', ids).execute().data if ids else []
    names = {p['id']: (p.get('first_name') or 'Player').split()[0][:40] for p in profiles or []}
    return {'day': day['day'], 'scores': [{'name': names.get(r['user_id'], 'Player'), 'seconds': r['seconds'], 'you': r['user_id'] == actor} for r in rows]}


def share_create(actor, body):
    return {'share': rpc('findez_world_share', p_actor=actor, p_id=str(body.request_id),
                         p_space=str(body.space_id), p_token=secrets.token_urlsafe(24), p_patch=None)}


def shares(actor, space_id):
    authorize(actor, str(space_id), True)
    return {'shares': pages('world_shares', 'id,space_id,token,created_at,revoked_at,show_counts,show_locations,show_photos', space_id=str(space_id))}


def share_patch(actor, ident, body):
    return {'share': rpc('findez_world_share', p_actor=actor, p_id=str(ident),
                         p_space=None, p_token=None, p_patch=body.model_dump(exclude_none=True))}


def public_room(token):
    if not 22 <= len(token) <= 64 or not all(c.isascii() and (c.isalnum() or c in '-_') for c in token):
        raise HTTPException(404, 'Shared room not found.')
    raw = get_supabase_raw()
    rows = raw.table('world_shares').select('*').eq('token', token).is_('revoked_at', 'null').limit(1).execute().data or []
    if not rows:
        raise HTTPException(404, 'Shared room not found.')
    share = rows[0]
    role = rpc('findez_world_space_role', p_actor=share['created_by'], p_space=share['space_id'])
    if role not in ('owner', 'admin', 'editor'):
        raise HTTPException(404, 'Shared room not found.')
    rows = raw.table('spaces').select('id,name,inventory_id').eq('id', share['space_id']).limit(1).execute().data or []
    if not rows:
        raise HTTPException(404, 'Shared room not found.')
    data = room(share['created_by'], rows[0], role)
    return public_projection(data, share)


def public_projection(data, share):
    def opaque(value):
        return hashlib.sha256((share['token'] + ':' + value).encode()).hexdigest()[:24]
    layout = data['layout'] or {'v': 2, 'floor': 0, 'pieces': [], 'places': {}}
    projected = {'v': 2, 'floor': layout['floor'],
                 'pieces': [{k: p[k] for k in ('t', 'x', 'z', 'r', 'y') if k in p} for p in layout['pieces']],
                 'places': {opaque(k): v for k, v in layout['places'].items()}}
    result = {'name': data['name'] if share['show_locations'] else 'Shared space', 'layout': projected,
              'items': [], 'storage': [], 'capped': data['capped'],
              'show_counts': share['show_counts'], 'show_locations': share['show_locations'], 'show_photos': share['show_photos']}
    # Preserve storage geometry without disclosing canonical IDs or private names.
    for prefix, records in (('bin', data.get('bins', [])), ('area', data.get('storage_areas', []))):
        for storage in records:
            key = prefix + ':' + storage['id']
            if key not in layout['places']:
                continue
            public_storage = {'id': opaque(key), 'kind': 'bin' if prefix == 'bin' else storage['kind']}
            if share['show_locations']:
                public_storage['name'] = storage['name']
            result['storage'].append(public_storage)
    for item in data['items']:
        public = {'id': opaque('item:' + item['id']), 'name': item['name']}
        if share['show_counts']:
            public.update(quantity=item['quantity'], running_low=item['running_low'])
        if share['show_locations']:
            public.update(location=item['location'], bin=item['bin'], container=item['container'])
        if share['show_photos'] and item['photo']:
            # Only sign known private bucket paths, never arbitrary client URLs.
            from app.core.config import get_settings
            from urllib.parse import urlparse
            image = str(item['photo'])
            marker = '/object/'
            parsed = urlparse(image)
            settings = get_settings()
            trusted_hosts = {urlparse(str(settings.supabase_url)).netloc,
                             urlparse(str(settings.supabase_public_url or settings.supabase_url)).netloc}
            if parsed.scheme in ('https', 'http') and parsed.netloc in trusted_hosts and marker in parsed.path:
                chunks = parsed.path.split(marker, 1)[1].split('/', 2)
                if len(chunks) == 3 and chunks[1] == settings.supabase_storage_bucket:
                    from app.api.routes.private_images import safe_image_path
                    try:
                        path = safe_image_path(chunks[2])
                        allowed = rpc('findez_can_read_item_image', p_actor=share['created_by'], p_path=path)
                        if allowed is True:
                            signed = get_supabase_raw().storage.from_(settings.supabase_storage_bucket).create_signed_url(path, 60)
                            url = signed.get('signedURL') or signed.get('signedUrl')
                            if url:
                                from app.services.storage import _external_storage_url
                                public['photo'] = _external_storage_url(url, settings.supabase_public_url)
                    except (HTTPException, ValueError, StorageException, HTTPError):
                        pass
        result['items'].append(public)
    return result
