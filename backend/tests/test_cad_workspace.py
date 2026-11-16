from datetime import datetime, timedelta, timezone
import importlib.util
from pathlib import Path
from types import SimpleNamespace as NS
from unittest.mock import Mock

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from app.core.auth import AuthenticatedUser, get_current_user
from app.api.routes import cad_workspace as routes
from app.services.cad import workspace as service
from backend.tests.test_cad_prototype import snapshot, stock

ACTOR='00000000-0000-0000-0000-000000000001'
INV='10000000-0000-0000-0000-000000000001'
TOKEN='a'*64
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('fusion_client',ROOT/'integrations/findez-fusion/FindEZ/client.py')
client=importlib.util.module_from_spec(spec); spec.loader.exec_module(client)

class Query:
    def __init__(self,rows=None,data=None):
        self.rows=rows or []; self.calls=[]; self.data=data
    def __getattr__(self,name):
        def call(*args,**kwargs):
            self.calls.append((name,args,kwargs)); return self
        return call
    def execute(self): return NS(data=self.rows if self.data is None else self.data,count=len(self.rows))


def grant():
    return {'id':'grant','actor_id':ACTOR,'inventory_id':INV,'inventory_name':'Test inventory','workspace_name':'Personal',
            'revoked_at':None,'session_expires_at':(datetime.now(timezone.utc)+timedelta(hours=1)).isoformat()}


def test_pairing_persists_only_hash_and_separates_browser_code(monkeypatch):
    db=Query(); monkeypatch.setattr(service,'get_supabase_raw',lambda:db)
    response=service.start()
    inserted=next(c[1][0] for c in db.calls if c[0]=='insert')
    assert len(response['device_code'])==64 and len(response['user_code'])==10
    assert inserted=={'device_hash':service.digest(response['device_code']),'user_code':response['user_code']}
    assert response['device_code'] not in str(db.calls)
    assert response['verification_uri']=='https://www.findez.ai/cad/fusion/connect'

@pytest.mark.parametrize('status',['pending','expired'])
def test_exchange_does_not_leak_tokens_while_pending(monkeypatch,status):
    db=Query(data={'status':status}); monkeypatch.setattr(service,'get_supabase_raw',lambda:db)
    assert service.exchange(TOKEN)=={'status':status}


def test_exchange_token_hash_only_in_database(monkeypatch):
    db=Query(data={'status':'connected','expires_in':28800,'actor_id':ACTOR,'inventory_id':INV})
    monkeypatch.setattr(service,'get_supabase_raw',lambda:db)
    result=service.exchange(TOKEN)
    assert result['access_token'] not in str(db.calls)
    assert service.digest(result['access_token']) in str(db.calls)
    assert 'actor_id' not in result

@pytest.mark.parametrize('bad',['', 'jwt.token.value', 'x'*65,'a'*63+'/', 'a'*63+'\n'])
def test_malformed_token_never_reads_database(monkeypatch,bad):
    db=Mock(); monkeypatch.setattr(service,'get_supabase_raw',db)
    with pytest.raises(HTTPException) as error: service.authorize(bad)
    assert error.value.status_code==401
    db.assert_not_called()

@pytest.mark.parametrize('condition',['expired','revoked','missing','revoked_inventory'])
def test_authorization_revocation_and_expiry(monkeypatch,condition):
    row=grant()
    if condition=='expired':row['session_expires_at']=(datetime.now(timezone.utc)-timedelta(seconds=1)).isoformat()
    if condition=='revoked':row['revoked_at']=datetime.now(timezone.utc).isoformat()
    db=Query([] if condition=='missing' else [row]); monkeypatch.setattr(service,'get_supabase_raw',lambda:db)
    def access(*args):raise HTTPException(403,'Revoked')
    monkeypatch.setattr(service,'_inventory',access)
    with pytest.raises(HTTPException): service.authorize(TOKEN)


def test_session_authority_comes_from_stored_scope(monkeypatch):
    db=Query([grant()]); db.rpc=lambda *a,**k:Query(data='viewer'); monkeypatch.setattr(service,'get_supabase_raw',lambda:db)
    access=Mock(return_value={'name':'Test inventory','workspace':{'name':'Personal'}})
    monkeypatch.setattr(service,'_inventory',access)
    assert service.authorize(TOKEN)['inventory_id']==INV
    access.assert_called_once_with(INV,ACTOR)
    assert ('eq',('token_hash',service.digest(TOKEN)),{}) in db.calls


def test_browse_scoped_available_not_owned_catalog(monkeypatch):
    read=Mock(return_value=([stock(42)], [{'inventory_item_id':'stock-1','quantity':10}], [{'item_id':'stock-1','quantity':3}]))
    monkeypatch.setattr(service,'read_inventory',read)
    result=service.browse(grant(),'m3-12')
    read.assert_called_once_with(INV,ACTOR)
    item=result['items'][0]
    assert (item['on_hand'],item['reserved'],item['checked_out'],item['available'])==(42,10,3,29)
    assert item['on_order'] is None and item['cad_model'] is None
    assert not service.browse(grant(),location='another bin')['items']


def test_browse_unknown_obligations_block_availability_and_paginate(monkeypatch):
    items=[stock(5,item_id=str(i),name=f'Part {i:03}') for i in range(51)]
    monkeypatch.setattr(service,'read_inventory',lambda *args:(items,[{'inventory_item_id':'0','quantity':'5'}],[]))
    result=service.browse(grant())
    assert len(result['items'])==50 and result['next_offset']==50
    assert result['items'][0]['available']==0 and not result['items'][0]['availability_known']
    assert len(service.browse(grant(),offset=50)['items'])==1


def test_catalog_restricts_verified_and_escapes_search(monkeypatch):
    db=Query([{'catalog_id':'a','canonical_name':'Part'}]); monkeypatch.setattr(service,'get_supabase_raw',lambda:db)
    result=service.catalog('10%_')
    assert ('eq',('verification_status','verified'),{}) in db.calls
    assert ('ilike',('canonical_name','%10\\%\\_%'),{}) in db.calls
    assert 'quantity' not in str(db.calls)
    assert result['source']=='global_catalog_not_owned_stock'
    assert result['parts'][0]['price'] is None


def api(monkeypatch):
    monkeypatch.setattr(service,'authorize',lambda token:grant())
    app=FastAPI(); app.include_router(routes.router)
    app.dependency_overrides[routes.session]=grant
    app.dependency_overrides[get_current_user]=lambda:AuthenticatedUser(ACTOR)
    return TestClient(app)


def test_compare_uses_same_engine_and_does_not_accept_scope_override(monkeypatch):
    read=Mock(return_value=([stock(6)],[],[])); monkeypatch.setattr(routes,'read_inventory',read)
    with api(monkeypatch) as http:
        result=http.post('/fusion/compare',json=snapshot().model_dump(mode='json'))
        assert result.status_code==200
        assert result.json()['summary']['covered_units']==6
        read.assert_called_once_with(INV,ACTOR)
        forged=snapshot().model_dump(mode='json'); forged['inventory_id']='other'
        assert http.post('/fusion/compare',json=forged).status_code==422
        assert http.post('/fusion/compare',content=b'x'*(5*1024*1024+1)).status_code==413


def test_approval_is_explicit_actor_bound_and_validated(monkeypatch):
    approve=Mock(return_value={'approved':True});monkeypatch.setattr(service,'approve',approve)
    with api(monkeypatch) as http:
        assert http.post('/fusion/pairing/approve',json={'code':'ABCD234567','inventory_id':INV}).status_code==200
        approve.assert_called_once_with('ABCD234567',INV,ACTOR,False)
        assert http.post('/fusion/pairing/approve',json={'code':'bad','inventory_id':INV}).status_code==422

def test_bom_save_is_bounded_and_rejects_forged_inventory(monkeypatch):
    save=Mock(return_value={'version':1});monkeypatch.setattr(routes.projects,'save',save)
    payload={'request_id':INV,'snapshot':snapshot().model_dump(mode='json')}
    with api(monkeypatch) as http:
        assert http.post('/fusion/bom/versions',json=payload).status_code==200
        assert save.call_args.args[1:3]==(INV,ACTOR)
        assert save.call_args.args[4]=='grant'
        assert http.post('/fusion/bom/versions',json={**payload,'inventory_id':'other'}).status_code==422
        assert http.post('/fusion/bom/versions',content=b'x'*(5*1024*1024+1)).status_code==413
    assert save.call_count==1


def test_client_rejects_redirects_and_stale_account_connect():
    assert client.NoRedirect().redirect_request(None,None,302,'','', 'https://elsewhere.invalid') is None
    session=client.Session();generation=session.generation;session.clear()
    assert not session.connect(TOKEN,generation) and session.token is None
    assert session.connect(TOKEN,session.generation)
    assert session.clear()==TOKEN
    with pytest.raises(client.ClientError):session.request('/inventory')

def test_queued_native_write_cannot_switch_to_a_new_inventory_session(monkeypatch):
    session=client.Session();session.connect(TOKEN,session.generation);old=session.generation
    session.clear();session.connect('b'*64,session.generation)
    transport=Mock();monkeypatch.setattr(client,'call',transport)
    with pytest.raises(client.ClientError):session.request_at(old,'/bom/versions',method='POST',data={})
    transport.assert_not_called()

@pytest.mark.parametrize('source,query,offset',[('https://evil.invalid','',0),('inventory','a'*101,0),('inventory','',-1),('inventory','',True)])
def test_client_validates_search(source,query,offset):
    with pytest.raises(client.ClientError):client.search_path(source,query,offset)



def test_native_requests_use_production_api_origin_without_redirects(monkeypatch):
    class Response:
        def __enter__(self):return self
        def __exit__(self,*args):pass
        def read(self,limit):return b'{"status":"pending"}'
    opener=Mock();opener.open.return_value=Response()
    monkeypatch.setattr(client.request,'build_opener',lambda *args:opener)
    assert client.call('/session',token=TOKEN)=={'status':'pending'}
    req=opener.open.call_args.args[0]
    assert req.full_url=='https://findez.openstack.ftctools.com/fusion/session'
    assert req.headers['Authorization']=='Bearer '+TOKEN


def test_ai_search_route_rechecks_capability_after_model_work(monkeypatch):
    authorize=Mock(return_value=grant()); search=Mock(return_value={'items':[],'source':'inventory'})
    monkeypatch.setattr(service,'authorize',authorize);monkeypatch.setattr(routes,'search_parts',search)
    app=FastAPI();app.include_router(routes.router)
    with TestClient(app) as http:
        response=http.post('/fusion/search',headers={'Authorization':'Bearer '+TOKEN},json={'query':'Find bearings','source':'inventory'})
        assert response.status_code==200
        assert authorize.call_count==2
        assert search.call_args.args[0] is authorize.return_value
        assert http.post('/fusion/search',headers={'Authorization':'Bearer '+TOKEN},json={'query':'bearings','inventory_id':'another'}).status_code==422
