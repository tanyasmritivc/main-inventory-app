"""Scoped read tools shared with inventory search and project readiness."""
from datetime import date
from typing import Literal
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field, model_validator

class Model(BaseModel):
    model_config = ConfigDict(extra='forbid')

class Filters(Model):
    location: str | None = Field(default=None, max_length=100)
    category: str | None = Field(default=None, max_length=100)
    brand: str | None = Field(default=None, max_length=100)
    space_id: str | None = None
    missing: Literal['location', 'image', 'category', 'quantity'] | None = None
    quantity_op: Literal['below', 'above', 'at least', 'at most', 'exactly'] | None = None
    quantity_value: int | None = Field(default=None, ge=0, le=1000000)
    created_op: Literal['since', 'after', 'before'] | None = None
    created_date: str | None = None

    @model_validator(mode='after')
    def pairs(self):
        if (self.quantity_op is None) != (self.quantity_value is None) or (self.created_op is None) != (self.created_date is None):
            raise ValueError('Supply both the comparison and its value.')
        if self.created_date is not None:
            date.fromisoformat(self.created_date)
        return self

class Query(Model):
    inventory_id: str | None = None
    terms: list[str] = Field(default_factory=list, max_length=12)
    filters: Filters = Field(default_factory=Filters)

class Projects(Model):
    inventory_id: str
    query: str = Field(default='', max_length=100)

class Readiness(Model):
    inventory_id: str
    kit_id: str

class Activity(Model):
    inventory_id: str
    since: str | None = None

MODELS = {'world_query': Query, 'world_projects': Projects, 'world_project_readiness': Readiness, 'world_activity': Activity}
DESCRIPTIONS = {
    'world_query': 'Search saved fields with typo tolerance and explicit location, brand, quantity or date filters. Server returns record counts and physical unit totals with completeness. Choose inventory_id or omit to search the selected organization. Likely matches need clarification before changes. Physical units are not reservation-adjusted availability.',
    'world_projects': 'Find saved projects by name in one authorized inventory. Returns exact project IDs for readiness.',
    'world_project_readiness': 'Compare a saved project BOM with current stock and reservations. Returns deterministic shortages. Similar names do not prove compatibility. This does not reserve or purchase parts.',
    'world_activity': 'Read the signed-in user\'s inventory changes since an optional ISO timestamp. Results are limited to 100 and may be incomplete. Historical events are not current inventory facts.',
}


def execute(actor, world, name, args):
    from app.services import world_chat as w
    from app.services.supabase_client import get_supabase_admin, get_supabase_raw
    parsed = MODELS[name].model_validate(args, strict=True)
    if name == 'world_query':
        from app.services.inventory_query import query_inventory
        choices = ([w.inventory_scope(actor, world, parsed.inventory_id)] if parsed.inventory_id
            else w.directory(actor, world)['inventories'])
        items, summaries = [], []
        for choice in choices:
            with w.in_inventory(actor, world, choice['inventory_id']) as inv:
                result = query_inventory(user_id=inv['owner_user_id'], terms=parsed.terms,
                    filters=parsed.filters.model_dump(exclude_none=True, mode='json'))
                summaries.append({'inventory_id': inv['inventory_id'], 'name': inv['name'],
                    **{k: result.get(k) for k in ('record_count', 'known_units', 'unknown_quantity_records', 'complete')}})
                items.extend({**item, 'inventory_id': inv['inventory_id'], 'inventory_name': inv['name']}
                    for item in result.get('items', [])[:max(0, 100-len(items))])
        return {'items': items, 'inventories': summaries,
            'record_count': sum(s.get('record_count') or 0 for s in summaries),
            'known_units': sum(s.get('known_units') or 0 for s in summaries),
            'unknown_quantity_records': sum(s.get('unknown_quantity_records') or 0 for s in summaries),
            'complete': all(s.get('complete') is True for s in summaries),
            'rows_truncated': sum(s.get('record_count') or 0 for s in summaries) > len(items),
            'quantity_basis': 'Saved physical quantities, before project reservations.'}
    with w.in_inventory(actor, world, parsed.inventory_id) as inv:
        if name == 'world_projects':
            query = get_supabase_admin().table('project_kits').select('id,name,location').eq('owner_user_id', inv['owner_user_id'])
            if parsed.query:
                term = parsed.query.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_')
                query = query.ilike('name', '%' + term + '%')
            rows = query.order('name').limit(51).execute().data or []
            return {'projects': [{**row, 'inventory_id': inv['inventory_id']} for row in rows[:50]], 'complete': len(rows) <= 50}
        if name == 'world_project_readiness':
            from app.services.project_kits_service import get_project_readiness
            result = get_project_readiness(kit_id=str(UUID(parsed.kit_id)), user_id=actor)
            return {**{k: v for k, v in result.items() if k in ('id', 'name', 'location', 'summary', 'items', 'can_reserve')},
                'projects': [{'id': result['id'], 'name': result['name'], 'inventory_id': inv['inventory_id']}],
                'scope_note': 'Requirements are compared with stock in the saved project Space. Exact identifiers or names are matches, not independently verified compatibility.'}
        query = get_supabase_raw().table('app_access_audit').select('action,target_id,changes,created_at').eq('actor_id', actor).eq('inventory_id', inv['inventory_id'])
        if parsed.since:
            from datetime import datetime
            timestamp = datetime.fromisoformat(parsed.since.replace('Z', '+00:00'))
            if timestamp.tzinfo is None:
                raise ValueError('Use an explicit timezone for activity timestamps.')
            query = query.gte('created_at', timestamp.isoformat())
        rows = query.order('created_at', desc=True).limit(101).execute().data or []
        return {'activity': rows[:100], 'complete': len(rows) <= 100}
