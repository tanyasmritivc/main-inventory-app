from types import SimpleNamespace
from unittest.mock import Mock
from uuid import uuid4
import pytest
from postgrest.exceptions import APIError
from backend.tests.test_inventory_journeys import api, OWNER


def respond(db, result):
    db.rpc = Mock(return_value=SimpleNamespace(execute=lambda: SimpleNamespace(data=result)))


@pytest.mark.parametrize('kind', ['organization', 'workspace', 'inventory', 'space'])
@pytest.mark.parametrize('action', ['move', 'delete'])
def test_removal_binds_actor_and_explicit_choice(api, kind, action):
    client, db = api
    resource = str(uuid4())
    result = {'id': resource, 'kind': kind, 'action': action, 'deleted': action == 'delete', 'moved': action == 'move'}
    respond(db, result)
    response = client.post(f'/resource-removal/{kind}/{resource}', json={'name': 'My resource', 'action': action})
    assert response.status_code == 200, response.text
    db.rpc.assert_called_once_with('findez_remove_resource', {'p_actor': OWNER, 'p_kind': kind, 'p_id': resource, 'p_name': 'My resource', 'p_action': action, 'p_destination': None})


@pytest.mark.parametrize('body', [{}, {'name': 'Part'}, {'name': 'Part', 'action': 'automatic'}, {'name': 'Part', 'action': 'delete', 'p_actor': str(uuid4())}])
def test_removal_requires_unambiguous_choice(api, body):
    client, db = api
    db.rpc = Mock()
    assert client.post(f'/resource-removal/inventory/{uuid4()}', json=body).status_code == 422
    db.rpc.assert_not_called()


@pytest.mark.parametrize('result', [None, {}, {'deleted': True}, {'id': str(uuid4()), 'kind': 'inventory', 'action': 'delete', 'deleted': True}])
def test_removal_never_accepts_unrelated_receipt(api, result):
    client, db = api
    respond(db, result)
    assert client.post(f'/resource-removal/inventory/{uuid4()}', json={'name': 'Parts', 'action': 'delete'}).status_code == 503


@pytest.mark.parametrize('code,status', [('42501',403),('P0002',404),('40001',409),('23503',409),('XX000',503)])
def test_removal_rejections_are_safe(api, code, status):
    client, db = api
    db.rpc = Mock(side_effect=APIError({'code':code,'message':'private schema detail','details':None,'hint':None}))
    response=client.post(f'/resource-removal/workspace/{uuid4()}',json={'name':'Workshop','action':'delete'})
    assert response.status_code==status
    assert 'private schema detail' not in response.text


def test_member_removal_binds_target_and_verifies_receipt(api):
    client, db=api
    org, member=str(uuid4()), str(uuid4())
    respond(db,{'removed':True,'user_id':member})
    response=client.delete(f'/organizations/{org}/members/{member}')
    assert response.status_code==200
    db.rpc.assert_called_once_with('findez_remove_organization_member',{'p_actor':OWNER,'p_organization':org,'p_member':member})
    respond(db,{'removed':True,'user_id':OWNER})
    assert client.delete(f'/organizations/{org}/members/{member}').status_code==503
