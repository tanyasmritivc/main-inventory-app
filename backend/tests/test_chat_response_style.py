import asyncio
import json
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, Mock, patch
import pytest
from app.services import ai_agent, ai_service, eezy_service
from app.services.chat_response_style import CHAT_STYLE_INSTRUCTION, format_chat_reply

def completion(text='', calls=None):
    return SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=text, tool_calls=calls or []))])

@pytest.mark.parametrize('mode', ['sync', 'events', 'sse'])
def test_replies_are_normalized_before_emission_and_session_persistence(mode):
    original = 'M4 screws—in Cabinet.\nStock — 24 units.'
    expected = 'M4 screws - in Cabinet.\nStock - 24 units.'
    user_text = 'Find my M4—steel screws'
    data = {'items': [{'item_id': 'item-1', 'name': 'M4—steel', 'quantity': 24}]}
    call = SimpleNamespace(id='call-1', function=SimpleNamespace(name='inventory_search', arguments=json.dumps({'query': 'M4—steel'})))
    create = Mock(side_effect=[completion('Checking—now', [call]), completion(original), completion(original)])
    provider = ai_agent._ChatProvider(client=SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=create))), model='test-model', conversation_id='conversation-1', timezone='America/Los_Angeles')
    state = ai_agent._SessionState()
    with patch.object(ai_agent, '_get_chat_provider', return_value=provider), patch.object(ai_agent, '_load_context', return_value={}), patch.object(ai_agent, '_get_state', return_value=state), patch.object(ai_agent, '_execute_tool_call', return_value=data) as execute, patch.object(ai_agent, '_update_memory_from_trace'), patch.object(ai_agent, '_persist_state') as persist:
        kwargs = dict(user_id='user-1', message=user_text, first_name=None)
        if mode == 'sync':
            answer = ai_agent.run_ai_command(**kwargs)
        else:
            if mode == 'events':
                events = list(ai_agent._iter_agent_streaming(**kwargs))
            else:
                events = [json.loads(chunk[6:]) for chunk in ai_agent.iter_ai_command_sse(**kwargs)]
            assert ''.join((evt['delta'] for evt in events if evt['type'] == 'delta')) == expected
            answer = events[-1]
    assert answer['assistant_message'] == expected
    assert state.conversation_history == [{'role': 'user', 'content': user_text}, {'role': 'assistant', 'content': expected}]
    persist.assert_called_once_with('user-1')
    execute.assert_called_once_with(user_id='user-1', tool_name='inventory_search', args={'query': 'M4—steel'})
    assert answer['result']['tool_trace'][0]['result'] == data
    messages = create.call_args.kwargs['messages']
    assert CHAT_STYLE_INSTRUCTION in messages[0]['content']
    assert messages[-2]['role'] == 'tool'
    assert json.loads(messages[-2]['content']) == data
    assert next((msg for msg in messages if msg['role'] == 'user'))['content'] == user_text

def test_document_chat_summary_emits_identical_delta_and_final_text():
    with patch.object(ai_service, 'extract_text_from_upload', return_value=('Receipt—24 screws', False)), patch.object(ai_service, '_gateway_messages', return_value=completion('24 screws—received today.')) as gateway:
        chunks = list(ai_service.iter_assist_file_analysis_sse(filename='receipt.txt', mime_type='text/plain', content=b'receipt'))
    events = [json.loads(chunk[6:]) for chunk in chunks if chunk.startswith('data: ') and chunk[6:].strip() != '{}']
    assert events[1]['delta'] == events[2]['assistant_message'] == '24 screws - received today.'
    messages = gateway.call_args.args[0]
    assert CHAT_STYLE_INSTRUCTION in messages[0]['content']
    assert 'Receipt—24 screws' in messages[1]['content']

def test_legacy_chat_applies_same_policy_without_changing_inventory_context():
    response = Mock()
    response.json.return_value = {'choices': [{'message': {'content': 'In Cabinet—24 units.'}}]}
    client = MagicMock()
    client.__aenter__ = AsyncMock(return_value=client)
    client.__aexit__ = AsyncMock(return_value=False)
    client.post = AsyncMock(return_value=response)
    with patch.object(eezy_service.httpx, 'AsyncClient', return_value=client):
        result = asyncio.run(eezy_service.ask_eezy('Find M4—steel', 'M4—steel: 24'))
    assert result == 'In Cabinet - 24 units.'
    messages = client.post.call_args.kwargs['json']['messages']
    assert CHAT_STYLE_INSTRUCTION in messages[0]['content']
    assert messages[1]['content'] == 'Inventory context:\nM4—steel: 24'
    assert messages[2]['content'] == 'Find M4—steel'

def test_formatter_preserves_newlines_and_other_unicode():
    original = 'Café: M4-20.\n— 2 units\nPrice: €3.00'
    expected = 'Café: M4-20.\n - 2 units\nPrice: €3.00'
    assert format_chat_reply(original) == expected
    assert format_chat_reply(expected) == expected
