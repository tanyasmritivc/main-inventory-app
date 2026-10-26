"""Negative caller-tool tests for both existing agent execution paths."""
from types import SimpleNamespace
from unittest.mock import Mock, patch
import json

import pytest

from app.services import ai_agent
from app.services.assistant_tool_safety import provider_data


def completion(content='', calls=()):
    return SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=content, tool_calls=list(calls)))])


def tool(name, args):
    return SimpleNamespace(id='test-call', function=SimpleNamespace(name=name, arguments=args))


@pytest.mark.parametrize('streaming', [False, True])
@pytest.mark.parametrize('model', ['fixture-route-a', 'fixture-route-b'])
def test_disabled_tools_cannot_write_even_when_gateway_returns_calls(streaming, model):
    create = Mock(side_effect=[completion(calls=[tool('inventory_delete_item', '{"item_id":"foreign"}')]), completion('Deleted everything!')])
    provider = ai_agent._ChatProvider(client=SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=create))), model=model, conversation_id='thread', timezone='UTC')
    with patch.object(ai_agent, '_get_chat_provider', return_value=provider), \
         patch.object(ai_agent, 'answer_question', return_value=None), \
         patch.object(ai_agent, '_project_readiness_for_question', return_value=None), \
         patch.object(ai_agent, '_load_context', return_value={}), \
         patch.object(ai_agent, '_get_state', return_value=ai_agent._SessionState()), \
         patch.object(ai_agent, '_persist_state'), \
         patch.object(ai_agent, '_execute_tool_call') as execute:
        if streaming:
            events = list(ai_agent._iter_agent_streaming(user_id='actor', message='Hello', first_name=None))
            answer = events[-1]['assistant_message']
            assert all('Deleted everything' not in event.get('delta', '') for event in events)
        else:
            answer = ai_agent.run_ai_command(user_id='actor', message='Hello')['assistant_message']
    execute.assert_not_called()
    assert 'No change' in answer
    assert all(call.kwargs['model'] == model for call in create.call_args_list)


@pytest.mark.parametrize('args', [None, [], {'query': True}, {'query': 'part', 'user_id': 'another'}, {'query': 'x' * 2001}])
def test_malformed_and_privileged_tool_arguments_never_execute(args):
    with patch.object(ai_agent, '_execute_tool_call') as execute:
        result = ai_agent._guarded_tool_call(user_id='actor', tool_name='inventory_search', args=args,
                                            enabled=True, message='Find part', trace=[], results={})
    assert result['error']
    execute.assert_not_called()


def test_request_local_reuse_and_literal_single_item_edit():
    item_id = '00000000-0000-4000-8000-000000000001'
    args = {'item_id': item_id, 'updates': {'notes': 'Inspected'}}
    trace = [{'tool': 'inventory_search', 'result': [{'item_id': item_id, 'name': 'Pliers'}]}]
    results = {}
    with patch.object(ai_agent, '_execute_tool_call', return_value={'item_id': item_id, 'notes': 'Inspected'}) as execute:
        first = ai_agent._guarded_tool_call(user_id='actor', tool_name='inventory_update_item', args=args, enabled=True,
                                            message='Change pliers notes to Inspected', trace=trace, results=results)
        trace.append({'tool': 'inventory_update_item', 'result': first})
        again = ai_agent._guarded_tool_call(user_id='actor', tool_name='inventory_update_item', args=args, enabled=True,
                                            message='Change pliers notes to Inspected', trace=trace, results=results)
    assert first == again
    execute.assert_called_once()
    # The map belongs to a request; another actor/request has an empty map and
    # cannot infer success from a previous actor's result.
    with patch.object(ai_agent, '_execute_tool_call') as execute:
        denied = ai_agent._guarded_tool_call(user_id='another', tool_name='inventory_update_item', args=args, enabled=True,
                                            message='Hello', trace=[], results={})
    execute.assert_not_called()
    assert denied['error']


def test_tool_failure_has_safe_message_and_no_retry_or_raw_error():
    with patch.object(ai_agent, '_execute_tool_call', side_effect=RuntimeError('PRIVATE_PROVIDER_SECRET')) as execute:
        result = ai_agent._guarded_tool_call(user_id='actor', tool_name='inventory_search', args={'query': 'pliers'},
                                            enabled=True, message='Find pliers', trace=[], results={})
    execute.assert_called_once()
    assert result['error']
    assert 'PRIVATE_PROVIDER_SECRET' not in json.dumps(result)


def test_provider_data_is_bounded_and_storage_references_are_omitted():
    value = {'documents': [{'filename': 'Manual', 'storage_path': 'owner/private.pdf', 'user_id': 'private-user',
                            'notes': 'Saved https://private.test/doc?token=SECRET', 'text': 'x' * 5000} for _ in range(100)]}
    projected = provider_data(value)
    text = json.dumps(projected)
    assert 'storage_path' not in text and 'private-user' not in text and 'SECRET' not in text
    assert projected['documents']['records_truncated'] is True
    assert len(projected['documents']['records']) <= 50
    assert len(text) < 16_000


def test_gateway_error_stream_is_a_real_failure_not_thinking_placeholder():
    create = Mock(side_effect=RuntimeError('PRIVATE_PROVIDER_SECRET'))
    provider = ai_agent._ChatProvider(client=SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=create))), model='fixture-route', conversation_id='thread', timezone='UTC')
    with patch.object(ai_agent, '_get_chat_provider', return_value=provider), \
         patch.object(ai_agent, 'answer_question', return_value=None), \
         patch.object(ai_agent, '_project_readiness_for_question', return_value=None), \
         patch.object(ai_agent, '_load_context', return_value={}), \
         patch.object(ai_agent, '_get_state', return_value=ai_agent._SessionState()), \
         patch.object(ai_agent, '_persist_state'):
        events = list(ai_agent._iter_agent_streaming(user_id='actor', message='Hello', first_name=None))
    assert 'unavailable' in events[-1]['assistant_message']
    assert 'PRIVATE_PROVIDER_SECRET' not in json.dumps(events)
    create.assert_called_once()


@pytest.mark.parametrize('streaming', [False, True])
def test_provider_prose_cannot_claim_an_unexecuted_edit(streaming):
    create = Mock(return_value=completion('I moved the pliers to Paris and set stock to 999.'))
    provider = ai_agent._ChatProvider(client=SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=create))), model='fixture-route', conversation_id='thread', timezone='UTC')
    with patch.object(ai_agent, '_get_chat_provider', return_value=provider), \
         patch.object(ai_agent, 'answer_question', return_value=None), \
         patch.object(ai_agent, '_project_readiness_for_question', return_value=None), \
         patch.object(ai_agent, '_load_context', return_value={}), \
         patch.object(ai_agent, '_get_state', return_value=ai_agent._SessionState()), \
         patch.object(ai_agent, '_persist_state'), patch.object(ai_agent, '_execute_tool_call') as execute:
        if streaming:
            events = list(ai_agent._iter_agent_streaming(user_id='actor', message='Move Red handle pliers to Office shelf', first_name=None))
            answer = events[-1]['assistant_message']
        else:
            answer = ai_agent.run_ai_command(user_id='actor', message='Move Red handle pliers to Office shelf')['assistant_message']
    assert 'No inventory change was confirmed' in answer
    assert 'Paris' not in answer and '999' not in answer
    execute.assert_not_called()


def test_confirmed_edit_evidence_replaces_the_pre_edit_location():
    from app.services.ask_presentation import answer_context_from_reads
    before = {'item_id': 'item', 'name': 'Pliers', 'location': 'Old drawer', 'quantity': 1}
    after = {**before, 'location': 'New drawer'}
    context = answer_context_from_reads({}, [{'tool': 'inventory_search', 'result': [before]},
                                            {'tool': 'inventory_update_item', 'result': after}])
    assert len(context['rows']) == 1
    assert context['rows'][0]['location'] == 'New drawer'


@pytest.mark.parametrize('message,updates', [
    ('Move Pliers to Garage', {'notes': 'Garage'}),
    ('Rename Pliers to New name', {'name': 'Pliers'}),
    ('Move Hammer to Pliers', {'location': 'Pliers'}),
    ('Move Red handle pliers to Garage', {'location': 'Garage'}),
])
def test_model_cannot_change_a_different_field_target_or_value(message, updates):
    from app.services.assistant_tool_safety import rejection
    trace = [{'tool': 'inventory_search', 'result': [{'item_id': 'pliers', 'name': 'Pliers'}]}]
    assert rejection(tool_name='inventory_update_item', args={'item_id': 'pliers', 'updates': updates},
                     definitions=ai_agent._TOOLS, enabled=True, message=message, trace=trace)
