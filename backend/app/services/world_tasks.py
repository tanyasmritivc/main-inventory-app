"""One reviewed intent, including creation and its dependent item operations."""
from pydantic import BaseModel, ConfigDict, Field
from uuid import UUID
from fastapi import HTTPException


class Model(BaseModel):
    model_config = ConfigDict(extra='forbid')


class NewItem(Model):
    name: str = Field(min_length=1, max_length=200)
    quantity: int = Field(ge=0, le=1000000)
    location: str = Field(min_length=1, max_length=100)
    category: str = Field(default='Other', min_length=1, max_length=100)
    notes: str = Field(default='', max_length=2000)


class MoveItem(Model):
    inventory_id: str
    item_id: str
    location: str = Field(min_length=1, max_length=100)


class Destination(Model):
    name: str = Field(min_length=1, max_length=100)
    spaces: list[str] = Field(default_factory=list, max_length=30)
    items: list[NewItem] = Field(default_factory=list, max_length=100)
    moves: list[MoveItem] = Field(default_factory=list, max_length=100)


class Task(Model):
    workspace_id: str | None = None
    workspace_name: str | None = Field(default=None, min_length=1, max_length=100)
    inventories: list[Destination] = Field(min_length=1, max_length=10)


def schema(model=Task):
    """Inline nested models for gateways without JSON Schema ref support."""
    root = model.model_json_schema()
    definitions = root.pop('$defs', {})
    def expand(value):
        if isinstance(value, dict):
            if '$ref' in value:
                return expand(definitions[value['$ref'].split('/')[-1]])
            return {k: expand(v) for k, v in value.items()}
        if isinstance(value, list):
            return [expand(v) for v in value]
        return value
    return expand(root)


def propose(actor, world, args):
    from app.services import world_chat as w
    from app.services.supabase_client import get_supabase_raw
    task = Task.model_validate(args, strict=True)
    if sum(len(i.items) + len(i.moves) for i in task.inventories) > 100:
        raise ValueError('Keep a creation request to at most 100 item changes.')
    base = task.model_dump(exclude={'inventories'})
    base['inventories'] = [{'name': i.name, 'spaces': i.spaces} for i in task.inventories]
    action = w.propose_structure(actor, world, base)
    seen = set()
    for target, original in zip(action['plan']['inventories'], task.inventories):
        spaces = {s.casefold(): s for s in target['spaces']}
        target['items'], target['moves'] = [], []
        for item in original.items:
            if not item.name.strip() or not item.category.strip() or item.location.strip().casefold() not in spaces:
                raise ValueError('Include the exact destination Space in the creation plan.')
            target['items'].append({**item.model_dump(), 'name': item.name.strip(),
                'category': item.category.strip(), 'location': spaces[item.location.strip().casefold()]})
        for move in original.moves:
            identity = (str(UUID(move.inventory_id)), str(UUID(move.item_id)))
            if identity in seen or move.location.strip().casefold() not in spaces:
                raise ValueError('Choose one destination per saved item.')
            seen.add(identity)
            with w.in_inventory(actor, world, identity[0]) as source:
                if not source['can_edit']:
                    raise HTTPException(403, 'You cannot move this item.')
                frozen = get_supabase_raw().rpc('findez_world_item_snapshot', {
                    'p_actor': actor, 'p_inventory': identity[0], 'p_item': identity[1]}).execute().data
                if not isinstance(frozen, dict) or not frozen.get('snapshot'):
                    raise ValueError('Read the saved item again before moving it.')
                item = frozen['item']
                target['moves'].append({'inventory_id': identity[0], 'item_id': identity[1],
                    'name': item['name'], 'quantity': item['quantity'] if item['quantity'] >= 0 else None,
                    'location': item.get('location') or 'Unsorted', 'snapshot': frozen['snapshot'],
                    'target_location': spaces[move.location.strip().casefold()]})
    action['version'] = 2
    # Bind a creation-only proposal to its existing draft, never duplicate the
    # observations into a text-only task. The binding is server-authored.
    from app.services.chat_capture import current_capture
    capture = current_capture.get()
    draft = capture and capture.get('draft')
    place = (draft or {}).get('summary', {}).get('described_place')
    if (draft and draft['status'] == 'draft' and not draft.get('space_id') and place
            and len(task.inventories) == 1 and not task.inventories[0].items
            and not task.inventories[0].moves and len(task.inventories[0].spaces) == 1
            and task.inventories[0].spaces[0].strip().casefold() == place.strip().casefold()):
        action['capture_destination'] = {'conversation_id': capture['cid'],
            'capture_id': draft['id'], 'place': place}

    return {'world_action': action, 'saved': False,
        'next_step': ('Offer to create this destination. Confirmation creates it and selects it for the existing draft; '
                      'the draft stays editable and unsaved until Save items.' if action.get('capture_destination') else
                      'One confirmation creates the listed structure AND adds or moves the listed items. Do not ask for a second confirmation.')}


def confirm(actor, world, action_id, decision, space_limits, item_limits):
    from app.services.supabase_client import get_supabase_raw
    return get_supabase_raw().rpc('findez_world_task_action', {
        'p_actor': actor, 'p_world': world, 'p_action': action_id,
        'p_decision': decision, 'p_space_limits': space_limits,
        'p_item_limits': item_limits}).execute().data
