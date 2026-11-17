from uuid import uuid4
from unittest.mock import Mock
import pytest
from fastapi import HTTPException
from app.services.cad import planning
from app.services.cad.comparison import compare
from backend.tests.test_cad_prototype import snapshot, stock
from backend.tests.test_cad_workspace import Query, INV, ACTOR


def saved(name='Robot'):
    value=snapshot();value.document.name=name
    return {'id':str(uuid4()),'project_id':str(uuid4()),'snapshot':value.model_dump(mode='json'),'version':1,'created_at':'today'}


def test_combined_projects_cannot_reuse_stock_and_keep_priority():
    a,b=saved('First'),saved('Second')
    combined=planning.combine([a,b]);single=compare(snapshot(),[stock(6)],[],[])
    result=compare(combined,[stock(6)],[],[])
    assert result['summary']['covered_units']==single['summary']['covered_units']
    assert result['summary']['required_units']==2*single['summary']['required_units']
    assert all(row['assigned']==0 for row in result['items'] if row['key'].startswith('p1.'))


def test_incomplete_projects_and_existing_commitments_remain_visible():
    a=saved();a['snapshot']['completeness']='partial';a['snapshot']['warnings']=['Unresolved part']
    combined=planning.combine([a]);item=stock(6)
    result=compare(combined,[item],[{'item_id':item['item_id'],'quantity':2}],[{'item_id':item['item_id'],'quantity':1}])
    assert result['completeness']=='partial' and result['warnings']
    assert result['summary']['covered_units']==3


def test_scoped_planning_rejects_missing_or_duplicate_projects(monkeypatch):
    monkeypatch.setattr(planning.projects,'require_enabled',Mock());monkeypatch.setattr(planning,'authorize_inventory',Mock())
    a,b=saved(),saved();b['project_id']=a['project_id']
    db=Query([a,b]);monkeypatch.setattr(planning,'get_supabase_raw',lambda:db)
    request=planning.Request(version_ids=[a['id'],b['id']])
    with pytest.raises(HTTPException) as exc:planning.evaluate(INV,ACTOR,request)
    assert exc.value.status_code==422
    with pytest.raises(HTTPException) as exc:planning.evaluate(INV,ACTOR,planning.Request(version_ids=[uuid4()]))
    assert exc.value.status_code==404
    assert ('eq',('inventory_id',INV),{}) in db.calls
