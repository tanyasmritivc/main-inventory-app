"""Organization-only context, private history, and retry transport regressions."""
import asyncio
import json
from types import SimpleNamespace as NS
from unittest.mock import MagicMock, patch
from uuid import UUID
import pytest
from fastapi import HTTPException
from app.services import world_chat as world
from app.api.routes import world_chat as route
from app.services.inventory_scope import current_inventory

ACTOR='10000000-0000-0000-0000-000000000001'
ORG='20000000-0000-0000-0000-000000000001'
OTHER='20000000-0000-0000-0000-000000000002'
INV='30000000-0000-0000-0000-000000000001'
INV2='30000000-0000-0000-0000-000000000002'
CID='40000000-0000-0000-0000-000000000001'

def inventory(i=INV, org=ORG):
    return dict(inventory_id=i, organization_id=org, owner_user_id=ACTOR,
                team_id=None, role='viewer', can_edit=False, name='Space '+i[-1],
                workspace={'organization_id':org, 'name':'Robotics'})

@pytest.mark.parametrize('parent', [OTHER, None])
def test_foreign_or_personal_inventory_is_rejected_before_read(parent):
    row=inventory(org=parent)
    with patch.object(world,'authorize',return_value=ORG), patch.object(world,'_inventory',return_value=row), \
         patch('app.services.organization_spaces.organization_id', return_value=ORG), \
         patch('app.services.ai_agent._current_items') as read:
        with pytest.raises(HTTPException) as exc:
            world.execute(ACTOR, ORG, 'world_inventory', {'inventory_id':INV,'query':'gears'})
        assert exc.value.status_code==403
        read.assert_not_called()


def test_org_search_reads_all_authorized_spaces_under_separate_scopes():
    seen=[]
    def read(**kwargs):
        scope=current_inventory.get()
        seen.append((scope.actor_id,scope.inventory_id,kwargs['q']))
        return [{'item_id':scope.inventory_id,'name':'Gear','quantity':3}]
    with patch.object(world,'authorize',return_value=ORG), patch.object(world,'directory',return_value={'inventories':[inventory(),inventory(INV2)]}), \
         patch.object(world,'inventory_scope',side_effect=lambda actor,org,i: inventory(i)), \
         patch('app.services.ai_agent._current_items',side_effect=read):
        prior=current_inventory.get()
        result=world.execute(ACTOR,ORG,'world_search',{'query':'gears'})
        assert current_inventory.get() is prior
    assert seen==[(ACTOR,INV,'gears'),(ACTOR,INV2,'gears')]
    assert {r['inventory_id'] for r in result['items']}=={INV,INV2}
    assert result['complete'] is False  # bounded searches never claim complete totals


def test_restricted_space_does_not_break_or_leak_into_directory():
    from app.services.organization_spaces import directory
    raw=MagicMock()
    raw.table.return_value.select.return_value.eq.return_value.order.return_value.range.return_value.execute.return_value.data=[{'inventory_id':INV},{'inventory_id':INV2}]
    raw.table.return_value.select.return_value.eq.return_value.execute.return_value.count=7
    with patch('app.services.organization_spaces.organization_id',return_value=ORG), \
         patch('app.api.routes.collaboration.organization',return_value={'name':'Robotics','role':'member'}), \
         patch('app.services.organization_spaces.get_supabase_raw',return_value=raw), \
         patch('app.api.routes.inventory_workspaces._inventory',side_effect=[HTTPException(403,'denied'),inventory(INV2)]):
        result=directory(ACTOR,ORG)
    assert [r['inventory_id'] for r in result['inventories']]==[INV2]
    assert INV not in json.dumps(result)
    assert raw.table.return_value.select.return_value.eq.call_args_list[0].args==('organization_id',ORG)


def test_conversation_query_always_binds_both_actor_and_org():
    raw=MagicMock()
    with patch.object(world,'authorize',return_value=ORG),patch.object(world,'get_supabase_raw',return_value=raw):
        world.conversations(ACTOR,ORG)
    q=raw.table.return_value.select.return_value
    q.eq.assert_called_once_with('user_id',ACTOR)
    q.eq.return_value.eq.assert_called_once_with('world_key',ORG)


def test_context_entry_inventory_is_verified_before_quota_or_history():
    async def run():
        with patch.object(world,'authorize',return_value=ORG), \
             patch.object(world,'inventory_scope',side_effect=HTTPException(403,'Wrong organization')), \
             patch.object(route,'check_and_increment_chat') as quota,patch.object(world,'prepare') as prepare:
            with pytest.raises(HTTPException):
                await route.answer(ACTOR,ORG,'gears',None,context_inventory_id=INV)
            quota.assert_not_called();prepare.assert_not_called()
    asyncio.run(run())


@pytest.mark.parametrize('contextual',[False,True])
def test_route_forwards_reset_and_only_saves_completed_attempt(contextual):
    async def run():
        events=[{'type':'delta','delta':'Abandoned answer'}, {'type':'reset'},
                {'type':'delta','delta':'**Gears**\n\n| Part | Quantity | Space |\n|---|---|---|\n| Gear | 3 | Workshop |'},
                {'type':'done','assistant_message':'Final table','answer_context':{}}]
        with patch.object(world,'authorize',return_value=ORG),patch.object(world,'inventory_scope',return_value=inventory()) as access, \
             patch.object(route,'check_and_increment_chat'),patch.object(world,'prepare',return_value=(CID,[])), \
             patch.object(world,'latest_photo',return_value=None),patch.object(world,'stream_turn',return_value=iter(events)) as turn, \
             patch.object(world,'save_answer',return_value={'message_id':'receipt'}) as save:
            response=await route.answer(ACTOR,ORG,'Were are my gears',None,context_inventory_id=INV if contextual else None)
            text=''.join([part async for part in response.body_iterator])
            frames=[json.loads(block[6:]) for block in text.split('\n\n') if block.startswith('data: {')]
            assert [f['type'] for f in frames][-4:]==['delta','reset','delta','done']
            save.assert_called_once_with(ACTOR,ORG,CID,'Final table',{})
            assert turn.call_args.kwargs.get('contextual',False)==contextual
            assert access.call_count==(2 if contextual else 0)
    asyncio.run(run())


def test_history_save_failure_is_not_silently_reported_as_success():
    async def run():
        with patch.object(world,'authorize',return_value=ORG), patch.object(route,'check_and_increment_chat'), \
             patch.object(world,'prepare',return_value=(CID,[])),patch.object(world,'latest_photo',return_value=None), \
             patch.object(world,'stream_turn',return_value=iter([{'type':'done','assistant_message':'Answer','answer_context':{}}])), \
             patch.object(world,'save_answer',side_effect=RuntimeError('private failure')):
            response=await route.answer(ACTOR,ORG,'gears',None)
            text=''.join([part async for part in response.body_iterator])
            assert 'history_save_failed' in text
            assert '"type": "done"' not in text and 'private failure' not in text
    asyncio.run(run())


@pytest.mark.parametrize('contextual',[False,True])
def test_inventory_formatting_applies_to_both_chats_but_scope_guidance_is_context_only(contextual):
    from app.services.context_ask import PRESENTATION, SCOPE
    from app.services.agent_gateway_client import _as_namespace
    calls=[]
    def model(**kwargs):
        calls.append(kwargs)
        return iter([_as_namespace({'choices':[{'message':{'content':'Hello!'},'finish_reason':'stop'}]})])
    with patch.object(world,'authorize',return_value=ORG),patch('app.services.agent_gateway_client.gateway_completion',side_effect=model):
        events=list(world.stream_turn(ACTOR,ORG,'Hello',[],CID,contextual=contextual))
    assert events[-1]['type']=='done'
    assert any(m['content']==PRESENTATION for m in calls[0]['messages'])
    assert any(m['content']==SCOPE for m in calls[0]['messages']) is contextual
    assert 'Markdown table' in PRESENTATION and '**bold section headings**' in PRESENTATION


def test_model_format_failure_retries_with_a_reset_and_no_duplicate_final_text():
    from app.services.agent_gateway_client import _as_namespace
    def response(text):
        return iter([_as_namespace({'choices':[{'delta':{'content':text},'finish_reason':'stop'}]})])
    with patch.object(world,'authorize',return_value=ORG), \
         patch('app.services.agent_gateway_client.gateway_completion',side_effect=[response('Old <tool_call>private'),response('**Your gears**\n\nNo matching records were checked.')]):
        events=list(world.stream_turn(ACTOR,ORG,'Hello',[],CID,contextual=True))
    visible=''
    for event in events:
        if event['type']=='reset':visible=''
        if event['type']=='delta':visible+=event['delta']
    assert any(e['type']=='reset' for e in events)
    assert events[-1]['type']=='done'
    assert visible==events[-1]['assistant_message']
    assert 'Old' not in visible and 'private' not in visible

@pytest.mark.parametrize('contextual',[False,True])
def test_control_markup_recovery_uses_buffered_native_tools_and_never_replays_reads(contextual):
    from app.services.agent_gateway_client import _as_namespace as ns
    calls=[]; operations=[]
    def native(name,args,ident):
        return ns({'choices':[{'message':{'content':'','tool_calls':[{'id':ident,'function':{'name':name,'arguments':json.dumps(args)}}]},'finish_reason':'tool_calls'}]})
    final='**Your gears**\n\n| Part | Quantity | Space |\n|---|---|---|\n| Gear A | 3 | Workshop |\n| Gear B | 2 | Store |'
    replies=[native('world_search',{'query':'gears'},'read1'),
             ns({'choices':[{'message':{'content':'<tool_call>private invalid request'},'finish_reason':'stop'}]}),
             ns({'choices':[{'message':{'content':final},'finish_reason':'stop'}]})]
    def gateway(**kwargs):
        calls.append(kwargs.copy())
        reply=replies.pop(0)
        return iter([reply]) if kwargs['stream'] else reply
    def execute(actor,org,name,args):
        operations.append((actor,org,name,args))
        return {'items':[{'name':'Gear A','quantity':3,'location':'Workshop'},{'name':'Gear B','quantity':2,'location':'Store'}]}
    with patch.object(world,'authorize',return_value=ORG),patch.object(world,'execute',side_effect=execute),patch('app.services.agent_gateway_client.gateway_completion',side_effect=gateway):
        events=list(world.stream_turn(ACTOR,ORG,'gears',[],CID,contextual=contextual))
    assert [c['stream'] for c in calls]==[True,True,False]
    assert calls[-1]['request_timeout_seconds']==60
    assert calls[-1]['tools'] and calls[-1]['tool_choice']=='auto'
    assert len(operations)==1 and operations[0][:3]==(ACTOR,ORG,'world_search')
    visible=''
    for event in events:
        if event['type']=='reset':visible=''
        if event['type']=='delta':visible+=event['delta']
    assert events[-1]['type']=='done' and visible==events[-1]['assistant_message']==final
    assert 'private' not in visible


def test_invalid_buffered_recovery_still_fails_closed():
    from app.services.agent_gateway_client import _as_namespace as ns
    from app.services.completion_stream import CompletionStreamError
    calls=[]
    def gateway(**kwargs):
        calls.append(kwargs)
        reply=ns({'choices':[{'message':{'content':'<tool_call>world_delete_items'},'finish_reason':'stop'}]})
        return iter([reply]) if kwargs['stream'] else reply
    with patch.object(world,'authorize',return_value=ORG),patch.object(world,'execute') as execute,patch('app.services.agent_gateway_client.gateway_completion',side_effect=gateway):
        with pytest.raises(CompletionStreamError):
            list(world.stream_turn(ACTOR,ORG,'gears',[],CID))
    assert len(calls)==2 and calls[-1]['stream'] is False
    execute.assert_not_called()
