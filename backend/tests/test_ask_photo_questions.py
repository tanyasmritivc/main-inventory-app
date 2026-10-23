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

@pytest.fixture(autouse=True)
def saved_gallery_io():
    # Dedicated saved-photo tests exercise pixels/storage; keep routing tests hermetic.
    with patch.object(photos, 'search_saved_photos', new=AsyncMock(return_value={
        'matches': [], 'photos_checked': 0, 'photos_available': 0, 'complete': True,
    })) as search:
        yield search


PATH = 'user-1/ask-' + 'a' * 32 + '.jpg'
URL = 'https://api.test/storage/v1/object/public/item-images/' + PATH


def image():
    output = io.BytesIO()
    Image.new('RGB', (32, 32), 'red').save(output, format='PNG')
    return output.getvalue()


def item(**changes):
    return {'item_id': 'a', 'name': 'Servo', 'brand': 'Acme', 'part_number': 'S-1',
            'barcode': '12345678', 'quantity': 2, 'location': 'Garage', **changes}




@pytest.mark.parametrize('photo,expected', [
    (item(barcode='', part_number=''), 'possible name match'),
    (item(barcode='', name='Different'), 'brand and part-number match'),
    (item(scan_evidence={'needs_review': True}), 'possible name match'),
    (item(barcode='1', part_number='', name='Object'), None),
    (item(barcode='', part_number='S-1', brand='Different', name='Other'), None),
])
def test_weak_names_short_codes_and_uncertainty_cannot_confirm_product(photo, expected):
    assert photos._match(photo, item()) == expected












@pytest.mark.parametrize('name', ['Unknown', 'unknown object', 'Unidentified item', 'Object', 'Item', ''])
def test_generic_unknown_labels_never_match_inventory_by_name(name):
    photo = item(name=name, barcode='', brand='', part_number='', scan_evidence={'needs_review': True})
    assert photos._match(photo, item(name=name)) is None
    result = photos.photo_evidence(identified=[photo], inventory=[item(name=name)], photo_url=URL)
    assert result['unidentified_observations'] is True
    assert result['observations'] == []
    assert result['answer_context']['rows'] == []




def noisy_scene():
    return [item(name=name, barcode='', brand='', part_number='',
                 scan_evidence={'needs_review': True}, notes='PRIVATE NOTES', image_url='https://private.test')
            for name in ['blueberry toast', 'banana dessert', 'banana slice', 'sliced banana', 'plastic bag', 'aluminum foil']]






















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




def test_failed_analysis_cleans_only_new_source_before_review():
    with patch.object(photos, 'upload_image', return_value=StoredImage(PATH, URL)), \
         patch.object(photos, 'extract_inventory_items_with_find', new=AsyncMock(side_effect=FindPipelineError('SECRET'))), \
         patch.object(photos, 'delete_image') as delete, patch('app.services.review_queue.enqueue_uncertain_items') as review:
        with pytest.raises(FindPipelineError):
            asyncio.run(photos.answer_photo_question(user_id='user-1', message='What is this?', image_bytes=image()))
    delete.assert_called_once_with(path=PATH)
    review.assert_not_called()






@pytest.mark.parametrize('path', ['other-user/ask-' + 'a'*32 + '.jpg', 'user-1/../photo.jpg', 'user-1/photo.jpg', None])
def test_history_never_signs_foreign_or_arbitrary_photo_paths(path):
    with patch.object(photos, 'get_supabase_admin') as storage:
        result = photos.refresh_photo_context({'photo_path': path, 'photo_url': 'https://evil.test/tracker'}, 'user-1')
    storage.assert_not_called()
    assert 'photo_url' not in result and 'photo_path' not in result


def test_history_refreshes_authenticated_photo_locator_from_owned_path():
    client = MagicMock()
    client.storage.from_.return_value.get_public_url.return_value = 'http://storage.internal/storage/v1/object/public/item-images/' + PATH
    settings = SimpleNamespace(supabase_storage_bucket='item-images', supabase_storage_public=False, supabase_storage_signed_url_ttl_seconds=3600, supabase_public_url='https://api.test')
    with patch.object(photos, 'get_settings', return_value=settings), patch.object(photos, 'get_supabase_admin', return_value=client):
        result = photos.refresh_photo_context({'photo_path': PATH, 'photo_url': 'https://evil.test'}, 'user-1')
    assert result['photo_url'].startswith('https://api.test/storage/')
    client.storage.from_.return_value.get_public_url.assert_called_once_with(PATH)
    client.storage.from_.return_value.create_signed_url.assert_not_called()


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
    result = photos.photo_evidence(identified=[item()], inventory=[item()], photo_url=URL)
    result = {'assistant_message': 'Model photo answer.', 'answer_context': result['answer_context']}
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

@pytest.mark.parametrize('identified',[[item()],noisy_scene(),[item(name='Unknown object',scan_evidence={'needs_review':True})],[]])
@pytest.mark.parametrize('question',['What is this? Do I own it?','How does this work?','Add this item'])
def test_every_photo_question_gets_its_answer_from_model(identified,question):
    reply=SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content='A model-written photo answer.'))])
    with patch.object(photos,'upload_image',return_value=StoredImage(PATH,URL)),patch.object(photos,'extract_inventory_items_with_find',new=AsyncMock(return_value={'items':identified})),patch.object(photos,'enrich_scan_items_from_verified_catalog',side_effect=lambda rows:rows),patch.object(photos,'accessible_inventory',return_value=[item()]),patch.object(photos,'gateway_completion',return_value=reply) as model,patch.object(photos,'load_preferences',return_value={'answer_format':'bullets'}),patch('app.services.review_queue.enqueue_uncertain_items') as enqueue:
        result=asyncio.run(photos.answer_photo_question(user_id='user-1',message=question,image_bytes=image()))
    model.assert_called_once()
    assert result['assistant_message']=='A model-written photo answer.'
    assert result['answer_context']['photo_path']==PATH
    payload=model.call_args.kwargs
    assert 'tools' not in payload
    assert question in payload['messages'][1]['content']
    assert 'Use a bullet list' in payload['messages'][0]['content']
    assert URL not in json.dumps(payload) and 'PRIVATE NOTES' not in json.dumps(payload)
    enqueue.assert_not_called()


@pytest.mark.parametrize('failure',['exception','empty'])
def test_photo_model_failure_has_no_scripted_answer_and_cleans_preview(failure):
    reply=SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=''))])
    with patch.object(photos,'upload_image',return_value=StoredImage(PATH,URL)),patch.object(photos,'extract_inventory_items_with_find',new=AsyncMock(return_value={'items':[item()]})),patch.object(photos,'enrich_scan_items_from_verified_catalog',side_effect=lambda rows:rows),patch.object(photos,'accessible_inventory',return_value=[]),patch.object(photos,'gateway_completion',return_value=reply,side_effect=RuntimeError('PRIVATE') if failure=='exception' else None) as model,patch.object(photos,'load_preferences',return_value={}),patch.object(photos,'delete_image') as delete:
        with pytest.raises(RuntimeError): asyncio.run(photos.answer_photo_question(user_id='user-1',message='What is this?',image_bytes=image()))
    model.assert_called_once()
    delete.assert_called_once_with(path=PATH)


def test_photo_evidence_keeps_matching_counts_and_never_writes_prose():
    evidence=photos.photo_evidence(identified=[item()]*30,inventory=[item(),item(item_id='b',quantity=3,location='Loft')],photo_url=URL)
    assert len(evidence['observations'])==1
    assert len(evidence['answer_context']['rows'])==2
    assert sorted(row['available_quantity'] for row in evidence['answer_context']['rows'])==[2,3]
    assert 'assistant_message' not in evidence
    assert evidence['inventory_changed'] is False


def test_existing_entry_photo_request_supplies_truthful_actions_and_keeps_model_answer():
    from app.services.inventory_scope import InventoryScope, current_inventory
    reply = SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content='I cannot attach this photo to all Garage entries from Chat. Open an existing item and use Add photo.'))])
    token = current_inventory.set(InventoryScope('inventory', 'actor', 'owner', None, 'viewer'))
    try:
        with patch.object(photos,'upload_image',return_value=StoredImage(PATH,URL)),patch.object(photos,'extract_inventory_items_with_find',new=AsyncMock(return_value={'items':[item()]})),patch.object(photos,'enrich_scan_items_from_verified_catalog',side_effect=lambda rows:rows),patch.object(photos,'accessible_inventory',return_value=[]),patch.object(photos,'gateway_completion',return_value=reply) as model,patch.object(photos,'load_preferences',return_value={}):
            result=asyncio.run(photos.answer_photo_question(user_id='user-1',message='add this to all the entries in garage',image_bytes=image()))
    finally:
        current_inventory.reset(token)
    payload=json.loads(model.call_args.kwargs['messages'][1]['content'].split('\nEvidence: ',1)[1])
    assert payload['available_actions']['attach_photo_from_chat'] is False
    assert payload['available_actions']['bulk_attach_photo_from_chat'] is False
    assert payload['available_actions']['can_edit_selected_inventory'] is False
    assert result['assistant_message']==reply.choices[0].message.content


@pytest.mark.parametrize('quantity',[None,-1,0.5,True,float('nan')])
def test_photo_evidence_does_not_convert_unknown_quantity_to_zero(quantity):
    evidence=photos.photo_evidence(identified=[item()],inventory=[item(quantity=quantity)],photo_url=URL)
    assert evidence['answer_context']['rows'][0]['available_quantity'] is None


def test_uncertain_photo_and_distinct_identifiers_preserve_evidence():
    photo=item(confidence=0.3,scan_evidence={'length_mm':123,'width_mm':45})
    evidence=photos.photo_evidence(identified=[photo],inventory=[item()],photo_url=URL)
    assert evidence['observations'][0]['uncertain'] is True
    assert evidence['observations'][0]['matches'][0]['match_basis']=='possible name match'
    assert evidence['observations'][0]['length_mm']==123
    evidence=photos.photo_evidence(identified=[item(barcode='',part_number='M1'),item(barcode='',part_number='M2')],inventory=[],photo_url=URL)
    assert len(evidence['observations'])==2
