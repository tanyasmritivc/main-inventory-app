from types import SimpleNamespace as NS
from unittest.mock import Mock, patch
from uuid import uuid4
import pytest
from fastapi import HTTPException
from app.services import chat_item_actions as actions
from app.services.inventory_scope import InventoryScope, current_inventory
from app.services import ai_agent

ACTOR, OWNER, INVENTORY, SPACE, ITEM, ACTION, CONVERSATION = [str(uuid4()) for _ in range(7)]

@pytest.fixture
def scope():
    token = current_inventory.set(InventoryScope(INVENTORY, ACTOR, OWNER, None, 'editor'))
    yield
    current_inventory.reset(token)


def pending(operation='add', status='pending'):
    row = {'name': 'Bolt', 'quantity': 3, 'location': 'Garage', 'item_id': ITEM}
    result = {'id': ACTION, 'inventory_id': INVENTORY, 'operation': operation, 'status': status, 'items': [row], 'conversation_id': CONVERSATION}
    if status == 'confirmed': result['receipt'] = {'operation': operation, 'count': 1, 'items': [row]}
    return result


def test_addition_is_a_scoped_proposal_with_no_item_write(scope):
    with patch.object(actions, 'list_spaces', return_value=[{'id': SPACE, 'name': 'Garage'}]), patch.object(actions, 'get_supabase_admin') as db:
        result = actions.propose_additions(user_id=OWNER, items=[{'name': 'Bolt', 'quantity': 3, 'location': 'garage'}])
    assert result['inventory_changed'] is False
    assert result['pending_action']['items'] == [{'name': 'Bolt', 'quantity': 3, 'location': 'Garage', 'space_id': SPACE, 'category': 'Other', 'notes': None}]
    db.assert_not_called()


@pytest.mark.parametrize('role', ['viewer', 'none'])
def test_read_only_users_cannot_even_prepare_a_write(role):
    token = current_inventory.set(InventoryScope(INVENTORY, ACTOR, OWNER, None, role))
    try:
        with patch.object(actions, 'get_supabase_raw') as raw:
            with pytest.raises(HTTPException) as error: actions.propose_deletion(user_id=OWNER, item_ids=[ITEM])
        assert error.value.status_code == 403
        raw.assert_not_called()
    finally: current_inventory.reset(token)


def test_missing_space_and_invalid_quantities_are_public_validation_facts(scope):
    with patch.object(actions, 'list_spaces', return_value=[]):
        with pytest.raises(actions.ChatProposalError, match='existing Space'):
            actions.propose_additions(user_id=OWNER, items=[{'name': 'Bolt', 'quantity': 3, 'location': 'Garage'}])
    with patch.object(actions, 'list_spaces', return_value=[{'id': SPACE, 'name': 'Garage'}]):
        for quantity in [-1, True, None, 1.5]:
            with pytest.raises(actions.ChatProposalError, match='whole-number'):
                actions.propose_additions(user_id=OWNER, items=[{'name': 'Bolt', 'quantity': quantity, 'location': 'Garage'}])


def test_deletion_uses_server_fingerprints_and_the_actor_not_the_effective_owner(scope):
    client = Mock(); client.rpc.return_value.execute.return_value.data = [{'item_id': ITEM, 'name': 'Bolt', 'quantity': 3, 'location': 'Garage', 'snapshot': 'f' * 64}]
    with patch.object(actions, 'get_supabase_raw', return_value=client):
        result = actions.propose_deletion(user_id=OWNER, item_ids=[ITEM])
    client.rpc.assert_called_once_with('findez_chat_delete_snapshot', {'p_actor': ACTOR, 'p_inventory': INVENTORY, 'p_items': [ITEM]})
    assert result['pending_action']['items'][0]['snapshot'] == 'f' * 64
    assert result['inventory_changed'] is False


def test_repeated_tool_calls_do_not_duplicate_unconfirmable_cards():
    value = {'pending_action': pending()}
    assert len(actions.action_context([{'result': value}, {'result': value}])) == 1


def test_confirmation_is_account_bound_and_only_sends_the_stored_action_id(scope):
    client = Mock(); client.rpc.return_value.execute.return_value.data = pending(status='confirmed')
    with patch.object(actions, 'get_supabase_raw', return_value=client), patch('app.services.limits.resolve_effective_limits', return_value=({'items': 30}, None)), patch('app.services.items_repo.invalidate_inventory_cache') as invalidate:
        assert actions.change_action(actor=ACTOR, action_id=ACTION, decision='confirm')['status'] == 'confirmed'
    assert client.rpc.call_args.args == ('findez_chat_item_action', {'p_actor': ACTOR, 'p_inventory': INVENTORY, 'p_action': ACTION, 'p_decision': 'confirm', 'p_item_limit': 30})
    invalidate.assert_called_once_with(OWNER)
    with pytest.raises(HTTPException): actions.change_action(actor=OWNER, action_id=ACTION, decision='confirm')


@pytest.mark.parametrize('bad', [None, {}, {'id': ACTION, 'status': 'confirmed'}, {**pending(status='confirmed'), 'inventory_id': str(uuid4())}, {**pending(status='confirmed'), 'receipt': {'operation': 'add','count': 8,'items':[]}}])
def test_unverified_receipts_never_become_success(scope, bad):
    client=Mock();client.rpc.return_value.execute.return_value.data=bad
    with patch.object(actions,'get_supabase_raw',return_value=client),patch('app.services.limits.resolve_effective_limits',return_value=({'items':None},None)):
        with pytest.raises(HTTPException) as error: actions.change_action(actor=ACTOR,action_id=ACTION,decision='confirm')
    assert error.value.status_code==502


def test_a_pending_proposal_does_not_authorize_a_model_success_claim(scope):
    call=NS(id='proposal',function=NS(name='inventory_propose_add',arguments='{"items":[{"name":"Bolt","quantity":3,"location":"Garage"}]}'))
    def completion(text='', calls=None):return NS(choices=[NS(message=NS(content=text,tool_calls=calls or []))])
    model=Mock(side_effect=[completion(calls=[call]),completion('I added the bolts.')])
    def model_call(messages,enabled):return model()
    with patch.object(ai_agent,'propose_additions',return_value={'pending_action':pending(),'inventory_changed':False}):
        with pytest.raises(RuntimeError,match='without a confirmed receipt'):
            list(ai_agent.iter_model_turn(user_id=OWNER,message='Add 3 bolts to Garage',messages=[],model_call=model_call,allowed_tools={'inventory_propose_add'}))


def test_confirmed_write_survives_model_outage_without_a_fallback_answer():
    import asyncio
    from app.api.routes.ai import chat_action_decision, ChatActionDecision
    from app.core.auth import AuthenticatedUser
    from starlette.requests import Request
    user=AuthenticatedUser(user_id=OWNER, actor_id=ACTOR, first_name='Test')
    request=Request({'type':'http','method':'POST','path':'/ai_actions/'+ACTION,'headers':[],'client':('127.0.0.1',1234)})
    with patch.object(actions,'change_action',return_value=pending(status='confirmed')) as change, patch.object(actions,'completed_reply',side_effect=RuntimeError('PRIVATE MODEL ERROR')):
        result=asyncio.run(chat_action_decision(request=request,action_id=__import__('uuid').UUID(ACTION),payload=ChatActionDecision(decision='confirm'),user=user))
    assert result['action']['status']=='confirmed'
    assert 'assistant_message' not in result and 'PRIVATE' not in str(result)
    assert change.call_args.kwargs['actor']==ACTOR


def test_chat_does_not_reuse_items_cached_before_another_worker_deleted_them(scope):
    from app.services import items_repo
    items_repo._set_cached_inventory(OWNER, [{'item_id': ITEM, 'name': 'Deleted bolt'}])
    db = Mock()
    query = db.table.return_value
    for method in ('select', 'eq', 'order', 'range'):
        getattr(query, method).return_value = query
    query.execute.return_value.data = []
    with patch.object(items_repo, 'get_supabase_admin', return_value=db):
        assert ai_agent._current_items(user_id=OWNER, q='') == []
    query.execute.assert_called_once()


@pytest.mark.parametrize('supported', [False, True])
def test_only_capable_clients_receive_item_action_tools(supported):
    provider = NS(model='unchanged', conversation_id=CONVERSATION, timezone='UTC')
    kwargs = ai_agent._completion_kwargs(provider, messages=[], stream=True, allow_tools=True, allow_item_actions=supported)
    names = {tool['function']['name'] for tool in kwargs['tools']}
    assert ('inventory_propose_add' in names) is supported
    assert ('inventory_propose_delete' in names) is supported
    assert not {'inventory_add_item', 'inventory_delete_item', 'inventory_delete_by_filter'} & names


@pytest.mark.parametrize('insert_lost, persisted', [(False, True), (True, True), (False, False), (True, False)])
def test_review_card_is_emitted_only_after_exact_history_payload_is_verified(insert_lost, persisted):
    from app.api.routes.ai import _save_ask_answer
    records = {}
    client = Mock()
    query = client.table.return_value
    for method in ('select', 'eq', 'limit', 'update'):
        getattr(query, method).return_value = query
    def insert(row):
        if persisted: records.update(row)
        if insert_lost: raise RuntimeError('response lost')
        return query
    query.insert.side_effect = insert
    query.execute.side_effect = lambda: NS(data=[dict(records)] if records else [])
    answer = {'assistant_message': 'Review these new items.', 'answer_context': {'pending_actions': [pending()]}}
    with patch('app.api.routes.ai.get_supabase_admin', return_value=client):
        if persisted:
            _save_ask_answer(conversation_id=CONVERSATION, answer=answer)
            assert records['answer_context'] == answer['answer_context']
        else:
            with pytest.raises(RuntimeError, match='Chat review'):
                _save_ask_answer(conversation_id=CONVERSATION, answer=answer)


def test_photo_proposal_uses_server_observation_crop_and_original_only(scope):
    source = f'https://storage.test/{ACTOR}/original.jpg'
    crop = f'https://storage.test/{ACTOR}/crop.jpg'
    with actions.use_photo({'items': [{'name': 'Bolt', 'image_url': crop}], 'source_url': source}), patch.object(actions, 'list_spaces', return_value=[{'id': SPACE, 'name': 'Garage'}]), patch('app.services.item_photos._storage_path', return_value='trusted-path'):
        proposal = actions.propose_additions(user_id=OWNER, items=[{'name': 'Bolt', 'quantity': 3, 'location': 'Garage', 'observation_index': 0}])
        row = proposal['pending_action']['items'][0]
        assert row['image_url'] == crop and row['source_frame_url'] == source
        with pytest.raises(actions.ChatProposalError):
            actions.propose_additions(user_id=OWNER, items=[{'name': 'Bolt', 'quantity': 3, 'location': 'Garage', 'observation_index': 1}])
    assert actions.photo_observations.get() is None


def test_confirmed_reply_retry_reuses_private_history_without_model_or_write(scope):
    client = Mock()
    query = client.table.return_value
    for method in ('select', 'eq', 'limit'): getattr(query, method).return_value = query
    query.execute.return_value.data = [{'id': 'saved', 'content': 'Added 3 bolts.'}]
    with patch.object(actions, 'get_supabase_admin', return_value=client), patch('app.services.agent_gateway_client.gateway_completion') as model:
        text, reply_id = actions.completed_reply(actor=ACTOR, action=pending(status='confirmed'))
    assert text == 'Added 3 bolts.' and reply_id
    model.assert_not_called()
    query.insert.assert_not_called()
