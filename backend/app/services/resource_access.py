"""Additional inventory restrictions for all authenticated application paths.

Original owner/share checks remain in place. This layer only narrows them; it
never turns a workspace or organization membership into global data access.
"""
from contextvars import ContextVar
from dataclasses import dataclass
import hashlib
import json

from fastapi import HTTPException


@dataclass
class ActorAccess:
    actor_id: str
    fences: list | None = None


request_actor: ContextVar[ActorAccess | None] = ContextVar('inventory_actor', default=None)


def begin_actor(actor_id):
    request_actor.set(ActorAccess(actor_id))


def fences(raw):
    state = request_actor.get()
    if state is None:
        return []
    if state.fences is None:
        result = raw.rpc('findez_inventory_fences', {'p_actor': state.actor_id}).execute().data
        if not isinstance(result, list):
            raise HTTPException(503, 'Inventory permissions could not be verified. Try again.')
        state.fences = result
    return state.fences


def inventory_can_write(inventory_id):
    if not inventory_id or request_actor.get() is None:
        return True
    from app.services.supabase_client import get_supabase_raw
    return all(row['role'] in ('owner', 'admin', 'editor')
               for row in fences(get_supabase_raw()) if row['inventory_id'] == inventory_id)


def require_inventory_write(inventory_id):
    if not inventory_can_write(inventory_id):
        raise HTTPException(403, 'You have view-only access to this inventory.')


def access_cache_key(raw):
    state = request_actor.get()
    if state is None:
        return ''
    digest = hashlib.sha256(json.dumps(fences(raw), sort_keys=True).encode()).hexdigest()[:20]
    return f'{state.actor_id}:{digest}:'


# Rows with an inventory_id; existing routes retain their normal owner filters.
RESOURCE_TABLES = frozenset(('items','spaces','bins','documents','activity_log','capture_reviews',
 'conversations','messages','checkouts','item_events','project_kits','project_kit_items',
 'project_kit_reservations','conversation_history','query_logs','inventory_user_memory',
 'inventory_conversation_sessions','team_shares','app_inventory_space_summaries'))
PRIVATE_WRITES = frozenset(('conversations','messages','conversation_history','query_logs',
 'inventory_user_memory','inventory_conversation_sessions','activity_log'))


class AccessQuery:
    def __init__(self, raw, query, table=None):
        self.raw,self.query,self.table = raw,query,table
        self.operation = None

    @property
    def headers(self):
        # Metadata is not a fluent query builder. Returning this wrapper here
        # corrupts the query when callers copy request-local actor headers.
        return self.query.headers

    @headers.setter
    def headers(self, value):
        self.query.headers = value

    def __getattr__(self, name):
        value = getattr(self.query, name)
        if not callable(value):
            self.query = value
            return self
        def chain(*args, **kwargs):
            self.query = value(*args, **kwargs)
            if name in ('select','update','delete','insert','upsert'):
                self.operation = name
                if self.table == 'conversations' and name in ('select', 'update', 'delete'):
                    # Organization Chat uses its own actor+world checked routes.
                    self.query = self.query.is_('world_key', 'null')
                if self.table in RESOURCE_TABLES and name in ('select','update','delete'):
                    write = name != 'select' and self.table not in PRIVATE_WRITES
                    excluded = [row['inventory_id'] for row in fences(self.raw)
                                if row['role'] is None or (write and row['role'] not in ('owner','admin','editor'))]
                    if excluded:
                        self.query = self.query.not_.in_('inventory_id', excluded)
            if self.table == 'team_activity' and name == 'select':
                # Legacy notifications contain human-readable item summaries.
                # Hide workspace-wide summaries when access is narrower.
                teams = list({r['team_id'] for r in fences(self.raw) if r['role'] is None and r.get('team_id')})
                if teams:
                    self.query = self.query.not_.in_('team_id', teams)
            return self
        return chain

    def execute(self):
        state = request_actor.get()
        # Headers belong to this query, never mutate a shared client's headers.
        # The database trusts this identity only on service-role requests.
        if state is not None:
            self.query.headers = {**self.query.headers, 'x-findez-actor': state.actor_id}
        return self.query.execute()


class AccessClient:
    def __init__(self, raw): self.raw = raw
    def __getattr__(self, name): return getattr(self.raw, name)
    def table(self, name): return AccessQuery(self.raw, self.raw.table(name), name)
    def rpc(self, name, params): return AccessQuery(self.raw, self.raw.rpc(name, params))


def guarded_client(raw):
    return AccessClient(raw) if request_actor.get() else raw
