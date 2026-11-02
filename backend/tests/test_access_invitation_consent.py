"""HTTP/delivery contracts; the SQL fixture proves actual membership isolation."""
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
from uuid import uuid4

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from postgrest.exceptions import APIError

from app.api.routes import access_invitations, collaboration
from app.core.auth import AuthenticatedUser, get_current_user
from app.services import access_invitations as service

ACTOR, RESOURCE, TARGET, INVITE = [str(uuid4()) for _ in range(4)]


def row(**extra):
    return {'invitation_id': INVITE, 'scope': 'organization', 'resource_id': RESOURCE,
            'resource_name': 'Acme <Project>', 'role': 'member', 'status': 'pending',
            'recipient_email': 'recipient@example.invalid', 'created_at': '2026-10-15T00:00:00Z',
            'expires_at': '2026-10-22T00:00:00Z', **extra}


@pytest.fixture
def api():
    app = FastAPI()
    app.include_router(collaboration.router)
    app.include_router(access_invitations.router)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(user_id=ACTOR)
    db = MagicMock()
    db.rpc.return_value.execute.return_value = SimpleNamespace(data=row())
    with patch.object(service, 'get_supabase_raw', return_value=db), patch.object(service, 'get_settings', return_value=SimpleNamespace(frontend_url='https://www.findez.ai/')), patch.object(service, 'send_transactional_email') as mail:
        with TestClient(app) as client:
            yield client, db, mail


def test_add_member_persists_pending_invitation_before_sending_link_and_code(api):
    client, db, mail = api
    result = client.post(f'/organizations/{RESOURCE}/members', json={'email': 'recipient@example.invalid', 'role': 'member'})
    assert result.status_code == 200, result.text
    data = result.json()
    args = db.rpc.call_args.args
    assert args[0] == 'findez_access_invitation'
    assert args[1]['p_actor'] == ACTOR and args[1]['p_action'] == 'create'
    assert args[1]['p_data']['code_hash'] == service.code_hash(data['code'])
    assert len(data['code']) == 12 and set(data['code']) <= set(service.ALPHABET)
    assert data['code'] not in str(args)
    assert data['invite_url'] == f"https://www.findez.ai/join/access?code={data['code']}"
    assert data['invitation']['status'] == 'pending' and data['email_sent'] is True
    assert '<Project>' not in mail.call_args.kwargs['html']
    assert 'No access is granted until you accept' in mail.call_args.kwargs['text']
    db.table.assert_not_called()


def test_email_failure_retains_pending_invitation_and_usable_link_without_claiming_delivery(api):
    client, db, mail = api
    mail.side_effect = RuntimeError('private SMTP error')
    result = client.post(f'/organizations/{RESOURCE}/members', json={'email': 'recipient@example.invalid'})
    assert result.status_code == 200
    assert result.json()['email_sent'] is False
    assert result.json()['invitation']['status'] == 'pending'
    assert result.json()['code'] and result.json()['invite_url']
    assert 'private SMTP error' not in result.text
    assert db.rpc.call_count == 1


def test_membership_assignment_uses_consent_rpc_and_existing_role_change_sends_no_email(api):
    client, db, mail = api
    db.rpc.return_value.execute.return_value.data = {'saved': True}
    result = client.put(f'/inventory-workspaces/{RESOURCE}/members/{TARGET}', json={'role': 'viewer'})
    assert result.status_code == 200 and result.json() == {'saved': True}
    request = db.rpc.call_args.args[1]
    assert request['p_action'] == 'change'
    assert request['p_data']['scope'] == 'workspace' and request['p_data']['user_id'] == TARGET
    mail.assert_not_called()


def test_preview_is_recipient_actor_bound_and_does_not_mutate_membership_or_send_email(api):
    client, db, mail = api
    result = client.post('/access-invitations/preview', json={'code': 'abcdef234567'})
    assert result.status_code == 200
    assert result.headers['cache-control'] == 'no-store'
    assert db.rpc.call_args.args[1] == {'p_actor': ACTOR, 'p_action': 'preview', 'p_data': {'code_hash': service.code_hash('ABCDEF234567')}}
    db.table.assert_not_called()
    mail.assert_not_called()


@pytest.mark.parametrize('payload', [{}, {'code': 'bad'}, {'code': 'ABCDEF234567', 'invitation_id': INVITE}])
def test_invalid_lookup_rejected_before_database(api, payload):
    client, db, mail = api
    assert client.post('/access-invitations/preview', json=payload).status_code == 422
    db.rpc.assert_not_called()
    mail.assert_not_called()


@pytest.mark.parametrize('action,status', [('accept','accepted'),('decline','declined'),('cancel','cancelled')])
def test_decision_is_explicit_and_authenticated(api, action, status):
    client, db, _ = api
    db.rpc.return_value.execute.return_value.data = row(status=status)
    result = client.post(f'/access-invitations/{INVITE}/decision', json={'action': action})
    assert result.status_code == 200 and result.json()['invitation']['status'] == status
    assert db.rpc.call_args.args[1] == {'p_actor': ACTOR, 'p_action': action, 'p_data': {'invitation_id': INVITE}}


def test_denied_invitation_never_sends_email_or_exposes_database_details(api):
    client, db, mail = api
    db.rpc.return_value.execute.side_effect = APIError({'code': '42501', 'message': 'private schema detail', 'details': None, 'hint': None})
    result = client.post(f'/organizations/{RESOURCE}/members', json={'email': 'recipient@example.invalid'})
    assert result.status_code == 403 and 'private schema' not in result.text
    mail.assert_not_called()
