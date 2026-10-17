"""Request-local inventory boundary for the new web inventory routes.

Legacy mobile and integration routes keep their existing clients/contracts.
Only an authorized inventory dependency can install this context. Inventory
queries then carry an independent inventory filter even when legacy services
also filter by their former personal owner. Account/catalog tables stay global.
"""

from contextvars import ContextVar
from dataclasses import dataclass

from fastapi import HTTPException


@dataclass(frozen=True)
class InventoryScope:
    inventory_id: str
    actor_id: str
    owner_id: str
    team_id: str | None
    role: str

    @property
    def can_edit(self):
        return self.role in ('owner', 'admin', 'editor', 'mentor', 'member')


current_inventory: ContextVar[InventoryScope | None] = ContextVar('findez_inventory', default=None)


def inventory_cache_key(user_id: str) -> str:
    scope = current_inventory.get()
    from app.services.resource_access import access_cache_key, request_actor
    from app.services.supabase_client import get_supabase_raw
    prefix = access_cache_key(get_supabase_raw()) if request_actor.get() else ""
    return prefix + (f'{scope.inventory_id}:{scope.actor_id}:{user_id}' if scope else user_id)


TABLES = frozenset((
    'items', 'spaces', 'bins', 'documents', 'activity_log', 'capture_reviews',
    'conversations', 'messages', 'checkouts', 'item_events', 'project_kits',
    'project_kit_items', 'project_kit_reservations', 'conversation_history', 'query_logs',
    'user_memory', 'conversation_sessions', 'team_shares',
))
PRIVATE = frozenset(('conversations', 'messages', 'conversation_history', 'query_logs', 'user_memory', 'conversation_sessions'))
PRIVATE_LEGACY = frozenset(('documents', 'capture_reviews'))
ALIASES = {'user_memory': 'inventory_user_memory', 'conversation_sessions': 'inventory_conversation_sessions'}
PARENTS = {
    'items': {'space_id': ('spaces', 'id'), 'bin_id': ('bins', 'id')},
    'bins': {'space_id': ('spaces', 'id')},
    'documents': {'item_id': ('items', 'item_id')},
    'item_events': {'item_id': ('items', 'item_id')},
    'capture_reviews': {'space_id': ('spaces', 'id'), 'resolved_item_id': ('items', 'item_id')},
    'checkouts': {'item_id': ('items', 'item_id')},
    'messages': {'conversation_id': ('conversations', 'id')},
    'team_shares': {'space_id': ('spaces', 'id')},
    'project_kit_items': {'kit_id': ('project_kits', 'id')},
    'project_kit_reservations': {'kit_id': ('project_kits', 'id'), 'kit_item_id': ('project_kit_items', 'id'), 'inventory_item_id': ('items', 'item_id')},
}
OWNERSHIP_FIELDS = frozenset(('user_id', 'owner_user_id', 'created_by_user_id'))
USAGE_RPCS = frozenset((
    'increment_usage_count', 'increment_chat_usage', 'increment_scan_usage',
    'increment_team_chat_usage', 'increment_team_scan_usage', 'increment_team_import_usage',
))
CATALOG_RPCS = frozenset(('findez_save_community_catalog', 'findez_link_verified_barcode_alias'))


class InventoryClient:
    def __init__(self, raw, scope: InventoryScope):
        self.raw, self.scope = raw, scope

    def __getattr__(self, name):
        return getattr(self.raw, name)

    def require_editor(self, table):
        if not self.scope.can_edit and table not in PRIVATE and table != 'activity_log':
            raise HTTPException(403, 'You have view-only access to this inventory.')

    def record(self, table, key, value):
        query = self.raw.table(ALIASES.get(table, table)).select('*').eq(key, value).eq('inventory_id', self.scope.inventory_id)
        if table in PRIVATE and table != 'messages':
            query = query.eq('user_id', self.scope.actor_id)
        if table in PRIVATE_LEGACY:
            query = query.or_(f'inventory_visibility.eq.inventory,user_id.eq.{self.scope.actor_id}')
        rows = query.limit(1).execute().data or []
        if not rows:
            raise HTTPException(404, 'This record is not in the selected inventory.')
        return rows[0]

    def table(self, name):
        if name not in TABLES:
            return self.raw.table(name)
        return InventoryQuery(self, name, self.raw.table(ALIASES.get(name, name)))

    def rpc(self, name, params):
        params = dict(params)
        if name in USAGE_RPCS or name in CATALOG_RPCS:
            # Catalog transactions own global provenance checks, independently
            # of the selected inventory. No other global RPC is permitted here.
            return self.raw.rpc(name, params)
        self.require_editor('items')
        if name == 'resolve_capture_review':
            review = self.record('capture_reviews', 'review_id', params['p_review_id'])
            params['p_user_id'] = review['user_id']
            if params.get('p_space_id'):
                self.record('spaces', 'id', params['p_space_id'])
        elif name == 'replace_project_kit_reservations':
            self.record('project_kits', 'id', params['p_kit_id'])
            params['p_actor_user_id'] = self.scope.actor_id
            for allocation in params.get('p_allocations', []):
                line = self.record('project_kit_items', 'id', allocation['kit_item_id'])
                if line['kit_id'] != params['p_kit_id']:
                    raise HTTPException(422, 'Choose an item from this project kit.')
                self.record('items', 'item_id', allocation['inventory_item_id'])
        else:
            raise HTTPException(400, 'This operation is unavailable in an inventory.')
        return self.raw.rpc(name, params)


class InventoryQuery:
    def __init__(self, client: InventoryClient, table, query):
        self.client, self.table, self.query = client, table, query
        self.conversation_id = None
        self.operation = None

    def _prepare(self, row):
        row = dict(row)
        scope = self.client.scope
        if row.get('inventory_id', scope.inventory_id) != scope.inventory_id:
            raise HTTPException(422, 'Choose the current inventory.')
        row['inventory_id'] = scope.inventory_id
        if self.operation in ('insert', 'upsert') and self.table in PRIVATE_LEGACY:
            row['inventory_visibility'] = 'inventory'
        if self.table == 'capture_reviews' and row.get('source_key'):
            row['source_key'] = self._source_key(row['source_key'])
        if self.table in PRIVATE and 'user_id' in row:
            row['user_id'] = scope.actor_id
        if self.table == 'activity_log':
            row['metadata'] = {**(row.get('metadata') or {}), 'actor_id': scope.actor_id}
        for field, (parent, key) in PARENTS.get(self.table, {}).items():
            if row.get(field):
                self.client.record(parent, key, row[field])
        return row

    def _source_key(self, key):
        prefix = f'inventory:{self.client.scope.inventory_id}:'
        return key if key.startswith(prefix) else prefix + key

    def select(self, *args, **kwargs):
        self.operation = 'select'
        if args and isinstance(args[0], str) and '*' not in args[0]:
            extra = ['inventory_id']
            if self.table in PRIVATE_LEGACY:
                extra += ['inventory_visibility']
            fields = args[0].split(',')
            args = (args[0] + ''.join(',' + field for field in extra if field not in fields), *args[1:])
        self.query = self.query.select(*args, **kwargs).eq('inventory_id', self.client.scope.inventory_id)
        if self.table in PRIVATE and self.table != 'messages':
            self.query = self.query.eq('user_id', self.client.scope.actor_id)
        if self.table in PRIVATE_LEGACY:
            self.query = self.query.or_(f'inventory_visibility.eq.inventory,user_id.eq.{self.client.scope.actor_id}')
        return self

    def insert(self, data, **kwargs):
        self.client.require_editor(self.table)
        self.operation = 'insert'
        prepared = [self._prepare(row) for row in data] if isinstance(data, list) else self._prepare(data)
        self.query = self.query.insert(prepared, **kwargs)
        return self

    def upsert(self, data, **kwargs):
        self.client.require_editor(self.table)
        self.operation = 'upsert'
        prepared = [self._prepare(row) for row in data] if isinstance(data, list) else self._prepare(data)
        if self.table in ('capture_reviews', 'user_memory', 'conversation_sessions'):
            kwargs['on_conflict'] = 'inventory_id,' + kwargs.get('on_conflict', 'user_id')
        else:
            raise HTTPException(400, 'Use an explicit save for this inventory record.')
        self.query = self.query.upsert(prepared, **kwargs)
        return self

    def update(self, data, **kwargs):
        self.client.require_editor(self.table)
        self.operation = 'update'
        prepared = self._prepare(data)
        # Setting the existing boundary on an update cannot move a record.
        self.query = self.query.update(prepared, **kwargs).eq('inventory_id', self.client.scope.inventory_id)
        if self.table in PRIVATE and self.table != 'messages':
            self.query = self.query.eq('user_id', self.client.scope.actor_id)
        if self.table in PRIVATE_LEGACY:
            self.query = self.query.or_(f'inventory_visibility.eq.inventory,user_id.eq.{self.client.scope.actor_id}')
        return self

    def delete(self, **kwargs):
        self.client.require_editor(self.table)
        self.operation = 'delete'
        self.query = self.query.delete(**kwargs).eq('inventory_id', self.client.scope.inventory_id)
        if self.table in PRIVATE and self.table != 'messages':
            self.query = self.query.eq('user_id', self.client.scope.actor_id)
        if self.table in PRIVATE_LEGACY:
            self.query = self.query.or_(f'inventory_visibility.eq.inventory,user_id.eq.{self.client.scope.actor_id}')
        return self

    def eq(self, field, value):
        if field == 'conversation_id':
            self.conversation_id = value
        # The validated inventory boundary replaces the former personal-owner
        # filter. Existing record ownership is retained, including linked Team Spaces.
        if field not in OWNERSHIP_FIELDS:
            if self.table == 'capture_reviews' and field == 'source_key':
                value = self._source_key(value)
            self.query = self.query.eq(field, value)
        return self

    def in_(self, field, values):
        if field not in OWNERSHIP_FIELDS:
            if self.table == 'capture_reviews' and field == 'source_key':
                values = [self._source_key(value) for value in values]
            self.query = self.query.in_(field, values)
        return self

    def execute(self):
        if self.table == 'messages' and self.operation not in ('insert', 'upsert'):
            if not self.conversation_id:
                raise HTTPException(400, 'Choose a conversation.')
            self.client.record('conversations', 'id', self.conversation_id)
        return self.query.execute()

    def __getattr__(self, name):
        value = getattr(self.query, name)
        if not callable(value):
            # PostgREST negation is a property returning another query builder.
            self.query = value
            return self
        def chain(*args, **kwargs):
            self.query = value(*args, **kwargs)
            return self
        return chain


def scoped_client(raw):
    scope = current_inventory.get()
    return InventoryClient(raw, scope) if scope else raw
