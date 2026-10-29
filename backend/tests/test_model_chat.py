"""Model routing, semantic tool selection, failures and action receipts."""
import json
from types import SimpleNamespace
from unittest.mock import Mock,patch
import pytest
from app.services import ai_agent,ai_service

def completion(content='',name=None,args=None):
    calls=[] if name is None else [SimpleNamespace(id=name,function=SimpleNamespace(name=name,arguments=json.dumps(args)))]
    return SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=content,tool_calls=calls))])

@pytest.mark.parametrize('streaming',[False,True])
def test_roadrunner_requirements_reach_model_and_exact_authorized_project_tool(streaming):
    model_text='Roadrunner requires 4 wheels. You have 2 recorded, so this saved parts list is short by 2.'
    create=Mock(side_effect=[completion(name='inventory_knowledge_search',args={'query':'Roadrunner'}),completion(name='project_kit_readiness',args={'kit_id':'project-id'}),completion(model_text),completion(model_text)])
    provider=ai_agent._ChatProvider(client=SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=create))),model='configured-route',conversation_id='roadrunner',timezone='UTC')
    project={'id':'project-id','name':'Roadrunner','items':[{'id':'wheel','name':'Wheel','required_quantity':4,'available_quantity':2}]}
    state=ai_agent._SessionState()
    with patch.object(ai_agent,'load_preferences',return_value={}),patch.object(ai_agent,'_load_context',return_value={'inventory_preview':[]}),patch.object(ai_agent,'_get_state',return_value=state),patch.object(ai_agent,'_persist_state'),patch.object(ai_agent,'_question_history',return_value=[]),patch.object(ai_agent,'_get_chat_provider',return_value=provider),patch.object(ai_agent,'_inventory_knowledge',return_value={'project_kits':[{'project_kit_id':'project-id','name':'Roadrunner'}]}) as knowledge,patch.object(ai_agent,'get_project_readiness',return_value=project) as readiness:
        args=dict(user_id='actor',message='how many wheels do I need for the roadrunner',first_name=None)
        answer=list(ai_agent._iter_agent_streaming(**args))[-1] if streaming else ai_agent.run_ai_command(**args)
    assert answer['assistant_message']==model_text
    assert create.call_count==4
    knowledge.assert_called_once_with(user_id='actor',query='Roadrunner')
    readiness.assert_called_once_with(kit_id='project-id',user_id='actor')
    assert answer['answer_context']['rows'][0]['required_quantity']==4
    assert answer['answer_context']['rows'][0]['available_quantity']==2
    assert state.conversation_history[-1]['content']==model_text


@pytest.mark.parametrize('result',[completion(''),RuntimeError('PRIVATE_DETAIL')])
def test_legacy_file_chat_failure_is_error_without_assistant_fallback(result):
    with patch.object(ai_service,'extract_text_from_upload',return_value=('Some text',False)),patch.object(ai_service,'_gateway_messages',side_effect=result if isinstance(result,Exception) else None,return_value=result) as gateway:
        events=[json.loads(chunk[6:]) for chunk in ai_service.iter_assist_file_analysis_sse(filename='fixture.txt',mime_type='text/plain',content=b'text') if chunk.startswith('data: {')]
    gateway.assert_called_once()
    assert any(event.get('type')=='error' for event in events)
    assert not any(event.get('type') in ['done','delta'] for event in events)
    assert 'PRIVATE_DETAIL' not in json.dumps(events)


def test_unreadable_file_is_still_interpreted_by_model_without_a_template():
    with patch.object(ai_service,'extract_text_from_upload',return_value=('',False)),patch.object(ai_service,'_gateway_messages',return_value=completion('Please send a clearer copy of this document.')) as model:
        events=[json.loads(chunk[6:]) for chunk in ai_service.iter_assist_file_analysis_sse(filename='fixture.pdf',mime_type='application/pdf',content=b'text') if chunk.startswith('data: {')]
    assert events[1]['delta']=='Please send a clearer copy of this document.'
    model.assert_called_once()
