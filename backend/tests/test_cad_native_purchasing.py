from types import SimpleNamespace as NS
from unittest.mock import Mock
from uuid import uuid4
import pytest
from fastapi import HTTPException
from app.api.routes import cad_workspace as routes
from app.services.cad import workspace, purchasing
from backend.tests.test_cad_workspace import api, grant, INV, ACTOR, Query


def test_native_rpc_requires_flag_and_does_not_fall_back_to_web(monkeypatch):
    monkeypatch.setenv('CAD_PURCHASING_ENABLED','true');monkeypatch.delenv('CAD_NATIVE_PURCHASING_ENABLED',raising=False)
    db=Query(data={'id':'plan'});monkeypatch.setattr(purchasing,'get_supabase_raw',lambda:db)
    with pytest.raises(HTTPException): purchasing._rpc(INV,ACTOR,uuid4(),None,'create',None,{},[], 'grant')
    assert not db.calls
    monkeypatch.setenv('CAD_NATIVE_PURCHASING_ENABLED','true');monkeypatch.setattr(purchasing,'authorize_inventory',Mock())
    purchasing._rpc(INV,ACTOR,uuid4(),None,'create',None,{},[], 'grant')
    name,params=next(args for method,args,_ in db.calls if method=='rpc')
    assert name=='findez_cad_native_purchase_action' and params['p_grant']=='grant'


@pytest.mark.parametrize('allowed',[False,True])
def test_native_create_uses_bound_actor_inventory_and_grant(monkeypatch,allowed):
    monkeypatch.setenv('CAD_PURCHASING_ENABLED','true');monkeypatch.setenv('CAD_NATIVE_PURCHASING_ENABLED','true')
    current={**grant(),'allow_purchasing':allowed}; monkeypatch.setattr(workspace,'authorize',lambda _:current)
    create=Mock(return_value={'id':'plan','inventory_id':INV});monkeypatch.setattr(purchasing,'create',create)
    with api(monkeypatch) as http:
        monkeypatch.setattr(workspace,'authorize',lambda _:current)
        response=http.post('/fusion/purchases',headers={'Authorization':'Bearer '+ 'a'*64},json={'request_id':str(uuid4()),'bom_version_id':str(uuid4())})
    assert response.status_code==(200 if allowed else 403)
    if allowed: assert create.call_args.args[0:2]==(INV,ACTOR) and create.call_args.args[3]=='grant'
    else: create.assert_not_called()


def test_purchase_read_rechecks_session_after_query(monkeypatch):
    monkeypatch.setenv('CAD_PURCHASING_ENABLED','true');monkeypatch.setenv('CAD_NATIVE_PURCHASING_ENABLED','true')
    auth=Mock(side_effect=[{**grant(),'allow_purchasing':True},HTTPException(403,'Revoked')]);monkeypatch.setattr(workspace,'authorize',auth)
    monkeypatch.setattr(purchasing,'plans',Mock(return_value={'plans':[{'name':'Private'}]}))
    with api(monkeypatch) as http:
        monkeypatch.setattr(workspace,'authorize',auth)
        response=http.get('/fusion/purchases',headers={'Authorization':'Bearer '+ 'a'*64})
    assert response.status_code==403 and 'Private' not in response.text


def test_explicit_purchase_pairing_uses_independent_consent(monkeypatch):
    monkeypatch.setenv('CAD_PURCHASING_ENABLED','true');monkeypatch.setenv('CAD_NATIVE_PURCHASING_ENABLED','true')
    monkeypatch.setattr(workspace,'_inventory',Mock());db=Query(data=True);monkeypatch.setattr(workspace,'get_supabase_raw',lambda:db)
    workspace.approve('ABCD234567',INV,ACTOR,False,True)
    name,params=next(args for method,args,_ in db.calls if method=='rpc')
    assert name=='findez_cad_device_approve_purchasing' and params['p_writes'] is False
