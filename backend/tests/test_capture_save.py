"""Capture persistence and retry behavior against an isolated in-memory store."""

from copy import deepcopy
from types import SimpleNamespace
from unittest.mock import patch

import pytest

from app.services import capture_save, items_repo, item_photos
from app.api.routes import items as routes
from app.core.auth import AuthenticatedUser
from app.schemas.inventory import BulkCreateRequest
from fastapi import HTTPException


class Store:
    def __init__(self):
        self.rows = []
        self.events = []
        self.photo_failure = False
        self.photo_response_lost = False
        self.insert_calls = 0
        self.fail_before = False
        self.fail_after = False

    def table(self, name):
        assert name in ('items', 'item_events')
        return Query(self, name)


class Query:
    def __init__(self, store, table='items'):
        self.store, self.filters, self.payload = store, [], None
        self.table = table

    def select(self, *_args, **_kwargs):
        return self

    def order(self, *_args, **_kwargs):
        return self

    def eq(self, key, value):
        self.filters.append(lambda row: row.get(key) == value)
        return self

    def in_(self, key, values):
        self.filters.append(lambda row: row.get(key) in values)
        return self

    def insert(self, payload):
        self.payload = deepcopy(payload)
        return self

    def execute(self):
        if self.table == 'item_events':
            if self.payload is not None:
                if self.store.photo_failure:
                    raise ConnectionError('Photo unavailable')
                if any(row['event_id'] == self.payload['event_id'] for row in self.store.events):
                    raise ValueError('Duplicate photo')
                self.store.events.append(deepcopy(self.payload))
                if self.store.photo_response_lost:
                    raise ConnectionError('Photo response lost after commit')
            return SimpleNamespace(data=deepcopy([row for row in self.store.events if all(check(row) for check in self.filters)]))
        if self.payload is not None:
            self.store.insert_calls += 1
            if self.store.fail_before:
                raise ConnectionError('No write')
            old_ids = {row['item_id'] for row in self.store.rows}
            if any(row['item_id'] in old_ids for row in self.payload):
                raise ValueError('Unique item identity conflict')
            self.store.rows.extend(deepcopy(self.payload))
            if self.store.fail_after:
                raise ConnectionError('Response lost after commit')
            return SimpleNamespace(data=deepcopy(self.payload))
        rows = [row for row in self.store.rows if all(check(row) for check in self.filters)]
        return SimpleNamespace(data=deepcopy(rows))


def draft(**changes):
    return dict(name='Soldering iron', category='Tools', quantity=1,
                location='Workbench', image_url='https://storage.test/crop-a.jpg',
                client_request_id='capture-a', **changes)


@pytest.fixture
def store():
    database = Store()
    items_repo._INVENTORY_CACHE.clear()
    with patch.object(capture_save, 'get_supabase_admin', return_value=database), \
         patch.object(item_photos, 'get_supabase_admin', return_value=database), \
         patch.object(items_repo, 'get_supabase_admin', return_value=database), \
         patch.object(capture_save, '_resolve_space_id', side_effect=lambda **kw: 'space-' + kw['location']), \
         patch.object(capture_save, 'verified_catalog_id_for_identity', return_value=None):
        yield database
    items_repo._INVENTORY_CACHE.clear()


def test_same_named_objects_keep_variants_locations_photos_and_can_be_retrieved(store):
    inputs = [draft(), {**draft(), 'client_request_id': 'capture-b', 'location': 'Garage',
                       'part_number': 'MODEL-B', 'image_url': 'https://storage.test/crop-b.jpg'}]
    inserted, failures = capture_save.save_capture_items(user_id='owner', items=inputs)
    assert not failures and len(inserted) == 2
    retrieved = items_repo.list_items(user_id='owner')
    assert {(r['location'], r['image_url'], r['part_number']) for r in retrieved} == {
        ('Workbench', 'https://storage.test/crop-a.jpg', None),
        ('Garage', 'https://storage.test/crop-b.jpg', 'MODEL-B'),
    }
    assert len({r['item_id'] for r in retrieved}) == 2
    assert items_repo.list_items(user_id='another-owner') == []


def test_same_label_in_one_space_does_not_merge_distinct_reviewed_objects(store):
    inserted, failures = capture_save.save_capture_items(user_id='owner', items=[
        draft(), {**draft(), 'client_request_id': 'capture-b', 'image_url': 'https://storage.test/crop-b.jpg'}])
    assert not failures and len(inserted) == 2
    assert [row['quantity'] for row in store.rows] == [1, 1]


def test_retry_returns_saved_receipts_without_adding_or_increasing_quantity(store):
    first = capture_save.save_capture_items(user_id='owner', items=[draft()])
    repeated = capture_save.save_capture_items(user_id='owner', items=[draft()], max_new_items=0)
    assert repeated == first and len(store.rows) == 1 and store.insert_calls == 1
    assert store.rows[0]['quantity'] == 1


def test_lost_response_is_resolved_from_actual_persisted_rows(store):
    store.fail_after = True
    inserted, failures = capture_save.save_capture_items(user_id='owner', items=[draft()])
    assert len(inserted) == 1 and not failures
    assert capture_save.save_capture_items(user_id='owner', items=[draft()])[0] == inserted
    assert len(store.rows) == 1


def test_original_is_second_for_each_crop_without_duplicate_uploads(store):
    source = 'https://storage.test/original.jpg'
    inputs = [draft(source_frame_url=source),
              {**draft(source_frame_url=source), 'client_request_id': 'b', 'image_url': 'https://storage.test/crop-b.jpg'}]
    saved, failures = capture_save.save_capture_items(user_id='owner', items=inputs)
    assert len(saved) == 2 and not failures
    assert len(store.events) == 2
    assert {event['image_url'] for event in store.events} == {source}
    for row in saved:
        events = [e for e in store.events if e['item_id'] == row['item_id']]
        assert [p['image_url'] for p in item_photos._photos_for_item(item=row, events=events)] == [row['image_url'], source]
    capture_save.save_capture_items(user_id='owner', items=inputs)
    assert len(store.rows) == len(store.events) == 2


def test_failed_original_retains_draft_and_retry_repairs_without_duplicate_item(store):
    inputs = [draft(source_frame_url='https://storage.test/original.jpg')]
    store.photo_failure = True
    saved, failures = capture_save.save_capture_items(user_id='owner', items=inputs)
    assert not saved and failures[0]['index'] == 0
    assert len(store.rows) == 1 and not store.events
    store.photo_failure = False
    store.photo_response_lost = True
    saved, failures = capture_save.save_capture_items(user_id='owner', items=inputs, max_new_items=0)
    assert len(saved) == 1 and not failures
    assert len(store.rows) == len(store.events) == 1


def test_retry_cannot_replace_the_saved_original(store):
    capture_save.save_capture_items(user_id='owner', items=[draft(source_frame_url='original-a.jpg')])
    saved, failures = capture_save.save_capture_items(user_id='owner', items=[draft(source_frame_url='original-b.jpg')])
    assert not saved and failures[0]['index'] == 0
    assert [event['image_url'] for event in store.events] == ['original-a.jpg']


def test_fallback_to_full_frame_appears_once(store):
    source = draft()['image_url']
    saved, failures = capture_save.save_capture_items(user_id='owner', items=[draft(source_frame_url=source)])
    assert len(saved) == 1 and not failures and not store.events


def test_uncommitted_failure_never_returns_synthetic_success(store):
    store.fail_before = True
    inserted, failures = capture_save.save_capture_items(user_id='owner', items=[draft()])
    assert inserted == [] and [row['index'] for row in failures] == [0]
    assert store.rows == []
    store.fail_before = False
    assert len(capture_save.save_capture_items(user_id='owner', items=[draft()])[0]) == 1


def test_changed_retry_cannot_replace_saved_location_or_photo(store):
    capture_save.save_capture_items(user_id='owner', items=[draft()])
    inserted, failures = capture_save.save_capture_items(user_id='owner', items=[{**draft(), 'location': 'Wrong shelf'}])
    assert not inserted and failures[0]['index'] == 0
    assert store.rows[0]['location'] == 'Workbench'


def test_limits_return_every_unsaved_input_index_and_preserve_existing_items(store):
    inserted, failures = capture_save.save_capture_items(user_id='owner', items=[
        draft(), {**draft(), 'client_request_id': 'capture-b'}, {**draft(), 'client_request_id': 'capture-c'}], max_new_items=1)
    assert len(inserted) == 1 and [row['index'] for row in failures] == [1, 2]
    assert len(store.rows) == 1


def test_request_ids_are_owner_bound(store):
    first, _ = capture_save.save_capture_items(user_id='owner', items=[draft()])
    second, _ = capture_save.save_capture_items(user_id='other', items=[draft()])
    assert first[0]['item_id'] != second[0]['item_id']
    assert len(items_repo.list_items(user_id='other')) == 1


def test_duplicate_request_id_is_explicit_and_zero_is_not_unknown(store):
    inserted, failures = capture_save.save_capture_items(user_id='owner', items=[draft(), draft()])
    assert len(inserted) == 1 and failures[0]['index'] == 1
    assert not capture_save._same_record({'quantity': None}, {'quantity': 0})


def test_route_returns_explicit_receipts_for_every_index_and_checks_every_owner(store):
    payload = BulkCreateRequest(items=[draft(), {**draft(), 'client_request_id': 'b', 'name': ''}])
    with patch.object(routes, '_resolve_owner_for_joined_space', return_value='owner') as owners, \
         patch.object(routes, 'is_pro_user', return_value=True), \
         patch.object(routes, 'create_activity'):
        result = routes.inventory_bulk_create_route(payload, AuthenticatedUser('owner'))
    assert owners.call_count == 2
    assert result.accepted_indices == [0]
    assert [failure['index'] for failure in result.failures] == [1]
    assert len(result.inserted) == 1


def test_route_rejects_mixed_owners_before_any_write(store):
    payload = BulkCreateRequest(items=[draft(), {**draft(), 'client_request_id': 'b', 'location': 'Shared'}])
    with patch.object(routes, '_resolve_owner_for_joined_space', side_effect=['owner', 'another']), pytest.raises(HTTPException) as error:
        routes.inventory_bulk_create_route(payload, AuthenticatedUser('owner'))
    assert error.value.status_code == 400 and store.rows == []


def test_route_does_not_treat_a_failed_quota_read_as_zero(store):
    payload = BulkCreateRequest(items=[draft()])
    with patch.object(routes, '_resolve_owner_for_joined_space', return_value='owner'), \
         patch.object(routes, 'is_pro_user', return_value=False), \
         patch.object(routes, 'get_supabase_admin', side_effect=ConnectionError), pytest.raises(HTTPException) as error:
        routes.inventory_bulk_create_route(payload, AuthenticatedUser('owner'))
    assert error.value.status_code == 503 and store.rows == []
