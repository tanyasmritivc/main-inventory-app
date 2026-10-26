"""Account-owned explicit preferences, independent of effective inventory owner.

Only this service accesses account memory without inventory table aliasing. Every
read carries the authenticated actor; every mutation is a serialized DB function.
"""
import hashlib
import json
import logging
import re
from fastapi import HTTPException
from postgrest.exceptions import APIError
from app.schemas.memory import MemoryChange
from app.services.supabase_client import get_supabase_raw

logger = logging.getLogger(__name__)
COLUMNS = 'key,value,memory_kind,payload,revision,confirmed_at,updated_at,source_operation_id'


def actor_id(user):
    return user.actor_id or user.user_id


def _inventory(inventory_id, actor):
    from app.api.routes.inventory_workspaces import _inventory as authorize
    return authorize(str(inventory_id), actor)


def _rows(client, table, actor, inventory=None):
    query = client.table(table).select(COLUMNS).eq('user_id', actor)
    if inventory:
        query = query.eq('inventory_id', str(inventory))
    return query.order('key').limit(101).execute().data or []


def snapshot(actor, inventory=None):
    if inventory:
        _inventory(inventory, actor)
    try:
        client = get_supabase_raw()
        before = client.table('user_memory').select(COLUMNS).eq('user_id', actor).eq('key', '__settings_v1').limit(1).execute().data or []
        rows = _rows(client, 'user_memory', actor)
        control = next((r for r in rows if r['key'] == '__settings_v1' and r.get('memory_kind') == 'settings'), None)
        # Settings must not disappear behind legacy rows or a bounded page.
        controls = client.table('user_memory').select(COLUMNS).eq('user_id', actor).eq('key', '__settings_v1').limit(1).execute().data or []
        control = controls[0] if controls and controls[0].get('memory_kind') == 'settings' else control
        aliases = _rows(client, 'inventory_user_memory', actor, inventory) if inventory else []
        if inventory:
            active = client.table('inventory_user_memory').select(COLUMNS).eq('user_id', actor).eq('inventory_id', str(inventory)).eq('memory_kind', 'alias').limit(50).execute().data or []
            aliases = [r for r in aliases if r.get('memory_kind') != 'alias'] + active
        entries = []
        for row in rows + aliases:
            if row.get('memory_kind') not in ('preference', 'alias') or not row.get('confirmed_at'):
                continue
            payload = row.get('payload') or {}
            if row.get('memory_kind') == 'preference' and row['key'] not in ('answer_length', 'answer_format'):
                continue
            entries.append({'key': row['key'], 'kind': row['memory_kind'], 'payload': payload,
                            'revision': row['revision'], 'confirmed_at': row['confirmed_at'],
                            'source': 'Explicitly saved by you'})
        # Avoid letting historical key counts hide the two supported preferences.
        for key in ('answer_length', 'answer_format'):
            if any(e['key'] == key for e in entries):
                continue
            exact = client.table('user_memory').select(COLUMNS).eq('user_id', actor).eq('key', key).limit(1).execute().data or []
            if exact and exact[0].get('memory_kind') == 'preference' and exact[0].get('confirmed_at'):
                row = exact[0]
                entries.append({'key': key, 'kind': 'preference', 'payload': row['payload'], 'revision': row['revision'],
                                'confirmed_at': row['confirmed_at'], 'source': 'Explicitly saved by you'})
        legacy = [{'key': str(r['key'])[:100], 'value': str(r.get('value') or '')[:500], 'state': 'Unverified; not used for personalization'}
                  for r in rows + aliases if r.get('memory_kind') == 'legacy']
        after = client.table('user_memory').select(COLUMNS).eq('user_id', actor).eq('key', '__settings_v1').limit(1).execute().data or []
        if (before[0].get('revision', 0) if before else 0) != (after[0].get('revision', 0) if after else 0):
            raise HTTPException(409, 'Memory changed while loading. Refresh before trying again.')
        settings = (control.get('payload') or {}) if control else {}
        return {'available': True, 'enabled': settings.get('enabled', True) is True,
                'revision': control.get('revision', 0) if control else 0,
                'generation': settings.get('generation', 0), 'entries': entries,
                'legacy': legacy, 'legacy_truncated': len(rows) == 101 or len(aliases) == 101}
    except HTTPException:
        raise
    except Exception:
        logger.warning('Account memory read unavailable')
        raise HTTPException(503, 'Memory is not available yet. Please try again later.') from None


def change(actor, command: MemoryChange):
    if command.inventory_id:
        _inventory(command.inventory_id, actor)
    body = command.model_dump(mode='json')
    digest = hashlib.sha256(json.dumps(body, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    key = command.key
    payload = {}
    if command.action == 'settings':
        payload = {'enabled': command.enabled}
    elif command.inventory_id:
        key = 'alias:' + hashlib.sha256(command.alias.encode()).hexdigest()
        if command.action == 'set':
            payload = {'alias': command.alias, 'space_id': str(command.space_id)}
    elif command.action == 'set':
        payload = {'value': command.value}
    try:
        result = get_supabase_raw().rpc('findez_change_memory', {
            'p_actor': actor, 'p_operation': str(command.operation_id), 'p_digest': digest,
            'p_expected': command.expected_revision, 'p_action': command.action,
            'p_key': key, 'p_payload': payload,
            'p_inventory': str(command.inventory_id) if command.inventory_id else None,
        }).execute().data
        if not isinstance(result, dict) or result.get('saved') is not True:
            raise HTTPException(503, 'The memory change was not confirmed. Retry the same request.')
        return result
    except APIError as exc:
        if exc.code in ('40001', '23505'):
            raise HTTPException(409, 'Memory changed or this request was already used. Refresh before trying again.') from None
        if exc.code == '42501':
            raise HTTPException(403, 'You do not have access to that memory or location.') from None
        if exc.code in ('23514', '22023', '22P02'):
            raise HTTPException(422, 'Enable memory and choose a supported preference or saved location.') from None
        raise HTTPException(503, 'The memory change could not be confirmed. Retry the same request.') from None
    except HTTPException:
        raise
    except Exception:
        logger.warning('Account memory write outcome unavailable')
        raise HTTPException(503, 'The memory change could not be confirmed. Retry the same request.') from None


def _export_memory(actor):
    """Bounded, explicit export; includes only currently authorized private aliases."""
    result = snapshot(actor)
    client = get_supabase_raw()
    aliases = client.table('inventory_user_memory').select('inventory_id,' + COLUMNS).eq('user_id', actor).order('inventory_id').order('key').limit(501).execute().data or []
    allowed = []
    for inventory in sorted({row['inventory_id'] for row in aliases}):
        try:
            _inventory(inventory, actor)
        except HTTPException as exc:
            if exc.status_code in (403, 404):
                continue
            raise
        allowed.extend([{**row, 'value': str(row.get('value') or '')[:500]} for row in aliases if row['inventory_id'] == inventory])
    # Remove historical URLs, including expiring tokens, from downloadable data.
    def scrub(value):
        if isinstance(value, str): return re.sub(r'https?://[^\s]+', '[URL omitted]', value)
        if isinstance(value, list): return [scrub(v) for v in value]
        if isinstance(value, dict): return {k: scrub(v) for k, v in value.items() if k != 'user_id'}
        return value
    return scrub({'schema_version': 1, 'memory': result, 'inventory_memory': allowed,
            'partial': result['legacy_truncated'] or len(aliases) == 501})


def export_memory(actor):
    try:
        return _export_memory(actor)
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(503, 'Memory could not be exported. Please try again.') from None
