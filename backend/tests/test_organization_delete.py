"""HTTP confirmation, actor binding and safe failures; PostgreSQL covers policy."""
from types import SimpleNamespace
from unittest.mock import Mock
from uuid import uuid4

import pytest
from postgrest.exceptions import APIError
from backend.tests.test_inventory_journeys import api, OWNER, OTHER


def test_delete_binds_verified_actor_and_exact_confirmed_name(api):
    client, db = api
    org = str(uuid4())
    db.rpc = Mock(return_value=SimpleNamespace(execute=lambda: SimpleNamespace(data={'deleted': True, 'organization_id': org})))
    response = client.request('DELETE', f'/organizations/{org}', json={'name': '  Acme  ', 'p_actor': OTHER})
    assert response.status_code == 200, response.text
    assert response.json() == {'deleted': True, 'organization_id': org}
    db.rpc.assert_called_once_with('findez_delete_empty_organization', {'p_actor': OWNER, 'p_organization': org, 'p_name': 'Acme'})


@pytest.mark.parametrize('code,status,message', [
    ('42501', 403, 'Only the organization owner'),
    ('P0002', 404, 'Organization not found'),
    ('23503', 409, 'no workspaces'),
    ('40P01', 409, 'being updated'),
    ('40001', 409, 'name changed'),
])
def test_delete_maps_atomic_database_rejections_without_leaking_errors(api, code, status, message):
    client, db = api
    db.rpc = Mock(side_effect=APIError({'code': code, 'message': 'private database detail', 'details': None, 'hint': None}))
    response = client.request('DELETE', f'/organizations/{uuid4()}', json={'name': 'Acme'})
    assert response.status_code == status, response.text
    assert message in response.json()['detail']
    assert 'private database detail' not in response.text
    assert db.writes == []


@pytest.mark.parametrize('result', [None, {}, [], {'deleted': False}, {'deleted': True, 'organization_id': 'other'}])
def test_delete_requires_a_matching_success_receipt(api, result):
    client, db = api
    db.rpc = Mock(return_value=SimpleNamespace(execute=lambda: SimpleNamespace(data=result)))
    response = client.request('DELETE', f'/organizations/{uuid4()}', json={'name': 'Acme'})
    assert response.status_code == 503


@pytest.mark.parametrize('name', ['', '   ', None, 'x' * 101])
def test_delete_rejects_invalid_confirmation_before_database_calls(api, name):
    client, db = api
    db.rpc = Mock()
    assert client.request('DELETE', f'/organizations/{uuid4()}', json={'name': name}).status_code == 422
    db.rpc.assert_not_called()
