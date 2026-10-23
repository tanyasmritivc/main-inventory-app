"""Durable, actor-private FIND drafts; only the explicit save endpoint writes stock.

The canonical draft lives on one existing conversation message. Compare-and-swap
of its JSON context prevents stale edits or destination changes after save starts.
Stable capture IDs feed the existing idempotent inventory and Review save paths.
"""
from contextlib import contextmanager
from contextvars import ContextVar
from copy import deepcopy
from uuid import UUID, uuid4
from fastapi import HTTPException
from pydantic import BaseModel, ConfigDict, Field
from app.services.supabase_client import get_supabase_raw
from app.schemas.inventory import ExtractedInventoryItem, BulkCreateRequest

current_capture = ContextVar('chat_capture', default=None)


class ItemEdit(BaseModel):
    model_config = ConfigDict(extra='forbid')
    index: int = Field(ge=0, lt=10000)
    selected: bool | None = None
    name: str | None = Field(default=None, min_length=1, max_length=200)
    category: str | None = Field(default=None, min_length=1, max_length=100)
    quantity: int | None = Field(default=None, ge=0, le=100000)
    brand: str | None = Field(default=None, max_length=100)
    part_number: str | None = Field(default=None, max_length=100)
    notes: str | None = Field(default=None, max_length=2000)


class DraftEdit(BaseModel):
    model_config = ConfigDict(extra='forbid')
    inventory_id: str | None = None
    space_id: str | None = None
    items: list[ItemEdit] = Field(default_factory=list, max_length=200)


def create(actor, key, cid, items, source_url, summary=None, *, source_kind="photo"):
    from app.services import world_chat as world
    from app.services.catalog_service import enrich_scan_items_from_verified_catalog
    if len(items) > (10000 if source_kind == 'spreadsheet' else 200):
        raise HTTPException(422, 'A chat draft supports up to 200 items. Split this capture into smaller batches.')
    clean = []
    for raw in (items if source_kind == 'spreadsheet' else enrich_scan_items_from_verified_catalog(items)):
        item = ExtractedInventoryItem.model_validate(raw).model_dump(exclude_none=True)
        for field in ('review_id', 'review_status', 'review_token', 'client_request_id'):
            item.pop(field, None)
        item['source_frame_url'] = source_url
        # A visual guess of a location is never an authorized destination.
        item.pop('location', None)
        clean.append({'index': len(clean), 'selected': True, 'item': item})
    draft = {'id': str(uuid4()), 'version': 1, 'revision': 1, 'status': 'draft',
             'items': clean, 'summary': summary or {}, 'inventory_id': None, 'space_id': None,
             'destination_label': None, 'source_url': source_url, 'source_kind': source_kind}
    world.save_answer(actor, key, cid, f'Auto Extract found {len(clean)} item(s). Review the draft before saving.',
                      {'chat_capture': draft}, message_id=draft['id'])
    return draft


def load(actor, key, cid, capture_id=None):
    from app.services import world_chat as world
    world.conversation(actor, key, cid)
    query = get_supabase_raw().table('messages').select('id,answer_context').eq('conversation_id', cid)
    if capture_id:
        query = query.eq('id', str(UUID(capture_id)))
    else:
        query = query.contains('answer_context', {'chat_capture': {'version': 1}}).order('created_at', desc=True)
    rows = query.limit(1).execute().data or []
    if not rows:
        if capture_id:
            raise HTTPException(404, 'This extraction is unavailable in this conversation.')
        return None
    row = rows[0]
    draft = (row.get('answer_context') or {}).get('chat_capture')
    if not isinstance(draft, dict) or draft.get('id') != row['id']:
        raise HTTPException(404, 'This extraction is unavailable.')
    return row


def replace(cid, row, draft):
    context = {**row['answer_context'], 'chat_capture': draft}
    # Compare the version and frozen save checkpoint, not the whole draft in
    # a URL filter (large spreadsheets exceed HTTP request-line limits).
    old = row['answer_context']['chat_capture']
    query = (get_supabase_raw().table('messages').update({'answer_context': context})
             .eq('id', row['id']).eq('conversation_id', cid)
             .eq('answer_context->chat_capture->>revision', str(old['revision']))
             .eq('answer_context->chat_capture->>status', old['status']))
    field = 'answer_context->chat_capture->>processed_count'
    query = query.eq(field, str(old['processed_count'])) if 'processed_count' in old else query.is_(field, 'null')
    result = query.execute().data
    if not result:
        raise HTTPException(409, 'This draft changed. Refresh it before continuing.')
    return draft


def edit(actor, key, cid, capture_id, revision, changes):
    from app.services import world_chat as world
    from app.services.spaces_repo import list_spaces
    changes = DraftEdit.model_validate(changes)
    row = load(actor, key, cid, capture_id)
    draft = deepcopy(row['answer_context']['chat_capture'])
    if draft['status'] != 'draft' or draft['revision'] != revision:
        raise HTTPException(409, 'This draft changed or saving already started. Refresh it before continuing.')
    if changes.inventory_id is not None:
        inv = world.inventory_scope(actor, key, changes.inventory_id)
        if not inv['can_edit']:
            raise HTTPException(403, 'Choose an inventory you can edit.')
        if draft['inventory_id'] != inv['inventory_id']:
            draft.update(inventory_id=inv['inventory_id'], space_id=None, location=None)
        draft['destination_label'] = inv['workspace']['name'] + ' / ' + inv['name']
    if changes.space_id is not None:
        if not draft['inventory_id']:
            raise HTTPException(422, 'Choose an inventory first.')
        with world.in_inventory(actor, key, draft['inventory_id']) as inv:
            matches = [s for s in list_spaces(user_id=inv['owner_user_id']) if s['id'] == changes.space_id]
            if not inv['can_edit'] or not matches:
                raise HTTPException(403, 'Choose an accessible Space in this inventory.')
            draft.update(space_id=matches[0]['id'], location=matches[0]['name'])
    seen = set()
    for update in changes.items:
        if update.index >= len(draft['items']) or update.index in seen:
            raise HTTPException(422, 'Choose a distinct item from this extraction.')
        seen.add(update.index)
        target = draft['items'][update.index]
        fields = update.model_dump(exclude_unset=True, exclude={'index'})
        if 'selected' in fields:
            selected = fields.pop('selected')
            if selected is None:
                raise HTTPException(422, 'Choose whether to keep the item.')
            target['selected'] = selected
        if any(value is None for field, value in fields.items() if field in ('name', 'category', 'quantity')):
            raise HTTPException(422, 'Name, category and quantity cannot be empty.')
        for field in ('name', 'category'):
            if field in fields:
                fields[field] = fields[field].strip()
                if not fields[field]:
                    raise HTTPException(422, 'Give the item a name and category.')
        target['item'].update(fields)
        ExtractedInventoryItem.model_validate(target['item'])
    draft['revision'] += 1
    return replace(cid, row, draft)


def facts(draft):
    if not draft:
        return None
    value = {k: draft.get(k) for k in ('id', 'revision', 'status', 'inventory_id', 'space_id', 'destination_label', 'location')} | {
        'observation_count': len(draft['items']),
        'selected_observation_count': sum(bool(row['selected']) for row in draft['items'])}
    receipt = draft.get('receipt')
    if receipt:
        value['receipt'] = {k: receipt.get(k, 0) for k in ('saved_count', 'review_count')}
        value['receipt']['failure_count'] = len(receipt.get('failures', []))
        value['receipt']['resource_links'] = [link for link in receipt.get('resource_links', []) if link.get('kind') == 'space'][:1]
    if draft.get('status') != 'saved':
        value['items'] = [{'index': row['index'], 'selected': row['selected'],
                          **{k: row['item'].get(k) for k in ('name', 'category', 'quantity', 'brand', 'part_number', 'scan_evidence')}}
                         for row in draft['items']]
    return value


@contextmanager
def use_capture(actor, key, cid, draft):
    state = {'actor': actor, 'world': key, 'cid': cid, 'draft': draft}
    token = current_capture.set(state)
    try:
        yield state
    finally:
        current_capture.reset(token)


def refine(changes):
    state = current_capture.get()
    if not state or not state['draft']:
        raise ValueError('Upload a photo to Auto Extract first.')
    draft = state['draft']
    state['draft'] = edit(state['actor'], state['world'], state['cid'], draft['id'], draft['revision'], changes)
    return {'capture_draft': facts(state['draft']), 'saved': False}


def duplicate_links(owner, inventory_id, selected):
    from app.services.supabase_client import get_supabase_admin
    from app.services import world_chat as world
    found = {}
    client = get_supabase_admin()
    for field in ('name', 'barcode', 'part_number'):
        values = list({entry['item'][field] for entry in selected if entry['item'].get(field)})
        for offset in range(0, len(values), 100):
            rows = client.table('items').select('item_id,name').eq('user_id', owner).in_(field, values[offset:offset + 100]).limit(200).execute().data or []
            for row in rows:
                found[row['item_id']] = {**row, 'inventory_id': inventory_id}
    # Links are bounded independently from the duplicate decision.
    return world.resource_links({'items': list(found.values())})


def save(actor, key, cid, capture_id, revision, allow_duplicates=False):
    from app.services import world_chat as world
    from app.services.spaces_repo import list_spaces
    from app.services.review_queue import enqueue_uncertain_items
    from app.api.routes.items import inventory_bulk_create_route
    from app.core.auth import AuthenticatedUser
    row = load(actor, key, cid, capture_id)
    draft = deepcopy(row['answer_context']['chat_capture'])
    if draft['status'] == 'saved':
        # Access is rechecked even for a receipt, so revoked inventory contents
        # cannot be surfaced by replaying a private chat card.
        world.inventory_scope(actor, key, draft['inventory_id'])
        return draft
    if draft['revision'] != revision:
        raise HTTPException(409, 'This draft changed. Refresh before saving.')
    if not draft.get('inventory_id') or not draft.get('space_id'):
        raise HTTPException(422, 'Choose an inventory and a Space before saving.')
    selected = [r for r in draft['items'] if r['selected']]
    if not selected:
        raise HTTPException(422, 'Select at least one extracted item.')
    with world.in_inventory(actor, key, draft['inventory_id']) as inv:
        if not inv['can_edit']:
            raise HTTPException(403, 'You no longer have permission to save here.')
        space = next((s for s in list_spaces(user_id=inv['owner_user_id']) if s['id'] == draft['space_id']), None)
        if not space or space['name'] != draft.get('location'):
            raise HTTPException(409, 'The Space changed. Review the destination before saving.')
        if draft['status'] == 'draft':
            duplicates = duplicate_links(inv['owner_user_id'], inv['inventory_id'], selected)
            if duplicates and not allow_duplicates:
                raise HTTPException(409, {'code': 'capture_duplicates', 'message': 'Possible matches already exist. Open them, or explicitly save these as separate items.', 'resource_links': duplicates})
            draft['status'] = 'saving'
            replace(cid, row, draft)
            row = {**row, 'answer_context': {**row['answer_context'], 'chat_capture': deepcopy(draft)}}
        # Frozen details + stable IDs: a partial/lost response can only finish the
        # same save; it cannot change the destination or create another copy.
        inventory_items, reviews = [], []
        processed = draft.get('processed_count', 0)
        batch = selected[processed:processed + 200]
        for entry in batch:
            item = {**entry['item'], 'location': draft['location'],
                    'client_request_id': f"chat_{draft['id']}_{entry['index']}"}
            if (item.get('scan_evidence') or {}).get('needs_review'):
                queued = enqueue_uncertain_items(user_id=inv['owner_user_id'],
                    source_digest=f"chat-{draft['id']}-{entry['index']}", items=[item])[0]
                reviews.append({'index': entry['index'], 'review_id': queued['review_id']})
            else:
                inventory_items.append((entry['index'], item))
        result = inventory_bulk_create_route(BulkCreateRequest(items=[i for _, i in inventory_items]),
                    AuthenticatedUser(user_id=inv['owner_user_id'])) if inventory_items else None
        inserted = result.inserted if result else []
        failures = [{**f, 'index': inventory_items[f['index']][0]} for f in (result.failures if result else [])]
        links = world.resource_links({'items': [{**r, 'inventory_id': inv['inventory_id']} for r in inserted],
            'spaces': [{**space, 'inventory_id': inv['inventory_id']}]})
        prior = draft.get('completed_receipt') or {}
        draft['receipt'] = {'saved_count': prior.get('saved_count', 0) + len(inserted), 'review_count': prior.get('review_count', 0) + len(reviews),
                            'reviews': prior.get('reviews', []) + reviews, 'failures': failures,
                            'resource_links': (prior.get('resource_links', []) + links)[-200:]}
        if not failures:
            draft['processed_count'] = processed + len(batch)
            draft['completed_receipt'] = deepcopy(draft['receipt'])
        draft['status'] = 'saving' if failures or draft.get('processed_count', 0) < len(selected) else 'saved'
        try:
            return replace(cid, row, draft)
        except HTTPException as error:
            if error.status_code != 409:
                raise
            latest = load(actor, key, cid, capture_id)['answer_context']['chat_capture']
            if latest['status'] == 'saved':
                return latest
            raise HTTPException(409, 'Saving is in progress. Refresh and retry this same draft.') from None
