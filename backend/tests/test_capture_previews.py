from copy import deepcopy
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.routes import items, review
from app.core.auth import AuthenticatedUser, get_current_user
from app.services import capture_previews as previews, review_queue
from app.services.storage import StoredImage


def uncertain():
    return {'name': 'Unidentified item', 'category': 'Other', 'quantity': 1,
            'image_url': 'https://storage.test/user-1/crop.jpg',
            'source_frame_url': 'https://storage.test/user-1/source.jpg',
            'scan_evidence': {'needs_review': True, 'identity_confidence': 0.2,
                              'review_reasons': ['Uncertain identity']}}


def preview():
    return previews.preview_uncertain_items(user_id='user-1', source_digest='digest', items=[uncertain()])[0]


@pytest.mark.parametrize('path', ['/extract_from_image', '/inventory/extract_from_image'])
def test_upload_preview_never_writes_the_review_queue(path):
    app = FastAPI()
    app.include_router(items.router)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(user_id='user-1')
    with patch.object(items, '_prepare_scan_image', return_value=(b'jpeg', 'photo.jpg')), \
         patch.object(items, 'check_and_increment_scan'), \
         patch.object(items, 'upload_image', return_value=StoredImage('user-1/source.jpg', 'https://storage.test/user-1/source.jpg')), \
         patch.object(items, 'extract_inventory_items_with_find', new=AsyncMock(return_value={'items': [uncertain()]})), \
         patch.object(items, 'enrich_scan_items_from_verified_catalog', side_effect=lambda rows: rows), \
         patch.object(items, 'create_activity'), \
         patch.object(items, 'enqueue_uncertain_items') as enqueue, \
         patch.object(review_queue, 'get_supabase_admin') as database:
        response = TestClient(app).post(path, files={'file': ('photo.jpg', b'image', 'image/jpeg')}, data={'preview_only': 'true'})
    assert response.status_code == 200
    result = response.json()
    value = result['extracted'] if 'extracted' in result else result['items'][0]
    assert value['review_status'] == 'preview'
    assert value['scan_evidence']['needs_review'] is True
    assert value['review_token']
    enqueue.assert_not_called()
    database.assert_not_called()


def test_confident_detections_have_no_review_preview_or_secret_fields():
    raw = {**uncertain(), 'scan_evidence': {'needs_review': False}, 'private_model': 'DO NOT EXPOSE'}
    result = previews.preview_uncertain_items(user_id='user-1', source_digest='digest', items=[raw])[0]
    assert 'review_token' not in result and 'review_id' not in result
    assert 'private_model' not in result


def test_older_capture_clients_keep_the_existing_pending_review_contract():
    app = FastAPI()
    app.include_router(items.router)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(user_id='user-1')
    saved = {**uncertain(), 'review_id': '10000000-0000-0000-0000-000000000001', 'review_status': 'pending'}
    with patch.object(items, '_prepare_scan_image', return_value=(b'jpeg', 'photo.jpg')), \
         patch.object(items, 'check_and_increment_scan'), \
         patch.object(items, 'upload_image', return_value=StoredImage('user-1/source.jpg', 'https://storage.test/user-1/source.jpg')), \
         patch.object(items, 'extract_inventory_items_with_find', new=AsyncMock(return_value={'items': [uncertain()]})), \
         patch.object(items, 'enrich_scan_items_from_verified_catalog', side_effect=lambda rows: rows), \
         patch.object(items, 'create_activity'), \
         patch.object(items, 'enqueue_uncertain_items', return_value=[saved]) as enqueue:
        response = TestClient(app).post('/inventory/extract_from_image', files={'file': ('photo.jpg', b'image', 'image/jpeg')})
    assert response.status_code == 200
    assert response.json()['items'][0]['review_status'] == 'pending'
    assert response.json()['items'][0]['review_token'] is None
    enqueue.assert_called_once()


@pytest.mark.parametrize('change', ['account', 'id', 'signature', 'payload', 'expired'])
def test_preview_cannot_be_transferred_tampered_with_or_saved_after_expiry(change):
    item = preview()
    kwargs = dict(user_id='user-1', preview_id=item['review_id'], token=item['review_token'])
    if change == 'account':
        kwargs['user_id'] = 'user-2'
    elif change == 'id':
        kwargs['preview_id'] = '10000000-0000-0000-0000-000000000001'
    elif change == 'signature':
        kwargs['token'] = item['review_token'][:-1] + ('0' if item['review_token'][-1] != '0' else '1')
    elif change == 'payload':
        kwargs['token'] = 'A' + item['review_token'][1:]
    with patch.object(previews.time, 'time', return_value=10**12 if change == 'expired' else 0), \
         patch.object(review_queue, 'get_supabase_admin') as database:
        with pytest.raises(previews.InvalidCapturePreview):
            review_queue.save_capture_preview(user_id=kwargs['user_id'], preview_id=kwargs['preview_id'],
                                             item={**item, 'review_token': kwargs['token']})
    database.assert_not_called()


class ReviewDatabase:
    def __init__(self):
        self.rows = {}
        self.filters = {}
        self.operation = None
        self.calls = []

    def table(self, name):
        assert name == 'capture_reviews'
        self.calls.append(name)
        self.filters = {}
        self.operation = None
        return self

    def eq(self, key, value):
        self.filters[key] = value
        return self

    def select(self, *_args):
        return self

    def limit(self, *_args):
        return self

    def upsert(self, payload, *, on_conflict, ignore_duplicates):
        assert on_conflict == 'user_id,source_key' and ignore_duplicates
        key = (payload['user_id'], payload['source_key'])
        self.rows.setdefault(key, {**deepcopy(payload), 'review_id': '10000000-0000-0000-0000-000000000001',
                                   'created_at': '2026-10-14T12:00:00Z'})
        return self

    def update(self, payload):
        self.operation = payload
        return self

    def execute(self):
        rows = [row for row in self.rows.values() if all(row.get(key) == value for key, value in self.filters.items())]
        if self.operation is not None:
            assert self.filters['user_id'] == 'user-1'
            assert self.filters['status'] == 'pending'
            for row in rows:
                row.update(deepcopy(self.operation))
        return SimpleNamespace(data=deepcopy(rows))


def test_explicit_save_retains_signed_evidence_and_photo_and_retry_is_idempotent():
    item = preview()
    modified = {**item, 'name': 'My object', 'location': 'Shelf 1',
                'image_url': 'https://attacker.test/foreign-photo',
                'source_frame_url': 'https://attacker.test/foreign-source',
                'scan_evidence': {'needs_review': False, 'identity_confidence': 1}}
    database = ReviewDatabase()
    with patch.object(review_queue, 'get_supabase_admin', return_value=database):
        first = review_queue.save_capture_preview(user_id='user-1', preview_id=item['review_id'], item=modified)
        second = review_queue.save_capture_preview(user_id='user-1', preview_id=item['review_id'], item=modified)
        assert first['review_id'] == second['review_id']
        assert len(database.rows) == 1
        assert first['name'] == 'My object' and first['location'] == 'Shelf 1'
        assert first['scan_evidence'] == item['scan_evidence']
        assert first['image_url'] == item['image_url']
        assert first['source_frame_url'] == item['source_frame_url']
        assert 'review_token' not in first
        source_key = previews.verify_capture_preview(user_id='user-1', preview_id=item['review_id'], token=item['review_token'])['source_key']
        database.rows[('user-1', source_key)]['status'] = 'dismissed'
        with pytest.raises(review_queue.ReviewItemConflict):
            review_queue.save_capture_preview(user_id='user-1', preview_id=item['review_id'], item=item)
        assert database.rows[('user-1', source_key)]['status'] == 'dismissed'


def test_saved_previews_do_not_accept_a_claimed_owner_or_unsigned_source():
    app = FastAPI()
    app.include_router(review.router)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(user_id='user-1')
    item = preview()
    with patch.object(review, 'save_capture_preview') as save:
        response = TestClient(app).post('/review-items/' + item['review_id'], json={**item, 'user_id': 'user-2'})
        missing = TestClient(app).post('/review-items/' + item['review_id'], json=uncertain())
    assert response.status_code == missing.status_code == 422
    save.assert_not_called()


def test_explicit_save_route_is_owned_retry_safe_and_returns_no_private_claims():
    app = FastAPI()
    app.include_router(review.router)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(user_id='user-1')
    item = preview()
    database = ReviewDatabase()
    with patch.object(review_queue, 'get_supabase_admin', return_value=database):
        response = TestClient(app).post('/review-items/' + item['review_id'], json=item)
        retry = TestClient(app).post('/review-items/' + item['review_id'], json=item)
    assert response.status_code == retry.status_code == 200
    value = response.json()['review_item']
    assert value['status'] == 'pending' and len(database.rows) == 1
    assert value['review_id'] == retry.json()['review_item']['review_id']
    assert not {'user_id', 'source_key', 'review_token'} & value.keys()
