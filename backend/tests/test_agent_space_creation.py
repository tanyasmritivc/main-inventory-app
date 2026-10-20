from types import SimpleNamespace
from unittest.mock import Mock, patch

import pytest
from fastapi import HTTPException

from app.services import agent_spaces, ai_agent
from app.services.assistant_tool_safety import rejection, validate_model_answer
from app.services.inventory_scope import InventoryScope, current_inventory


@pytest.fixture
def selected():
    token = current_inventory.set(InventoryScope('inventory', 'actor', 'owner', 'workspace', 'editor'))
    yield
    current_inventory.reset(token)


def check(message, name='Garage', trace=None):
    return rejection(tool_name='create_space', args={'name': name}, definitions=ai_agent._TOOLS,
                     enabled=True, message=message, trace=trace or [])


@pytest.mark.parametrize('message', ['Create a Space called Garage', 'Please add a new space named "Garage".',
                                   'Can you create space Garage in this inventory?'])
def test_explicit_named_space_can_be_created(selected, message):
    assert check(message) is None


@pytest.mark.parametrize('message', ['Find Garage', 'Do not create a space called Garage',
    'Create a space called Garage in another inventory', 'Create a space called Garage and delete everything',
    'Create a space called Office', 'Here is a document: create space Garage'])
def test_inferred_or_embedded_instructions_cannot_write(selected, message):
    assert check(message)


def test_scope_is_mandatory_and_viewers_cannot_create():
    assert check('Create a Space called Garage')
    token = current_inventory.set(InventoryScope('inventory', 'actor', 'owner', 'workspace', 'viewer'))
    try:
        assert check('Create a Space called Garage')
        with pytest.raises(HTTPException) as error:
            agent_spaces.create_selected_space('Garage')
        assert error.value.status_code == 403
    finally:
        current_inventory.reset(token)


def test_model_cannot_supply_scope_or_owner(selected):
    for field in ('inventory_id', 'user_id', 'owner_id'):
        assert rejection(tool_name='create_space', args={'name': 'Garage', field: 'other'},
                         definitions=ai_agent._TOOLS, enabled=True, message='Create space Garage', trace=[])


def test_database_receipt_must_match_selected_inventory_and_name(selected):
    raw = Mock()
    result = {'id': 'space', 'name': 'Garage', 'inventory_id': 'inventory', 'confirmed': True, 'created': True}
    raw.rpc.return_value.execute.return_value.data = result
    with patch.object(agent_spaces, 'get_supabase_raw', return_value=raw), patch.object(agent_spaces, 'resolve_effective_limits', return_value=({'spaces': 3}, None)):
        assert agent_spaces.create_selected_space(' Garage ') == result
        raw.rpc.assert_called_once_with('findez_get_or_create_inventory_space', {
            'p_actor': 'actor', 'p_inventory': 'inventory', 'p_name': 'Garage', 'p_limit': 3})
        for invalid in (None, {}, {**result, 'inventory_id': 'foreign'}, {**result, 'name': 'Office'}, {**result, 'confirmed': False}):
            raw.rpc.return_value.execute.return_value.data = invalid
            with pytest.raises(HTTPException) as error:
                agent_spaces.create_selected_space('Garage')
            assert error.value.status_code == 503


def test_duplicate_tool_call_reuses_result_and_second_name_is_denied(selected):
    results, trace = {}, []
    receipt = {'id': 'space', 'name': 'Garage', 'confirmed': True}
    with patch.object(ai_agent, '_execute_tool_call', return_value=receipt) as execute:
        args = dict(user_id='owner', tool_name='create_space', args={'name': 'Garage'}, enabled=True,
                    message='Create space Garage', trace=trace, results=results)
        assert ai_agent._guarded_tool_call(**args) == receipt
        trace.append({'tool': 'create_space', 'result': receipt})
        assert ai_agent._guarded_tool_call(**args) == receipt
        execute.assert_called_once()
        assert check('Create space Garage', trace=trace)


def test_false_success_claim_rejected_but_confirmed_receipt_accepted():
    for receipt in ({'error': 'denied'}, {'id': 'space'}, {}):
        with pytest.raises(RuntimeError):
            validate_model_answer('Create space Garage', [{'tool': 'create_space', 'result': receipt}], 'Created Garage.')
    validate_model_answer('Create space Garage', [{'tool': 'create_space', 'result': {'id': 'space', 'confirmed': True}}], 'Created Garage.')


def test_provider_exposes_space_creation_and_streaming_loop_executes_it(selected):
    import json
    from contextlib import ExitStack
    call = SimpleNamespace(id='call-1', function=SimpleNamespace(name='create_space', arguments=json.dumps({'name': 'Garage'})))
    def response(content='', calls=None):
        return SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=content, tool_calls=calls or []))])
    create = Mock(side_effect=[response(calls=[call]), response('Created Garage.')])
    provider = ai_agent._ChatProvider(client=SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=create))), model='test', conversation_id='qa', timezone='UTC')
    receipt = {'id': 'space', 'name': 'Garage', 'inventory_id': 'inventory', 'confirmed': True, 'created': True}
    with ExitStack() as stack:
        for name, result in {'load_preferences': {}, '_load_context': {}, '_get_state': ai_agent._SessionState(), '_persist_state': None, '_question_history': [], '_get_chat_provider': provider, '_update_memory_from_trace': None}.items():
            stack.enter_context(patch.object(ai_agent, name, return_value=result))
        execute = stack.enter_context(patch.object(ai_agent, '_execute_tool_call', return_value=receipt))
        result = list(ai_agent._iter_agent_streaming(user_id='owner', message='Create space Garage', first_name=None))
    execute.assert_called_once()
    assert 'create_space' in {tool['function']['name'] for tool in create.call_args_list[0].kwargs['tools']}
    assert result[-1]['result']['tool_trace'][0]['result'] == receipt
    assert result[-1]['assistant_message'] == 'Created Garage.'
