"""Hermetic Ask-photo security, matching, persistence and failure regressions."""
import asyncio
import io
import json
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from PIL import Image

from app.api.routes import ai
from app.core.auth import AuthenticatedUser, get_current_user
from app.services import ai_agent, ask_photo_questions as photos
from app.services.find_pipeline import FindPipelineError
from app.services.limits import ScanLimitExceeded
from app.services.storage import StoredImage

PATH = 'user-1/ask-' + 'a' * 32 + '.jpg'
URL = 'https://api.test/storage/v1/object/public/item-images/' + PATH


def image():
    output = io.BytesIO()
    Image.new('RGB', (32, 32), 'red').save(output, format='PNG')
    return output.getvalue()


def item(**changes):
    return {'item_id': 'a', 'name': 'Servo', 'brand': 'Acme', 'part_number': 'S-1',
            'barcode': '12345678', 'quantity': 2, 'location': 'Garage', **changes}


def test_strong_identifiers_match_product_not_physical_ownership():
    result = photos.format_photo_answer(identified=[item()], inventory=[item(), item(item_id='b', quantity=3, location='Loft')], photo_url=URL)
    assert '5 units available' in result['assistant_message']
    assert 'Garage, Loft' in result['assistant_message']
    assert 'already lists this product' in result['assistant_message']
    assert len(result['answer_context']['rows']) == 2
    assert all('required_quantity' not in row and 'status' not in row for row in result['answer_context']['rows'])


@pytest.mark.parametrize('photo,expected', [
    (item(barcode='', part_number=''), 'possible name match'),
    (item(barcode='', name='Different'), 'brand and part-number match'),
    (item(scan_evidence={'needs_review': True}), 'possible name match'),
    (item(barcode='1', part_number='', name='Object'), None),
    (item(barcode='', part_number='S-1', brand='Different', name='Other'), None),
])
def test_weak_names_short_codes_and_uncertainty_cannot_confirm_product(photo, expected):
    assert photos._match(photo, item()) == expected


def test_uncertain_item_and_no_match_are_honest_and_visible_in_review():
    result = photos.format_photo_answer(identified=[item(scan_evidence={'needs_review': True}, review_id='r', review_status='pending')], inventory=[], photo_url=URL)
    text = result['assistant_message']
    assert 'Possible identification' in text and 'cannot prove' in text
    assert 'Review on Home' in text and 'No inventory item has been added' in text


def test_zero_stock_and_output_has_no_private_fields():
    result = photos.format_photo_answer(identified=[item()], inventory=[item(quantity=0, user_id='SECRET', internal_model='SECRET')], photo_url=URL)
    assert '0 units available' in result['assistant_message']
    assert 'SECRET' not in json.dumps(result)


def test_empty_and_large_photo_results_are_explicitly_bounded():
    assert 'could not identify' in photos.format_photo_answer(identified=[], inventory=[], photo_url=URL)['assistant_message']
    result = photos.format_photo_answer(identified=[item() for _ in range(21)], inventory=[item()], photo_url=URL)
    assert '1 additional objects' in result['assistant_message']
    assert len(result['answer_context']['rows']) == 1


def test_barcode_padding_brand_aliases_and_specific_name_matches():
    assert photos._match(item(barcode='0123456789012'), item(barcode='123456789012')) == 'barcode match'
    assert photos._match(item(barcode='', brand='REV', part_number='P-2'), item(barcode='', brand='REV Robotics', part_number='P-2')) == 'brand and part-number match'
    assert photos._match(item(barcode='', part_number='', name='Hex bolts'), item(name='M4 hex bolt')) == 'possible name match'


def test_accessible_inventory_deduplicates_only_authorized_live_reads():
    with patch.object(ai_agent, '_inventory_knowledge', return_value={
        'personal_items': [item()], 'shared_and_joined_items': [item(), item(item_id='joined')],
    }) as knowledge:
        result = photos.accessible_inventory('user-1')
    knowledge.assert_called_once_with(user_id='user-1', query='', include_projects=False)
    assert [row['item_id'] for row in result] == ['a', 'joined']


@pytest.mark.parametrize('message', ['What is this? Do I own it?', 'What are its dimensions?', 'Measure the width'])
def test_photo_service_pipeline_review_and_inventory_without_mutation(message):
    uncertain = item(scan_evidence={'needs_review': True})
    with patch.object(photos, 'upload_image', return_value=StoredImage(PATH, URL)) as upload, \
         patch.object(photos, 'extract_inventory_items_with_find', new=AsyncMock(return_value={'items': [uncertain]})) as extract, \
         patch.object(photos, 'enrich_scan_items_from_verified_catalog', side_effect=lambda rows: rows), \
         patch.object(photos, 'enqueue_uncertain_items', side_effect=lambda **kw: kw['items']) as review, \
         patch.object(photos, 'accessible_inventory', return_value=[]) as inventory, \
         patch.object(photos, 'gateway_completion') as gateway:
        result = asyncio.run(photos.answer_photo_question(user_id='user-1', message=message, image_bytes=image()))
    assert upload.call_args.kwargs['user_id'] == 'user-1'
    assert upload.call_args.kwargs['filename'].startswith('ask-')
    assert 'include_measurements' not in extract.call_args.kwargs
    assert extract.call_args.kwargs['source_frame_url'] == URL
    assert review.call_args.kwargs['source_digest'].startswith('ask:')
    assert 'ownership is not confirmed' in uncertain['notes']
    inventory.assert_called_once_with('user-1')
    gateway.assert_not_called()
    assert result['answer_context']['photo_path'] == PATH


def test_failed_analysis_cleans_only_new_source_before_review():
    with patch.object(photos, 'upload_image', return_value=StoredImage(PATH, URL)), \
         patch.object(photos, 'extract_inventory_items_with_find', new=AsyncMock(side_effect=FindPipelineError('SECRET'))), \
         patch.object(photos, 'delete_image') as delete, patch.object(photos, 'enqueue_uncertain_items') as review:
        with pytest.raises(FindPipelineError):
            asyncio.run(photos.answer_photo_question(user_id='user-1', message='What is this?', image_bytes=image()))
    delete.assert_called_once_with(path=PATH)
    review.assert_not_called()


@pytest.mark.parametrize('question,explain', [('Add this photo item', False), ('How does this work?', True)])
def test_photo_requests_use_no_mutation_tools_and_keep_grounded_check(question, explain):
    reply = SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content='A servo controls position.'))])
    with patch.object(photos, 'upload_image', return_value=StoredImage(PATH, URL)), \
         patch.object(photos, 'extract_inventory_items_with_find', new=AsyncMock(return_value={'items': [item()]})), \
         patch.object(photos, 'enrich_scan_items_from_verified_catalog', side_effect=lambda rows: rows), \
         patch.object(photos, 'enqueue_uncertain_items', side_effect=lambda **kw: kw['items']), \
         patch.object(photos, 'accessible_inventory', return_value=[]), patch.object(photos, 'gateway_completion', return_value=reply) as gateway:
        result = asyncio.run(photos.answer_photo_question(user_id='user-1', message=question, image_bytes=image()))
    if explain:
        assert 'tools' not in gateway.call_args.kwargs
        assert 'controls position' in result['assistant_message']
    else:
        gateway.assert_not_called()
        assert 'confirm the change' in result['assistant_message']
    assert 'No inventory item' in result['assistant_message']


@pytest.mark.parametrize('path', ['other-user/ask-' + 'a'*32 + '.jpg', 'user-1/../photo.jpg', 'user-1/photo.jpg', None])
def test_history_never_signs_foreign_or_arbitrary_photo_paths(path):
    with patch.object(photos, 'get_supabase_admin') as storage:
        result = photos.refresh_photo_context({'photo_path': path, 'photo_url': 'https://evil.test/tracker'}, 'user-1')
    storage.assert_not_called()
    assert 'photo_url' not in result and 'photo_path' not in result


def test_history_refreshes_expired_private_photo_url_from_owned_path():
    client = MagicMock()
    client.storage.from_.return_value.create_signed_url.return_value = {'signedURL': 'http://storage.internal/storage/v1/object/sign/item-images/' + PATH + '?token=fresh'}
    settings = SimpleNamespace(supabase_storage_bucket='item-images', supabase_storage_public=False, supabase_storage_signed_url_ttl_seconds=3600, supabase_public_url='https://api.test')
    with patch.object(photos, 'get_settings', return_value=settings), patch.object(photos, 'get_supabase_admin', return_value=client):
        result = photos.refresh_photo_context({'photo_path': PATH, 'photo_url': 'https://evil.test'}, 'user-1')
    assert result['photo_url'].startswith('https://api.test/storage/')
    client.storage.from_.return_value.create_signed_url.assert_called_once_with(PATH, 3600)


def api_client(authenticated=True):
    app = FastAPI()
    app.include_router(ai.router)
    if authenticated:
        app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(user_id='user-1')
    return TestClient(app)


@pytest.fixture
def route_io():
    client = MagicMock()
    query = client.table.return_value
    for name in ('select', 'eq', 'limit', 'insert', 'update'):
        getattr(query, name).return_value = query
    query.execute.return_value = SimpleNamespace(data=[{'id': 'conversation-1'}])
    result = photos.format_photo_answer(identified=[item()], inventory=[item()], photo_url=URL)
    result['answer_context']['photo_path'] = PATH
    with patch.object(ai, 'get_supabase_admin', return_value=client), \
         patch.object(ai, 'check_and_increment_scan') as scan, patch.object(ai, 'check_and_increment_chat') as chat, \
         patch.object(ai, 'answer_photo_question', new=AsyncMock(return_value=result)) as answer, \
         patch.object(ai, 'remember_photo_answer') as memory:
        yield SimpleNamespace(client=client, scan=scan, chat=chat, answer=answer, memory=memory)


def post(data=None, content=None):
    return api_client().post('/ai_photo_question', files={'file': ('untrusted.exe', image() if content is None else content, 'application/octet-stream')}, data=data or {})


def test_photo_route_auth_required_before_processing(route_io):
    response = api_client(False).post('/ai_photo_question', files={'file': ('p.jpg', image())})
    assert response.status_code == 401
    route_io.answer.assert_not_called()


@pytest.mark.parametrize('content,status', [(b'', 400), (b'not-a-photo', 400), (b'x' * (10*1024*1024+1), 413)])
def test_invalid_uploads_do_not_consume_quota_or_create_conversations(route_io, content, status):
    response = post(content=content)
    assert response.status_code == status
    route_io.scan.assert_not_called()
    route_io.client.table.assert_not_called()
    route_io.answer.assert_not_called()


def test_photo_route_normalizes_bytes_not_filename_and_saves_snapshot(route_io):
    response = post(data={'message': 'What is this?'})
    assert response.status_code == 200
    assert 'Reading your photo' in response.text and '"type": "done"' in response.text
    jpeg = route_io.answer.call_args.kwargs['image_bytes']
    assert Image.open(io.BytesIO(jpeg)).format == 'JPEG'
    route_io.scan.assert_called_once_with('user-1')
    route_io.chat.assert_called_once_with('user-1')
    saved = [call.args[0] for call in route_io.client.table.return_value.insert.call_args_list if call.args[0].get('role')]
    assert saved[0]['role'] == 'user'
    assert saved[1]['answer_context']['photo_path'] == PATH
    route_io.memory.assert_called_once()


def test_oversized_dimensions_rejected_before_processing(route_io):
    output = io.BytesIO()
    Image.new('RGB', (5100, 5000)).save(output, format='PNG')
    assert post(content=output.getvalue()).status_code == 400
    route_io.scan.assert_not_called()
    route_io.answer.assert_not_called()


def test_question_is_bounded_and_invalid_requests_do_not_consume_quota(route_io):
    assert post({'message': 'x' * 2001}).status_code == 422
    route_io.scan.assert_not_called()


def test_photo_followup_state_retains_question_and_grounded_answer():
    state = ai_agent._SessionState()
    with patch.object(ai_agent, '_get_state', return_value=state), patch.object(ai_agent, '_persist_state') as persist:
        photos.remember_photo_answer(user_id='user-1', message='What is this?', answer='A servo; no confirmed match.')
    assert state.conversation_history[-1]['content'] == 'A servo; no confirmed match.'
    assert '[Attached photo]' in state.conversation_history[-2]['content']
    persist.assert_called_once_with('user-1')


def test_foreign_conversation_rejected_before_quota_or_analysis(route_io):
    query = route_io.client.table.return_value
    query.execute.return_value = SimpleNamespace(data=[])
    response = post({'conversation_id': 'foreign'})
    assert response.status_code == 404
    assert any(call.args == ('user_id', 'user-1') for call in query.eq.call_args_list)
    query.insert.assert_not_called()
    route_io.scan.assert_not_called()
    route_io.answer.assert_not_called()


def test_photo_quota_failure_does_not_analyze_or_upload(route_io):
    route_io.scan.side_effect = ScanLimitExceeded(resets_at='2026-10-01', current=10, limit=10)
    assert post().status_code == 403
    route_io.answer.assert_not_called()


@pytest.mark.parametrize('error,code', [(FindPipelineError('SECRET', status_code=504), 'photo_timeout'), (RuntimeError('SECRET'), 'photo_failed')])
def test_photo_failures_safe_and_never_emit_done_metadata(route_io, error, code):
    route_io.answer.side_effect = error
    response = post()
    assert code in response.text and 'SECRET' not in response.text
    assert '"type": "done"' not in response.text


def test_failed_photo_snapshot_is_visible_and_not_remembered(route_io):
    query = route_io.client.table.return_value
    def insert(row):
        if row.get('role') == 'assistant':
            raise RuntimeError('SECRET snapshot failure')
        return query
    query.insert.side_effect = insert
    response = post()
    assert 'history_save_failed' in response.text and 'SECRET' not in response.text
    assert '"type": "done"' not in response.text
    route_io.memory.assert_not_called()
