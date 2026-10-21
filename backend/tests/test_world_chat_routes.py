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

def test_uploaded_photo_uses_existing_vision_and_later_added_gallery_search(transport):
    out = io.BytesIO(); Image.new('RGB', (30, 30), 'orange').save(out, format='PNG')
    stored = NS(path=f'{ACTOR}/ask-' + 'a'*32 + '.jpg', url='https://api.test/private.jpg')
    match = {'matches': [{'name': 'Saved motor', 'match_basis': 'same saved photo'}]}
    with patch.object(route, 'check_and_increment_scan'), \
         patch('app.services.storage.upload_image', return_value=stored), \
         patch('app.services.storage.delete_image') as cleanup, \
         patch('app.services.find_pipeline.extract_inventory_items_with_find', new=AsyncMock(return_value={'items': [{'name': 'Motor', 'quantity': 1}]})), \
         patch.object(world, 'photo_matches', new=AsyncMock(return_value=match)) as gallery, \
         patch.object(world, 'stream_turn', return_value=events()) as stream:
        response = transport.client.post(f'/worlds/{WORLD}/ai_photo_question', data={'message': 'Do I have this?'}, files={'file': ('motor.png', out.getvalue(), 'image/png')})
    assert '"type": "done"' in response.text
    assert gallery.await_args.args[:2] == (ACTOR, WORLD)
    assert stream.call_args.args[-1]['saved_photos'] == match
    assert transport.save.call_args.args[-1]['photo_path'] == stored.path
    cleanup.assert_not_called()

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
