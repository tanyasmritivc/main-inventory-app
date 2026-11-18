from app.services.agent_gateway_client import _as_namespace as ns
from app.services.completion_stream import completion_events, CompletionStreamError
import pytest

def event(content,kind='delta',**kw):
    return ns({'choices':[{kind:{'content':content,**kw}}]})

def test_final_snapshot_does_not_repeat_streamed_answer():
    result=list(completion_events(iter([event('Your gears '),event('are in Workshop.'),event('Your gears are in Workshop.','message')])))
    assert ''.join(e['delta'] for e in result if e['type']=='delta')=='Your gears are in Workshop.'
    assert result[-1]['content']=='Your gears are in Workshop.'

def test_final_snapshot_can_supply_only_the_unseen_suffix():
    result=list(completion_events(iter([event('**Gears**'),event('**Gears**\n\n| Part | Qty |','message')])))
    assert ''.join(e['delta'] for e in result if e['type']=='delta')==result[-1]['content']

@pytest.mark.parametrize('kind',['delta','message'])
def test_whole_message_and_true_repeated_deltas_are_preserved(kind):
    result=list(completion_events(iter([event('ha',kind)] if kind=='message' else [event('ha'),event('ha')])))
    assert result[-1]['content']==('ha' if kind=='message' else 'haha')

def test_conflicting_final_snapshot_fails_instead_of_appending():
    with pytest.raises(CompletionStreamError) as e:
        list(completion_events(iter([event('Answer A'),event('Answer B','message')])))
    assert e.value.code=='snapshot_mismatch'

def test_repeated_tool_identity_and_final_snapshot_do_not_corrupt_tool():
    call=lambda args: {'index':0,'id':'call_1','function':{'name':'world_search','arguments':args}}
    result=list(completion_events(iter([event(None,tool_calls=[call('{"query":')]),event(None,tool_calls=[call('"gears"}')]),event(None,'message',tool_calls=[call('{"query":"gears"}')]) ])))
    assert [e['type'] for e in result]==['completion']
    tool=result[-1]['tool_calls'][0]
    assert tool.id=='call_1' and tool.function.name=='world_search'
    assert tool.function.arguments=='{"query":"gears"}'

def test_finish_failure_without_delta_is_detected():
    with pytest.raises(CompletionStreamError) as e:
        list(completion_events(iter([event('partial'),ns({'choices':[{'finish_reason':'length'}]})])))
    assert e.value.code=='output_limit'

def test_many_argument_fragments_with_repeated_identity_do_not_hit_false_size_limit():
    args='{"query":"'+'g'*40+'"}'
    chunks=[event(None,tool_calls=[{'index':0,'id':'call_repeat_identity','function':{'name':'world_search','arguments':c}}]) for c in args]
    result=list(completion_events(iter(chunks)))
    assert result[-1]['tool_calls'][0].function.arguments==args
    assert result[-1]['tool_calls'][0].function.name=='world_search'


def test_completed_tool_array_uses_position_even_when_gateway_repeats_delta_index():
    calls=[{'index':0,'id':'one','function':{'name':'world_directory','arguments':'{}'}},
           {'index':0,'id':'two','function':{'name':'world_search','arguments':'{"query":"gears"}'}}]
    result=list(completion_events(ns({'choices':[{'message':{'content':'','tool_calls':calls},'finish_reason':'tool_calls'}]})))
    assert [c.id for c in result[-1]['tool_calls']]==['one','two']
    assert [c.function.name for c in result[-1]['tool_calls']]==['world_directory','world_search']
    assert all(e['type']!='delta' for e in result)


def test_final_full_array_does_not_duplicate_a_nonzero_stream_index():
    call={'index':1,'id':'read','function':{'name':'world_search','arguments':'{"query":"gears"}'}}
    result=list(completion_events(iter([
        ns({'choices':[{'delta':{'tool_calls':[call]}}]}),
        ns({'choices':[{'message':{'tool_calls':[call]}}]})])))
    assert len(result[-1]['tool_calls'])==1
    assert result[-1]['tool_calls'][0].id=='read'
