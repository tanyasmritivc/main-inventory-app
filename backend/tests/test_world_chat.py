from types import SimpleNamespace as NS
from unittest.mock import Mock, patch
from uuid import uuid4
import pytest
from fastapi import HTTPException
from app.services import world_chat as w
from app.services.inventory_scope import current_inventory

ACTOR, WORLD, OTHER, INVENTORY, WORKSPACE = [str(uuid4()) for _ in range(5)]


def test_personal_group_request_is_truthful_and_never_creates_duplicate_stock():
    message = ('My usual electronics repair kit means my multimeter, soldering iron, wire stripper, USB-C cables, and electrical tape. '
               'Save this as my personal group called "electronics repair kit". Don\'t create duplicate inventory items.')
    with patch.object(w, 'directory', return_value={}) as authorized, patch.object(w, 'execute') as execute, \
         patch('app.services.agent_gateway_client.gateway_completion') as gateway:
        result = list(w.stream_turn(ACTOR, WORLD, message, [], str(uuid4())))[-1]
    authorized.assert_called_once_with(ACTOR, WORLD)
    execute.assert_not_called()
    gateway.assert_not_called()
    assert result['type'] == 'done'
    assert "can't save a reusable personal group yet" in result['assistant_message']
    assert result['answer_context']['operation_diagnostics'] == []


def test_personal_group_fast_answer_still_requires_world_access():
    with patch.object(w, 'directory', side_effect=HTTPException(403)):
        with pytest.raises(HTTPException):
            list(w.stream_turn(ACTOR, WORLD, 'Save this as my personal group "kit"', [], str(uuid4())))

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
    assert result == {'inventory_id': INVENTORY, 'name': 'Hardware'}

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
    with patch.object(w, 'directory', return_value={}), patch.object(w, 'execute', return_value={'world_action': {'id': 'review'}}), patch('app.services.agent_gateway_client.gateway_completion', side_effect=[completion(calls=[call]), completion('I created the inventory.'), completion('I created the inventory.')]):
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


def test_destination_lookup_does_not_load_large_inventory_stock():
    space = str(uuid4())
    with patch.object(w, 'authorize'), patch.object(w, '_inventory', return_value=inventory()), \
         patch('app.services.spaces_repo.list_spaces', return_value=[{'id': space, 'name': 'Workbench'}]) as read, \
         patch('app.services.ai_agent._current_items') as stock:
        result = w.execute(ACTOR, WORLD, 'world_spaces', {'inventory_id': INVENTORY})
    read.assert_called_once_with(user_id=ACTOR)
    stock.assert_not_called()
    assert result['spaces'][0]['id'] == space
    assert w.resource_links(result)[0]['href'] == f'findez://space/{INVENTORY}/{space}'
    assert current_inventory.get() is None


def test_destination_lookup_rejects_foreign_inventory_before_read():
    with patch.object(w, 'authorize'), patch.object(w, '_inventory', return_value=inventory(OTHER)), \
         patch('app.services.spaces_repo.list_spaces') as read:
        with pytest.raises(HTTPException):
            w.execute(ACTOR, WORLD, 'world_spaces', {'inventory_id': INVENTORY})
    read.assert_not_called()


def draft_context():
    from app.services.chat_capture import use_capture
    return use_capture(ACTOR, WORLD, 'cid', {'id':str(uuid4()),'version':1,
        'revision':1,'status':'draft','items':[]})


def broken_stream():
    yield completion('Partial reply')
    raise RuntimeError('PRIVATE model transport details')


def test_capture_reply_retries_interrupted_generation_once_and_resets_text():
    with draft_context(), patch.object(w, 'directory', return_value={}), \
         patch('app.services.agent_gateway_client.gateway_completion', side_effect=[broken_stream(),completion('Which inventory and Space should I use?')]) as gateway:
        result = list(w.stream_turn(ACTOR, WORLD, 'Auto extract', [], 'cid'))
    assert gateway.call_count == 2
    assert gateway.call_args.kwargs['max_tokens'] == w.CHAT_RETRY_TOKENS
    assert [e['type'] for e in result if e['type'] not in ('status', 'activity')] == ['delta','reset','delta','done']
    assert result[-1]['assistant_message'] == 'Which inventory and Space should I use?'


def test_capture_reply_retry_never_replays_an_executed_tool():
    call = NS(id='c', function=NS(name='world_refine_capture', arguments='{}'))
    with draft_context(), patch.object(w, 'directory', return_value={}), \
         patch.object(w, 'execute', return_value={'capture_draft':{'status':'draft'},'saved':False}) as execute, \
         patch('app.services.agent_gateway_client.gateway_completion', side_effect=[completion(calls=[call]),broken_stream(),completion('The current draft is ready to review.')]):
        result = list(w.stream_turn(ACTOR, WORLD, 'Only tools', [], 'cid'))
    execute.assert_called_once()
    assert result[-1]['type'] == 'done'


def test_capture_reply_second_failure_is_an_error_not_a_fabricated_answer():
    with draft_context(), patch.object(w, 'directory', return_value={}), \
         patch('app.services.agent_gateway_client.gateway_completion', side_effect=[broken_stream(),broken_stream()]) as gateway:
        with pytest.raises(RuntimeError, match='PRIVATE'):
            list(w.stream_turn(ACTOR, WORLD, 'Auto extract', [], 'cid'))
    assert gateway.call_count == 2


def test_capture_false_save_claim_gets_one_model_correction_without_tools():
    call = NS(id='c', function=NS(name='world_refine_capture', arguments='{}'))
    with draft_context(), patch.object(w, 'directory', return_value={}), \
         patch.object(w, 'execute', return_value={'capture_draft':{'status':'draft'},'saved':False}) as execute, \
         patch('app.services.agent_gateway_client.gateway_completion', side_effect=[completion(calls=[call]),completion('I saved your items.'),completion('The draft is ready. Choose a destination and tap Save items.')]) as gateway:
        result = list(w.stream_turn(ACTOR, WORLD, 'Keep only tools', [], 'cid'))
    execute.assert_called_once()
    assert 'tools' not in gateway.call_args.kwargs
    assert result[-1]['assistant_message'].startswith('The draft is ready.')


def test_capture_bad_correction_still_cannot_claim_inventory_write():
    with draft_context(), patch.object(w, 'directory', return_value={}), \
         patch('app.services.agent_gateway_client.gateway_completion', side_effect=[completion('I saved your items.'),completion('I added your items.')]):
        with pytest.raises(RuntimeError, match='without a confirmed receipt'):
            list(w.stream_turn(ACTOR, WORLD, 'Add these items', [], 'cid'))


def test_saved_capture_uses_current_receipt_over_unsaved_history():
    from app.services.chat_capture import use_capture
    space = str(uuid4())
    link = {'kind':'space','id':space,'inventory_id':INVENTORY,'label':'Fasteners',
            'href':f'findez://space/{INVENTORY}/{space}'}
    draft = {'id':str(uuid4()),'status':'saved','items':[],
             'receipt':{'saved_count':295,'review_count':0,'resource_links':[link]}}
    reply = f'All 295 items were saved to [Fasteners]({link["href"]}).'
    with use_capture(ACTOR, WORLD, 'cid', draft), patch.object(w, 'directory', return_value={}), \
         patch('app.services.agent_gateway_client.gateway_completion', return_value=completion(reply)) as gateway:
        result = list(w.stream_turn(ACTOR, WORLD, 'Are all the items saved?',
            [{'role':'assistant','content':'Nothing is saved. Choose a destination.'}], 'cid'))
    messages = gateway.call_args.kwargs['messages']
    current = next(row['content'] for row in messages if 'Current confirmed extraction receipt' in row['content'])
    assert 'Current confirmed extraction receipt' in current
    assert '"saved_count": 295' in current
    assert 'supersedes earlier conversation claims' in current
    assert not any('Use world_refine_capture to' in row['content'] for row in messages)
    assert not any(t['function']['name'] == 'world_refine_capture' for t in gateway.call_args.kwargs['tools'])
    assert result[-1]['answer_context']['resource_links'] == [link]


def test_missing_card_is_repaired_with_real_tool_before_completion():
    call = NS(id='add', function=NS(name='world_add_items', arguments='{}'))
    proposal = {'pending_action': {'id': 'real-card', 'status': 'pending'}}
    with patch.object(w, 'directory', return_value={}), patch.object(w, 'execute', return_value=proposal), patch('app.services.agent_gateway_client.gateway_completion', side_effect=[completion('Please confirm the action card.'), completion(calls=[call]), completion('Review the items below.')]) as gateway:
        result = list(w.stream_turn(ACTOR, WORLD, 'Add 4 cables', [], 'cid'))
    assert result[-1]['answer_context']['pending_actions'] == [proposal['pending_action']]
    assert 'tools' in gateway.call_args_list[1].kwargs


def test_repeated_imaginary_card_never_becomes_success():
    with patch.object(w, 'directory', return_value={}), patch('app.services.agent_gateway_client.gateway_completion', return_value=completion('Confirm the action card.')):
        with pytest.raises(RuntimeError, match='does not exist'):
            list(w.stream_turn(ACTOR, WORLD, 'Add cables', [], 'cid'))


def test_plain_chat_recovers_a_transient_generation_failure():
    with patch.object(w, 'directory', return_value={}), patch('app.services.agent_gateway_client.gateway_completion', side_effect=[RuntimeError('interrupted'), completion('How can I help?')]) as gateway:
        result = list(w.stream_turn(ACTOR, WORLD, 'Hello', [], 'cid'))
    assert gateway.call_count == 2
    assert result[-1]['type'] == 'done'


def test_retry_of_completed_turn_disables_mutations_and_uses_receipt():
    turn = str(uuid4())
    saved = {'id': str(uuid4()), 'turn_id': turn, 'direct': True, 'status': 'confirmed',
        'operation': 'edit', 'receipt': {'count': 1, 'operation': 'edit', 'items': [{'name': 'Batteries', 'quantity': 5}]}}
    history = [{'role': 'system', 'content': 'Saved receipt', 'action_states': [saved]}]
    with patch.object(w, 'directory', return_value={}), patch('app.services.agent_gateway_client.gateway_completion', return_value=completion('Updated the batteries to 5.')) as gateway:
        result = list(w.stream_turn(ACTOR, WORLD, 'I used 3 batteries', history, 'cid', supports_item_management=True, supports_task_actions=True, turn_id=turn))
    names = {t['function']['name'] for t in gateway.call_args.kwargs['tools']}
    assert not names.intersection({'world_edit_item', 'world_adjust_quantity', 'world_move_item', 'world_create_task', 'world_add_items'})
    assert result[-1]['answer_context']['pending_actions'] == [saved]


def test_old_retry_recovers_canonical_receipt_outside_recent_history():
    turn, cid = str(uuid4()), str(uuid4())
    saved = {'id': str(uuid4()), 'turn_id': turn, 'status': 'confirmed', 'direct': True, 'operation': 'edit'}
    q = Mock()
    for method in ('select', 'eq', 'limit', 'order', 'contains'): getattr(q, method).return_value = q
    q.execute.side_effect = [NS(data=[{'conversation_id': cid, 'content': 'I used 3 batteries'}]), NS(data=[]),
        NS(data=[{'id': str(uuid4()), 'role': 'assistant', 'content': '', 'answer_context': {'pending_actions': [saved]}}])]
    db = Mock(); db.table.return_value = q
    with patch.object(w, 'authorize'), patch.object(w, 'conversation'), patch.object(w, 'get_supabase_raw', return_value=db):
        result_cid, history = w.prepare(ACTOR, WORLD, 'I used 3 batteries', cid, turn_id=turn)
    assert result_cid == cid and history[0]['action_states'] == [saved]
    q.contains.assert_called_once_with('answer_context', {'direct_receipt': True, 'turn_id': turn})
    q.insert.assert_not_called()


def test_invented_internal_link_is_plain_text_not_an_inert_control():
    with patch.object(w, 'directory', return_value={}), patch('app.services.agent_gateway_client.gateway_completion', return_value=completion('See [Hardware](findez://inventory/invented).')):
        done = list(w.stream_turn(ACTOR, WORLD, 'What is available?', [], 'cid'))[-1]
    assert done['assistant_message'] == 'See Hardware.'
    assert done['answer_context']['resource_links'] == []


def test_read_only_world_history_answer_does_not_trigger_write_claim_guard():
    from app.services.assistant_tool_safety import validate_model_answer
    validate_model_answer('When was this created?', [{'tool': 'world_activity', 'result': {'activity': []}}], 'Created on October 21.')


@pytest.mark.parametrize('history', [[], [{'role': 'system', 'content': 'Older unrelated draft', 'action_states': [{'id': 'old', 'status': 'pending'}]}]])
def test_confirmation_card_noun_does_not_bypass_real_card_requirement(history):
    call = NS(id='new', function=NS(name='world_create_task', arguments='{}'))
    proposal = {'world_action': {'id': 'actual', 'version': 2, 'status': 'pending'}}
    with patch.object(w, 'directory', return_value={}), patch.object(w, 'execute', return_value=proposal), patch('app.services.agent_gateway_client.gateway_completion', side_effect=[completion('One confirmation card completes the Space creation and move. Confirm it.'), completion(calls=[call]), completion('Review the complete task below.')]) as gateway:
        done = list(w.stream_turn(ACTOR, WORLD, 'Move batteries to a new Garage Space', history, 'cid', supports_task_actions=True))[-1]
    assert gateway.call_count == 3
    assert done['answer_context']['world_actions'] == [proposal['world_action']]


def test_direct_image_reaches_multimodal_model_and_is_not_a_photo_observation():
    image = {'type':'image_url','image_url':{'url':'data:image/jpeg;base64,abc'}}
    with patch.object(w,'directory',return_value={}), patch('app.services.agent_gateway_client.gateway_completion',return_value=completion('The handles appear orange.')) as gateway:
        result=list(w.stream_turn(ACTOR,WORLD,'What color are the handles?',[],'cid',image_content=image))
    assert result[-1]['assistant_message']=='The handles appear orange.'
    args=gateway.call_args.kwargs
    assert args['model']=='glm-5.3-flash-agent'
    assert any(isinstance(m['content'],list) and image in m['content'] for m in args['messages'])
    assert 'image_url' not in str(result[-1]['answer_context'])


def test_existing_draft_does_not_substitute_for_a_real_destination_proposal():
    call = NS(id='create', function=NS(name='world_create_task', arguments='{}'))
    proposal = {'world_action': {'id': 'real-destination-card', 'status': 'pending'}}
    with draft_context(), patch.object(w, 'directory', return_value={}), patch.object(w, 'execute', return_value=proposal), patch('app.services.agent_gateway_client.gateway_completion', side_effect=[completion("I've prepared a Pantry inventory with a Pantry Space."), completion(calls=[call]), completion('Review your Pantry below.')]) as gateway:
        result = list(w.stream_turn(ACTOR, WORLD, 'Save to my pantry', [], 'cid', supports_task_actions=True))
    assert result[-1]['answer_context']['world_actions'] == [proposal['world_action']]
    assert gateway.call_count == 3


def test_reasoning_exhaustion_retries_with_room_for_structured_inventory_without_partial_writes():
    from app.services.agent_gateway_client import _as_namespace
    partial = _as_namespace({'choices':[{'delta':{'tool_calls':[{'index':0,'id':'partial','function':{'name':'world_create_task','arguments':'{"inventories":['}}]},'finish_reason':'length'}]})
    call = NS(id='complete', function=NS(name='world_create_task', arguments='{}'))
    with patch.object(w, 'directory', return_value={}), patch.object(w, 'execute', return_value={'world_action':{'id':'review','status':'pending'}}) as execute, patch('app.services.agent_gateway_client.gateway_completion', side_effect=[iter([partial]),completion(calls=[call]),completion('Review these additions.')]) as gateway:
        result=list(w.stream_turn(ACTOR,WORLD,'Build inventory from my apartment notes',[],'cid',supports_task_actions=True))
    execute.assert_called_once_with(ACTOR,WORLD,'world_create_task',{})
    assert [c.kwargs['max_tokens'] for c in gateway.call_args_list] == [8192,16384,16384]
    assert result[-1]['type']=='done'
    assert result[-1]['answer_context']['world_actions'][0]['id']=='review'


def test_repeated_output_limit_is_bounded_and_never_executes_partial_tool(caplog):
    from app.services.agent_gateway_client import _as_namespace
    def interrupted():
        return iter([_as_namespace({'choices':[{'delta':{'reasoning_content':'PRIVATE'},'finish_reason':'length'}]})])
    with patch.object(w,'directory',return_value={}), patch.object(w,'execute') as execute, patch('app.services.agent_gateway_client.gateway_completion',side_effect=[interrupted(),interrupted()]) as gateway:
        with pytest.raises(RuntimeError,match='interrupted'):
            list(w.stream_turn(ACTOR,WORLD,'My private apartment',[],'cid'))
    assert gateway.call_count==2
    execute.assert_not_called()
    assert 'reason=output_limit' in caplog.text
    assert 'PRIVATE' not in caplog.text and 'My private apartment' not in caplog.text


def test_length_retry_does_not_consume_answer_repair_and_unverified_summary_never_flashes():
    call = NS(id='c', function=NS(name='world_create_task', arguments='{}'))
    proposal = {'world_action': {'id': 'review', 'status': 'pending'}}
    with patch.object(w, 'directory', return_value={}), patch.object(w, 'execute', return_value=proposal) as execute, patch('app.services.agent_gateway_client.gateway_completion', side_effect=[
        broken_stream(), completion(calls=[call]), completion('I created your items.'),
        completion('Your draft is ready to review. Nothing has been saved yet.')
    ]) as gateway:
        events = list(w.stream_turn(ACTOR, WORLD, 'Build my apartment inventory', [], 'cid', supports_task_actions=True))
    execute.assert_called_once()
    assert gateway.call_count == 4
    assert 'tools' not in gateway.call_args_list[-1].kwargs
    assert events[-1]['type'] == 'done'
    assert events[-1]['answer_context']['world_actions'] == [proposal['world_action']]
    assert 'I created' not in ''.join(e['delta'] for e in events if e['type'] == 'delta')
    labels = [e['message'] for e in events if e['type'] == 'status']
    assert 'Building your item draft...' in labels
    assert 'Writing your draft summary...' in labels
    assert 'Retrying the interrupted response...' in labels
    assert 'Checking the answer against your saved changes...' in labels


def test_repeated_false_claims_still_fail_closed_after_transport_retry():
    call = NS(id='c', function=NS(name='world_create_task', arguments='{}'))
    with patch.object(w, 'directory', return_value={}), patch.object(w, 'execute', return_value={'world_action': {'id': 'review', 'status': 'pending'}}) as execute, patch('app.services.agent_gateway_client.gateway_completion', side_effect=[
        broken_stream(), completion(calls=[call]), completion('I saved the items.'), completion('I saved the items.')
    ]) as gateway:
        events = []
        with pytest.raises(RuntimeError, match='without a confirmed receipt'):
            for event in w.stream_turn(ACTOR, WORLD, 'Add my items', [], 'cid', supports_task_actions=True):
                events.append(event)
    execute.assert_called_once()
    assert gateway.call_count == 4
    assert not any(e['type'] in ('delta', 'done') for e in events)

def test_regenerating_finished_answer_cannot_repeat_inventory_mutation():
    call = NS(id='c',function=NS(name='world_adjust_quantity',arguments='{}'))
    with patch.object(w,'directory',return_value={}),patch.object(w,'execute') as execute,patch('app.services.agent_gateway_client.gateway_completion',side_effect=[completion(calls=[call]),completion('No additional changes were made.')]) as gateway:
        result=list(w.stream_turn(ACTOR,WORLD,'Add five more',[],'cid',read_only_retry=True))
    execute.assert_not_called()
    for invocation in gateway.call_args_list:
        assert all(t['function']['name'] not in ('world_adjust_quantity','world_structure','world_add_items') for t in invocation.kwargs.get('tools',[]))
    assert result[-1]['type']=='done'

def test_operation_diagnostics_never_copy_arguments_or_results():
    result=w.trace_diagnostics([{'tool':'world_adjust_quantity','args':{'secret':'private'},'result':{'inventory_changed':True,'name':'private','quantity':4}}])
    assert result==[{'operation':'world_adjust_quantity','read_only':False,'result':'database_confirmed'}]


def test_tool_context_preserves_source_and_target_inventory_ids_without_secrets():
    from uuid import uuid4
    target = str(uuid4())
    data = w.model_data({'items': [{'inventory_id': INVENTORY, 'target_inventory_id': target,
        'item_id': 'item', 'owner_user_id': 'SECRET', 'token': 'SECRET'}]})
    assert data['items'][0]['inventory_id'] == INVENTORY
    assert data['items'][0]['target_inventory_id'] == target
    assert 'SECRET' not in str(data)


def test_text_channel_tool_markup_retries_native_tools_without_leaking_or_executing_text():
    call = NS(id='read', function=NS(name='world_search', arguments='{"query":"drill"}'))
    outputs = [completion('<tool_call>world_delete_items<arg_key>item_ids</arg_key><arg_value>PRIVATE</arg_value></tool_call>'),
               completion(calls=[call]), completion('No matching saved items were found.')]
    with patch.object(w, 'directory', return_value={}), patch.object(w, 'execute', return_value={'items': []}) as execute, \
         patch('app.services.agent_gateway_client.gateway_completion', side_effect=outputs) as model:
        events = list(w.stream_turn(ACTOR, WORLD, 'Where is my drill?', [], 'cid'))
    assert events[-1]['type'] == 'done'
    assert events[-1]['conversation_id'] == 'cid'
    assert not any('PRIVATE' in e.get('delta', '') or '<tool_call' in e.get('delta', '') for e in events)
    execute.assert_called_once_with(ACTOR, WORLD, 'world_search', {'query': 'drill'})
    assert any('native tool_calls' in m.get('content', '') for m in model.call_args.kwargs['messages'])


def test_repeated_text_tool_markup_stops_after_one_retry():
    from app.services.completion_stream import CompletionStreamError
    with patch.object(w, 'directory', return_value={}), patch.object(w, 'execute') as execute, \
         patch('app.services.agent_gateway_client.gateway_completion', side_effect=lambda **kw: completion('<tool_call>PRIVATE</tool_call>')) as model:
        with pytest.raises(CompletionStreamError):
            list(w.stream_turn(ACTOR, WORLD, 'What do I have?', [], 'cid'))
    assert model.call_count == 2
    execute.assert_not_called()
