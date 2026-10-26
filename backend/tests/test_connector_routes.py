from unittest.mock import patch, MagicMock
from uuid import uuid4
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from app.main import app
from app.core.auth import AuthenticatedUser
from app.api.routes.connectors import CommitRequest, commit_import, MappingRequest, preview_import, connector_status


def source(**changes):
    return {'id':str(uuid4()),'owner_id':'owner','inventory_id':'inventory','kind':'inventory','revision':1,
            'status':'review','decisions':None,'review':[{'index':0,'errors':[],'duplicates':[],'duplicate_rows':[]}],**changes}


def call(s,payload):
    with patch('app.api.routes.connectors._session',return_value=s):
        return commit_import.__wrapped__(request=None,session_id=s['id'],payload=payload,user=AuthenticatedUser(user_id='actor'))


def test_anonymous_sources_and_imports_require_authentication():
    client=TestClient(app)
    assert client.get('/connectors').status_code==401
    assert client.get('/connectors/imports/'+str(uuid4())).status_code==401
    assert client.post('/connectors/imports',data={'location':'Storage'},files={'file':('a.csv',b'Name,Qty\nCable,2','text/csv')}).status_code==401


def test_only_finished_connectors_advertised():
    assert {x['id'] for x in connector_status(AuthenticatedUser(user_id='actor'))['connectors']}=={'spreadsheet','bom'}


@pytest.mark.parametrize('s,payload,status',[
    (source(kind='bom'),{'revision':1,'decisions':{'0':'create'}},422),
    (source(),{'revision':0,'decisions':{'0':'create'}},409),
    (source(),{'revision':1,'decisions':{}},422),
    (source(decisions={'0':'skip'}),{'revision':1,'decisions':{'0':'create'}},409),
    (source(review=[{'index':0,'errors':['invalid'],'duplicates':[],'duplicate_rows':[]}]),{'revision':1,'decisions':{'0':'create'}},422),
    (source(review=[{'index':0,'errors':[],'duplicates':[{'item_id':'existing'}],'duplicate_rows':[]}]),{'revision':1,'decisions':{'0':'create'}},422),
])
def test_invalid_commit_never_reaches_database(s,payload,status):
    with patch('app.api.routes.connectors.get_supabase_raw') as client:
        with pytest.raises(HTTPException) as exc:call(s,CommitRequest(**payload))
        assert exc.value.status_code==status
        client.assert_not_called()


def test_commit_uses_session_owner_authenticated_actor_and_frozen_choices():
    s=source()
    client=MagicMock()
    client.rpc.return_value.execute.return_value.data={'id':s['id'], 'status':'complete', 'receipts':{}}
    with patch('app.api.routes.connectors.get_supabase_raw',return_value=client),patch('app.api.routes.connectors.check_item_limit',return_value={'limit':100}),patch('app.api.routes.connectors._public',return_value={}),patch('app.api.routes.connectors.invalidate_inventory_cache'):
        call(s,CommitRequest(revision=1,decisions={'0':'create'}))
    args=client.rpc.call_args.args
    assert args[0]=='findez_commit_connector_import'
    assert args[1]['p_actor']=='actor' and args[1]['p_session']==s['id']
    assert args[1]['p_item_limit']==100


def test_lost_commit_response_is_not_reported_as_success():
    client=MagicMock();client.rpc.return_value.execute.side_effect=RuntimeError('network')
    with patch('app.api.routes.connectors.get_supabase_raw',return_value=client),patch('app.api.routes.connectors.check_item_limit',return_value={'limit':None}):
        with pytest.raises(HTTPException) as exc:call(source(),CommitRequest(revision=1,decisions={'0':'create'}))
        assert exc.value.status_code==503


def test_mapping_rejects_coerced_column_indices():
    with pytest.raises(ValueError):MappingRequest(revision=0,sheet=0,columns={'name':True})


def test_import_quota_uses_existing_plan_limits():
    from app.api.routes.connectors import _import_quota
    with patch('app.api.routes.connectors.get_settings') as settings, patch('app.api.routes.connectors.resolve_effective_plan') as plan:
        settings.return_value.pilot_mode=False
        plan.return_value=('free',None)
        assert _import_quota('actor')=={'limit':2}
        plan.return_value=('pro',None)
        assert _import_quota('actor')=={'limit':20}
        plan.return_value=('team','team-id')
        assert _import_quota('actor')=={'team_id':'team-id','limit':100}
        settings.return_value.pilot_mode=True
        assert _import_quota('actor')=={}


def test_allowance_failure_is_actionable_and_never_reported_as_success():
    class LimitError(Exception):
        message='CONNECTOR_IMPORT_LIMIT'
    client=MagicMock();client.rpc.return_value.execute.side_effect=LimitError()
    with patch('app.api.routes.connectors.get_supabase_raw',return_value=client),patch('app.api.routes.connectors.check_item_limit',return_value={'limit':None}):
        with pytest.raises(HTTPException) as exc:call(source(),CommitRequest(revision=1,decisions={'0':'create'}))
        assert exc.value.status_code==403
