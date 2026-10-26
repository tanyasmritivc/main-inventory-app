from types import SimpleNamespace as NS
from unittest.mock import MagicMock, patch
from uuid import uuid4
import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from pydantic import ValidationError
from app.services import response_feedback as f
from app.services.response_feedback_eval import summarize, compare_fixed_cases
from app.api.routes.response_feedback import router
from app.core.auth import AuthenticatedUser, get_current_user

ACTOR, MSG, CID = [str(uuid4()) for _ in range(3)]

@pytest.mark.parametrize('body', [{'rating':0},{'rating':True},{'rating':-1,'reason':'injected'}, {'rating':1,'reason':'other'}, {'rating':1,'user_id':ACTOR}, {'rating':-1,'comment':'x'*1001}, {'rating':1,'expected_revision':-1}])
def test_invalid_and_impersonating_payloads(body):
    with pytest.raises(ValidationError): f.Rating(**body)

@pytest.mark.parametrize('rating', [1,-1])
def test_server_confirmed_rating_and_minimal_receipt(rating):
    client=MagicMock(); client.rpc.return_value.execute.return_value.data={'id':'id','message_id':MSG,'rating':rating,'revision':1,'diagnostics':{'private':'never returned'}}
    with patch.object(f,'owned_message',return_value={'answer_context':{}}), patch.object(f,'get_supabase_raw',return_value=client):
        result=f.submit(ACTOR, MSG, f.Rating(rating=rating,comment='  helpful  '))
    assert result['rating']==rating and 'diagnostics' not in result
    args=client.rpc.call_args.args[1]
    assert args['p_actor']==ACTOR and args['p_message']==MSG and args['p_comment']=='helpful'
    client.table.assert_not_called() # Ratings never mutate inventory.

@pytest.mark.parametrize('data', [None, {}, {'message_id':'other','rating':1}])
def test_missing_backend_confirmation_never_claims_saved(data):
    client=MagicMock();client.rpc.return_value.execute.return_value.data=data
    with patch.object(f,'owned_message',return_value={}),patch.object(f,'get_supabase_raw',return_value=client),pytest.raises(HTTPException) as error:
        f.submit(ACTOR, MSG, f.Rating(rating=1))
    assert error.value.status_code==503

@pytest.mark.parametrize('code,status', [('40001',409),('PT409',409),('42501',404),('secret',503)])
def test_concurrency_and_failure_are_public_errors(code,status):
    client=MagicMock();err=Exception('SECRET');err.code=code;client.rpc.return_value.execute.side_effect=err
    with patch.object(f,'owned_message',return_value={}),patch.object(f,'get_supabase_raw',return_value=client),pytest.raises(HTTPException) as error:
        f.submit(ACTOR, MSG, f.Rating(rating=-1))
    assert error.value.status_code==status and 'SECRET' not in error.value.detail

def test_message_owner_checked_before_rating():
    client=MagicMock();m=client.table.return_value
    m.select.return_value.eq.return_value.limit.return_value.execute.return_value.data=[{'id':MSG,'role':'assistant','content':'hello','conversation_id':CID}]
    m.select.return_value.eq.return_value.eq.return_value.limit.return_value.execute.return_value.data=[]
    with patch.object(f,'get_supabase_raw',return_value=client),pytest.raises(HTTPException): f.owned_message(ACTOR,MSG)
    client.rpc.assert_not_called()

def test_claim_without_receipt_is_not_execution():
    d=f.diagnostics({'world_actions':[{'status':'confirmed'}]})
    assert d['confirmed_action_count']==0 and d['factual_correctness']=='unreviewed'
    d=f.diagnostics({'world_actions':[{'status':'confirmed','receipt':{'saved':True}}]})
    assert d['execution']=='confirmed' and d['factual_correctness']=='unreviewed'

@pytest.mark.parametrize('enabled,rows,expected', [(False,[{'rating':-1,'reason':'wrong_inventory'}]*4,0),(True,[],0),(True,[{'rating':-1,'reason':'wrong_inventory'}],0),(True,[{'rating':-1,'reason':'clarity'}]*4,0),(True,[{'rating':-1,'reason':'wrong_inventory'}]*3,1)])
def test_gradual_opt_in_learning_never_infers_style(enabled,rows,expected):
    client=MagicMock();q=client.table.return_value
    q.select.return_value.eq.return_value.eq.return_value.gte.return_value.order.return_value.limit.return_value.execute.return_value.data=rows
    with patch('app.services.personalization.repository.profile',return_value={'effective_enabled':enabled,'generation':7}),patch.object(f,'learning_client',return_value=client):
        assert len(f.learning_guidance(ACTOR))==expected
    if enabled: q.select.return_value.eq.return_value.eq.assert_called_once_with('learning_generation',7)
    else: client.table.assert_not_called()

def test_learning_failure_does_not_break_chat():
    with patch('app.services.personalization.repository.profile',side_effect=RuntimeError('offline')): assert f.learning_guidance(ACTOR)==[]

def test_eval_excludes_unreviewed_labels_private_data_and_unrated():
    row={'rating':-1,'reason':'wrong_inventory','comment':'SECRET','user_id':ACTOR,'reviewed_labels':{'retrieval_accuracy':'incorrect'},'review_status':'unreviewed'}
    result=summarize([row],10)
    assert result['coverage']==.1 and result['reviewed_examples']==[] and result['groups']==[]
    assert 'SECRET' not in str(result) and ACTOR not in str(result)
    row['review_status']='reviewed';row['reviewed_labels']['made_up']='correct'
    assert summarize([row],10)['reviewed_examples'][0]['labels']=={'retrieval_accuracy':'incorrect'}

def test_fixed_evaluation_detects_regression_and_requires_same_cases():
    a={'case':{'groundedness':'correct'}};b={'case':{'groundedness':'incorrect'}}
    assert not compare_fixed_cases(a,b)['passed']
    with pytest.raises(ValueError):compare_fixed_cases(a,{})

def test_routes_use_authenticated_actor_and_validate_body():
    app=FastAPI();app.include_router(router)
    app.dependency_overrides[get_current_user]=lambda:AuthenticatedUser(user_id=ACTOR)
    client=TestClient(app)
    with patch.object(f,'submit',return_value={'message_id':MSG,'rating':1,'revision':1}) as submit:
        r=client.put('/response-feedback/'+MSG,json={'rating':1})
        assert r.status_code==200 and r.headers['cache-control']=='private, no-store'
        assert submit.call_args.args[0]==ACTOR
        assert client.put('/response-feedback/'+MSG,json={'rating':1,'user_id':'other'}).status_code==422
    with patch.object(f,'forget',return_value={'deleted':True}) as forget:
        assert client.delete('/response-feedback').status_code==200
        forget.assert_called_once_with(ACTOR)
