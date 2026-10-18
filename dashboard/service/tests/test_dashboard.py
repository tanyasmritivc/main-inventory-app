import asyncio
import sys
from pathlib import Path
from unittest.mock import AsyncMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import httpx
from fastapi.testclient import TestClient
from collectors import Sources, metric
from main import create_app
from store import Store

OWNER = 'bcbfb7db-a5a0-4987-8847-b7bb37c68a36'


def client(tmp_path, user=None, status=200):
    async def handler(request):
        return httpx.Response(status, json=user or {'id': OWNER, 'email_confirmed_at': '2026-01-01T00:00:00Z'})
    source = Sources({'SUPABASE_URL':'https://auth.example.test','SUPABASE_SERVICE_ROLE_KEY':'server-only','SUPABASE_ANON_KEY':'public'}, httpx.AsyncClient(transport=httpx.MockTransport(handler)))
    store = Store(tmp_path/'dashboard.sqlite')
    return TestClient(create_app(source, store, OWNER, monitor=False)), store, source


def test_all_administrative_routes_require_authentication(tmp_path):
    c, _, _ = client(tmp_path)
    for method, path, payload in [('GET','snapshot',None),('POST','issues',{'title':'Test issue'}),('PATCH','issues/x',{'status':'resolved'})]:
        r=c.request(method,'/dashboard/v1/'+path,json=payload)
        assert r.status_code==401
        assert r.headers['cache-control']=='no-store, private'


def test_ordinary_account_cannot_read_or_write_and_denial_is_audited(tmp_path):
    c, store, _=client(tmp_path, {'id':'someone-else','email_confirmed_at':'2026-01-01'})
    for method,path,payload in [('GET','snapshot',None),('POST','issues',{'title':'Unauthorized issue'}),('PATCH','issues/x',{'status':'resolved'})]:
        assert c.request(method,'/dashboard/v1/'+path,json=payload,headers={'Authorization':'Bearer token'}).status_code==403
    assert len(store.audits())==3
    assert not store.issues()


def test_invalid_token_never_reaches_sources(tmp_path):
    c,_,source=client(tmp_path,status=401)
    source.application=AsyncMock()
    assert c.get('/dashboard/v1/snapshot',headers={'Authorization':'Bearer bad'}).status_code==401
    source.application.assert_not_called()


def test_unconfirmed_founder_is_rejected(tmp_path):
    c,_,_=client(tmp_path,{'id':OWNER})
    assert c.get('/dashboard/v1/snapshot',headers={'Authorization':'Bearer token'}).status_code==403


def test_multifactor_account_requires_aal2(tmp_path):
    import base64,json
    c,_,_=client(tmp_path,{'id':OWNER,'email_confirmed_at':'yes','factors':[{'status':'verified'}]})
    claims=base64.urlsafe_b64encode(json.dumps({'aal':'aal1'}).encode()).decode().rstrip('=')
    assert c.get('/dashboard/v1/snapshot',headers={'Authorization':'Bearer a.'+claims+'.b'}).status_code==403


def test_founder_issue_updates_are_durable_and_audited(tmp_path):
    c,store,_=client(tmp_path)
    h={'Authorization':'Bearer token'}
    r=c.post('/dashboard/v1/issues',json={'title':'Investigate scan failure','severity':'critical'},headers=h)
    assert r.status_code==201
    identity=r.json()['id']
    assert c.patch('/dashboard/v1/issues/'+identity,json={'status':'resolved'},headers=h).status_code==200
    assert Store(tmp_path/'dashboard.sqlite').issues()[0]['status']=='resolved'
    assert {r['action'] for r in store.audits()}=={'create_issue','set_status_resolved'}
    assert c.patch('/dashboard/v1/issues/'+identity,json={'status':'deleted'},headers=h).status_code==422
    assert c.patch('/dashboard/v1/issues/missing',json={'status':'open'},headers=h).status_code==404


def test_unavailable_source_does_not_become_zero_and_other_sources_survive(tmp_path):
    c,_,source=client(tmp_path)
    source.application=AsyncMock(side_effect=RuntimeError('secret internal information'))
    source.usage=AsyncMock(return_value={'metrics':[metric('chats','Chats',0,source='counter')]})
    source.revenue=AsyncMock(return_value={'metrics':[]})
    source.health=AsyncMock(return_value={'metrics':[],'checks':[]})
    diagnostics={'requests':0,'errors':0,'error_rate':None,'categories':{},'events':[],'partial':False,'note':'No traffic'}
    with patch('main.journal_summary',AsyncMock(return_value=diagnostics)):
        r=c.get('/dashboard/v1/snapshot',headers={'Authorization':'Bearer token'})
    assert r.status_code==200
    data=r.json()
    assert data['analytics']['unavailable'] is True
    assert data['ai']['metrics'][0]['value']==0
    assert 'secret' not in r.text
    assert not data['customers']


def test_test_mode_stripe_is_not_reported_as_real_revenue(tmp_path):
    _,_,source=client(tmp_path)
    source.env['STRIPE_SECRET_KEY']='sk_test_placeholder'
    value=asyncio.run(source.revenue())
    assert value['connected'] is False
    assert all(m['value'] is None for m in value['metrics'])


def test_mrr_annual_normalization_and_refunds_are_distinct(tmp_path):
    _,_,source=client(tmp_path)
    source.env['STRIPE_SECRET_KEY']='sk_live_placeholder'
    source.stripe_list=AsyncMock(side_effect=[[
        {'status':'active','customer':'c1','items':{'data':[{'quantity':2,'price':{'currency':'usd','unit_amount':12000,'recurring':{'interval':'year','interval_count':1,'usage_type':'licensed'}}}]}},
    ],[{'currency':'usd','paid':True,'status':'succeeded','amount':12000,'amount_refunded':2000}]])
    values={m['id']:m for m in asyncio.run(source.revenue())['metrics']}
    assert values['mrr']['value']==20
    assert values['arr']['value']==240
    assert values['gross30']['value']==120
    assert values['after_refunds']['value']==100
    assert values['cash']['value'] is None
    assert values['profit']['value'] is None


def test_detected_health_issue_resolves_and_reopens(tmp_path):
    store=Store(tmp_path/'issues.sqlite')
    store.incident('api','API down','Probe failed','critical',True)
    store.incident('api','API down','Probe failed','critical',False)
    assert store.issues()[0]['status']=='resolved'
    store.incident('api','API down','Probe failed','critical',True)
    assert store.issues()[0]['status']=='open'
    assert store.audits()[0]['action']=='auto_resolve'


def test_email_code_only_goes_to_configured_founder_and_is_throttled(tmp_path):
    c,store,source=client(tmp_path)
    source.env.update(BREVO_SMTP_USERNAME='smtp-test',BREVO_SMTP_PASSWORD='not-real')
    async def handler(request):
        if request.url.path.endswith('/generate_link'):
            import json
            assert json.loads(request.content)['email']=='founder@example.test'
            return httpx.Response(200,json={'email_otp':'123456'})
        return httpx.Response(200,json={'id':OWNER,'email':'founder@example.test','email_confirmed_at':'yes'})
    source.client=httpx.AsyncClient(transport=httpx.MockTransport(handler))
    with patch('smtplib.SMTP') as smtp:
        response=c.post('/dashboard/v1/login/code',json={'email':'attacker@example.test'})
        assert response.status_code==200
        assert '123456' not in response.text
        message=smtp.return_value.__enter__.return_value.send_message.call_args[0][0]
        assert message['To']=='founder@example.test'
        assert c.post('/dashboard/v1/login/code').status_code==429
    assert any(a['action']=='send_signin_code' for a in store.audits())


def test_email_delivery_failure_is_reported_and_audited(tmp_path):
    c,store,source=client(tmp_path)
    source.env.update(BREVO_SMTP_USERNAME='smtp-test',BREVO_SMTP_PASSWORD='not-real')
    async def handler(request):
        return httpx.Response(200,json={'email_otp':'123456'} if request.url.path.endswith('/generate_link') else {'id':OWNER,'email':'founder@example.test','email_confirmed_at':'yes'})
    source.client=httpx.AsyncClient(transport=httpx.MockTransport(handler))
    with patch('smtplib.SMTP',side_effect=RuntimeError('private SMTP credential details')):
        response=c.post('/dashboard/v1/login/code')
    assert response.status_code==503
    assert 'private SMTP' not in response.text
    assert store.audits()[0]['outcome']=='failed'
