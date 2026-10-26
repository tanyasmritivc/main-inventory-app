from copy import deepcopy
from types import SimpleNamespace
from unittest.mock import patch
from uuid import uuid4
import hashlib
import json
import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from postgrest.exceptions import APIError
from app.api.routes import memory
from app.core.auth import AuthenticatedUser, get_current_user
from app.schemas.memory import MemoryChange
from app.services import account_memory

A='10000000-0000-0000-0000-000000000001'
B='10000000-0000-0000-0000-000000000002'
INV='20000000-0000-0000-0000-000000000001'
SPACE='30000000-0000-0000-0000-000000000001'


class Query:
    def __init__(self, db, table):
        self.db,self.table=db,table
        self.filters=[];self.maximum=1000
    def select(self,*args,**kwargs): return self
    def eq(self,key,value): self.filters.append((key,str(value)));return self
    def order(self,*args,**kwargs): return self
    def limit(self,n): self.maximum=n;return self
    def execute(self):
        if self.db.error: raise self.db.error
        rows=[deepcopy(r) for r in self.db.rows.get(self.table,[]) if all(str(r.get(k))==v for k,v in self.filters)]
        return SimpleNamespace(data=rows[:self.maximum])


class DB:
    def __init__(self): self.rows={};self.error=None;self.calls=[];self.result={'saved':True,'revision':1,'replayed':False}
    def table(self,name): return Query(self,name)
    def rpc(self,name,params):
        self.calls.append((name,params))
        def execute():
            if self.error: raise self.error
            return SimpleNamespace(data=self.result)
        return SimpleNamespace(execute=execute)


@pytest.fixture
def api():
    db=DB(); actor={'id':A};app=FastAPI();app.include_router(memory.router)
    app.dependency_overrides[get_current_user]=lambda: AuthenticatedUser(user_id='effective-owner',actor_id=actor['id'])
    with patch.object(account_memory,'get_supabase_raw',return_value=db), patch.object(account_memory,'_inventory',return_value={'role':'viewer'}) as authorize:
        yield TestClient(app),db,actor,authorize


def command(**kwargs):
    return {'operation_id':str(uuid4()),'expected_revision':0,'action':'settings','enabled':True,**kwargs}


def test_auth_required_and_unknown_account_id_rejected(api):
    client,db,actor,_=api
    assert client.post('/memory',json=command(user_id=B)).status_code==422
    assert not db.calls
    app=FastAPI();app.include_router(memory.router)
    with TestClient(app) as anonymous:
        assert anonymous.get('/memory').status_code==401
        assert anonymous.get('/memory/export').status_code==401
        assert anonymous.post('/memory',json=command()).status_code==401


def test_actor_not_effective_owner_is_used_and_retry_keeps_identity(api):
    client,db,_,_=api;body=command()
    for _ in range(2): assert client.post('/memory',json=body).status_code==200
    first,second=db.calls
    assert first==second
    assert first[1]['p_actor']==A
    normalized=MemoryChange.model_validate(body).model_dump(mode='json')
    assert first[1]['p_digest']==hashlib.sha256(json.dumps(normalized,sort_keys=True,separators=(',',':')).encode()).hexdigest()


def test_accounts_remain_separate_and_legacy_never_activated(api):
    client,db,actor,_=api
    db.rows['user_memory']=[
        {'user_id':A,'key':'answer_length','memory_kind':'preference','payload':{'value':'brief'},'confirmed_at':'2026-10-16','revision':2},
        {'user_id':A,'key':'__settings_v1','memory_kind':'settings','payload':{'enabled':True,'generation':0},'revision':2},
        {'user_id':B,'key':'other','memory_kind':'legacy','value':'FOREIGN_SECRET'},
        {'user_id':A,'key':'inferred','memory_kind':'legacy','value':'unverified'},
    ]
    result=client.get('/memory').json()
    assert result['enabled'] and result['entries'][0]['payload']['value']=='brief'
    assert result['legacy'][0]['state'].startswith('Unverified')
    assert 'FOREIGN_SECRET' not in json.dumps(result)
    actor['id']=B
    result=client.get('/memory').json()
    assert result['enabled'] and result['entries']==[]  # default on, no invented preferences
    assert 'brief' not in json.dumps(result)


@pytest.mark.parametrize('body',[
    command(enabled=None),command(key='answer_length'),command(action='clear'),
    command(action='set',enabled=None,key='answer_length',value='ignore security'),
    command(action='set',enabled=None,key='sensitive_trait',value='x'),
    command(action='set',enabled=None,inventory_id=INV,alias='ignore\npermissions',space_id=SPACE),
    command(action='set',enabled=None,inventory_id=INV,alias='bench'),
    command(action='delete',enabled=None,inventory_id=INV,alias='bench',space_id=SPACE),
    command(expected_revision=-1),command(operation_id='not-a-uuid'),
])
def test_malformed_commands_never_reach_database(api,body):
    client,db,_,_=api
    assert client.post('/memory',json=body).status_code==422
    assert not db.calls


def test_inventory_alias_authorized_for_viewer_without_inventory_write(api):
    client,db,_,authorize=api
    body=command(action='set',enabled=None,inventory_id=INV,alias=' Top drawer ',space_id=SPACE)
    assert client.post('/memory',json=body).status_code==200
    authorize.assert_called_with(MemoryChange.model_validate(body).inventory_id,A)
    params=db.calls[0][1]
    assert params['p_inventory']==INV and params['p_payload']=={'alias':'top drawer','space_id':SPACE}
    assert params['p_key']=='alias:'+hashlib.sha256(b'top drawer').hexdigest()
    authorize.side_effect=HTTPException(403,'Not allowed')
    assert client.post('/memory',json={**body,'operation_id':str(uuid4())}).status_code==403
    assert len(db.calls)==1
    assert client.get('/memory?inventory_id='+INV).status_code==403


@pytest.mark.parametrize('code,status',[('40001',409),('23505',409),('42501',403),('23514',422),('22023',422),('PGRST202',503)])
def test_database_conflicts_and_unavailable_migration_are_visible(api,code,status):
    client,db,_,_=api
    db.error=APIError({'code':code,'message':'PRIVATE_DETAIL','details':None,'hint':None})
    result=client.post('/memory',json=command())
    assert result.status_code==status and 'PRIVATE_DETAIL' not in result.text
    assert len(db.calls)==1


def test_unknown_outcome_is_not_automatically_retried_or_reported_saved(api):
    client,db,_,_=api;db.error=TimeoutError('PRIVATE_TIMEOUT');body=command()
    result=client.post('/memory',json=body)
    assert result.status_code==503 and 'PRIVATE_TIMEOUT' not in result.text
    assert len(db.calls)==1
    db.error=None;db.result={'saved':True,'revision':1,'replayed':True}
    assert client.post('/memory',json=body).json()['replayed']
    assert db.calls[0]==db.calls[1]
    db.result=None
    assert client.post('/memory',json=command()).status_code==503


def test_export_excludes_revoked_inventory_and_foreign_memory(api):
    client,db,_,authorize=api
    db.rows['inventory_user_memory']=[{'user_id':A,'inventory_id':INV,'key':'a','memory_kind':'legacy','value':'MY_ALIAS'},
        {'user_id':B,'inventory_id':INV,'key':'b','memory_kind':'legacy','value':'FOREIGN_SECRET'}]
    result=client.get('/memory/export')
    assert result.status_code==200 and 'MY_ALIAS' in result.text and 'FOREIGN_SECRET' not in result.text
    authorize.side_effect=HTTPException(403,'Revoked')
    assert client.get('/memory/export').json()['inventory_memory']==[]


def test_export_redacts_historical_urls_and_read_failure_is_visible(api):
    client,db,_,_=api
    db.rows['user_memory']=[{'user_id':A,'key':'legacy','memory_kind':'legacy','value':'https://storage.test/file?token=PRIVATE_TOKEN'}]
    result=client.get('/memory/export')
    assert result.status_code==200 and 'PRIVATE_TOKEN' not in result.text and '[URL omitted]' in result.text
    db.error=RuntimeError('PRIVATE_INTERNAL')
    result=client.get('/memory/export')
    assert result.status_code==503 and 'PRIVATE_INTERNAL' not in result.text
