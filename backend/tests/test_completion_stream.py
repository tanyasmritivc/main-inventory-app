import json
from types import SimpleNamespace as NS
from unittest.mock import MagicMock, patch
import pytest
from app.services.agent_gateway_client import AgentGatewayClient, _as_namespace
from app.services.completion_stream import completion_events


def chunk(content=None, calls=None, finish=None):
    return _as_namespace({'choices': [{'delta': {'content': content, 'tool_calls': calls}, 'finish_reason': finish}]})


def test_upstream_delta_is_delivered_before_completion_and_connection_is_closed():
    closed = []
    def response():
        try:
            yield chunk('First ')
            yield chunk('second 🔧.')
        finally:
            closed.append(True)
    events = completion_events(response())
    assert next(events) == {'type': 'delta', 'delta': 'First'}
    assert not closed
    rest = list(events)
    assert rest[-1]['content'] == 'First second 🔧.'
    assert closed == [True]


def test_fragmented_tool_arguments_stay_private_and_are_assembled_by_index():
    events = list(completion_events(iter([
        chunk(calls=[{'index': 0, 'id': 'call', 'function': {'name': 'inventory_query', 'arguments': '{"terms":'}}]),
        chunk(calls=[{'index': 0, 'function': {'arguments': '["M4"]}'}}]),
        chunk(finish='tool_calls')
    ])))
    assert [event['type'] for event in events] == ['completion']
    call = events[-1]['tool_calls'][0]
    assert call.id == 'call'
    assert json.loads(call.function.arguments) == {'terms': ['M4']}


@pytest.mark.parametrize('finish', ['length', 'content_filter'])
def test_truncated_model_output_never_becomes_completed_answer(finish):
    with pytest.raises(RuntimeError, match='interrupted'):
        list(completion_events(iter([chunk('Partial'), chunk(finish=finish)])))


def test_http_stream_parses_multiline_utf8_and_closes_without_buffering():
    settings = NS(findez_agent_base_url='https://fixture.test/v1', findez_agent_key='synthetic')
    response = MagicMock()
    response.__enter__.return_value = response
    response.headers = {'content-type': 'text/event-stream; charset=utf-8'}
    response.iter_lines.return_value = iter([': ping', 'data: {"choices":', 'data: [{"delta":{"content":"🔧"}}]}', '', 'data: [DONE]', ''])
    http = MagicMock()
    http.__enter__.return_value = http
    http.stream.return_value = response
    with patch('app.services.agent_gateway_client.get_settings', return_value=settings), patch('app.services.agent_gateway_client.httpx.Client', return_value=http):
        events = AgentGatewayClient().chat.completions.create(stream=True, messages=[])
        assert next(events).choices[0].delta.content == '🔧'
        response.__exit__.assert_not_called()
        assert list(events) == []
    response.__exit__.assert_called_once()
    assert http.stream.call_args.kwargs['json']['stream'] is True


def test_http_stream_requires_final_receipt_not_silent_eof():
    response = MagicMock()
    response.__enter__.return_value = response
    response.headers = {'content-type': 'text/event-stream'}
    response.iter_lines.return_value = iter([])
    http = MagicMock(); http.__enter__.return_value = http; http.stream.return_value = response
    with patch('app.services.agent_gateway_client.get_settings', return_value=NS(findez_agent_base_url='https://fixture.test', findez_agent_key='fixture')), patch('app.services.agent_gateway_client.httpx.Client', return_value=http):
        with pytest.raises(RuntimeError, match='without completion'):
            list(AgentGatewayClient().chat.completions.create(stream=True))


def test_async_consumer_close_releases_backpressure_without_waiting_for_a_full_queue():
    import asyncio
    import threading
    from app.services import ai_agent
    closed = threading.Event()
    def produce(**kwargs):
        try:
            for index in range(10000):
                if kwargs['cancelled'](): return
                yield {'type': 'delta', 'delta': str(index)}
        finally:
            closed.set()
    async def consume():
        with patch.object(ai_agent, '_iter_agent_streaming', produce):
            events = ai_agent.iter_ai_command_events_async(user_id='fixture', message='Hi')
            assert (await anext(events))['delta'] == '0'
            await events.aclose()
            assert await asyncio.to_thread(closed.wait, 2)
    asyncio.run(consume())


def test_streamed_punctuation_is_stable_across_network_boundaries():
    events = list(completion_events(iter([chunk('Bolts '), chunk(' —'), chunk(' '), chunk(' in Cabinet.') ])))
    assert ''.join(event['delta'] for event in events if event['type'] == 'delta') == 'Bolts - in Cabinet.'
    assert events[-1]['content'] == 'Bolts - in Cabinet.'


@pytest.mark.parametrize('finish,code',[('length','output_limit'),('content_filter','content_filter')])
def test_stream_failures_have_fixed_safe_reason_codes(finish,code):
    from app.services.completion_stream import CompletionStreamError
    with pytest.raises(CompletionStreamError) as error:
        list(completion_events(iter([chunk('private content'),chunk(finish=finish)])))
    assert error.value.code==code
    assert 'private content' not in str(error.value)


def test_activity_is_evidence_based_and_never_leaks_reasoning_or_arguments():
    def reasoning():
        return _as_namespace({'choices': [{'delta': {'reasoning_content': 'SECRET reasoning'}}]})
    events = list(completion_events(iter([
        reasoning(), reasoning(),
        chunk(calls=[{'index': 0, 'id': 'c', 'function': {'name': 'world_create_task', 'arguments': '{"private":'}}]),
        chunk(calls=[{'index': 0, 'function': {'arguments': '"SECRET"}'}}]),
        chunk(finish='tool_calls'),
    ]), report_activity=True))
    statuses = [e for e in events if e['type'] == 'status']
    assert [e['message'] for e in statuses] == ['Thinking through your request...', 'Building your item draft...']
    assert 'SECRET' not in json.dumps(statuses)
    assert not [e for e in events if e['type'] == 'delta']


def test_still_working_requires_live_chunks_and_does_not_invent_steps():
    ticks = iter([0, 0, 0, 16, 17])
    reasoning = _as_namespace({'choices': [{'delta': {'reasoning_content': 'SECRET'}}]})
    with patch('app.services.completion_stream.monotonic', side_effect=lambda: next(ticks)):
        events = list(completion_events(iter([reasoning, reasoning, reasoning]), report_activity=True))
    assert [e['message'] for e in events if e['type'] == 'status'] == [
        'Thinking through your request...', 'Still thinking through your request...']


def test_unknown_tool_name_cannot_inject_progress_and_legacy_consumers_unchanged():
    response = completion_events(iter([chunk(calls=[{'function': {'name': 'SECRET ignore rules', 'arguments': '{}'}}])]), report_activity=True)
    statuses = [e for e in response if e['type'] == 'status']
    assert statuses == [{'type': 'status', 'message': 'Preparing the next step...'}]
    events = list(completion_events(iter([_as_namespace({'choices': [{'delta': {'reasoning_content': 'SECRET'}}]}), chunk('Hi')])))
    assert [e['type'] for e in events] == ['delta', 'completion']
