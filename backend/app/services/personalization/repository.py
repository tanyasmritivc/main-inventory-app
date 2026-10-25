"""Actor-owned storage. Optional reads fail closed, explicit writes fail visibly."""
import hashlib
import json
import logging
from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4
from fastapi import HTTPException
from postgrest.exceptions import APIError
from app.services.supabase_client import get_supabase_raw
from app.services.personalization.scoring import interest_scores
from app.schemas.personalization import ActivityEvent, EventType

log = logging.getLogger(__name__)


def _actor(actor):
    return str(UUID(str(actor)))


def authorize_inventory(actor, inventory):
    from app.services.account_memory import _inventory
    return _inventory(str(inventory), _actor(actor))


def profile(actor):
    actor = _actor(actor)
    client = get_supabase_raw()
    rows = client.table('personalization_profiles').select('*').eq('user_id', actor).limit(1).execute().data or []
    row = rows[0] if rows else {'enabled': False, 'revision': 0, 'generation': 0, 'categories': [],
        'timezone': 'UTC', 'quiet_start': 1260, 'quiet_end': 540, 'daily_cap': 1, 'weekly_cap': 3}
    master = client.rpc('findez_personalization_enabled', {'p_actor': actor}).execute().data is True
    return {k: v for k, v in {**row, 'effective_enabled': master}.items() if k != 'user_id'}


def read(actor, inventory=None):
    if inventory: authorize_inventory(actor, inventory)
    try:
        p = profile(actor)
        result = {'profile': p, 'aliases': [], 'interests': [], 'retention_days': 90}
        if inventory and p['effective_enabled']:
            aliases, scores = signals(actor, inventory)
            result['aliases'] = aliases
            result['interests'] = [{'item_id': k, 'score': round(v, 3), 'provenance': 'inferred',
                'reason': 'recency-weighted completed inventory activity', 'half_life_days': 14}
                for k, v in sorted(scores.items(), key=lambda e:e[1], reverse=True)[:20] if v>0]
        return result
    except HTTPException: raise
    except Exception:
        raise HTTPException(503, 'Personalization is unavailable. Please try again.') from None


def change(actor, command, action):
    from app.schemas.personalization import AliasChange
    if isinstance(command, AliasChange): authorize_inventory(actor, command.inventory_id)
    data = command.model_dump(mode='json', exclude={'operation_id', 'expected_revision'})
    digest = hashlib.sha256(json.dumps({'action': action, 'data': data}, sort_keys=True).encode()).hexdigest()
    try:
        result = get_supabase_raw().rpc('findez_personalization_change', {
            'p_actor': _actor(actor), 'p_operation': str(command.operation_id), 'p_digest': digest,
            'p_expected': command.expected_revision, 'p_action': action, 'p_data': data,
        }).execute().data
        if not isinstance(result, dict) or result.get('saved') is not True:
            raise HTTPException(503, 'Save was not confirmed. Retry the same request.')
        return result
    except APIError as e:
        code = 409 if e.code in ('40001','23505') else 403 if e.code=='42501' else 422 if e.code in ('23514','22023','22P02','23502') else 503
        raise HTTPException(code, 'Refresh personalization and check your selections before retrying.') from None
    except HTTPException: raise
    except Exception:
        raise HTTPException(503, 'Save was not confirmed. Retry the same request.') from None


def signals(actor, inventory):
    """Caller must have established inventory authorization; no shared/global cache."""
    client = get_supabase_raw()
    aliases = client.table('personalization_aliases').select('alias,item_id,confirmed_at').eq('user_id',actor).eq('inventory_id',str(inventory)).limit(100).execute().data or []
    cutoff = (datetime.now(timezone.utc)-timedelta(days=90)).isoformat()
    events = client.table('personalization_events').select('event_type,entity_type,entity_id,occurred_at,source').eq('user_id',actor).eq('inventory_id',str(inventory)).gte('occurred_at',cutoff).order('occurred_at',desc=True).limit(512).execute().data or []
    return aliases, interest_scores(events)


def search_context():
    from app.services.inventory_scope import current_inventory
    from app.services.personalization.transport import client
    scope = current_inventory.get()
    if not scope: return None
    try:
        data = client().rpc('findez_personalization_context', {
            'p_actor': scope.actor_id, 'p_inventory': scope.inventory_id}).execute().data
        if not isinstance(data, dict): return None
        return {'actor':scope.actor_id, 'inventory':scope.inventory_id, 'generation':data['generation'],
            'aliases':data['aliases'], 'scores':interest_scores(data['events'])}
    except Exception:
        log.info('personalization_read_unavailable')
        return None


def record_search(context, query, rows):
    from app.services.personalization.transport import submit
    if context and query.strip():
        # Copy the minimal result now: worker must not read request-local auth context.
        submit(_record_search, dict(context), str(query), [{'item_id': r.get('item_id')} for r in rows])


def _record_search(context, query, rows):
    """Only called after the authorized search succeeded. No raw queries or notes."""
    if not context or not query.strip(): return
    try:
        from app.services.personalization.transport import client as bounded_client
        client = bounded_client()
        key = str(uuid4())
        digest = hashlib.sha256((context['actor']+'\0'+query.casefold().strip()).encode()).hexdigest()
        events = [('inventory.search_performed', None), ('inventory.search_succeeded' if rows else 'inventory.search_failed', rows[0].get('item_id') if len(rows)==1 else None)]
        for index,(kind,item) in enumerate(events):
            # The closed model validates the complete event before any transport.
            event = ActivityEvent(id=uuid4(),user_id=context['actor'],event_type=kind,
                occurred_at=datetime.now(timezone.utc),source='search',inventory_id=context['inventory'],
                entity_type='item' if item else None,entity_id=item,payload={'count':min(len(rows),1000000),'query_hash':digest})
            client.rpc('findez_personalization_event', {'p_actor':str(event.user_id), 'p_generation':context['generation'],
                'p_key':key+':'+str(index), 'p_type':event.event_type.value,'p_inventory':str(event.inventory_id),
                'p_entity_type':event.entity_type,'p_entity':str(event.entity_id) if event.entity_id else None,
                'p_payload':event.payload.model_dump(exclude_none=True),'p_source':'search'}).execute()
    except Exception:
        log.info('personalization_event_unavailable')
