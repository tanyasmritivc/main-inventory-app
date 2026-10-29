"""Hermetic transport checks: real routes, no real identities or provider calls."""
import asyncio
import io
import json
from contextlib import ExitStack
from types import SimpleNamespace as NS
from unittest.mock import AsyncMock, Mock, patch
from uuid import uuid4
import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from PIL import Image
from app.api.routes import world_chat as route
from app.core.auth import AuthenticatedUser, get_current_user
from app.services import world_chat as world
from app.services.inventory_scope import current_inventory
from app.services.limits import ChatLimitExceeded

ACTOR, WORLD, CID = [str(uuid4()) for _ in range(3)]

@pytest.fixture
def transport():
    app = FastAPI()
    app.include_router(route.router)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(user_id=ACTOR)
    with ExitStack() as stack:
        authorize = stack.enter_context(patch.object(world, 'authorize', side_effect=lambda a, k: k))
        prepare = stack.enter_context(patch.object(world, 'prepare', return_value=(CID, [])))
        save = stack.enter_context(patch.object(world, 'save_answer'))
        stack.enter_context(patch.object(world, 'latest_photo', return_value=None))
        stack.enter_context(patch('app.services.chat_vision.retain'))
        stack.enter_context(patch.object(route, 'check_and_increment_chat'))
        yield NS(client=TestClient(app), authorize=authorize, prepare=prepare, save=save)

def events():
    yield {'type': 'delta', 'delta': 'Review this plan.'}
    yield {'type': 'done', 'assistant_message': 'Review this plan.', 'conversation_id': CID,
        'answer_context': {'world_actions': [{'id': 'review', 'status': 'pending'}]}}

def test_stream_receipt_is_saved_before_done_and_uses_private_world(transport):
    with patch.object(world, 'stream_turn', return_value=events()):
        response = transport.client.post(f'/worlds/{WORLD}/ai_command', json={'message': 'Organize my shelf'})
    assert response.status_code == 200
    assert response.headers['x-accel-buffering'] == 'no'
    assert response.headers['cache-control'] == 'no-store, no-transform'
    assert '"type": "delta"' in response.text and '"type": "done"' in response.text
    transport.prepare.assert_called_once_with(ACTOR, WORLD, 'Organize my shelf', None)
    transport.save.assert_called_once_with(ACTOR, WORLD, CID, 'Review this plan.',
        {'world_actions': [{'id': 'review', 'status': 'pending'}]})

def test_failed_durable_save_never_delivers_an_action_card(transport):
    transport.save.side_effect = RuntimeError('SECRET backend failure')
    with patch.object(world, 'stream_turn', return_value=events()):
        response = transport.client.post(f'/worlds/{WORLD}/ai_command', json={'message': 'Create it'})
    assert '"type": "done"' not in response.text
    assert '"type": "error"' in response.text
    assert 'SECRET' not in response.text and 'world_actions' not in response.text
    assert '"type": "delta"' not in response.text

def test_membership_and_allowance_failure_happen_before_conversation_write(transport):
    transport.authorize.side_effect = HTTPException(403, 'Access denied')
    response = transport.client.post(f'/worlds/{WORLD}/ai_command', json={'message': 'Hello'})
    assert response.status_code == 403
    transport.prepare.assert_not_called()
    transport.authorize.side_effect = lambda a, k: k
    with patch.object(route, 'check_and_increment_chat', side_effect=ChatLimitExceeded(resets_at='2026-11-01', current=10, limit=10)):
        response = transport.client.post(f'/worlds/{WORLD}/ai_command', json={'message': 'Hello'})
    assert response.status_code == 403
    transport.prepare.assert_not_called()

def test_malformed_photo_does_not_reach_ai_or_create_conversation(transport):
    response = transport.client.post(f'/worlds/{WORLD}/ai_photo_question', files={'file': ('bad.jpg', b'not-image', 'image/jpeg')})
    assert response.status_code == 422
    transport.prepare.assert_not_called()

def test_ordinary_photo_goes_directly_to_chat_without_find_or_scan(transport):
    out = io.BytesIO(); Image.new('RGB', (30, 30), 'orange').save(out, format='PNG')
    stored = NS(path=f'{ACTOR}/ask-' + 'a'*32 + '.jpg', url='https://api.test/private.jpg')
    with patch.object(route, 'check_and_increment_scan') as scan, \
         patch('app.services.storage.upload_image', return_value=stored), \
         patch('app.services.storage.delete_image') as cleanup, \
         patch('app.services.photo_extraction.extract_inventory_items') as find, \
         patch.object(world, 'photo_matches') as gallery, \
         patch.object(world, 'stream_turn', return_value=events()) as stream:
        response = transport.client.post(f'/worlds/{WORLD}/ai_photo_question', data={'message': 'Read this label'}, files={'file': ('motor.png', out.getvalue(), 'image/png')})
    assert '"type": "done"' in response.text
    assert stream.call_args.kwargs['image_content']['image_url']['url'].startswith('data:image/jpeg;base64,')
    assert transport.save.call_args.args[-1]['chat_photo']['mode'] == 'chat'
    find.assert_not_called(); gallery.assert_not_called(); scan.assert_not_called(); cleanup.assert_not_called()

def test_concurrent_photo_search_keeps_inventory_scope_isolated():
    ids = [str(uuid4()) for _ in range(4)]
    def scope(actor, key, inventory):
        return {'inventory_id': inventory, 'owner_user_id': actor, 'team_id': None, 'role': 'owner', 'name': inventory}
    def read(**kwargs):
        return [{'item_id': current_inventory.get().inventory_id, 'name': 'Motor'}]
    async def match(**kwargs):
        inventory = current_inventory.get().inventory_id
        await asyncio.sleep(.005)
        assert current_inventory.get().inventory_id == inventory
        assert kwargs['inventory'][0]['item_id'] == inventory
        return {'matches': [{'item_id': inventory}], 'photos_checked': 1, 'photos_available': 1, 'complete': True}
    with patch.object(world, 'directory', return_value={'inventories': [{'inventory_id': i} for i in ids]}), \
         patch.object(world, 'inventory_scope', side_effect=scope), \
         patch('app.services.ai_agent._current_items', side_effect=read), \
         patch('app.services.saved_photo_search.search_saved_photos', side_effect=match):
        result = asyncio.run(world.photo_matches(ACTOR, WORLD, b'image'))
    assert {m['inventory_id'] for m in result['matches']} == set(ids)
    assert result['all_inventories_checked']
    assert current_inventory.get() is None


def test_direct_photo_retained_before_failed_reply_and_followup_has_pixels(transport):
    out = io.BytesIO(); Image.new('RGB', (30, 30), 'orange').save(out, format='PNG')
    stored = NS(path=f'{ACTOR}/ask-test.jpg', url='https://api.test/private.jpg')
    with patch('app.services.storage.upload_image', return_value=stored), \
         patch('app.services.storage.delete_image') as cleanup, \
         patch('app.services.chat_vision.retain') as retain, \
         patch.object(world, 'stream_turn', side_effect=RuntimeError('failed')):
        response = transport.client.post(f'/worlds/{WORLD}/ai_photo_question', data={'message':'Read it','supports_task_actions':'true'}, files={'file': ('photo.png', out.getvalue(), 'image/png')})
    assert '"type": "error"' in response.text
    retain.assert_called_once(); cleanup.assert_not_called()
    with patch.object(world,'latest_photo',return_value={'mode':'chat','items':[],'source_path':stored.path,'source_url':stored.url}), \
         patch('app.services.chat_vision.retained_image',return_value={'type':'image_url','image_url':{'url':'data:image/jpeg;base64,abc'}}) as read, \
         patch.object(world,'stream_turn',return_value=events()) as stream:
        result=transport.client.post(f'/worlds/{WORLD}/ai_command',json={'message':'What color is it?','conversation_id':CID})
    assert '"type": "done"' in result.text
    read.assert_called_once()
    assert stream.call_args.kwargs['image_content']['type']=='image_url'

def test_resource_route_validates_ids_and_forwards_actor_world(transport):
    inv, item = str(uuid4()), str(uuid4())
    with patch.object(world, 'resolve_resource', return_value={'kind': 'item'}) as resolve:
        assert transport.client.get(f'/worlds/{WORLD}/resources/{inv}/item/{item}').status_code == 200
        resolve.assert_called_once_with(ACTOR, WORLD, inv, 'item', item)
        assert transport.client.get(f'/worlds/{WORLD}/resources/bad/item/{item}').status_code == 422

@pytest.mark.parametrize('supported', [False, True])
def test_transport_negotiates_management_card_support(transport, supported):
    with patch.object(world, 'stream_turn', return_value=events()) as stream:
        payload = {'message': 'Hello'}
        if supported: payload['supports_item_management'] = True
        response = transport.client.post(f'/worlds/{WORLD}/ai_command', json=payload)
    assert response.status_code == 200
    assert stream.call_args.kwargs['supports_item_management'] is supported


def test_capture_is_durable_and_visible_before_model_reply_without_gallery_delay(transport):
    from app.services import chat_capture as capture
    out = io.BytesIO(); Image.new('RGB', (30, 30), 'orange').save(out, format='PNG')
    draft = {'id': str(uuid4()), 'version': 1, 'revision': 1, 'status': 'draft', 'items': [], 'source_url': 'https://api.test/private.jpg'}
    def stream(*args, **kwargs):
        assert capture.current_capture.get()['draft'] == draft
        yield {'type': 'delta', 'delta': 'Choose a Space.'}
        yield {'type': 'done', 'assistant_message': 'Choose a Space.', 'conversation_id': CID,
               'answer_context': {'chat_capture_id': draft['id']}}
    with patch.object(route, 'check_and_increment_scan'), \
         patch('app.services.storage.upload_image', return_value=NS(path='private/photo', url='https://api.test/private.jpg')), \
         patch('app.services.photo_extraction.extract_inventory_items', new=AsyncMock(return_value={'items': []})), \
         patch.object(capture, 'create', return_value=draft) as create, \
         patch.object(world, 'photo_matches') as gallery, \
         patch.object(world, 'stream_turn', side_effect=stream):
        response = transport.client.post(f'/worlds/{WORLD}/ai_photo_question', data={'message': 'Auto extract', 'supports_capture': 'true', 'auto_extract': 'true'}, files={'file': ('photo.png', out.getvalue(), 'image/png')})
    assert response.text.index('"type": "capture"') < response.text.index('"type": "delta"')
    create.assert_called_once(); gallery.assert_not_called()
    assert '"type": "done"' in response.text
    assert 'chat_capture' in response.text
    assert capture.current_capture.get() is None


def test_capture_survives_a_failed_model_reply_after_extraction(transport, caplog):
    from app.services import chat_capture as capture
    out = io.BytesIO(); Image.new('RGB', (30, 30), 'orange').save(out, format='PNG')
    draft = {'id': str(uuid4()), 'version': 1, 'revision': 1, 'status': 'draft', 'items': [], 'source_url': 'https://api.test/private.jpg'}
    with patch.object(route, 'check_and_increment_scan'), \
         patch('app.services.storage.upload_image', return_value=NS(path='private/photo', url='https://api.test/private.jpg')), \
         patch('app.services.storage.delete_image') as cleanup, \
         patch('app.services.photo_extraction.extract_inventory_items', new=AsyncMock(return_value={'items': []})), \
         patch.object(capture, 'create', return_value=draft), \
         patch.object(world, 'stream_turn', side_effect=RuntimeError('SECRET provider detail')):
        response = transport.client.post(f'/worlds/{WORLD}/ai_photo_question', data={'supports_capture': 'true', 'auto_extract': 'true'}, files={'file': ('photo.png', out.getvalue(), 'image/png')})
    assert '"type": "capture"' in response.text and '"type": "error"' in response.text
    cleanup.assert_not_called()
    assert 'stage=chat_reply error_type=RuntimeError' in caplog.text
    assert 'SECRET' not in caplog.text and 'SECRET' not in response.text


def test_capture_followup_uses_same_conversation_and_missing_capability_is_compatible(transport):
    from app.services import chat_capture as capture
    draft = {'id': str(uuid4()), 'version': 1, 'revision': 1, 'status': 'draft', 'items': [], 'source_url': 'https://api.test/private.jpg'}
    with patch.object(capture, 'load', return_value={'answer_context': {'chat_capture': draft}}) as load, \
         patch.object(world, 'stream_turn', return_value=events()):
        response = transport.client.post(f'/worlds/{WORLD}/ai_command', json={'message': 'Only tools', 'conversation_id': CID, 'supports_capture': True})
    load.assert_called_once_with(ACTOR, WORLD, CID)
    assert '"type": "done"' in response.text


def test_spreadsheet_capture_has_no_destination_and_preserves_original_columns(transport):
    from app.services import chat_capture
    from app.services.spreadsheet_import import infer_import_mapping
    with patch('app.services.limits.check_and_increment_import'), \
         patch('app.services.usage_service.check_limit', new=AsyncMock(return_value={'allowed':True})), \
         patch('app.services.usage_service.increment_usage', new=AsyncMock()), \
         patch('app.services.spreadsheet_import.infer_import_mapping', return_value={'name_columns':['Name'], 'quantity_column':'Qty', 'category':'Tools'}), \
         patch.object(chat_capture, 'create', return_value={'status':'draft'}) as create:
        response = transport.client.post(f'/worlds/{WORLD}/captures/spreadsheet', files={'file':('items.csv',b'Name,Qty,Serial\nDrill,2,ABC-123\n','text/csv')})
    assert response.status_code == 200, response.text
    args = create.call_args.args
    assert args[:3] == (ACTOR, WORLD, CID)
    assert args[3][0]['name'] == 'Drill' and args[3][0]['quantity'] == 2
    assert args[3][0]['import_data']['fields'][-1] == {'name':'Serial','value':'ABC-123'}
    assert args[4] is None
    assert create.call_args.kwargs['source_kind'] == 'spreadsheet'


def test_barcode_capture_is_unknown_review_draft_without_stock_reads(transport):
    from app.schemas.inventory import BarcodeLookupResponse
    with patch('app.services.usage_service.check_limit', new=AsyncMock(return_value={'allowed':True})), \
         patch('app.api.routes.items.lookup_barcode_product', new=AsyncMock(return_value=BarcodeLookupResponse(name='Unknown item'))) as lookup, \
         patch('app.services.chat_capture.create', return_value={'status':'draft'}) as create:
        response = transport.client.post(f'/worlds/{WORLD}/captures/barcode', json={'barcode':'12345678'})
    assert response.status_code == 200, response.text
    lookup.assert_awaited_once_with('12345678', ACTOR)
    assert create.call_args.args[3][0]['scan_evidence']['needs_review'] is True
    assert create.call_args.kwargs['source_kind'] == 'barcode'


def test_capture_import_rejects_unauthorized_world_before_parse(transport):
    transport.authorize.side_effect = HTTPException(403, 'Access denied')
    with patch('app.services.spreadsheet_import.parse_import_tables') as parse:
        result = transport.client.post(f'/worlds/{WORLD}/captures/spreadsheet', files={'file':('items.csv', b'Name\nDrill', 'text/csv')})
    assert result.status_code == 403
    parse.assert_not_called(); transport.prepare.assert_not_called()


def test_extraction_activity_is_forwarded_before_the_draft(transport):
    from app.services import chat_capture as capture
    import asyncio
    out = io.BytesIO(); Image.new('RGB', (20, 20)).save(out, format='PNG')
    async def extract(**kwargs):
        kwargs['on_progress']('Finding objects in your photo…')
        await asyncio.sleep(.001)
        kwargs['on_progress']('Checking confidence and trimming item photos…')
        return {'items': [], 'summary': {}}
    with patch('app.services.storage.upload_image', return_value=NS(url='https://fixture.test/source', path='fixture/source')), \
         patch('app.services.photo_extraction.extract_inventory_items', side_effect=extract), \
         patch.object(capture, 'create', return_value={'id': 'draft', 'status': 'draft', 'items': []}), \
         patch.object(world, 'stream_turn', return_value=events()):
        response = transport.client.post(f'/worlds/{WORLD}/ai_photo_question',
            data={'supports_capture': 'true', 'auto_extract': 'true'}, files={'file': ('photo.png', out.getvalue(), 'image/png')})
    assert response.text.index('Finding objects') < response.text.index('Checking confidence') < response.text.index('"type": "capture"')

def test_done_returns_persisted_message_identifier(transport):
    transport.save.return_value={'message_id':str(uuid4()),'created_at':'2026-10-25T20:00:00Z'}
    with patch.object(world,'stream_turn',return_value=events()):
        response=transport.client.post(f'/worlds/{WORLD}/ai_command',json={'message':'hello'})
    assert transport.save.return_value['message_id'] in response.text
    assert transport.save.return_value['created_at'] in response.text

def test_response_retry_uses_original_prompt_and_read_only_mode(transport):
    mid,turn=str(uuid4()),str(uuid4())
    original={'conversation_id':CID,'content':'Answer','created_at':'2026-10-25T20:00:00Z','answer_context':{'world_actions':[{'id':'saved','status':'confirmed','receipt':{}}]}}
    db=Mock();q=Mock();db.table.return_value=q
    for name in ('select','eq','lte','order','limit'): getattr(q,name).return_value=q
    q.execute.return_value.data=[{'id':turn,'content':'Original prompt'}]
    with patch('app.services.response_feedback.owned_message',return_value=original),patch.object(world,'conversation'),patch.object(route,'get_supabase_raw',return_value=db),patch.object(world,'stream_turn',return_value=events()) as stream:
        response=transport.client.post(f'/worlds/{WORLD}/ai_command',json={'message':'Malicious replacement','conversation_id':CID,'retry_of':mid})
    assert response.status_code==200 and '"type": "done"' in response.text
    assert stream.call_args.args[2]=='Original prompt'
    assert stream.call_args.kwargs['read_only_retry'] is True
    assert transport.prepare.call_args.kwargs['turn_id']==turn
    assert transport.save.call_args.args[-1]['retry_of']==mid
    assert 'world_actions' not in transport.save.call_args.args[-1]
    assert '"id": "saved"' in response.text

def test_regenerated_history_keeps_original_position_and_current_card(transport):
    a,b,c=str(uuid4()),str(uuid4()),str(uuid4())
    rows=[{'id':'prompt-one','role':'user','answer_context':{}},
          {'id':a,'role':'assistant','answer_context':{'world_actions':[{'id':'unique','status':'confirmed'}]}},
          {'id':'prompt-two','role':'user','answer_context':{}},
          {'id':b,'role':'assistant','answer_context':{}},
          {'id':c,'role':'assistant','answer_context':{'retry_of':a}}]
    db=Mock();q=Mock();db.table.return_value=q
    for name in ('select','eq','order'):getattr(q,name).return_value=q
    q.execute.return_value.data=rows
    with patch.object(world,'conversation',return_value={'id':CID}),patch.object(route,'get_supabase_raw',return_value=db),patch('app.services.ask_photo_questions.refresh_photo_context',side_effect=lambda context,actor:context):
        result=transport.client.get(f'/worlds/{WORLD}/conversations/{CID}').json()
    assert [m['id'] for m in result['messages']]==['prompt-one',c,'prompt-two',b]
    assert result['messages'][1]['answer_context']['world_actions'][0]['status']=='confirmed'


def test_preview_only_extracts_without_model_reply_or_synthetic_user_prompt(transport):
    from app.services import chat_capture as capture
    out = io.BytesIO(); Image.new('RGB', (30, 30), 'orange').save(out, format='PNG')
    draft = {'id': str(uuid4()), 'version': 1, 'revision': 1, 'status': 'draft', 'items': []}
    with patch.object(route, 'check_and_increment_scan'), \
         patch('app.services.storage.upload_image', return_value=NS(path='private/photo', url='https://api.test/private.jpg')), \
         patch('app.services.photo_extraction.extract_inventory_items', new=AsyncMock(return_value={'items': []})), \
         patch.object(capture, 'create', return_value=draft), \
         patch.object(world, 'stream_turn') as model:
        response = transport.client.post(f'/worlds/{WORLD}/ai_photo_question',
            data={'supports_capture': 'true', 'auto_extract': 'true', 'preview_only': 'true'},
            files={'file': ('photo.png', out.getvalue(), 'image/png')})
    assert response.status_code == 200
    assert '"type": "capture"' in response.text and '"type": "done"' in response.text
    model.assert_not_called()
    assert '"assistant_message": ""' in response.text


def test_personal_group_model_reply_has_complete_client_receipt(transport):
    """Exercise a model-written grouping answer through the real SSE route."""
    message = 'Save this as my personal group called electronics repair kit.'
    receipt = {'message_id': str(uuid4()), 'created_at': '2026-10-26T20:00:00Z'}
    transport.save.return_value = receipt
    with patch.object(world, 'directory', return_value={}), \
         patch.object(world, 'execute') as execute, \
         patch('app.services.agent_gateway_client.gateway_completion', return_value=iter([NS(choices=[NS(delta=NS(content='I can recall this definition in this organization.', tool_calls=None), finish_reason=None)]), NS(choices=[NS(delta=NS(content=None, tool_calls=None), finish_reason='stop')])])) as model:
        response = transport.client.post(f'/worlds/{WORLD}/ai_command', json={'message': message})
    payloads = [json.loads(line[6:]) for line in response.text.splitlines()
                if line.startswith('data: {')]
    done = next(event for event in payloads if event['type'] == 'done')
    assert done['conversation_id'] == CID
    assert done['message_id'] == receipt['message_id']
    assert done['created_at'] == receipt['created_at']
    assert 'recall this definition' in done['assistant_message']
    assert not any(event['type'] == 'error' for event in payloads)
    assert transport.save.call_args.args[:4] == (ACTOR, WORLD, CID, done['assistant_message'])
    assert transport.save.call_args.args[-1]['operation_diagnostics'] == []
    execute.assert_not_called()
    model.assert_called_once()


def test_personal_group_save_failure_is_not_success(transport):
    transport.save.side_effect = RuntimeError('private storage error')
    with patch.object(world, 'stream_turn', return_value=events()):
        response = transport.client.post(f'/worlds/{WORLD}/ai_command',
            json={'message': 'Save this as my personal group kit'})
    assert '"type": "error"' in response.text
    assert '"type": "done"' not in response.text
    assert 'private storage error' not in response.text


@pytest.mark.parametrize('outcome', ['success', 'generation_failure', 'save_failure'])
def test_public_world_answer_is_append_only_after_tools_retries_and_save(transport, outcome):
    final = 'The charger is in Hardware, on shelf 2. ' * 8
    def attempts(*args, **kwargs):
        for text in ['First speculative line.', 'Different speculative line.', 'Unverified answer.']:
            yield {'type': 'delta', 'delta': text}
            yield {'type': 'reset'}
            yield {'type': 'status', 'message': 'Working through the results...'}
        if outcome == 'generation_failure':
            raise RuntimeError('interrupted')
        yield {'type': 'done', 'assistant_message': final, 'conversation_id': CID, 'answer_context': {}}
        yield {'type': 'status', 'message': 'Unexpected late working'}
    if outcome == 'save_failure':
        transport.save.side_effect = RuntimeError('save failed')
    with patch.object(world, 'stream_turn', side_effect=attempts):
        response = transport.client.post(f'/worlds/{WORLD}/ai_command', json={'message': 'Where is the charger?'})
    rows = [json.loads(line[6:]) for line in response.text.splitlines() if line.startswith('data: ') and line != 'data: [DONE]']
    chunks = [row['delta'] for row in rows if row.get('type') == 'delta']
    assert not any(row.get('type') == 'reset' for row in rows)
    assert 'speculative' not in response.text and 'Unverified answer' not in response.text
    if outcome != 'success':
        assert chunks == []
        assert rows[-1]['type'] == 'error'
        return
    assert len(chunks) > 1
    assert ''.join(chunks) == rows[-1]['assistant_message'] == final
    first = next(i for i, row in enumerate(rows) if row.get('type') == 'delta')
    assert all(row['type'] in ('delta', 'done') for row in rows[first:])
    transport.save.assert_called_once()
