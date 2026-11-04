import asyncio
from dataclasses import replace
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest
from fastapi import HTTPException, FastAPI, Depends
from httpx import ASGITransport, AsyncClient

from app.services import space_chat
from app.services.inventory_scope import InventoryScope, InventoryClient, current_inventory, inventory_cache_key

SPACE = '11111111-1111-4111-8111-111111111111'
OTHER = '22222222-2222-4222-8222-222222222222'
ITEM = '33333333-3333-4333-8333-333333333333'

@pytest.fixture
def selected():
    value = InventoryScope('inventory-a', 'actor', 'owner', None, 'editor', SPACE, 'Workshop')
    token = current_inventory.set(value)
    yield value
    current_inventory.reset(token)


def client(value, rows=None):
    raw, query = MagicMock(), MagicMock()
    for method in ('select', 'eq', 'limit', 'insert', 'update', 'delete', 'in_', 'order', 'contains'):
        getattr(query, method).return_value = query
    raw.table.return_value = query
    query.execute.return_value = SimpleNamespace(data=rows or [])
    return InventoryClient(raw, value), query


@pytest.mark.parametrize('operation', ['select', 'update', 'delete'])
def test_repository_fences_space_reads_and_writes(selected, operation):
    scoped, query = client(selected)
    operation_fn = getattr(scoped.table('items'), operation)
    result = operation_fn('*') if operation == 'select' else operation_fn({'name': 'Saved'}) if operation == 'update' else operation_fn()
    result.execute()
    query.eq.assert_any_call('inventory_id', 'inventory-a')
    query.eq.assert_any_call('space_id', SPACE)


def test_space_history_is_actor_private_and_cannot_open_another_space(selected):
    scoped, query = client(selected)
    with patch.object(space_chat, 'conversation_ids', return_value=['local-conversation']):
        scoped.table('conversations').select('*').execute()
        query.eq.assert_any_call('user_id', 'actor')
        query.in_.assert_any_call('id', ['local-conversation'])
        with pytest.raises(HTTPException):
            scoped.table('messages').insert({'conversation_id': 'other-space-conversation', 'content': 'hello'})
    assert inventory_cache_key('owner').endswith(':space:' + SPACE)


@pytest.mark.parametrize('change', [{'space_id': OTHER}, {'space_id': None}, {'location': 'Elsewhere'}])
def test_space_chat_cannot_move_items_outside(selected, change):
    scoped, query = client(selected)
    with pytest.raises(HTTPException):
        scoped.table('items').update(change)
    query.update.assert_not_called()


def test_non_space_clients_keep_previous_filters_and_tool_behavior():
    value = InventoryScope('inventory-a', 'actor', 'owner', None, 'editor')
    scoped, query = client(value)
    scoped.table('items').select('*').execute()
    assert ('space_id', SPACE) not in [c.args for c in query.eq.call_args_list]
    scoped.table('conversations').insert({'user_id': 'owner', 'title': 'Old chat'}).execute()
    assert 'world_key' not in query.insert.call_args.args[0]
    space_chat.guard_tool('world_directory', {})


def test_tool_arguments_cannot_escape_or_use_foreign_item_ids(selected):
    scoped, query = client(selected)
    with patch.object(space_chat, 'get_supabase_admin', return_value=scoped):
        for name, args in [('inventory_knowledge_search', {'query': ''}),
                           ('documents_list', {}), ('create_space', {'name': 'Other'}),
                           ('inventory_query', {'filters': {'space_id': OTHER}}),
                           ('inventory_update_item', {'item_id': ITEM, 'updates': {'name': 'Changed'}}),
                           ('inventory_propose_delete', {'item_ids': [ITEM]})]:
            with pytest.raises(HTTPException):
                space_chat.guard_tool(name, args)
    args = {'terms': [], 'filters': {'quantity_op': 'below', 'quantity_value': 3}}
    space_chat.guard_tool('inventory_query', args)
    assert args['filters']['space_id'] == SPACE
    assert args['filters']['quantity_value'] == 3


def test_space_generation_budget_covers_planning_and_final_without_exposing_other_tools(selected):
    provider = SimpleNamespace(model='existing-model', conversation_id='thread', timezone='UTC')
    for enabled in (True, False):
        values = space_chat.model_kwargs(provider, [], enabled, True)
        assert values['max_tokens'] == 8192
        assert values['model'] == 'existing-model'
        assert {t['function']['name'] for t in values.get('tools', [])} <= space_chat.TOOLS
    from app.services.ai_agent import _completion_kwargs
    token = current_inventory.set(None)
    try:
        assert _completion_kwargs(provider, messages=[], stream=True, allow_tools=False)['max_tokens'] == 500
    finally:
        current_inventory.reset(token)


def test_request_boundary_validates_space_then_resets_even_on_denial():
    async def run():
        from app.api.routes import inventory_workspaces as routes
        from app.core.auth import get_current_user
        user = SimpleNamespace(user_id='actor', actor_id=None)
        app = FastAPI()
        app.dependency_overrides[get_current_user] = lambda: user
        @app.get('/inventories/{inventory_id}/conversations', dependencies=[Depends(routes.inventory_session)])
        async def endpoint():
            return {'space': current_inventory.get().chat_space_id, 'actor': current_inventory.get().actor_id}
        raw, query = client(InventoryScope('inventory-a', 'actor', 'owner', None, 'editor'), [{'id': SPACE, 'name': 'Workshop'}])
        inventory = {'inventory_id': 'inventory-a', 'owner_user_id': 'owner', 'role': 'editor', 'workspace': {}}
        with patch.object(routes, '_inventory', return_value=inventory), patch('app.services.supabase_client.get_supabase_admin', return_value=raw):
            async with AsyncClient(transport=ASGITransport(app=app), base_url='http://test') as http:
                reply = await http.get('/inventories/inventory-a/conversations', headers={'X-Findez-Space-ID': SPACE})
                assert reply.status_code == 200 and reply.json() == {'space': SPACE, 'actor': 'actor'}
                assert user.user_id == 'actor' and current_inventory.get() is None
                query.execute.return_value.data = []
                reply = await http.get('/inventories/inventory-a/conversations', headers={'X-Findez-Space-ID': OTHER})
                assert reply.status_code == 404 and current_inventory.get() is None
                reply = await http.get('/inventories/inventory-a/conversations', headers={'X-Findez-Space-ID': 'invalid'})
                assert reply.status_code == 422 and current_inventory.get() is None
    asyncio.run(run())

def test_failed_generation_never_emits_a_success_or_saves_partial_text(selected):
    async def run():
        from app.api.routes import ai
        user = SimpleNamespace(user_id='owner')
        def failed(*args):
            yield {'type': 'delta', 'delta': 'Partial'}
            raise RuntimeError('fixture interrupted stream')
        with patch('app.services.limits.check_and_increment_chat'), patch.object(space_chat, 'prepare_conversation', return_value='conversation'), patch.object(ai, '_save_ask_answer') as saved, patch.object(space_chat, 'events', side_effect=failed):
            response = await space_chat.response(user=user, message='Count parts', conversation_id=None, allow_item_actions=True)
            body = b''.join([chunk async for chunk in response.body_iterator]).decode()
        assert 'Partial' in body and '"type":"error"' in body and '"type": "done"' not in body
        saved.assert_not_called()
    asyncio.run(run())

def test_completed_answer_keeps_space_scope_after_dependency_exits(selected):
    async def run():
        from app.api.routes import ai
        user = SimpleNamespace(user_id='owner')
        def done(user_id, *args):
            assert user_id == 'owner' and current_inventory.get().chat_space_id == SPACE
            yield {'type': 'done', 'assistant_message': 'There are two parts.', 'answer_context': {}}
        with patch('app.services.limits.check_and_increment_chat'), patch.object(space_chat, 'prepare_conversation', return_value='conversation'), patch.object(ai, '_save_ask_answer', return_value={'message_id': 'saved'}) as saved, patch.object(space_chat, 'events', side_effect=done):
            response = await space_chat.response(user=user, message='Count parts', conversation_id=None, allow_item_actions=True)
            user.user_id = 'actor'
            token = current_inventory.set(None)
            try:
                body = b''.join([chunk async for chunk in response.body_iterator]).decode()
            finally:
                current_inventory.reset(token)
        assert '"message_id": "saved"' in body and '"conversation_id": "conversation"' in body
        saved.assert_called_once()
    asyncio.run(run())



def test_space_history_marker_query_fences_actor_inventory_and_space(selected):
    scoped, query = client(selected, [{'conversation_id': 'local-conversation'}])
    query.range.return_value = query
    assert space_chat.conversation_ids(scoped.raw, selected) == ['local-conversation']
    query.eq.assert_any_call('conversations.user_id', 'actor')
    query.eq.assert_any_call('conversations.inventory_id', 'inventory-a')
    query.eq.assert_any_call('inventory_id', 'inventory-a')
    query.contains.assert_called_with('answer_context', {'space_chat': SPACE})


def test_new_space_history_keeps_legacy_action_compatibility_and_writes_marker(selected):
    scoped, query = client(replace(selected, chat_space_id=None, chat_space_name=None), [{'id': 'new-conversation'}])
    with patch.object(space_chat, 'get_supabase_admin', return_value=scoped):
        assert space_chat.prepare_conversation('owner', 'Hello', None) == 'new-conversation'
    writes = [call.args[0] for call in query.insert.call_args_list]
    assert 'world_key' not in writes[0]
    assert writes[1]['answer_context'] == {'space_chat': SPACE, 'space_chat_marker': True}
    assert writes[1]['role'] == 'assistant' and writes[1]['content'] == ''
    assert writes[2]['role'] == 'user' and 'answer_context' not in writes[2]
    assert writes[1]['conversation_id'] == 'new-conversation'
    assert current_inventory.get() == selected


def test_private_space_marker_is_never_a_rendered_or_model_history_answer(selected):
    scoped, query = client(selected, [{'id': 'conversation'}])
    result = SimpleNamespace(data=[{'role': 'assistant', 'content': '', 'answer_context': {'space_chat_marker': True}}, {'role': 'user', 'content': 'Question'}])
    query.execute.side_effect = [SimpleNamespace(data=[{'id': 'conversation'}]), result]
    with patch.object(space_chat, 'conversation_ids', return_value=['conversation']):
        rows = scoped.table('messages').select('role,content').eq('conversation_id', 'conversation').execute().data
    assert rows == [{'role': 'user', 'content': 'Question'}]
    assert 'answer_context' in query.select.call_args_list[0].args[0]
