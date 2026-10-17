"""Directory HTTP contracts; SQL fixtures exercise actual grants and RLS."""
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
from uuid import uuid4
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from postgrest.exceptions import APIError
from app.api.routes import workspace_directory as routes
from app.core.auth import AuthenticatedUser, get_current_user
ACTOR, WS, INV, REQ = [str(uuid4()) for _ in range(4)]

@pytest.fixture
def api():
    app = FastAPI(); app.include_router(routes.router)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(user_id=ACTOR)
    db = MagicMock(); db.rpc.return_value.execute.return_value = SimpleNamespace(data={})
    with patch.object(routes, 'get_supabase_raw', return_value=db), patch.object(routes, '_workspace', return_value={'workspace_id': WS}) as workspace:
        with TestClient(app) as client: yield client, db, workspace

def test_directory_reads_are_actor_bound_and_not_cached(api):
    client, db, workspace = api
    db.rpc.return_value.execute.return_value.data = {'inventories': [], 'total': 0, 'next_offset': None}
    response = client.get(f'/inventory-workspaces/{WS}/directory?q=Tools&offset=100')
    assert response.status_code == 200 and response.headers['cache-control'] == 'no-store'
    workspace.assert_called_once_with(WS, ACTOR)
    assert db.rpc.call_args.args[1] == {'p_actor': ACTOR, 'p_action': 'list', 'p_data': {'workspace_id': WS, 'query': 'Tools', 'offset': 100}}
    db.table.assert_not_called()

def test_restricted_entry_uses_directory_not_content_query(api):
    client, db, _ = api
    db.rpc.return_value.execute.return_value.data = {'inventory': {'inventory_id': INV, 'workspace_id': WS, 'name': 'Tools', 'can_open': False}, 'request': None}
    response = client.get(f'/inventory-directory/{INV}')
    assert response.status_code == 200 and 'item_count' not in response.json()['inventory']
    assert response.headers['cache-control'] == 'no-store'
    assert db.rpc.call_args.args[1]['p_action'] == 'entry'
    db.table.assert_not_called()

@pytest.mark.parametrize('path,body,action,data', [
    (f'/inventory-directory/{INV}/request', {'user_id': 'forged', 'role': 'owner'}, 'request', {'inventory_id': INV}),
    (f'/inventory-access-requests/{REQ}/decision', {'action': 'approve', 'user_id': 'forged', 'role': 'owner'}, 'approve', {'request_id': REQ}),
])
def test_requests_cannot_choose_actor_target_or_grant_role(api, path, body, action, data):
    client, db, _ = api
    db.rpc.return_value.execute.return_value.data = {'request_id': REQ, 'status': 'pending'}
    assert client.post(path, json=body).status_code == 200
    assert db.rpc.call_args.args[1] == {'p_actor': ACTOR, 'p_action': action, 'p_data': data}
    db.table.assert_not_called()

@pytest.mark.parametrize('code,status', [('42501',403),('P0002',404),('23514',409),('23505',409),('23503',409)])
def test_permission_errors_hide_internal_details(api, code, status):
    client, db, _ = api
    db.rpc.return_value.execute.side_effect = APIError({'code':code, 'message':'private schema details', 'hint':None, 'details':None})
    response = client.post(f'/inventory-directory/{INV}/request')
    assert response.status_code == status and 'private schema' not in response.text

@pytest.mark.parametrize('payload', [{'directory_visibility':'public'}, {'directory_visibility':'hidden','description':'x'*501}])
def test_invalid_settings_rejected_before_database(api, payload):
    client, db, _ = api
    assert client.patch(f'/inventory-directory/{INV}',json=payload).status_code == 422
    db.rpc.assert_not_called()

def test_unconfirmed_write_is_not_reported_saved(api):
    client, db, _ = api
    db.rpc.return_value.execute.return_value.data = None
    assert client.post(f'/inventory-directory/{INV}/request').status_code == 503

def test_directory_pagination_and_decisions_are_validated(api):
    client, db, _ = api
    assert client.get(f'/inventory-workspaces/{WS}/directory?offset=-1').status_code == 422
    assert client.post(f'/inventory-access-requests/{REQ}/decision',json={'action':'owner'}).status_code == 422
    db.rpc.assert_not_called()
