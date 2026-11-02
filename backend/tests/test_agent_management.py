from dataclasses import replace
from types import SimpleNamespace
from unittest.mock import Mock
from uuid import UUID

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.api.routes import agent_management as routes, agent_approvals
from app.core import api_key_auth
from app.core.auth import AuthenticatedUser, get_current_user

ORG = '60000000-0000-0000-0000-000000000001'
RESOURCE = '70000000-0000-0000-0000-000000000001'
KEY = '40000000-0000-0000-0000-000000000001'
ACTOR = '20000000-0000-0000-0000-000000000001'
REQUEST = '80000000-0000-0000-0000-000000000001'
PRINCIPAL = api_key_auth.APIKeyPrincipal(KEY, None, ACTOR,
    api_key_auth.ORGANIZATION_SCOPES, ACTOR, ORG)


@pytest.fixture
def api(monkeypatch):
    app = FastAPI()
    app.include_router(routes.router)
    app.include_router(agent_approvals.router)
    state = SimpleNamespace(principal=PRINCIPAL)
    app.dependency_overrides[api_key_auth.authenticate_api_key] = lambda: state.principal
    monkeypatch.setattr(api_key_auth, '_consume_rate_limit', lambda *args: True)
    state.bound = Mock(return_value={'owner_user_id': ACTOR})
    monkeypatch.setattr(routes, 'bound', state.bound)
    state.raw = Mock()
    state.raw.rpc.return_value.execute.return_value.data = {'id': RESOURCE, 'confirmed': True, 'name': 'Shelf'}
    monkeypatch.setattr(routes, 'get_supabase_raw', lambda: state.raw)
    monkeypatch.setattr(agent_approvals, 'get_supabase_raw', lambda: state.raw)
    from app.services import limits, items_repo
    monkeypatch.setattr(limits, 'resolve_effective_limits', lambda actor: ({'spaces': 3}, None))
    monkeypatch.setattr(items_repo, 'invalidate_inventory_cache', lambda owner: None)
    state.app, state.client = app, TestClient(app)
    return state


def body(**extra):
    return {'operation': 'space_create', 'request_id': REQUEST, 'kind': 'inventory', 'resource_id': RESOURCE, 'name': 'Shelf', **extra}


def test_new_scopes_require_actual_organization_and_do_not_expand_legacy_keys():
    for scope in api_key_auth.MANAGEMENT_SCOPES:
        for workspace in (None, RESOURCE):
            with pytest.raises(ValueError):
                api_key_auth.validate_scopes(workspace_id=workspace, scopes=[scope])
        assert api_key_auth.validate_scopes(workspace_id=None, organization_id=ORG, scopes=[scope]) == {scope}
        assert not replace(PRINCIPAL, scopes=frozenset({'org:read', 'org:write'})).allows(scope)
    with pytest.raises(ValueError):
        api_key_auth.validate_scopes(workspace_id=RESOURCE, organization_id=ORG, scopes=['structure:write'])


@pytest.mark.parametrize('fields', [
    {'actor_id': ACTOR}, {'user_id': ACTOR}, {'role': 'owner'}, {'kind': 'organization'},
    {'name': '   '}, {'inventory_id': RESOURCE}, {'request_id': None}, {'operation': 'delete_everything'},
    {'name': None}, {'kind': 'item'},
])
def test_irrelevant_or_forged_action_arguments_are_rejected(fields):
    with pytest.raises(ValidationError):
        routes.OrganizationAction(**body(**fields))


@pytest.mark.parametrize('scopes', [frozenset(), frozenset({'org:write'}), frozenset({'structure:read'}), frozenset({'members:write'})])
def test_action_scope_denial_happens_before_target_access(api, scopes):
    api.principal = replace(PRINCIPAL, scopes=scopes)
    response = api.client.post('/api/v1/organization/actions', json=body())
    assert response.status_code == 403
    api.bound.assert_not_called(); api.raw.rpc.assert_not_called()


def test_legacy_key_cannot_manage_even_with_forged_new_scope(api):
    api.principal = replace(PRINCIPAL, organization_id=None)
    assert api.client.post('/api/v1/organization/actions', json=body()).status_code == 403
    api.raw.rpc.assert_not_called()


def test_creation_calls_key_bound_atomic_operation_and_preserves_request_id(api):
    result = api.client.post('/api/v1/organization/actions', json=body())
    assert result.status_code == 200
    api.raw.rpc.assert_called_once_with('findez_agent_manage', {
        'p_key': KEY, 'p_request': REQUEST, 'p_operation': 'space_create', 'p_kind': 'inventory',
        'p_resource': RESOURCE, 'p_data': {'name': 'Shelf'}, 'p_space_limit': 3,
    })
    assert result.json()['request_id'] == REQUEST


def test_prepare_is_not_confirmation_and_link_contains_no_credentials(api, monkeypatch):
    api.raw.rpc.return_value.execute.return_value.data = {'id': REQUEST, 'status': 'pending'}
    monkeypatch.setattr(routes, 'get_settings', lambda: SimpleNamespace(frontend_url='https://findez.ai'))
    result = api.client.post('/api/v1/organization/deletions', json={'request_id': REQUEST, 'kind': 'space', 'resource_id': RESOURCE})
    assert result.status_code == 201
    assert result.json()['status'] == 'pending'
    assert result.json()['approval_url'] == f'https://findez.ai/agent-approvals/{REQUEST}'
    assert api.raw.rpc.call_args.args[0] == 'findez_agent_prepare_delete'
    assert api.client.post(f'/api/v1/organization/deletions/{REQUEST}/confirm', json={}).status_code == 404


@pytest.mark.parametrize('kind,scope', [('item', 'structure:delete'), ('space', 'items:delete')])
def test_delete_permissions_are_separate(api, kind, scope):
    api.principal = replace(PRINCIPAL, scopes=frozenset({scope}))
    result = api.client.post('/api/v1/organization/deletions', json={'request_id': REQUEST, 'kind': kind, 'resource_id': RESOURCE})
    assert result.status_code == 403
    api.raw.rpc.assert_not_called()


def test_api_key_cannot_call_human_confirmation(api):
    response = api.client.post(f'/agent-approvals/{REQUEST}/decision',
        headers={'Authorization': 'Bearer findez_test_sk_' + 'x' * 32}, json={'decision': 'confirm', 'name': 'Shelf'})
    assert response.status_code == 401
    api.raw.rpc.assert_not_called()


def test_human_confirmation_uses_verified_session_actor(api):
    api.app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(ACTOR)
    api.raw.rpc.return_value.execute.return_value.data = {'id': REQUEST, 'status': 'confirmed', 'receipt': {'deleted': True}}
    response = api.client.post(f'/agent-approvals/{REQUEST}/decision', json={'decision': 'confirm', 'name': 'Shelf'})
    assert response.status_code == 200
    api.raw.rpc.assert_called_once_with('findez_agent_confirm_delete', {
        'p_actor': ACTOR, 'p_approval': REQUEST, 'p_decision': 'confirm', 'p_name': 'Shelf'})
    assert api.client.post(f'/agent-approvals/{REQUEST}/decision', json={'decision': 'confirm', 'name': 'Shelf', 'actor_id': ACTOR}).status_code == 422
