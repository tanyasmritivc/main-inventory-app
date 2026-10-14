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
    assert 'Your inventory lists these products' in result['assistant_message']
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
    assert 'I am not certain' in text and 'does not mean you do not own' in text
    assert 'Review on Home' not in text and 'No inventory item has been added' in text


def test_zero_stock_and_output_has_no_private_fields():
    result = photos.format_photo_answer(identified=[item()], inventory=[item(quantity=0, user_id='SECRET', internal_model='SECRET')], photo_url=URL)
    assert '0 units available' in result['assistant_message']
    assert 'SECRET' not in json.dumps(result)


def test_empty_and_large_photo_results_are_explicitly_bounded():
    assert 'could not identify' in photos.format_photo_answer(identified=[], inventory=[], photo_url=URL)['assistant_message']
    result = photos.format_photo_answer(identified=[item(name=f'Servo type {i}') for i in range(21)], inventory=[item()], photo_url=URL)
    assert 'Showing 6 of 21 distinct item types' in result['assistant_message']
    assert 'Servo type 6' not in result['assistant_message']
    assert len(result['answer_context']['rows']) == 1


def test_repeated_fragments_do_not_become_repeated_objects_or_stock_totals():
    result = photos.format_photo_answer(identified=[item() for _ in range(30)], inventory=[item()], photo_url=URL)
    text = result['assistant_message']
    assert text.count('- Servo (') == 1
    assert text.count('2 units available') == 1
    assert '30' not in text and 'additional' not in text
    assert len(result['answer_context']['rows']) == 1


@pytest.mark.parametrize('name', ['Unknown', 'unknown object', 'Unidentified item', 'Object', 'Item', ''])
def test_generic_unknown_labels_never_match_inventory_by_name(name):
    photo = item(name=name, barcode='', brand='', part_number='', scan_evidence={'needs_review': True})
    assert photos._match(photo, item(name=name)) is None
    result = photos.format_photo_answer(identified=[photo], inventory=[item(name=name)], photo_url=URL)
    assert 'could not identify the contents' in result['assistant_message']
    assert 'Possible name matches' not in result['assistant_message']
    assert result['answer_context']['rows'] == []


def test_noisy_scene_has_one_inventory_check_and_one_uncertainty_explanation():
    names = ['blueberry toast', 'banana dessert', 'banana slice', 'sliced banana',
             'plastic bag', 'aluminum foil', 'bubble wrap', 'unknown object', 'unknown']
    identified = [item(name=name, barcode='', brand='', part_number='', category='Supplies',
                       scan_evidence={'needs_review': True}) for name in names] * 3
    inventory = [item(item_id=str(i), name='Other saved part') for i in range(637)]
    result = photos.format_photo_answer(identified=identified, inventory=inventory, photo_url=URL)
    text = result['assistant_message']
    assert text.count('Inventory check') == 1
    assert text.count('No matching saved items found') == 1
    assert text.count('The uncertain labels are guesses') == 1
    assert 'Category:' not in text and '637' not in text and 'unknown object' not in text
    assert 'Showing 6 of 7 distinct item types' in text
    assert len(text) < 900
    assert '637 accessible item records' in result['answer_context']['sources'][1]['detail']


def noisy_scene():
    return [item(name=name, barcode='', brand='', part_number='',
                 scan_evidence={'needs_review': True}, notes='PRIVATE NOTES', image_url='https://private.test')
            for name in ['blueberry toast', 'banana dessert', 'banana slice', 'sliced banana', 'plastic bag', 'aluminum foil']]


def test_scene_consolidation_only_selects_existing_labels_and_omits_overlapping_guesses():
    identified = noisy_scene()
    reply = SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content='{"indices": [0, 2]}'))])
    with patch.object(photos, 'gateway_completion', return_value=reply) as gateway:
        subjects = photos.select_photo_subjects(identified)
    assert subjects == [identified[0], identified[2]]
    request = gateway.call_args.kwargs
    assert request['request_timeout_seconds'] == 12
    assert 'tools' not in request
    assert 'PRIVATE' not in json.dumps(request) and 'https://' not in json.dumps(request)
    result = photos.format_photo_answer(identified=identified, subjects=subjects, inventory=[], photo_url=URL)
    text = result['assistant_message']
    assert 'blueberry toast' in text and 'banana slice' in text
    assert 'banana dessert' not in text and 'sliced banana' not in text
    assert 'plastic bag' not in text and 'aluminum foil' not in text
    assert text.count('No matching saved items found') == 1
    assert 'conflicting detections were left out' in text


@pytest.mark.parametrize('content', ['not json', '{"indices": [999]}', '{"indices": [-1]}',
                                     '{"indices": [true]}', '{"indices": [0, 0]}',
                                     '{"indices": [0, 1, 2, 3]}', '{"summary": "Invented object"}'])
def test_invalid_scene_selection_falls_back_without_generated_identities(content):
    reply = SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=content))])
    with patch.object(photos, 'gateway_completion', return_value=reply):
        assert photos.select_photo_subjects(noisy_scene()) is None


def test_unavailable_consolidation_keeps_deterministic_photo_results():
    with patch.object(photos, 'gateway_completion', side_effect=TimeoutError):
        assert photos.select_photo_subjects(noisy_scene()) is None


def test_incoherent_scene_does_not_turn_any_guess_into_a_product_match():
    result = photos.format_photo_answer(identified=noisy_scene(), subjects=[], inventory=[item(name='banana slice')], photo_url=URL)
    assert 'could not identify the contents' in result['assistant_message']
    assert result['answer_context']['rows'] == []


def test_scene_selection_skips_single_items_and_product_identifiers():
    with patch.object(photos, 'gateway_completion') as gateway:
        assert photos.select_photo_subjects([item()]) is None
        assert photos.select_photo_subjects([*noisy_scene(), item()]) is None
    gateway.assert_not_called()


def test_noisy_photo_service_returns_consolidated_reply_through_existing_contract():
    reply = SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content='{"indices": [0, 2]}'))])
    with patch.object(photos, 'upload_image', return_value=StoredImage(PATH, URL)), \
         patch.object(photos, 'extract_inventory_items_with_find', new=AsyncMock(return_value={'items': noisy_scene()})), \
         patch.object(photos, 'enrich_scan_items_from_verified_catalog', side_effect=lambda rows: rows), \
         patch.object(photos, 'accessible_inventory', return_value=[]), \
         patch.object(photos, 'gateway_completion', return_value=reply) as gateway:
        result = asyncio.run(photos.answer_photo_question(user_id='user-1', message='What is in this photo, and do I own it?', image_bytes=image()))
    assert 'banana dessert' not in result['assistant_message'] and 'plastic bag' not in result['assistant_message']
    assert 'banana slice' in result['assistant_message']
    assert result['answer_context']['photo_path'] == PATH
    assert result['answer_context']['photo_url'] == URL
    assert result['answer_context']['rows'] == []
    gateway.assert_called_once()


def test_clear_identifications_precede_uncertain_fragments_without_confirming_them():
    weak = [item(name=f'Guess {i}', scan_evidence={'needs_review': True}) for i in range(10)]
    clear = item(name='Known motor', confidence=0.95)
    result = photos.format_photo_answer(identified=[*weak, clear], inventory=[item()], photo_url=URL)
    text = result['assistant_message']
    assert text.index('Known motor') < text.index('Guess 0')
    assert 'Guess 0 (uncertain' in text


def test_same_named_products_with_different_identifiers_remain_distinct():
    first = item(name='Motor', barcode='', part_number='M-1')
    second = item(name='Motor', barcode='', part_number='M-2')
    inventory = [first, {**second, 'item_id': 'b', 'quantity': 4}]
    result = photos.format_photo_answer(identified=[first, second], inventory=inventory, photo_url=URL)
    assert len(result['answer_context']['rows']) == 2
    assert 'Part: M-1' in result['assistant_message'] and 'Part: M-2' in result['assistant_message']
    assert '2 units available' in result['assistant_message'] and '4 units available' in result['assistant_message']


def test_low_confidence_cannot_confirm_stock_even_without_review_flag():
    photo = item(confidence=0.3)
    result = photos.format_photo_answer(identified=[photo], inventory=[item()], photo_url=URL)
    assert 'Possible name matches' in result['assistant_message']
    assert 'units available' not in result['assistant_message']


def test_measurements_are_shown_only_when_requested_and_keep_estimate_caveat():
    photo = item(scan_evidence={'length_mm': 123, 'width_mm': 45})
    normal = photos.format_photo_answer(identified=[photo], inventory=[], photo_url=URL)
    measured = photos.format_photo_answer(identified=[photo], inventory=[], photo_url=URL, message='How wide is this?')
    assert '123 x 45' not in normal['assistant_message']
    assert 'estimated 123 x 45 mm' in measured['assistant_message']
    assert 'check with a ruler' in measured['assistant_message']


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
def test_photo_service_checks_inventory_without_creating_reviews(message):
    uncertain = item(scan_evidence={'needs_review': True})
    with patch.object(photos, 'upload_image', return_value=StoredImage(PATH, URL)) as upload, \
         patch.object(photos, 'extract_inventory_items_with_find', new=AsyncMock(return_value={'items': [uncertain]})) as extract, \
         patch.object(photos, 'enrich_scan_items_from_verified_catalog', side_effect=lambda rows: rows), \
         patch('app.services.review_queue.enqueue_uncertain_items') as review, \
         patch.object(photos, 'accessible_inventory', return_value=[]) as inventory, \
         patch.object(photos, 'gateway_completion') as gateway:
        result = asyncio.run(photos.answer_photo_question(user_id='user-1', message=message, image_bytes=image()))
    assert upload.call_args.kwargs['user_id'] == 'user-1'
    assert upload.call_args.kwargs['filename'].startswith('ask-')
    assert 'include_measurements' not in extract.call_args.kwargs
    assert extract.call_args.kwargs['source_frame_url'] == URL
    review.assert_not_called()
    assert 'ownership is not confirmed' in uncertain['notes']
    inventory.assert_called_once_with('user-1')
    gateway.assert_not_called()
    assert result['answer_context']['photo_path'] == PATH


def test_failed_analysis_cleans_only_new_source_before_review():
    with patch.object(photos, 'upload_image', return_value=StoredImage(PATH, URL)), \
         patch.object(photos, 'extract_inventory_items_with_find', new=AsyncMock(side_effect=FindPipelineError('SECRET'))), \
         patch.object(photos, 'delete_image') as delete, patch('app.services.review_queue.enqueue_uncertain_items') as review:
        with pytest.raises(FindPipelineError):
            asyncio.run(photos.answer_photo_question(user_id='user-1', message='What is this?', image_bytes=image()))
    delete.assert_called_once_with(path=PATH)
    review.assert_not_called()


@pytest.mark.parametrize('question,explain', [('Add this photo item', False), ('How does this work?', True)])
def test_photo_requests_use_no_mutation_tools_and_keep_grounded_check(question, explain):
    reply = SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content='A servo controls position\u2014using feedback.'))])
    with patch.object(photos, 'upload_image', return_value=StoredImage(PATH, URL)), \
         patch.object(photos, 'extract_inventory_items_with_find', new=AsyncMock(return_value={'items': [item()]})), \
         patch.object(photos, 'enrich_scan_items_from_verified_catalog', side_effect=lambda rows: rows), \
         patch.object(photos, 'accessible_inventory', return_value=[]), patch.object(photos, 'gateway_completion', return_value=reply) as gateway:
        result = asyncio.run(photos.answer_photo_question(user_id='user-1', message=question, image_bytes=image()))
    if explain:
        assert 'tools' not in gateway.call_args.kwargs
        assert 'controls position - using feedback' in result['assistant_message']
        assert 'Do not use em dashes' in gateway.call_args.kwargs['messages'][0]['content']
    else:
        gateway.assert_not_called()
        assert 'confirm the change' in result['assistant_message']
    assert 'No inventory item' in result['assistant_message']
    assert '\u2014' not in result['assistant_message']


def test_unknown_only_photo_does_not_generate_an_explanation_from_missing_identity():
    unknown = item(name='Unknown object', scan_evidence={'needs_review': True})
    with patch.object(photos, 'upload_image', return_value=StoredImage(PATH, URL)), \
         patch.object(photos, 'extract_inventory_items_with_find', new=AsyncMock(return_value={'items': [unknown]})), \
         patch.object(photos, 'enrich_scan_items_from_verified_catalog', side_effect=lambda rows: rows), \
         patch.object(photos, 'accessible_inventory', return_value=[]), patch.object(photos, 'gateway_completion') as gateway:
        result = asyncio.run(photos.answer_photo_question(user_id='user-1', message='How does this work?', image_bytes=image()))
    gateway.assert_not_called()
    assert 'could not identify the contents' in result['assistant_message']


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
