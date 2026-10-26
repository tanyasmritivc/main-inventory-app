"""HTTP regressions for automatic administration and assignment provenance."""
from uuid import uuid4
from unittest.mock import patch
from backend.tests.test_inventory_journeys import api, OWNER, OTHER, MEMBER, VIEWER, TEAM, TEAM_INV
from app.api.routes import team_board


def configure(db):
    org = str(uuid4())
    db.rows['teams'][0]['organization_id'] = org
    db.rows['app_organization_members'] = [
        {'organization_id':org,'user_id':uid,'role':role}
        for uid,role in [(OWNER,'owner'),(OTHER,'admin'),(MEMBER,'member'),(VIEWER,'member')]]
    inv = next(i for i in db.rows['app_inventories'] if i['inventory_id']==TEAM_INV)
    inv['access_mode']='restricted'
    db.rows['app_inventory_members']=[{'inventory_id':TEAM_INV,'user_id':OTHER,'role':'none'}]
    return org


def test_admin_enters_restricted_inventory_without_workspace_assignment_and_demotion_revokes(api):
    client,db=api
    configure(db)
    headers={'x-test-actor':OTHER}
    result=client.get(f'/inventories/{TEAM_INV}',headers=headers)
    assert result.status_code==200,result.text
    assert result.json()['inventory']['role']=='admin'
    assert client.get(f'/inventories/{TEAM_INV}/spaces',headers=headers).status_code==200
    db.rows['app_organization_members'][1]['role']='member'
    assert client.get(f'/inventories/{TEAM_INV}',headers=headers).status_code==403


def test_task_reassignment_records_assigner_and_viewer_cannot_write(api):
    client,db=api
    configure(db)
    db.rows['team_board_tasks']=[{'task_id':'task','team_id':TEAM,'title':'Check tools','created_by':OWNER,'assigned_to':MEMBER,'assigned_by':OWNER}]
    with patch.object(team_board,'_record'):
        result=client.patch(f'/teams/{TEAM}/board/task',headers={'x-test-actor':OTHER},json={'assigned_to':VIEWER,'assigned_by':OWNER})
        assert result.status_code==200,result.text
        assert result.json()['task']['assigned_by']==OTHER
        assert result.json()['task']['assigned_to']==VIEWER
        result=client.patch(f'/teams/{TEAM}/board/task',headers={'x-test-actor':VIEWER},json={'assigned_to':OWNER})
        assert result.status_code==403
        result=client.patch(f'/teams/{TEAM}/board/task',headers={'x-test-actor':MEMBER},json={'status':'done'})
        assert result.status_code==200
        assert result.json()['task']['assigned_by']==OTHER
