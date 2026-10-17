from types import SimpleNamespace
from unittest.mock import MagicMock, patch
from uuid import uuid4
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from postgrest.exceptions import APIError
from app.api.routes import inventory_workspaces as routes
from app.core.auth import AuthenticatedUser, get_current_user

ACTOR, INV = str(uuid4()), str(uuid4())
@pytest.fixture
def api():
    app=FastAPI();app.include_router(routes.router)
    app.dependency_overrides[get_current_user]=lambda:AuthenticatedUser(user_id=ACTOR)
    raw=MagicMock();raw.rpc.return_value.execute.return_value=SimpleNamespace(data={'deleted':True,'inventory_id':INV})
    with patch.object(routes,'_inventory',return_value={'can_manage':True}),patch.object(routes,'get_supabase_raw',return_value=raw):
        yield TestClient(app),raw

def test_delete_uses_verified_actor_and_requires_confirmed_outcome(api):
    client,raw=api
    result=client.request('DELETE',f'/inventories/{INV}',json={'name':'Hardware'})
    assert result.status_code==200
    raw.rpc.assert_called_once_with('findez_delete_empty_inventory',{'p_actor':ACTOR,'p_inventory':INV,'p_name':'Hardware'})
    raw.rpc.return_value.execute.return_value=SimpleNamespace(data={})
    assert client.request('DELETE',f'/inventories/{INV}',json={'name':'Hardware'}).status_code==503

@pytest.mark.parametrize('code,status',[('42501',403),('P0002',404),('22023',409),('23514',409),('23503',409),('PGRST202',503)])
def test_rejected_delete_is_actionable_and_not_retried(api,code,status):
    client,raw=api;raw.rpc.return_value.execute.side_effect=APIError({'code':code,'message':'internal'})
    response=client.request('DELETE',f'/inventories/{INV}',json={'name':'Hardware'})
    assert response.status_code==status and 'internal' not in response.text
    assert raw.rpc.call_count==1

def test_editor_cannot_delete_even_if_creator_and_client_cannot_choose_actor(api):
    client,raw=api
    with patch.object(routes,'_inventory',return_value={'can_manage':False,'can_rename':True}):
        assert client.request('DELETE',f'/inventories/{INV}',json={'name':'Hardware'}).status_code==403
    raw.rpc.assert_not_called()
    assert client.request('DELETE',f'/inventories/{INV}',json={'name':'Hardware','p_actor':str(uuid4())}).status_code==422
