"""Reviewed edits, moves and reorder approvals. Purchases are never placed."""
from datetime import date
from decimal import Decimal
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from fastapi import HTTPException
from app.services.supabase_client import get_supabase_raw
from app.services.chat_item_actions import _proposal

class StrictModel(BaseModel):
    model_config = ConfigDict(extra='forbid')

class Changes(StrictModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    category: str | None = Field(default=None, min_length=1, max_length=100)
    subcategory: str | None = Field(default=None, max_length=100)
    brand: str | None = Field(default=None, max_length=200)
    part_number: str | None = Field(default=None, max_length=200)
    barcode: str | None = Field(default=None, max_length=200)
    notes: str | None = Field(default=None, max_length=2000)
    purchase_source: str | None = Field(default=None, max_length=500)
    quantity: int | None = Field(default=None, ge=0, le=1000000)
    unit_price: float | None = Field(default=None, ge=0, le=1000000000, allow_inf_nan=False)
    currency: str | None = Field(default=None, pattern=r'^[A-Z]{3}$')
    expires_on: str | None = None
    reorder_enabled: bool | None = None
    reorder_threshold: int | None = Field(default=None, ge=0, le=1000000)
    reorder_quantity: int | None = Field(default=None, ge=1, le=1000000)

    @field_validator('unit_price')
    @classmethod
    def exact_price(cls, value):
        if value is not None and Decimal(str(value)).normalize().as_tuple().exponent < -4:
            raise ValueError('Use at most four decimal places for a unit price.')
        return value

    @field_validator('expires_on')
    @classmethod
    def valid_date(cls, value):
        if value is not None and date.fromisoformat(value).isoformat() != value:
            raise ValueError('Use YYYY-MM-DD.')
        return value

    @model_validator(mode='after')
    def required_values(self):
        if not self.model_fields_set:
            raise ValueError('Choose at least one change.')
        for key in ('name', 'category', 'quantity', 'reorder_enabled'):
            if key in self.model_fields_set and getattr(self, key) is None:
                raise ValueError(f'{key} cannot be cleared.')
        for key in ('name', 'category'):
            if getattr(self, key) is not None and not getattr(self, key).strip():
                raise ValueError('Use a non-empty name.')
        return self

class Edit(StrictModel):
    inventory_id: str
    item_id: str
    changes: Changes

class Move(StrictModel):
    inventory_id: str
    item_id: str
    target_inventory_id: str
    target_space_id: str

class Reorders(StrictModel):
    inventory_id: str
    status: str = Field(default='pending', pattern=r'^(pending|approved|dismissed|received|all)$')

class DecideReorder(StrictModel):
    inventory_id: str
    request_id: str
    status: str = Field(pattern=r'^(approved|dismissed|received)$')

class Tracking(StrictModel):
    inventory_id: str
    kind: str = Field(pattern=r'^(expiry|price|reorder_rules)$')
    through: str | None = None


def _record(table, inventory, key, value):
    rows = get_supabase_raw().table(table).select('*').eq('inventory_id', inventory).eq(key, str(UUID(value))).limit(1).execute().data
    if not rows:
        raise HTTPException(404, 'This record is no longer in the selected inventory.')
    return rows[0]


def _label(value):
    if value is None: return 'Not set'
    if value is True: return 'On'
    if value is False: return 'Off'
    return str(value)


def execute(actor, world, name, args):
    from app.services.world_chat import in_inventory, inventory_scope
    models = {'world_edit_item': Edit, 'world_move_item': Move, 'world_reorders': Reorders,
              'world_reorder_decision': DecideReorder, 'world_tracking': Tracking}
    parsed = models[name].model_validate(args, strict=True)
    inventory = str(UUID(parsed.inventory_id))
    with in_inventory(actor, world, inventory) as inv:
        raw = get_supabase_raw()
        if name == 'world_reorders':
            query = raw.table('app_reorder_requests').select('*').eq('inventory_id', inventory)
            if parsed.status != 'all': query = query.eq('status', parsed.status)
            return {'requests': query.order('created_at', desc=True).limit(100).execute().data or [],
                    'complete': False, 'note': 'Approval requests only. No purchases are placed.'}
        if name == 'world_tracking':
            query = raw.table('items').select('item_id,name,inventory_id,location,quantity,unit_price,currency,expires_on,reorder_enabled,reorder_threshold,reorder_quantity').eq('inventory_id', inventory)
            if parsed.kind == 'expiry':
                through = date.fromisoformat(parsed.through).isoformat() if parsed.through else date.today().isoformat()
                query = query.lte('expires_on', through).order('expires_on')
            elif parsed.kind == 'price': query = query.not_.is_('unit_price', 'null').order('name')
            else: query = query.eq('reorder_enabled', True).order('name')
            return {'items': query.limit(100).execute().data or [], 'complete': False}
        if not inv['can_edit']:
            raise HTTPException(403, 'You have view-only access to this inventory.')
        request = None
        if name == 'world_reorder_decision':
            request = _record('app_reorder_requests', inventory, 'id', parsed.request_id)
            item_id = request['item_id']
            allowed = {'pending': {'approved', 'dismissed'}, 'approved': {'received', 'dismissed'}}
            if parsed.status not in allowed.get(request['status'], set()):
                raise ValueError('This request cannot make that transition. Read current requests again.')
        else: item_id = parsed.item_id
        frozen = raw.rpc('findez_world_item_snapshot', {'p_actor': actor, 'p_inventory': inventory, 'p_item': str(UUID(item_id))}).execute().data
        if not isinstance(frozen, dict) or not frozen.get('snapshot') or not isinstance(frozen.get('item'), dict):
            raise ValueError('Read this item again.')
        item = frozen['item']
        entry = {'item_id': item['item_id'], 'name': item['name'], 'quantity': item['quantity'] if item['quantity'] >= 0 else None,
                 'location': item.get('location') or 'Unsorted', 'snapshot': frozen['snapshot']}
        details = []
        if name == 'world_edit_item':
            changes = parsed.changes.model_dump(exclude_unset=True)
            merged = {**item, **changes}
            if merged.get('unit_price') is not None and not merged.get('currency'):
                raise ValueError('Ask for the currency with the price.')
            if merged.get('reorder_enabled') and (merged.get('reorder_threshold') is None or merged.get('reorder_quantity') is None):
                raise ValueError('Ask for both the low-stock threshold and reorder quantity.')
            changes = {k: v for k,v in changes.items() if item.get(k) != v}
            if not changes: raise ValueError('These values are already saved.')
            entry['changes'] = changes
            details = [f'{k.replace("_", " ").capitalize()}: {_label(item.get(k))} → {_label(v)}' for k,v in changes.items()]
            operation = 'edit'
        elif name == 'world_move_item':
            target = inventory_scope(actor, world, parsed.target_inventory_id)
            if not target['can_edit']: raise HTTPException(403, 'You cannot edit the destination inventory.')
            space = _record('spaces', target['inventory_id'], 'id', parsed.target_space_id)
            entry.update(target_inventory_id=target['inventory_id'], target_space_id=space['id'], target_location=space['name'])
            details = [f'Move: {inv["name"]} / {item.get("location") or "Unsorted"} → {target["name"]} / {space["name"]}',
                       'Linked photos, documents and item history move with this item. Any old bin assignment is cleared.']
            operation = 'move'
        else:
            entry.update(request_id=request['id'], request_status=request['status'], request_quantity=request['quantity'], next_status=parsed.status)
            details = [f'Reorder request: {request["status"]} → {parsed.status}', f'Quantity: {request["quantity"]}',
                       'Adds received quantity to stock.' if parsed.status == 'received' else 'No purchase will be placed.']
            operation = 'reorder'
        entry['details'] = details
        result = _proposal(operation, [entry])
        result['pending_action'].update(version=2, world=world, destination_label=inv['workspace']['name']+' / '+inv['name'])
        return result


def change_action(*, actor, world, inventory, action_id, decision):
    try:
        result = get_supabase_raw().rpc('findez_world_item_change', {
            'p_actor': actor, 'p_world': world, 'p_inventory': inventory,
            'p_action': action_id, 'p_decision': decision}).execute().data
    except Exception as error:
        code = getattr(error, 'code', None)
        if code == '42501': raise HTTPException(403, 'Your access changed. Review the destination again.') from None
        if code in ('P0002', 'P0003', '23514', '23505', '22023', '22007', '22P02', '40001'):
            raise HTTPException(409, 'This item, request or destination changed. Ask again for a fresh review. Linked project allocations must be released before a move.') from None
        raise HTTPException(502, 'The change could not be confirmed. Retry this same card safely.') from None
    if (not isinstance(result, dict) or result.get('id') != action_id or result.get('inventory_id') != inventory
        or result.get('operation') not in ('edit','move','reorder') or result.get('status') not in ('pending','confirmed','cancelled')):
        raise HTTPException(502, 'The action receipt could not be verified. Retry the same card.')
    if result['status'] == 'confirmed':
        receipt = result.get('receipt') or {}
        if receipt.get('count') != 1 or len(receipt.get('items') or []) != 1 or receipt.get('operation') != result['operation']:
            raise HTTPException(502, 'The completed receipt could not be verified. Retry the same card.')
        from app.services.items_repo import invalidate_inventory_cache
        from app.services.world_chat import inventory_scope
        destinations = {inventory, receipt['items'][0].get('inventory_id') or inventory}
        for destination in destinations:
            invalidate_inventory_cache(inventory_scope(actor, world, destination)['owner_user_id'])
    return result
