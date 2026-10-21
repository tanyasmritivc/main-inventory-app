from types import SimpleNamespace as NS
from unittest.mock import Mock, patch
from uuid import uuid4
import pytest
from fastapi import HTTPException
from app.services import world_chat as w
from app.services.inventory_scope import current_inventory

ACTOR, WORLD, OTHER, INVENTORY, WORKSPACE = [str(uuid4()) for _ in range(5)]

def inventory(world=WORLD, role='editor'):
    return {'inventory_id': INVENTORY, 'name': 'Hardware', 'owner_user_id': ACTOR,
        'team_id': WORKSPACE, 'role': role, 'can_edit': role != 'viewer',
        'workspace': {'organization_id': world, 'name': 'Workshop'}}

@pytest.mark.parametrize('bad', ['', 'not-a-uuid', None])
def test_invalid_world_is_not_server_error(bad):
    with pytest.raises(HTTPException) as error: w.world_key(bad)
    assert error.value.status_code == 404

def test_foreign_inventory_never_installs_scope():
    with patch.object(w, 'authorize'), patch.object(w, '_inventory', return_value=inventory(OTHER)):
        with pytest.raises(HTTPException):
            with w.in_inventory(ACTOR, WORLD, INVENTORY): pytest.fail('foreign scope installed')
    assert current_inventory.get() is None

def test_scope_restored_even_on_tool_error():
    with patch.object(w, 'authorize'), patch.object(w, '_inventory', return_value=inventory()):
        with pytest.raises(RuntimeError):
            with w.in_inventory(ACTOR, WORLD, INVENTORY):
                assert current_inventory.get().actor_id == ACTOR
                raise RuntimeError()
    assert current_inventory.get() is None

def test_structure_is_only_a_review_with_explicit_existing_destination():
    directory = {'workspaces': [{'workspace_id': WORKSPACE, 'name': 'Workshop', 'can_create': True}]}
    with patch.object(w, 'directory', return_value=directory), patch.object(w, 'get_supabase_raw') as db:
        result = w.propose_structure(ACTOR, WORLD, {'workspace_id': WORKSPACE,
            'inventories': [{'name': ' Hardware ', 'spaces': ['Bolts', 'bolts', ' Motors ']}]})
    db.assert_not_called()
    assert result['workspace_label'] == 'Workshop'
    assert result['status'] == 'pending' and not result['inventory_changed']
    assert result['plan']['inventories'][0] == {'name': 'Hardware', 'spaces': ['Motors', 'Bolts']}

@pytest.mark.parametrize('args', [
    {'workspace_id': WORKSPACE, 'workspace_name': 'New', 'inventories': [{'name': 'A'}]},
    {'workspace_id': WORKSPACE, 'inventories': [{'name': ' '}]},
    {'workspace_id': WORKSPACE, 'inventories': [{'name': 'A'}, {'name': 'a'}]},
    {'workspace_id': WORKSPACE, 'inventories': [{'name': 'A', 'spaces': [' ']}]},
])
def test_invalid_structure_cannot_become_review(args):
    with patch.object(w, 'directory', return_value={'workspaces': [{'workspace_id': WORKSPACE, 'name': 'Workshop', 'can_create': True}]}):
        with pytest.raises(ValueError): w.propose_structure(ACTOR, WORLD, args)

def test_viewer_cannot_propose_structure_or_items():
    with patch.object(w, 'directory', return_value={'workspaces': [{'workspace_id': WORKSPACE, 'can_create': False}]}):
        with pytest.raises(HTTPException): w.propose_structure(ACTOR, WORLD, {'workspace_id': WORKSPACE, 'inventories': [{'name': 'A'}]})
    with patch.object(w, 'authorize'), patch.object(w, '_inventory', return_value=inventory(role='viewer')):
        with pytest.raises(HTTPException): w.execute(ACTOR, WORLD, 'world_add_items', {'inventory_id': INVENTORY, 'items': [{'name': 'Bolt', 'quantity': 1, 'location': 'Shelf'}]})

@pytest.mark.parametrize('args', [{'query': 1}, {'query': 'ok', 'organization_id': OTHER}, {'query': 'x' * 201}])
def test_tools_reject_malformed_model_arguments(args):
    with patch.object(w, 'authorize'):
        with pytest.raises(ValueError): w.execute(ACTOR, WORLD, 'world_search', args)

def test_model_can_read_target_ids_but_not_credentials():
    result = w.model_data({'inventory_id': INVENTORY, 'token': 'SECRET', 'image_url': 'SECRET', 'name': 'Hardware'})
    assert result == {'target_inventory_id': INVENTORY, 'name': 'Hardware'}

def test_world_search_uses_fresh_scoped_records():
    with patch.object(w, 'authorize'), patch.object(w, '_inventory', return_value=inventory()), patch.object(w, 'directory', return_value={'inventories': [inventory()]}), patch('app.services.ai_agent._current_items', return_value=[{'item_id': 'bolt', 'name': 'Bolt'}]) as read:
        result = w.execute(ACTOR, WORLD, 'world_search', {'query': 'Bolt'})
    read.assert_called_once_with(user_id=ACTOR, q='Bolt')
    assert result['items'][0]['inventory_id'] == INVENTORY and not result['complete']

def completion(content='', calls=None):
    return NS(choices=[NS(message=NS(content=content, tool_calls=calls or []))])

def test_structure_proposals_stream_and_survive_repeated_tool_call_without_writes():
    call = NS(id='c', function=NS(name='world_structure', arguments='{}'))
    proposal = {'world_action': {'id': 'review', 'status': 'pending'}}
    with patch.object(w, 'directory', return_value={}), patch.object(w, 'execute', return_value=proposal) as execute, patch('app.services.agent_gateway_client.gateway_completion', side_effect=[completion(calls=[call]), completion(calls=[call]), completion('Review the plan below.')]):
        result = list(w.stream_turn(ACTOR, WORLD, 'Create an inventory', [], 'cid'))
    execute.assert_called_once()
    assert result[-1]['answer_context']['world_actions'] == [proposal['world_action']]
    assert any(e['type'] == 'delta' for e in result)

def test_model_cannot_claim_pending_action_was_saved():
    call = NS(id='c', function=NS(name='world_structure', arguments='{}'))
    with patch.object(w, 'directory', return_value={}), patch.object(w, 'execute', return_value={'world_action': {'id': 'review'}}), patch('app.services.agent_gateway_client.gateway_completion', side_effect=[completion(calls=[call]), completion('I created the inventory.')]):
        with pytest.raises(RuntimeError, match='without a confirmed receipt'):
            list(w.stream_turn(ACTOR, WORLD, 'Create inventory', [], 'cid'))

def test_history_query_is_author_and_world_bound():
    query = Mock(); query.select.return_value = query; query.eq.return_value = query
    db = Mock(); db.table.return_value = query
    with patch.object(w, 'authorize'), patch.object(w, 'get_supabase_raw', return_value=db):
        w.conversations(ACTOR, WORLD)
    assert query.eq.call_args_list[0].args == ('user_id', ACTOR)
    assert query.eq.call_args_list[1].args == ('world_key', WORLD)

def test_failed_save_never_exposes_an_action_card():
    q = Mock(); q.insert.return_value = q; q.select.return_value = q; q.eq.return_value = q
    q.execute.return_value.data = []
    db = Mock(); db.table.return_value = q
    with patch.object(w, 'conversation'), patch.object(w, 'get_supabase_raw', return_value=db):
        with pytest.raises(RuntimeError, match='verified'): w.save_answer(ACTOR, WORLD, 'cid', 'Review', {'world_actions': []})


def test_links_only_use_saved_scoped_read_ids():
    item, space = str(uuid4()), str(uuid4())
    links = w.resource_links({'items': [
        {'item_id': item, 'inventory_id': INVENTORY, 'name': 'Drill'},
        {'item_id': 'invented', 'inventory_id': INVENTORY, 'name': 'Fake'}],
        'spaces': [{'id': space, 'inventory_id': INVENTORY, 'name': 'Shelf'}],
        'world_action': {'name': 'Unsaved'}})
    assert [r['kind'] for r in links] == ['item', 'space']
    assert links[0]['href'] == f'findez://item/{INVENTORY}/{item}'


def test_answer_links_are_grounded_in_reads_and_limited_to_referenced_records():
    item, absent = str(uuid4()), str(uuid4())
    call = NS(id='read', function=NS(name='world_search', arguments='{"query":"drill"}'))
    read = {'items': [{'item_id': item, 'inventory_id': INVENTORY, 'name': 'Drill'},
                      {'item_id': absent, 'inventory_id': INVENTORY, 'name': 'Hammer'}]}
    with patch.object(w, 'directory', return_value={}), patch.object(w, 'execute', return_value=read), patch('app.services.agent_gateway_client.gateway_completion', side_effect=[completion(calls=[call]), completion('Your Drill is on Shelf 2.')]):
        answer = list(w.stream_turn(ACTOR, WORLD, 'Where is my drill?', [], 'cid'))[-1]
    assert [r['id'] for r in answer['answer_context']['resource_links']] == [item]


def test_resource_rechecks_world_before_any_read():
    with patch.object(w, 'authorize'), patch.object(w, '_inventory', return_value=inventory(OTHER)), patch('app.services.supabase_client.get_supabase_admin') as db:
        with pytest.raises(HTTPException): w.resolve_resource(ACTOR, WORLD, INVENTORY, 'item', str(uuid4()))
    db.assert_not_called()


@pytest.mark.parametrize('kind,column', [('item', 'item_id'), ('space', 'id')])
def test_resource_reads_exact_current_id_and_handles_deleted_records(kind, column):
    ident = str(uuid4())
    q = Mock()
    for method in ('select', 'eq', 'limit'): getattr(q, method).return_value = q
    q.execute.return_value.data = [{column: ident, 'name': 'Renamed'}]
    db = Mock(); db.table.return_value = q
    inv = inventory(); inv['workspace']['workspace_id'] = WORKSPACE
    with patch.object(w, 'authorize'), patch.object(w, '_inventory', return_value=inv), patch('app.services.supabase_client.get_supabase_admin', return_value=db):
        result = w.resolve_resource(ACTOR, WORLD, INVENTORY, kind, ident)
        assert result['resource']['name'] == 'Renamed'
        assert ('user_id', ACTOR) in [c.args for c in q.eq.call_args_list]
        assert (column, ident) in [c.args for c in q.eq.call_args_list]
        q.execute.return_value.data = []
        with pytest.raises(HTTPException) as error: w.resolve_resource(ACTOR, WORLD, INVENTORY, kind, ident)
        assert error.value.status_code == 404
    assert current_inventory.get() is None

@pytest.mark.parametrize('supported', [False, True])
def test_management_tools_require_client_card_support(supported):
    with patch.object(w, 'directory', return_value={}), patch('app.services.agent_gateway_client.gateway_completion', return_value=completion('Hello.')) as gateway:
        list(w.stream_turn(ACTOR, WORLD, 'Hello', [], 'cid', supports_item_management=supported))
    names = {t['function']['name'] for t in gateway.call_args.kwargs['tools']}
    assert (w.MANAGEMENT_TOOLS <= names) == supported
    assert 'world_add_items' in names


def test_old_client_cannot_execute_unadvertised_management_tool():
    call = NS(id='c', function=NS(name='world_edit_item', arguments='{}'))
    with patch.object(w, 'directory', return_value={}), patch.object(w, 'execute') as execute, patch('app.services.agent_gateway_client.gateway_completion', side_effect=[completion(calls=[call]), completion('Please update FindEZ to review this change.')]):
        result = list(w.stream_turn(ACTOR, WORLD, 'Edit this item', [], 'cid'))
    execute.assert_not_called()
    assert not result[-1]['answer_context'].get('item_actions')
