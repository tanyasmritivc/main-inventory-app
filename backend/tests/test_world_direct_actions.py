from unittest.mock import Mock, patch
from types import SimpleNamespace as NS
import pytest
from app.services import world_chat as w, world_item_changes as m, world_direct_actions as direct
from backend.tests.test_world_item_changes import ACTOR, WORLD, INV, ITEM, inv, snapshot
from backend.tests.test_world_chat import completion
from uuid import uuid4
import json

@pytest.mark.parametrize('message', ['I used 3 AA batteries', 'Move my drill to Garage', 'Actually, I used only 2', 'Add five more batteries'])
def test_clear_natural_requests_authorize_direct_edits(message):
    assert direct.requested(message)

@pytest.mark.parametrize('message', ['Where is my drill?', 'Do I have enough batteries?', 'Move the drill. Actually cancel that.', 'Do not change the quantity', 'yes'])
def test_questions_and_cancel_do_not_authorize_edits(message):
    assert not direct.requested(message)

@pytest.mark.parametrize('delta, expected', [(-2, 1), (50, 53)])
def test_stock_delta_uses_fresh_quantity_and_retains_snapshot(delta, expected):
    db = Mock(); db.rpc.return_value.execute.return_value = NS(data=snapshot())
    with patch.object(w, 'authorize'), patch.object(w, '_inventory', return_value=inv()), patch.object(m, 'get_supabase_raw', return_value=db):
        result = w.execute(ACTOR, WORLD, 'world_adjust_quantity', {'inventory_id': INV, 'item_id': ITEM, 'delta': delta})
    assert result['pending_action']['items'][0]['changes'] == {'quantity': expected}
    assert result['pending_action']['items'][0]['snapshot'] == 'frozen'


def test_consumption_cannot_make_stock_negative():
    db = Mock(); db.rpc.return_value.execute.return_value = NS(data=snapshot())
    with patch.object(w, 'authorize'), patch.object(w, '_inventory', return_value=inv()), patch.object(m, 'get_supabase_raw', return_value=db):
        with pytest.raises(ValueError, match='exceeds'):
            w.execute(ACTOR, WORLD, 'world_adjust_quantity', {'inventory_id': INV, 'item_id': ITEM, 'delta': -4})


def test_direct_result_is_receipt_grounded_and_not_a_pending_confirmation():
    call = NS(id='edit', function=NS(name='world_adjust_quantity', arguments=json.dumps({'inventory_id': INV, 'item_id': ITEM, 'delta': -3})))
    action = {'id': str(uuid4()), 'status': 'pending', 'operation': 'edit', 'inventory_id': INV}
    result = {'pending_action': {**action, 'status': 'confirmed'}, 'inventory_changed': True, 'receipt': {'operation': 'edit', 'count': 1}}
    with patch.object(w, 'directory', return_value={}), patch.object(w, 'execute', return_value={'pending_action': action}), patch.object(direct, 'apply', return_value=result) as apply, patch('app.services.agent_gateway_client.gateway_completion', side_effect=[completion(calls=[call]), completion('Updated the saved quantity to 5.')]):
        events = list(w.stream_turn(ACTOR, WORLD, 'I used 3 AA batteries', [], str(uuid4()), supports_item_management=True, supports_task_actions=True, turn_id=str(uuid4())))
    apply.assert_called_once()
    assert events[-1]['answer_context']['pending_actions'][0]['status'] == 'confirmed'
