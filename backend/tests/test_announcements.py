from types import SimpleNamespace
from unittest.mock import Mock
from uuid import uuid4

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from app.api.routes.announcements import router, ClaimRequest
from app.core.auth import AuthenticatedUser, get_current_user
from app.services import announcements as service


@pytest.fixture
def client():
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser('actor-a')
    return TestClient(app)


def test_claim_binds_actor_and_validates_input(client, monkeypatch):
    claim = Mock(return_value={'campaign': None, 'access': {}})
    monkeypatch.setattr(service, 'claim', claim)
    data = {'session_id': str(uuid4()), 'platform': 'ios', 'client_revision': 1, 'user_id': 'victim'}
    assert client.post('/announcements/claim', json=data).status_code == 200
    assert claim.call_args.args[0] == 'actor-a'
    for field, value in [('platform','web'), ('session_id','bad'), ('client_revision',0)]:
        assert client.post('/announcements/claim', json={**data,field:value}).status_code == 422


def test_receipts_require_owned_claim_and_are_bounded(client, monkeypatch):
    receipt = Mock(return_value=False)
    monkeypatch.setattr(service,'receipt',receipt)
    assert client.post('/announcements/other/receipt',json={'event':'clicked'}).status_code == 404
    assert receipt.call_args.args == ('actor-a','other','clicked')
    assert client.post('/announcements/other/receipt',json={'event':'published'}).status_code == 422
    receipt.return_value = True
    assert client.post('/announcements/mine/receipt',json={'event':'dismissed'}).json() == {'saved':True}


def test_requires_authentication():
    app=FastAPI(); app.include_router(router)
    client=TestClient(app)
    assert client.get('/announcements/access').status_code == 401


def test_pilot_uses_actual_free_allowances_not_prototype_restrictions(monkeypatch):
    monkeypatch.setattr(service,'get_settings',lambda:SimpleNamespace(pilot_mode=True))
    monkeypatch.setattr(service,'resolve_effective_limits',lambda _: ({'items':None,'chats_per_month':None,'scans_per_month':None},None))
    monkeypatch.setattr(service,'get_user_tier',lambda _:'free')
    snapshot=service.access_snapshot('actor-a')
    assert snapshot['name']=='Free pre-launch access'
    assert all(r['now']==r['free']=='Included' for r in snapshot['rows'])
    assert 'ever deleted' not in snapshot['fine']


def test_nonpilot_current_caps_and_team_imports(monkeypatch):
    monkeypatch.setattr(service,'get_settings',lambda:SimpleNamespace(pilot_mode=False))
    monkeypatch.setattr(service,'resolve_effective_limits',lambda _: ({'items':None,'chats_per_month':2000,'scans_per_month':600},'team'))
    monkeypatch.setattr(service,'get_user_tier',lambda _:'team_member')
    data=service.access_snapshot('actor-a')
    assert data['badge'] is None
    assert data['name']=='Team'
    assert data['rows'][-1]['now']=='Limited'
    assert data['rows'][-1]['free']=='Limited'


def test_plan_failure_does_not_consume_claim(monkeypatch):
    def fail(_): raise RuntimeError('read failed')
    monkeypatch.setattr(service,'access_snapshot',fail)
    rpc=Mock(); monkeypatch.setattr(service,'get_supabase_admin',rpc)
    with pytest.raises(RuntimeError):
        service.claim('actor-a',ClaimRequest(session_id=uuid4(),platform='ios',client_revision=1))
    rpc.assert_not_called()
