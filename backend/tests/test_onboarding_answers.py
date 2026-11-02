from copy import deepcopy
from types import SimpleNamespace
from unittest.mock import patch
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from app.api.routes import onboarding
from app.core.auth import AuthenticatedUser, get_current_user

BASE = {'schema_version':1,'use_case':'business','use_case_other':None,
        'inventory_types':['tools','supplies'],'inventory_other':None,
        'primary_goal':'find_items','collaboration':'others'}
class Query:
    def __init__(self,db): self.db=db; self.uid=None; self.payload=None
    def select(self,fields): return self
    def eq(self,field,value): assert field=='user_id'; self.uid=value; return self
    def limit(self,n): assert n==1; return self
    def upsert(self,payload,on_conflict): assert on_conflict=='user_id'; self.payload=payload; return self
    def execute(self):
        if self.db.fail: raise RuntimeError('private database detail')
        if self.payload is not None:
            row=deepcopy(self.payload); self.db.rows[row['user_id']]=row
            return SimpleNamespace(data=[] if self.db.unconfirmed else [row])
        return SimpleNamespace(data=[deepcopy(self.db.rows[self.uid])] if self.uid in self.db.rows else [])
@pytest.fixture
def api():
    db=SimpleNamespace(rows={},fail=False,unconfirmed=False)
    db.table=lambda name: Query(db) if name=='onboarding_responses' else pytest.fail('Unexpected table')
    actor={'id':'account-a'}; app=FastAPI(); app.include_router(onboarding.router)
    app.dependency_overrides[get_current_user]=lambda: AuthenticatedUser(user_id=actor['id'])
    with patch.object(onboarding,'get_supabase_admin',return_value=db): yield TestClient(app),db,actor

def test_owned_read_update_and_repeat_are_separate_from_inventory(api):
    client,db,actor=api
    assert client.get('/profile/onboarding').json()=={'answers':None}
    for _ in range(2):
        result=client.put('/profile/onboarding',json=BASE); assert result.status_code==200
        assert result.json()['saved'] is True
    assert len(db.rows)==1 and db.rows['account-a']['source']=='ios'
    assert client.get('/profile/onboarding').json()['answers']['inventory_types']==['supplies','tools']
    actor['id']='account-b'
    assert client.get('/profile/onboarding').json()=={'answers':None}
    assert client.put('/profile/onboarding',json={**BASE,'use_case':'laboratory'}).status_code==200
    assert db.rows['account-a']['use_case']=='business'
    assert db.rows['account-b']['use_case']=='laboratory'

@pytest.mark.parametrize('change', [
    {'user_id':'foreign'}, {'schema_version':2}, {'use_case':'unknown'},
    {'use_case':'other'}, {'use_case_other':'Unchosen'}, {'inventory_types':[]},
    {'inventory_types':['tools','tools']}, {'inventory_types':['unknown']},
    {'inventory_types':['other']}, {'inventory_other':'Unchosen'},
    {'primary_goal':'sell_personal_data'}, {'collaboration':'everyone'},
    {'use_case':'other','use_case_other':'\n'},
    {'use_case':'other','use_case_other':'x\ny'},
    {'use_case':'other','use_case_other':'x'*81},
])
def test_invalid_answers_never_write(api,change):
    client,db,_=api
    assert client.put('/profile/onboarding',json={**BASE,**change}).status_code==422
    assert db.rows=={}

def test_custom_labels_are_trimmed_and_returned(api):
    client,db,_=api
    result=client.put('/profile/onboarding',json={**BASE,'use_case':'other','use_case_other':' Costume department ',
        'inventory_types':['other'],'inventory_other':' Fabric and props '})
    assert result.status_code==200
    assert result.json()['answers']['use_case_other']=='Costume department'
    assert result.json()['answers']['inventory_other']=='Fabric and props'

@pytest.mark.parametrize('method',['get','put'])
def test_failed_database_calls_are_visible_without_internal_details(api,method):
    client,db,_=api;db.fail=True
    response=client.get('/profile/onboarding') if method=='get' else client.put('/profile/onboarding',json=BASE)
    assert response.status_code==503
    assert 'private database detail' not in response.text

def test_unconfirmed_write_is_not_reported_as_saved(api):
    client,db,_=api;db.unconfirmed=True
    assert client.put('/profile/onboarding',json=BASE).status_code==503

def test_missing_auth_cannot_read_or_write():
    app=FastAPI();app.include_router(onboarding.router);client=TestClient(app)
    assert client.get('/profile/onboarding').status_code==401
    assert client.put('/profile/onboarding',json=BASE).status_code==401
