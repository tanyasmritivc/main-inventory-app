from unittest.mock import MagicMock, patch
from uuid import uuid4
import pytest
from fastapi import HTTPException
from app.api.routes.commerce import ConnectRequest
from app.services.commerce import repository as repo

ACTOR, OTHER, ORG = [str(uuid4()) for _ in range(3)]

def connection(row, actor=ACTOR, **kwargs):
    with patch.object(repo, 'execute', return_value=[row]), patch.object(repo, 'get_supabase_raw', return_value=MagicMock()):
        return repo.connection(str(uuid4()), actor, **kwargs)

def test_personal_history_uses_owner_not_creator_or_inventory():
    row = dict(scope_type='personal', owner_user_id=ACTOR, actor_id=OTHER, inventory_id=None)
    with patch.object(repo, 'authorize') as inventory_access:
        assert connection(row) == row
        inventory_access.assert_not_called()
    with pytest.raises(HTTPException) as exc:
        connection(row, OTHER, require_access=False)
    assert exc.value.status_code == 404

@pytest.mark.parametrize('role', ['member', 'viewer', 'editor', None])
def test_org_scope_requires_org_admin_not_inventory_editor(role):
    with patch.object(repo, 'get_supabase_raw', return_value=MagicMock()), patch.object(repo, 'execute', return_value=[{'role':role}] if role else []):
        with pytest.raises(HTTPException) as exc:
            repo.authorize_scope('organization', ORG, ACTOR)
        assert exc.value.status_code == 403

@pytest.mark.parametrize('role', ['owner', 'admin'])
def test_org_admin_authorized(role):
    with patch.object(repo, 'get_supabase_raw', return_value=MagicMock()), patch.object(repo, 'execute', return_value=[{'role':role}]):
        repo.authorize_scope('organization', ORG, ACTOR)

def test_org_disconnect_never_bypasses_current_membership():
    with patch.object(repo, 'authorize_scope', side_effect=HTTPException(403,'denied')) as check:
        with pytest.raises(HTTPException):
            connection(dict(scope_type='organization',organization_id=ORG,actor_id=ACTOR),require_access=False)
        check.assert_called_once_with('organization', ORG, ACTOR)

@pytest.mark.parametrize('body', [dict(scope_type='organization'),dict(organization_id=ORG),dict(scope_type='organization',organization_id=ORG,inventory_id=str(uuid4()))])
def test_mixed_or_incomplete_owner_rejected(body):
    with pytest.raises(ValueError):
        ConnectRequest(provider='amazon_consumer',**body)

def test_personal_request_needs_no_inventory():
    body=ConnectRequest(provider='amazon_consumer')
    assert body.inventory_id is None and body.scope_type=='personal'

def test_scope_routes_accept_personal_preview_and_connect_without_inventory():
    from fastapi import FastAPI
    from fastapi.testclient import TestClient
    from app.api.routes import commerce
    from app.core.auth import AuthenticatedUser, get_current_user
    from app.services.commerce.config import CommerceSettings
    app=FastAPI(); app.include_router(commerce.router)
    app.dependency_overrides[get_current_user]=lambda: AuthenticatedUser(user_id=ACTOR)
    client=TestClient(app)
    row=dict(id=str(uuid4()),scope_type='personal',organization_id=None,inventory_id=None,provider='amazon_consumer',status='connected')
    content=b'Order ID,Product Name,Quantity,Order Date\nqa-1,Motor,2,2026-11-01\n'
    with patch.object(commerce,'settings',return_value=CommerceSettings(purchase_import_enabled=True)), patch.object(repo,'authorize_scope') as access, patch.object(repo,'start_scoped',return_value=row) as start, patch.object(repo,'authorize') as old:
        response=client.post('/commerce/purchase-file/preview',data={'scope_type':'personal'},files={'file':('orders.csv',content,'text/csv')})
        assert response.status_code==200 and response.json()['committed'] is False
        start.assert_not_called(); old.assert_not_called()
        response=client.post('/commerce/connections',json={'provider':'amazon_consumer','scope_type':'personal'})
        assert response.status_code==200 and response.json()['connection']['inventory_id'] is None
        assert start.call_args.args[:3]==(ACTOR,'personal',None)
        access.assert_called_with('personal',None,ACTOR)


def test_organization_preview_checks_access_before_parsing_file():
    from fastapi import FastAPI
    from fastapi.testclient import TestClient
    from app.api.routes import commerce
    from app.core.auth import AuthenticatedUser, get_current_user
    from app.services.commerce.config import CommerceSettings
    app=FastAPI(); app.include_router(commerce.router)
    app.dependency_overrides[get_current_user]=lambda: AuthenticatedUser(user_id=ACTOR)
    with patch.object(commerce,'settings',return_value=CommerceSettings(purchase_import_enabled=True)), patch.object(repo,'authorize_scope',side_effect=HTTPException(403,'denied')), patch.object(commerce,'preview') as parse:
        response=TestClient(app).post('/commerce/purchase-file/preview',data={'scope_type':'organization','organization_id':ORG},files={'file':('private.csv',b'private','text/csv')})
        assert response.status_code==403
        parse.assert_not_called()
