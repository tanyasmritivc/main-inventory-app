"""Stock retrieval must be complete, scoped and based on recorded thresholds."""
from types import SimpleNamespace
from unittest.mock import Mock, patch
from uuid import uuid4
import pytest
from app.services import inventory_query as q, world_chat as w
from app.services.inventory_scope import current_inventory

@pytest.mark.parametrize('row,low,out', [
    ({'quantity': 0}, True, True),
    ({'quantity': 1}, False, False),
    ({'quantity': None, 'reorder_enabled': True, 'reorder_threshold': 5}, False, False),
    ({'quantity': 3, 'reorder_enabled': True, 'reorder_threshold': 3}, True, False),
    ({'quantity': 2, 'reorder_enabled': True, 'reorder_threshold': 3}, True, False),
    ({'quantity': 4, 'reorder_enabled': True, 'reorder_threshold': 3}, False, False),
    ({'quantity': 1, 'reorder_enabled': False, 'reorder_threshold': 3}, False, False),
    ({'quantity': 1, 'reorder_enabled': True, 'reorder_threshold': None}, False, False),
    ({'quantity': True, 'reorder_enabled': True, 'reorder_threshold': 3}, False, False),
])
def test_only_recorded_stock_facts(row, low, out):
    assert q._filter(row, {'stock_status': 'low'}) is low
    assert q._filter(row, {'stock_status': 'out'}) is out


def test_stock_query_filters_before_paging_and_does_not_stop_at_500():
    query = Mock()
    for method in ('select','eq','or_','order','range'):
        getattr(query, method).return_value = query
    page = [{'item_id': str(i), 'name': 'M3 screw', 'quantity': 0} for i in range(500)]
    query.execute.side_effect = [SimpleNamespace(data=page), SimpleNamespace(data=[{'item_id':'last','name':'M3 nut','quantity':0}])]
    db = Mock(); db.table.return_value = query
    with patch.object(q, 'get_supabase_admin', return_value=db), patch.object(q, 'search_memory_candidates') as broad:
        result = q.query_inventory(user_id='owner', terms=[], filters={'stock_status':'low'})
    broad.assert_not_called()
    assert result['record_count'] == 501 and result['complete'] is True
    assert query.range.call_args_list[1].args == (500,999)
    assert all(call.args == ('user_id','owner') for call in query.eq.call_args_list)
    assert all(call.args == ('quantity.eq.0,reorder_enabled.eq.true',) for call in query.or_.call_args_list)


def test_combined_stock_filters_and_terms_are_respected():
    query = Mock()
    for method in ('select','eq','or_','order','range'): getattr(query, method).return_value = query
    query.execute.return_value.data = [
        {'name':'M3 screws','quantity':0,'location':'Drawer 2'},
        {'name':'M3 screws','quantity':0,'location':'Drawer 3'},
        {'name':'Servo','quantity':0,'location':'Drawer 2'},
    ]
    db = Mock(); db.table.return_value = query
    with patch.object(q, 'get_supabase_admin', return_value=db):
        result=q.query_inventory(user_id='owner',terms=['screws'],filters={'stock_status':'out','location':'Drawer 2'})
    assert len(result['items']) == 1
    assert result['items'][0]['name'] == 'M3 screws'
    assert ('quantity',0) in [c.args for c in query.eq.call_args_list]


def test_scan_cap_does_not_claim_complete():
    query=Mock()
    for method in ('select','eq','or_','order','range'):getattr(query,method).return_value=query
    query.execute.return_value.data=[{'quantity':5,'reorder_enabled':True,'reorder_threshold':1}]*500
    db=Mock();db.table.return_value=query
    with patch.object(q,'get_supabase_admin',return_value=db):
        result=q.query_inventory(user_id='owner',terms=[],filters={'stock_status':'low'})
    assert result['complete'] is False and result['truncated'] is True
    assert query.execute.call_count == 20


def test_organization_query_preserves_each_authorized_scope_and_row_limit():
    actor,world,one,two=[str(uuid4()) for _ in range(4)]
    def inventory(key, user):
        assert user == actor
        return {'inventory_id':key,'owner_user_id':'owner','name':key,'role':'viewer','can_edit':False,'workspace':{'organization_id':world}}
    def read(**kwargs):
        assert current_inventory.get().actor_id==actor
        assert current_inventory.get().inventory_id in (one,two)
        assert kwargs['filters']=={'stock_status':'low'}
        return {'items':[{'item_id':str(i),'name':'Bolt','quantity':0} for i in range(70)],'record_count':70,'known_units':0,'unknown_quantity_records':0,'complete':True}
    with patch.object(w,'authorize'),patch.object(w,'directory',return_value={'inventories':[{'inventory_id':one},{'inventory_id':two}]}),patch.object(w,'_inventory',side_effect=inventory),patch.object(q,'query_inventory',side_effect=read):
        result=w.execute(actor,world,'world_query',{'filters':{'stock_status':'low'}})
    assert result['record_count']==140 and len(result['items'])==100 and result['rows_truncated']
    assert result['complete'] is True
    assert 'enabled' in result['stock_basis']
    assert current_inventory.get() is None
