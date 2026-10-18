"""Role matrix and HTTP boundaries from the supplied permission specification."""
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest
from fastapi import HTTPException

from app.services import permissions
from app.services.inventory_scope import InventoryClient, InventoryScope
from app.api.routes import collaboration
from app.core import auth
from app.services import supabase_client
from backend.tests.test_access_invitation_consent import api, ACTOR, RESOURCE, TARGET


@pytest.mark.parametrize('stored,expected', [('owner','owner'),('mentor','admin'),('member','editor'),('viewer','viewer')])
@pytest.mark.parametrize('mode', ['legacy','workspace'])
def test_inherited_inventory_follows_current_workspace_role(stored, expected, mode):
    inv = {'inventory_id':'inv', 'team_id':'team', 'access_mode':mode, 'default_role':'viewer'}
    assert permissions.inventory_role(inv, {'role':stored}, 'actor', []) == expected


@pytest.mark.parametrize('stored', ['owner','mentor','member','viewer'])
@pytest.mark.parametrize('assigned,expected', [('admin','admin'),('editor','editor'),('viewer','viewer'),('none',None)])
@pytest.mark.parametrize('mode', ['workspace','restricted'])
def test_custom_inventory_role_overrides_every_workspace_role(stored, assigned, expected, mode):
    inv = {'inventory_id':'inv', 'team_id':'team', 'access_mode':mode}
    grants = [{'inventory_id':'inv', 'role':assigned}]
    assert permissions.inventory_role(inv, {'role':stored}, 'actor', grants) == expected
    # Revoked workspace membership retires custom access, too.
    assert permissions.inventory_role(inv, {'role':None}, 'actor', grants) is None


@pytest.mark.parametrize('stored', ['owner','mentor','member','viewer'])
def test_restricted_inventory_never_automatically_grants_content(stored):
    inv = {'inventory_id':'inv', 'team_id':'team', 'access_mode':'restricted'}
    role = permissions.inventory_role(inv, {'role':stored}, 'actor', [])
    assert role is None
    assert permissions.can_administer_inventory(inv, {'role':stored}, role) is (stored in ('owner','mentor'))


@pytest.mark.parametrize('role', ['owner','admin','editor','viewer',None])
def test_space_deletion_is_admin_only_in_the_actual_scoped_transport(role):
    raw = MagicMock()
    client = InventoryClient(raw, InventoryScope('inv','actor','owner','team',role))
    if role in ('owner','admin'):
        client.table('spaces').delete()
        raw.table.return_value.delete.assert_called_once()
    else:
        with pytest.raises(HTTPException) as error:
            client.table('spaces').delete()
        assert error.value.status_code == 403
        raw.table.return_value.delete.assert_not_called()


@pytest.mark.parametrize('scope,path', [('organization','organizations'),('workspace','inventory-workspaces')])
def test_ownership_transfer_requires_confirmation_and_exact_receipt(api, monkeypatch, scope, path):
    client, _, _ = api
    db = MagicMock()
    monkeypatch.setattr(collaboration, 'get_supabase_raw', lambda:db)
    body = {'name':'Resource', 'user_id':TARGET, 'confirmed':False}
    assert client.post(f'/{path}/{RESOURCE}/transfer-owner', json=body).status_code == 422
    db.rpc.assert_not_called()
    body['confirmed'] = True
    db.rpc.return_value.execute.return_value = SimpleNamespace(data={
        'transferred':True, 'scope':scope, 'resource_id':RESOURCE, 'owner_user_id':TARGET,
    })
    assert client.post(f'/{path}/{RESOURCE}/transfer-owner', json=body).status_code == 200
    assert db.rpc.call_args.args == ('findez_transfer_resource_owner', {
        'p_actor':ACTOR, 'p_scope':scope, 'p_resource':RESOURCE, 'p_target':TARGET, 'p_name':'Resource',
    })
    db.rpc.return_value.execute.return_value.data['owner_user_id'] = ACTOR
    assert client.post(f'/{path}/{RESOURCE}/transfer-owner', json=body).status_code == 503


@pytest.mark.parametrize('active,status', [(True,200),(False,401),(None,503)])
def test_current_account_status_is_required_even_with_valid_jwt(monkeypatch, active, status):
    from fastapi import Depends, FastAPI
    from fastapi.testclient import TestClient
    from jose import jwt
    from time import time
    settings = SimpleNamespace(supabase_jwt_secret='unit-test-secret-for-permissions-only', supabase_jwt_audience='authenticated')
    monkeypatch.setattr(auth, 'get_settings', lambda:settings)
    monkeypatch.setattr(auth, '_get_cached_first_name', lambda _: (True,None))
    db = MagicMock()
    db.rpc.return_value.execute.return_value.data = active
    monkeypatch.setattr(supabase_client, 'get_supabase_raw', lambda:db)
    app = FastAPI()
    @app.get('/protected')
    def protected(user=Depends(auth.get_current_user)):
        return {'user_id':user.user_id}
    token = jwt.encode({'sub':ACTOR, 'aud':'authenticated', 'exp':int(time())+60},settings.supabase_jwt_secret,algorithm='HS256')
    with TestClient(app) as client:
        assert client.get('/protected',headers={'Authorization':'Bearer '+token}).status_code == status
    db.rpc.assert_called_once_with('findez_actor_active', {'p_actor':ACTOR})


@pytest.mark.parametrize('flag,expected', [('true',200),('1',200),('false',403),(None,403)])
def test_viewer_photo_preview_is_read_only_without_allowing_save(monkeypatch, flag, expected):
    from fastapi import Depends, FastAPI
    from fastapi.testclient import TestClient
    from app.api.routes import inventory_workspaces as routes
    from app.core.auth import AuthenticatedUser, get_current_user
    monkeypatch.setattr(routes, '_inventory', lambda *_:{'inventory_id':'inv','owner_user_id':'owner','team_id':'team','role':'viewer','workspace':{}})
    app = FastAPI()
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(user_id='viewer')
    @app.post('/inventories/{inventory_id}/inventory/extract_from_image',dependencies=[Depends(routes.inventory_session)])
    def preview(): return {'preview':True}
    with TestClient(app) as client:
        fields = {} if flag is None else {'preview_only':flag}
        result=client.post('/inventories/inv/inventory/extract_from_image',data=fields,files={'file':('photo.jpg',b'fixture','image/jpeg')})
        assert result.status_code == expected
