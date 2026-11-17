"""Inventory-scoped purchase plans and append-only manual quote history."""
import os
import json
from collections import defaultdict
from decimal import Decimal
from typing import Literal
from uuid import UUID, uuid4
from fastapi import HTTPException
from pydantic import Field, field_validator, model_validator
from app.services.supabase_client import get_supabase_raw
from . import projects
from .repository import authorize_inventory
from .snapshot import Model, Snapshot
from .pricing import Quote, Quantity, estimate


def native_enabled():
    return enabled() and os.environ.get("CAD_NATIVE_PURCHASING_ENABLED") == "true"


def enabled():
    return os.environ.get('CAD_PURCHASING_ENABLED', '').lower() == 'true'


def access(inventory, actor):
    if not enabled():
        raise HTTPException(503, 'CAD purchasing is not enabled yet.')
    return authorize_inventory(inventory, actor)


class CreatePlan(Model):
    request_id: UUID
    bom_version_id: UUID


class Action(Model):
    request_id: UUID
    expected_revision: int = Field(strict=True, ge=1)
    action: Literal['quote', 'select_quote', 'approve', 'reopen', 'order', 'receive', 'cancel']
    line_id: UUID | None = None
    quote_id: UUID | None = None
    quote: Quote | None = None
    order_reference: str | None = Field(default=None, min_length=1, max_length=1000)
    quantity: Quantity | None = None
    item_id: UUID | None = None
    identity_confirmed: Literal[True] | None = None

    @field_validator('identity_confirmed', mode='before')
    @classmethod
    def confirmed(cls, value):
        if value is not None and value is not True:
            raise ValueError('Explicitly confirm the received part and destination.')
        return value

    @model_validator(mode='after')
    def action_fields(self):
        required = {'quote': {'line_id', 'quote'}, 'select_quote': {'line_id', 'quote_id'},
            'order': {'order_reference'}, 'receive': {'line_id', 'quantity', 'item_id', 'identity_confirmed'}}.get(self.action, set())
        supplied = {field for field in ('line_id', 'quote_id', 'quote', 'order_reference', 'quantity', 'item_id', 'identity_confirmed')
            if getattr(self, field) is not None}
        if supplied != required:
            raise ValueError('Provide only the fields required for this purchase action.')
        return self


def _rpc(inventory, actor, request, plan, action, revision, data, identity, grant=None):
    params = {'p_actor': actor, 'p_inventory': inventory, 'p_request': str(request),
        'p_plan': plan, 'p_action': action, 'p_expected': revision, 'p_data': data,
        'p_hash': projects.digest(identity)}
    if grant is not None:
        if not native_enabled():
            raise HTTPException(503, 'Purchasing inside Fusion is not enabled yet.')
        params['p_grant'] = grant
    result = get_supabase_raw().rpc('findez_cad_native_purchase_action' if grant is not None else 'findez_cad_purchase_action', params).execute().data
    messages = {
        'forbidden': (403, 'Inventory editing permission is required.'),
        'approval_required': (403, 'An inventory owner or administrator must approve and record orders.'),
        'not_found': (404, 'The purchase record or stock item is not in this inventory.'),
        'stale': (409, 'This plan changed. Reload it before making another change.'),
        'conflict': (409, 'This request was already used for a different change.'),
        'transition': (409, 'This action is not available in the current purchase state.'),
        'quote_unavailable': (409, 'Choose a current, available quote for every line.'),
        'over_receipt': (409, 'The delivery exceeds the quantity still on order.'),
        'invalid_stock': (409, 'Correct the destination stock quantity before receiving.'),
        'limit': (429, 'The purchase planning limit has been reached.'),
        'active_plan': (409, 'This project already has an active purchase plan. Open that plan first.'),
    }
    if not isinstance(result, dict) or not result.get('id'):
        status, message = messages.get((result or {}).get('error') if isinstance(result, dict) else '',
            (422, 'Check the purchase details and try again.'))
        raise HTTPException(status, message)
    authorize_inventory(inventory, actor)
    if action == 'receive':
        from app.api.routes.inventory_workspaces import _inventory
        from app.services.items_repo import invalidate_inventory_cache
        invalidate_inventory_cache(_inventory(inventory, actor)['owner_user_id'])
    return {'inventory_id': inventory, **result}


def create(inventory, actor, body: CreatePlan, grant=None):
    access(inventory, actor)
    # A successful retry must survive subsequent stock changes or a completed
    # order. The RPC still verifies actor, role and the original request hash.
    previous = get_supabase_raw().table('cad_purchase_events').select('id').eq('inventory_id', inventory).eq(
        'request_id', str(body.request_id)).limit(1).execute().data or []
    if previous:
        return _rpc(inventory, actor, body.request_id, None, 'create', None, {}, ['create', str(body.bom_version_id)], grant)
    # Reconcile against current stock, not the historical comparison. The saved
    # snapshot stays immutable and the resulting plan records its own timestamp.
    rows = get_supabase_raw().table('cad_bom_versions').select('snapshot').eq('inventory_id', inventory).eq('id', str(body.bom_version_id)).limit(1).execute().data or []
    if not rows:
        raise HTTPException(404, 'Choose a saved BOM in this inventory.')
    snapshot = Snapshot.model_validate(rows[0]['snapshot'])
    result = projects.evaluate(snapshot, inventory, actor)
    if result['completeness'] != 'complete' or any(row['status'] == 'needs_review'
        and row['procurement_policy'] not in ('fabricate', 'exclude') for row in result['items']):
        raise HTTPException(409, 'Resolve incomplete extraction and review lines in Fusion before creating a purchase plan.')
    lines = [{'id': str(uuid4()), 'component_key': row['key'], 'name': row['name'],
        'manufacturer': row['manufacturer'], 'part_number': row['part_number'],
        'catalog_id': row.get('catalog_id'), 'specifications': row.get('specifications', {}),
        'required': row['required'], 'available': row['assigned'], 'quantity': row['missing'],
        'received': 0, 'quotes': [], 'selected_quote': None}
        for row in result['items'] if row['missing'] > 0 and row['procurement_policy'] == 'purchase']
    if not lines:
        raise HTTPException(409, 'No confirmed shortages remain in this design.')
    if len(lines) > 500 or any(line['quantity'] > 1_000_000 for line in lines):
        raise HTTPException(422, 'Split this BOM into purchase plans of at most 500 lines and 1,000,000 units per line.')
    data = {'bom_version_id': str(body.bom_version_id), 'name': snapshot.document.name,
        'lines': lines, 'inventory_as_of': result['inventory_as_of']}
    return _rpc(inventory, actor, body.request_id, None, 'create', None, data, ['create', str(body.bom_version_id)], grant)


def plans(inventory, actor, offset=0):
    access(inventory, actor)
    rows = get_supabase_raw().table('cad_purchase_plans').select('id,name,state,revision,created_at,bom_version_id').eq(
        'inventory_id', inventory).order('created_at', desc=True).order('id').range(offset, offset + 49).execute().data or []
    authorize_inventory(inventory, actor)
    return {'inventory_id': inventory, 'plans': rows, 'next_offset': offset + 50 if len(rows) == 50 else None}


def detail(inventory, actor, plan):
    access(inventory, actor)
    rows = get_supabase_raw().table('cad_purchase_plans').select('*').eq('inventory_id', inventory).eq('id', plan).limit(1).execute().data or []
    authorize_inventory(inventory, actor)
    if not rows:
        raise HTTPException(404, 'Purchase plan not found in this inventory.')
    result = rows[0]
    totals = defaultdict(Decimal)
    groups = defaultdict(list)
    for line in result['lines']:
        quote = line['selected_quote']
        if quote:
            totals[quote['currency']] += Decimal(quote['estimate']['subtotal'])
            groups[quote['vendor']].append(line['id'])
    return {**result, 'totals': {k: str(v) for k, v in totals.items()},
        'vendor_groups': dict(groups), 'excludes': ['shipping', 'tax']}


def action(inventory, actor, plan, body: Action, grant=None):
    current = detail(inventory, actor, plan)
    data = body.model_dump(mode='json', exclude_none=True, exclude={'action', 'request_id', 'expected_revision'})
    if body.action == 'quote':
        line = next((row for row in current['lines'] if row['id'] == str(body.line_id)), None)
        if not line:
            raise HTTPException(404, 'Purchase line not found.')
        data['quote'] = {**data['quote'], 'id': str(uuid4()), 'recorded_by': actor,
            'estimate': estimate(body.quote, line['quantity'])}
        # Leave room for JSONB formatting and later receipt metadata.
        if len(json.dumps(current['lines']).encode()) + len(json.dumps(data['quote']).encode()) > 3_000_000:
            raise HTTPException(422, 'This plan has reached its quote history limit.')
    return _rpc(inventory, actor, body.request_id, plan, body.action, body.expected_revision, data,
        [plan, body.model_dump(mode='json')], grant)
