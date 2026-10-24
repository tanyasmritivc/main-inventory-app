from unittest.mock import Mock, patch
from types import SimpleNamespace as NS
import json
import pytest
from app.services import world_tasks as tasks, world_chat as world
from backend.tests.test_world_chat import ACTOR, WORLD, WORKSPACE, INVENTORY, inventory, completion
from uuid import uuid4

PLAN = {'workspace_id': WORKSPACE, 'inventories': [{'name': 'FindEZ Test',
    'spaces': ['Storage'], 'items': [{'name': 'AA batteries', 'quantity': 10, 'location': 'Storage'}]}]}

def directory():
    return {'workspaces': [{'workspace_id': WORKSPACE, 'name': 'Test Ws', 'can_create': True}]}


def test_creation_and_items_are_one_exact_review_without_writes():
    with patch.object(world, 'directory', return_value=directory()), patch('app.services.supabase_client.get_supabase_raw') as db:
        result = tasks.propose(ACTOR, WORLD, PLAN)
    db.assert_not_called()
    card = result['world_action']
    assert card['version'] == 2 and card['status'] == 'pending'
    assert card['plan']['inventories'][0]['items'][0]['quantity'] == 10
    assert not card['inventory_changed']
    assert '$ref' not in json.dumps(tasks.schema())


def test_destination_must_be_visible_in_same_review():
    with patch.object(world, 'directory', return_value=directory()):
        with pytest.raises(ValueError):
            tasks.propose(ACTOR, WORLD, {**PLAN, 'inventories': [{**PLAN['inventories'][0], 'spaces': ['Elsewhere']}]})


def test_move_freezes_saved_identity_instead_of_copying_or_trusting_model_snapshot():
    item = str(uuid4())
    db = Mock(); db.rpc.return_value.execute.return_value = NS(data={'snapshot': 'server-snapshot',
        'item': {'item_id': item, 'name': 'Bosch drill', 'quantity': 1, 'location': 'Storage'}})
    plan = {'workspace_id': WORKSPACE, 'inventories': [{'name': 'Garage inventory', 'spaces': ['Garage'],
        'moves': [{'inventory_id': INVENTORY, 'item_id': item, 'location': 'Garage'}]}]}
    with patch.object(world, 'directory', return_value=directory()), patch.object(world, 'authorize'), patch.object(world, '_inventory', return_value=inventory()), patch('app.services.supabase_client.get_supabase_raw', return_value=db):
        result = tasks.propose(ACTOR, WORLD, plan)
    move = result['world_action']['plan']['inventories'][0]['moves'][0]
    assert move['snapshot'] == 'server-snapshot' and move['name'] == 'Bosch drill'
    assert move['location'] == 'Storage' and move['target_location'] == 'Garage'
    db.table.assert_not_called()


@pytest.mark.parametrize('supported', [False, True])
def test_composite_tool_only_exposed_to_clients_that_display_entire_plan(supported):
    with patch.object(world, 'directory', return_value={}), patch('app.services.agent_gateway_client.gateway_completion', return_value=completion('Hello')) as gateway:
        list(world.stream_turn(ACTOR, WORLD, 'Hello', [], 'cid', supports_task_actions=supported))
    names = {t['function']['name'] for t in gateway.call_args.kwargs['tools']}
    assert ('world_create_task' in names) == supported
    assert ('world_structure' in names) != supported
