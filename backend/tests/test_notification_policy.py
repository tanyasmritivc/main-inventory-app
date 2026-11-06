from types import SimpleNamespace
from unittest.mock import MagicMock
from uuid import uuid4
import httpx
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from app.api.routes import notifications as routes
from app.core.auth import AuthenticatedUser, get_current_user
from app.services import notification_delivery as delivery, notification_policy, push_notifications

A=str(uuid4()); B=str(uuid4()); N=str(uuid4())


@pytest.fixture
def api(monkeypatch):
    monkeypatch.setenv('FINDEZ_NOTIFICATION_POLICY_ENABLED','1')
    app=FastAPI();app.include_router(routes.router)
    app.dependency_overrides[get_current_user]=lambda:AuthenticatedUser(user_id=B,actor_id=A)
    return TestClient(app)


def test_preferences_are_actor_bound_and_closed(api,monkeypatch):
    calls=[]
    def rpc(name,args): calls.append((name,args));return {'revision':1,'push_enabled':False}
    monkeypatch.setattr(routes,'_policy_rpc',rpc)
    assert api.get('/notifications/preferences').json()['policy']=={'daily':2,'weekly':5,'noncritical_hours':24,'local_alerts':False}
    assert calls[-1][1]['p_actor']==A
    assert api.patch('/notifications/preferences',json={'expected_revision':0,'push_enabled':True}).status_code==200
    assert calls[-1][1]['p_data']=={'push_enabled':True}
    for extra in ({'user_id':B},{'weekly_recap':True},{'push_enabled':None},{'push_enabled':'true'},{'quiet_start':1440},{'timezone':'Mars/Test'},{'paused_until':'2099-01-01T00:00:00Z'}):
        assert api.patch('/notifications/preferences',json={'expected_revision':0,**extra}).status_code==422


def test_unavailable_and_errors_do_not_expose_internals(api,monkeypatch):
    monkeypatch.setenv('FINDEZ_NOTIFICATION_POLICY_ENABLED','0')
    assert api.get('/notifications/preferences').status_code==404
    monkeypatch.setenv('FINDEZ_NOTIFICATION_POLICY_ENABLED','1')
    db=MagicMock();db.rpc.side_effect=RuntimeError('SECRET')
    monkeypatch.setattr(routes,'get_supabase_raw',lambda:db)
    response=api.get('/notifications/preferences')
    assert response.status_code==503 and 'SECRET' not in response.text


def test_policy_default_blocks_legacy_push_paths(monkeypatch):
    monkeypatch.delenv('FINDEZ_NOTIFICATION_POLICY_ENABLED',raising=False)
    assert not notification_policy.enabled()
    monkeypatch.setenv('FINDEZ_NOTIFICATION_POLICY_ENABLED','1')
    monkeypatch.setattr(push_notifications,'_credentials',lambda:pytest.fail('legacy must not reach provider'))
    assert push_notifications._send({},title='x',body='x') is False


def test_inapp_off_never_fetches_activity_or_invitation_content(api,monkeypatch):
    monkeypatch.setattr(routes,'_policy_rpc',lambda *a:{'in_app_enabled':False})
    monkeypatch.setattr(routes,'notification_rows',lambda *a:pytest.fail('disabled inbox'))
    assert api.get('/notifications').json()=={'notifications':[],'unread_count':0,'policy_version':1}


@pytest.mark.parametrize('status,reason,result',[(200,None,('accepted',None)),(429,None,('retry','provider_transient')),(503,None,('retry','provider_transient')),(410,'Unregistered',('failed','invalid_token')),(400,'BadDeviceToken',('failed','invalid_token')),(403,'Forbidden',('failed','provider_rejected'))])
def test_provider_results_and_privacy(monkeypatch,status,reason,result):
    client=MagicMock();client.__enter__.return_value=client
    client.post.return_value=SimpleNamespace(status_code=status,json=lambda:{'reason':reason})
    monkeypatch.setattr(delivery.httpx,'Client',lambda **kw:client)
    monkeypatch.setattr(push_notifications,'_credentials',lambda:('path','kid','team','topic'))
    monkeypatch.setattr(push_notifications,'_authorization',lambda:'fake')
    db=MagicMock();monkeypatch.setattr(delivery,'get_supabase_raw',lambda:db)
    assert delivery.send_once({'device_token':'PRIVATE','environment':'sandbox'},N,A,{'title':'FindEZ','body':'An inventory item needs your attention.'})==result
    payload=client.post.call_args.kwargs['json']
    assert set(payload)=={'aps','action','notification_id','recipient_user_id'}
    assert client.post.call_args.kwargs['headers']['apns-expiration']=='0'
    assert db.table.called == (result[1]=='invalid_token')


def test_unknown_transport_outcome_is_not_retryable(monkeypatch,caplog):
    client=MagicMock();client.__enter__.return_value=client
    client.post.side_effect=httpx.ReadTimeout('PRIVATE_DEVICE_TOKEN')
    monkeypatch.setattr(delivery.httpx,'Client',lambda **kw:client)
    monkeypatch.setattr(push_notifications,'_credentials',lambda:('path','kid','team','topic'))
    monkeypatch.setattr(push_notifications,'_authorization',lambda:'fake')
    assert delivery.send_once({'device_token':'PRIVATE'},N,A,{})==('unknown','transport_unknown')
    assert 'PRIVATE' not in caplog.text and client.post.call_count==1


@pytest.mark.parametrize('outcomes,expected',[
    ([('retry','provider_transient')]*3,'failed'),
    ([('retry','provider_transient'),('accepted',None)],'accepted'),
    ([('unknown','transport_unknown')],'unknown'),
    ([('failed','invalid_token')],'failed'),
])
def test_dispatch_rechecks_each_bounded_attempt_and_keeps_one_id(monkeypatch,outcomes,expected):
    calls=[];results=iter(outcomes);sends=[]
    class DB:
        name=''
        def rpc(self,name,args):self.name=name;calls.append((name,args));return self
        def table(self,name):self.name=name;return self
        def __getattr__(self,key):return lambda *a,**kw:self
        def execute(self):
            data={'findez_personalization_candidates':[{'id':N}],
                  'findez_personalization_claim':{'user_id':A,'category':'low_stock'},
                  'findez_notification_content':{'title':'FindEZ','body':'Generic','revision':0},
                  'findez_notification_begin_attempt':True,
                  'push_devices':[{'device_token':'fake'}]}.get(self.name)
            return SimpleNamespace(data=data)
    monkeypatch.setattr(delivery,'get_supabase_raw',DB)
    def send(*args):sends.append(args);return next(results)
    monkeypatch.setattr(delivery,'send_once',send)
    sleeps=[];monkeypatch.setattr(delivery.time,'sleep',sleeps.append)
    assert delivery.dispatch()['accepted']==int(expected=='accepted')
    assert len(sends)==len(outcomes)
    assert all(args[1]==N for args in sends)
    assert sum(name=='findez_notification_begin_attempt' for name,_ in calls)==len(outcomes)
    assert calls[-1][1]['p_result']==expected
    assert len(sleeps)==len(outcomes)-1


def test_personal_stock_rules_are_account_bound_and_bounded(api,monkeypatch):
    calls=[]
    monkeypatch.setattr(routes,'_policy_rpc',lambda name,args:calls.append((name,args)) or {})
    item=str(uuid4())
    body={'rules':[{'item_id':item,'threshold':5}], 'import_only':True}
    assert api.post('/notifications/stock-rules',json=body).status_code==200
    assert calls[-1][1]=={'p_actor':A,'p_rules':body['rules'],'p_import':True}
    for invalid in ({'rules':[{'item_id':item,'threshold':-1}]},{'rules':body['rules']*501},{**body,'user_id':B},{'rules':[{'item_id':item,'threshold':True}]}):
        assert api.post('/notifications/stock-rules',json=invalid).status_code==422
