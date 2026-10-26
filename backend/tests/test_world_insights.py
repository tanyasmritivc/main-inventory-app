from unittest.mock import Mock, patch
from uuid import uuid4
import pytest
from fastapi import HTTPException
from app.services import world_chat as w, world_insights as i
from app.services.inventory_scope import current_inventory

ACTOR, OWNER, WORLD, INV, PROJECT, SPACE = [str(uuid4()) for _ in range(6)]

def inventory(world=WORLD):
    return {'inventory_id': INV, 'owner_user_id': OWNER, 'name': 'Hardware',
            'role': 'viewer', 'can_edit': False, 'workspace': {'organization_id': world}}

@pytest.mark.parametrize('name,args', [
    ('world_query', {'inventory_id': INV}),
    ('world_projects', {'inventory_id': INV}),
    ('world_project_readiness', {'inventory_id': INV, 'kit_id': PROJECT}),
    ('world_activity', {'inventory_id': INV}),
])
def test_foreign_inventory_rejected_before_tool_io(name, args):
    with patch.object(w, 'authorize'), patch.object(w, '_inventory', return_value=inventory('foreign')), patch('app.services.supabase_client.get_supabase_admin') as db, patch('app.services.supabase_client.get_supabase_raw') as raw:
        with pytest.raises(HTTPException):
            w.execute(ACTOR, WORLD, name, args)
    db.assert_not_called(); raw.assert_not_called()
    assert current_inventory.get() is None


def test_query_keeps_physical_totals_and_uncertainty_and_normalized_filters():
    def query(**kwargs):
        assert current_inventory.get().inventory_id == INV
        assert current_inventory.get().actor_id == ACTOR
        assert kwargs == {'user_id': OWNER, 'terms': ['screws'], 'filters': {'space_id': SPACE, 'quantity_op': 'above', 'quantity_value': 100}}
        return {'items': [{'item_id': str(uuid4()), 'name': 'M3 screws'}],
                'record_count': 1, 'known_units': 110, 'unknown_quantity_records': 0, 'complete': False}
    with patch.object(w, 'authorize'), patch.object(w, '_inventory', return_value=inventory()), patch('app.services.inventory_query.query_inventory', side_effect=query):
        result = w.execute(ACTOR, WORLD, 'world_query', {'inventory_id': INV, 'terms': ['screws'], 'filters': {'space_id': SPACE, 'quantity_op': 'above', 'quantity_value': 100}})
    assert result['known_units'] == 110 and result['record_count'] == 1 and not result['complete']
    assert result['items'][0]['inventory_id'] == INV
    assert 'before project reservations' in result['quantity_basis']
    assert current_inventory.get() is None

@pytest.mark.parametrize('filters', [
    {'quantity_op': 'above'}, {'quantity_value': 2}, {'quantity_value': True, 'quantity_op': 'above'},
    {'created_op': 'since', 'created_date': 'yesterday'}, {'created_date': '2026-10-22'}, {'not_a_filter': 'x'},
])
def test_bad_filters_rejected_before_read(filters):
    with patch.object(w, 'authorize'), patch('app.services.inventory_query.query_inventory') as query:
        with pytest.raises(ValueError):
            w.execute(ACTOR, WORLD, 'world_query', {'filters': filters})
    query.assert_not_called()


def test_project_readiness_uses_existing_calculation_and_links_actual_project():
    def ready(**kwargs):
        assert current_inventory.get().inventory_id == INV
        assert kwargs == {'user_id': ACTOR, 'kit_id': PROJECT}
        return {'id': PROJECT, 'name': 'Robot', 'summary': {'missing_lines': 2}, 'items': [], 'can_reserve': False, 'owner_user_id': OWNER, 'private_extra': 'omit'}
    with patch.object(w, 'authorize'), patch.object(w, '_inventory', return_value=inventory()), patch('app.services.project_kits_service.get_project_readiness', side_effect=ready):
        result = w.execute(ACTOR, WORLD, 'world_project_readiness', {'inventory_id': INV, 'kit_id': PROJECT})
    assert result['summary']['missing_lines'] == 2 and not result['can_reserve']
    assert 'owner_user_id' not in result and 'private_extra' not in result
    assert w.resource_links(result)[0]['href'] == f'findez://project/{INV}/{PROJECT}'


def test_activity_is_actor_private_and_reports_truncation():
    q = Mock()
    for method in ('select', 'eq', 'gte', 'order', 'limit'): getattr(q, method).return_value = q
    q.execute.return_value.data = [{'action': 'world_item_edit'}] * 101
    db = Mock(); db.table.return_value = q
    with patch.object(w, 'authorize'), patch.object(w, '_inventory', return_value=inventory()), patch('app.services.supabase_client.get_supabase_raw', return_value=db):
        result = w.execute(ACTOR, WORLD, 'world_activity', {'inventory_id': INV, 'since': '2026-10-22T00:00:00-07:00'})
        with pytest.raises(ValueError):
            w.execute(ACTOR, WORLD, 'world_activity', {'inventory_id': INV, 'since': '2026-10-22'})
    assert ('actor_id', ACTOR) in [c.args for c in q.eq.call_args_list]
    assert ('inventory_id', INV) in [c.args for c in q.eq.call_args_list]
    assert not result['complete'] and len(result['activity']) == 100
    assert q.execute.call_count == 1
