"""Synthetic capture workflow: durable draft CAS, intent, review and retry boundaries."""
from copy import deepcopy
from contextlib import ExitStack
from types import SimpleNamespace as NS
from unittest.mock import patch
from uuid import uuid4
import json
import pytest
from fastapi import HTTPException
from app.services import chat_capture as c, world_chat as w
from app.schemas.inventory import BulkCreateResponse

ACTOR, WORLD, CID, INV, SPACE, ITEM = [str(uuid4()) for _ in range(6)]

class Database:
    def __init__(self): self.rows = {}; self.writes = 0
    def table(self, name):
        assert name == 'messages'
        return Query(self)

class Query:
    def __init__(self, db): self.db, self.filters, self.payload = db, [], None
    def select(self, *args): return self
    def is_(self, key, value):
        assert value == 'null'
        self.filters.append(lambda row: row['answer_context']['chat_capture'].get(key.split('->>')[-1]) is None)
        return self
    def eq(self, key, value):
        if key.startswith('answer_context->chat_capture->>'):
            self.filters.append(lambda row: str(row['answer_context']['chat_capture'].get(key.split('->>')[-1])) == value)
            return self
        if key == 'answer_context': value = json.loads(value)
        self.filters.append(lambda row: row.get(key) == value)
        return self
    def contains(self, key, value):
        self.filters.append(lambda row: row.get(key, {}).get('chat_capture', {}).get('version') == 1)
        return self
    def limit(self, *args): return self
    def order(self, *args, **kwargs): return self
    def update(self, payload): self.payload = deepcopy(payload); return self
    def execute(self):
        rows = [r for r in self.db.rows.values() if all(f(r) for f in self.filters)]
        if self.payload:
            for row in rows: row.update(self.payload); self.db.writes += 1
        return NS(data=deepcopy(rows))

@pytest.fixture
def store():
    db = Database()
    inv = {'inventory_id': INV, 'owner_user_id': ACTOR, 'role': 'owner', 'name': 'Tools', 'can_edit': True, 'workspace': {'name': 'Home'}}
    def record(actor, world, cid, answer, context, *, message_id=None):
        assert (actor, world, cid) == (ACTOR, WORLD, CID)
        db.rows[message_id] = {'id': message_id, 'conversation_id': cid, 'answer_context': deepcopy(context)}
    with ExitStack() as stack:
        stack.enter_context(patch.object(c, 'get_supabase_raw', return_value=db))
        access = stack.enter_context(patch.object(w, 'conversation'))
        stack.enter_context(patch.object(w, 'inventory_scope', return_value=inv))
        stack.enter_context(patch.object(w, 'save_answer', side_effect=record))
        stack.enter_context(patch('app.services.catalog_service.enrich_scan_items_from_verified_catalog', side_effect=lambda items: items))
        stack.enter_context(patch('app.services.spaces_repo.list_spaces', return_value=[{'id': SPACE, 'name': 'Garage'}]))
        duplicate = stack.enter_context(patch.object(c, 'duplicate_links', return_value=[]))
        review = stack.enter_context(patch('app.services.review_queue.enqueue_uncertain_items', side_effect=lambda **kw: [{**kw['items'][0], 'review_id': 'review-one', 'review_status': 'pending'}]))
        bulk = stack.enter_context(patch('app.api.routes.items.inventory_bulk_create_route', return_value=BulkCreateResponse(inserted=[{'item_id': ITEM, 'name': 'Drill'}], failures=[], accepted_indices=[0])))
        yield NS(db=db, inv=inv, duplicate=duplicate, review=review, bulk=bulk, access=access)

def make(**kw):
    return c.create(ACTOR, WORLD, CID, [
        {'name': 'Drill', 'category': 'Tools', 'quantity': 1, 'image_url': 'https://storage.test/crop.jpg', 'location': 'Guessed shelf'},
        {'name': 'Unknown fastener', 'category': 'Hardware', 'quantity': 0, 'scan_evidence': {'needs_review': True, 'review_reasons': ['Identity uncertain']}}
    ], 'https://storage.test/original.jpg')

def destination(d):
    return c.edit(ACTOR, WORLD, CID, d['id'], d['revision'], {'inventory_id': INV, 'space_id': SPACE})

def test_extract_retains_all_evidence_without_inventory_or_review_writes(store):
    d = make()
    assert len(d['items']) == 2 and d['status'] == 'draft'
    assert 'location' not in d['items'][0]['item']
    assert d['items'][0]['item']['source_frame_url'].endswith('original.jpg')
    assert d['items'][1]['item']['scan_evidence']['needs_review']
    store.bulk.assert_not_called(); store.review.assert_not_called()
    assert c.load(ACTOR, WORLD, CID)['answer_context']['chat_capture'] == d

def test_refine_same_draft_keeps_crops_uncertainty_and_selection(store):
    d = make()
    with c.use_capture(ACTOR, WORLD, CID, d):
        result = c.refine({'items': [{'index': 0, 'quantity': 3}, {'index': 1, 'selected': False}]})
        assert result['saved'] is False
    changed = c.load(ACTOR, WORLD, CID, d['id'])['answer_context']['chat_capture']
    assert changed['items'][0]['item']['quantity'] == 3
    assert changed['items'][0]['item']['image_url'].endswith('crop.jpg')
    assert not changed['items'][1]['selected']
    assert changed['items'][1]['item']['scan_evidence']['needs_review']
    with pytest.raises(HTTPException) as err: c.edit(ACTOR, WORLD, CID, d['id'], 1, {'items': []})
    assert err.value.status_code == 409
    store.bulk.assert_not_called()

@pytest.mark.parametrize('changes', [
    {'items': [{'index': 0, 'image_url': 'forged'}]}, {'items': [{'index': 0, 'scan_evidence': {'needs_review': False}}]},
    {'items': [{'index': 0, 'quantity': -1}]}, {'items': [{'index': 0, 'name': ' '}]},
    {'items': [{'index': 0, 'selected': None}]}, {'items': [{'index': 2, 'quantity': 3}]},
    {'items': [{'index': 0, 'quantity': 2}, {'index': 0, 'quantity': 3}]},
])
def test_invalid_or_evidence_forging_edits_never_mutate(store, changes):
    d = make()
    with pytest.raises((ValueError, HTTPException)): c.edit(ACTOR, WORLD, CID, d['id'], 1, changes)
    assert c.load(ACTOR, WORLD, CID, d['id'])['answer_context']['chat_capture'] == d


def test_save_uses_existing_capture_and_review_pipelines_with_receipt_links(store):
    d = destination(make())
    saved = c.save(ACTOR, WORLD, CID, d['id'], d['revision'])
    assert saved['status'] == 'saved' and saved['receipt']['review_count'] == 1
    assert saved['receipt']['saved_count'] == 1
    assert {r['kind'] for r in saved['receipt']['resource_links']} == {'space', 'item'}
    payload = store.bulk.call_args.args[0].items[0]
    assert payload.quantity == 1 and payload.location == 'Garage'
    assert payload.image_url.endswith('crop.jpg') and payload.source_frame_url.endswith('original.jpg')
    assert payload.client_request_id == f"chat_{d['id']}_0"
    assert store.review.call_args.kwargs['items'][0]['quantity'] == 0
    assert c.save(ACTOR, WORLD, CID, d['id'], d['revision']) == saved
    assert store.bulk.call_count == 1 and store.review.call_count == 1


def test_duplicates_require_explicit_separate_save_and_never_merge(store):
    d = destination(make())
    store.duplicate.return_value = [{'kind': 'item', 'id': ITEM}]
    with pytest.raises(HTTPException) as err: c.save(ACTOR, WORLD, CID, d['id'], d['revision'])
    assert err.value.detail['code'] == 'capture_duplicates'
    store.bulk.assert_not_called(); store.review.assert_not_called()
    assert c.save(ACTOR, WORLD, CID, d['id'], d['revision'], True)['status'] == 'saved'


def test_partial_save_freezes_destination_edits_and_retries_identical_ids(store):
    d = destination(make())
    store.bulk.return_value = BulkCreateResponse(inserted=[], failures=[{'index': 0, 'reason': 'Retry'}], accepted_indices=[])
    partial = c.save(ACTOR, WORLD, CID, d['id'], d['revision'])
    assert partial['status'] == 'saving' and partial['receipt']['failures'][0]['index'] == 0
    original = store.bulk.call_args.args[0]
    with pytest.raises(HTTPException): c.edit(ACTOR, WORLD, CID, d['id'], d['revision'], {'inventory_id': str(uuid4())})
    store.bulk.return_value = BulkCreateResponse(inserted=[{'item_id': ITEM, 'name': 'Drill'}], failures=[], accepted_indices=[0])
    assert c.save(ACTOR, WORLD, CID, d['id'], d['revision'])['status'] == 'saved'
    assert store.bulk.call_args.args[0] == original
    assert store.duplicate.call_count == 1
    assert store.review.call_args_list[0] == store.review.call_args_list[1]


def test_failed_save_response_retains_frozen_draft_for_reconciliation(store):
    d = destination(make())
    store.bulk.side_effect = RuntimeError('Lost response')
    with pytest.raises(RuntimeError): c.save(ACTOR, WORLD, CID, d['id'], d['revision'])
    assert c.load(ACTOR, WORLD, CID, d['id'])['answer_context']['chat_capture']['status'] == 'saving'


def test_missing_destination_and_demoted_viewer_cannot_save(store):
    d = make()
    with pytest.raises(HTTPException): c.save(ACTOR, WORLD, CID, d['id'], 1)
    d = destination(d); store.inv['can_edit'] = False
    with pytest.raises(HTTPException) as err: c.save(ACTOR, WORLD, CID, d['id'], d['revision'])
    assert err.value.status_code == 403
    store.bulk.assert_not_called(); store.review.assert_not_called()


def test_foreign_conversation_denied_before_draft_read(store):
    make(); store.access.side_effect = HTTPException(404, 'Unavailable')
    with pytest.raises(HTTPException): c.load('stranger', WORLD, CID)


def test_contexts_are_restored_and_mutations_cannot_escape_conversation(store):
    with c.use_capture(ACTOR, WORLD, CID, make()): assert c.current_capture.get()['cid'] == CID
    assert c.current_capture.get() is None
    with pytest.raises(ValueError): c.refine({'items': []})


def test_model_draft_counts_remain_explicit_before_bounded_observations():
    from app.services.world_chat import model_data
    from app.services.chat_capture import facts
    draft = {'id':'capture','revision':1,'status':'draft','items':[
        {'index':i,'selected':i<21,'item':{'name':f'Object {i}','quantity':1,
            'scan_evidence':{'notes':'long evidence '*200}}} for i in range(22)]}
    result = model_data(facts(draft))
    assert result['observation_count'] == 22
    assert result['selected_observation_count'] == 21


def test_spreadsheet_draft_preserves_source_fields_through_save(store):
    original = {'filename':'parts.csv','sheet':'Sheet1','fields':[{'name':'Serial','value':'0000123'}]}
    draft = c.create(ACTOR, WORLD, CID, [{'name':'Drill','category':'Tools','quantity':2,
        'import_data':original,'purchase_source':'Local shop'}], None, source_kind='spreadsheet')
    draft = destination(draft)
    c.save(ACTOR, WORLD, CID, draft['id'], draft['revision'])
    item = store.bulk.call_args.args[0].items[0]
    assert item.import_data.model_dump() == original
    assert item.purchase_source == 'Local shop'


def test_large_spreadsheet_checkpoints_bounded_batches_and_replay(store):
    from app.schemas.inventory import BulkCreateResponse
    store.bulk.side_effect = lambda payload, user: BulkCreateResponse(
        inserted=[{'item_id': str(uuid4()), 'name': item.name} for item in payload.items],
        failures=[], accepted_indices=list(range(len(payload.items))))
    draft = c.create(ACTOR, WORLD, CID, [{'name':f'Part {n}','category':'Tools','quantity':1} for n in range(450)], None, source_kind='spreadsheet')
    draft = destination(draft)
    for processed in [200, 400, 450]:
        draft = c.save(ACTOR, WORLD, CID, draft['id'], draft['revision'])
        assert draft['processed_count'] == processed
        assert draft['receipt']['saved_count'] == processed
    assert draft['status'] == 'saved'
    assert [len(call.args[0].items) for call in store.bulk.call_args_list] == [200,200,50]
    c.save(ACTOR, WORLD, CID, draft['id'], draft['revision'])
    assert store.bulk.call_count == 3
