"""Space shortcuts must be metadata-only, scoped, and still require review."""
from copy import deepcopy
from types import SimpleNamespace as NS
from unittest.mock import Mock

import pytest
from fastapi import HTTPException

from app.services import chat_space_creation as fast, world_chat as w
from app.services import agent_gateway_client, chat_capture


@pytest.mark.parametrize('message,name', [
    ('create a space called bathroom', 'bathroom'),
    ('Please create a new space named "Guest Bathroom".', 'Guest Bathroom'),
    ("make a space called 'Mom\'s tools'", "Mom's tools"),
    ('set up a space named FTC-parts!', 'FTC-parts'),
    ('add a space called Room 2', 'Room 2'),
])
def test_clear_creation_name(message, name):
    assert fast.space_name(message) == name


@pytest.mark.parametrize('message', [
    'do not create a space called bathroom',
    'can you create a space called bathroom?',
    'if I create a space called bathroom',
    'create a space called bathroom and add soap',
    'create a space called bathroom then delete garage',
    'create a space called bathroom in my workshop',
    'create a space called bathroom without saving it',
    'create a space called bathroom please do not save',
    'create a space called bathroom tomorrow',
    'create a space called bathroom after lunch',
    'create a space called bathroom\nand remove garage',
    'create a space called "bathroom',
    'create a space called ""',
    'create a space called it',
    'create two spaces called bathroom and garage',
    'create a space called bathroom; delete garage',
    'create a space called bathroom, actually cancel',
    'create a space called ' + 'x' * 101,
    'create a space called %',
])
def test_contextual_or_complex_requests_do_not_take_shortcut(message):
    assert fast.space_name(message) is None


class Metadata:
    def __init__(self):
        self.rows, self.ids = [], []

    def table(self, table):
        assert table == 'spaces', 'The shortcut must never read or mutate stock'
        return self

    def select(self, fields):
        assert fields == 'id,name,inventory_id'
        return self

    def in_(self, field, ids):
        assert field == 'inventory_id'
        self.ids = ids
        return self

    def ilike(self, field, name):
        assert field == 'name'
        self.name = name
        return self

    def limit(self, count):
        assert count == 201
        return self

    def execute(self):
        return NS(data=deepcopy(self.rows))


@pytest.fixture
def env(monkeypatch):
    known = {'workspaces': [{'workspace_id': 'personal', 'name': 'Personal', 'can_create': True}],
             'inventories': []}
    metadata = Metadata()
    directory = Mock(side_effect=lambda *args: deepcopy(known))
    monkeypatch.setattr(w, 'directory', directory)
    monkeypatch.setattr(w, 'get_supabase_raw', lambda: metadata)
    auth = Mock()
    monkeypatch.setattr(w, 'authorize', auth)
    scope = Mock()
    monkeypatch.setattr(w, 'inventory_scope', scope)
    model = Mock(side_effect=AssertionError('No model call for a simple creation'))
    monkeypatch.setattr(agent_gateway_client, 'gateway_completion', model)
    return NS(known=known, metadata=metadata, directory=directory, auth=auth, scope=scope, model=model)


def inventory(name='Bathroom', workspace='personal', writable=True, identity='inv-one'):
    return {'inventory_id': identity, 'name': name, 'workspace_id': workspace, 'can_edit': writable}


@pytest.mark.parametrize('modern', [True, False])
def test_real_stream_returns_existing_review_contract_without_model_or_stock(env, modern):
    events = list(w.stream_turn('actor', 'personal', 'create a space called bathroom', [], 'cid',
                               supports_task_actions=modern))
    assert events[0] == {'type': 'status', 'message': 'Checking the Space destination...'}
    result = events[-1]
    assert result['type'] == 'done' and result['conversation_id'] == 'cid'
    context = result['answer_context']
    action, = context['world_actions']
    assert action['status'] == 'pending' and action['inventory_changed'] is False
    assert action['world'] == 'personal' and action['plan']['workspace_id'] == 'personal'
    target, = action['plan']['inventories']
    assert target['name'] == 'bathroom' and target['spaces'] == ['bathroom']
    if modern:
        assert action['version'] == 2 and target['items'] == target['moves'] == []
    else:
        assert 'version' not in action and 'items' not in target
    assert context['pending_actions'] == []
    assert 'Ready to create' in result['assistant_message']
    assert env.directory.call_count == 2  # Lookup plus existing proposal reauthorization.
    env.model.assert_not_called()


def test_existing_space_does_not_propose_duplicate(env):
    env.known['inventories'] = [inventory()]
    env.metadata.rows = [{'id': 'space-one', 'name': 'Bathroom', 'inventory_id': 'inv-one'}]
    result = fast.prepare('actor', 'personal', 'bathroom', supports_task_actions=True)
    assert 'already exists' in result['assistant_message']
    assert result['answer_context']['world_actions'] == []
    assert env.metadata.ids == ['inv-one']
    env.scope.assert_called_once_with('actor', 'personal', 'inv-one')
    assert env.directory.call_count == 1


def test_reuses_named_inventory_without_changing_other_spaces(env):
    env.known['inventories'] = [inventory(), inventory('Garage', identity='inv-two')]
    result = fast.prepare('actor', 'personal', 'bathroom', supports_task_actions=True)
    target = result['answer_context']['world_actions'][0]['plan']['inventories'][0]
    assert target == {'name': 'Bathroom', 'spaces': ['bathroom'], 'items': [], 'moves': []}


@pytest.mark.parametrize('case', ['read_only', 'duplicate_inventory', 'duplicate_space', 'multiple_workspaces',
                                 'no_permission', 'too_many_inventories', 'too_many_spaces'])
def test_ambiguous_or_incomplete_destinations_fall_back_without_proposal(env, case):
    world = 'personal'
    if case == 'read_only':
        env.known['inventories'] = [inventory(writable=False)]
    elif case == 'duplicate_inventory':
        env.known['inventories'] = [inventory(), inventory(identity='inv-two')]
    elif case == 'duplicate_space':
        env.known['inventories'] = [inventory()]
        env.metadata.rows = [{'id': f's{i}', 'name': 'Bathroom', 'inventory_id': 'inv-one'} for i in range(2)]
    elif case == 'multiple_workspaces':
        world = 'organization'
        env.known['workspaces'] = [{'workspace_id': f'w{i}', 'can_create': True} for i in range(2)]
    elif case == 'no_permission':
        env.known['workspaces'][0]['can_create'] = False
    elif case == 'too_many_inventories':
        env.known['inventories'] = [inventory(identity=f'i{i}') for i in range(201)]
    else:
        env.known['inventories'] = [inventory()]
        env.metadata.rows = [{'id': f's{i}', 'name': 'Bathroom', 'inventory_id': 'inv-one'} for i in range(201)]
    assert fast.prepare('actor', world, 'bathroom', supports_task_actions=True) is None
    assert env.directory.call_count == 1


def test_organization_uses_only_sole_authorized_workspace(env):
    env.known['workspaces'] = [{'workspace_id': 'team-one', 'name': 'Workshop', 'can_create': True}]
    result = fast.prepare('actor', 'organization', 'bathroom', supports_task_actions=True)
    action = result['answer_context']['world_actions'][0]
    assert action['world'] == 'organization' and action['plan']['workspace_id'] == 'team-one'


def test_proposal_rechecks_permission_if_revoked_after_lookup(env):
    revoked = deepcopy(env.known)
    revoked['workspaces'][0]['can_create'] = False
    env.directory.side_effect = [deepcopy(env.known), revoked]
    with pytest.raises(HTTPException) as error:
        fast.prepare('actor', 'personal', 'bathroom', supports_task_actions=True)
    assert error.value.status_code == 403


def test_existing_space_rechecks_current_inventory_access(env):
    env.known['inventories'] = [inventory()]
    env.metadata.rows = [{'id': 'space-one', 'name': 'Bathroom', 'inventory_id': 'inv-one'}]
    env.scope.side_effect = HTTPException(403, 'Access revoked')
    with pytest.raises(HTTPException):
        fast.prepare('actor', 'personal', 'bathroom', supports_task_actions=True)


@pytest.mark.parametrize('kwargs', [
    {'history': [{'role': 'user', 'content': 'Use my workshop'}]},
    {'history': [{'action_states': [{'status': 'confirmed'}]}]},
    {'photo_evidence': {'items': []}}, {'source_evidence': [{'kind': 'space'}]},
    {'image_content': {'type': 'image_url'}}, {'read_only_retry': True},
])
def test_contextual_turns_leave_existing_flow_untouched(env, kwargs, monkeypatch):
    prepare = Mock(side_effect=AssertionError('Shortcut must not run'))
    monkeypatch.setattr(fast, 'prepare', prepare)
    args = dict(actor='actor', world='personal', message='create a space called bathroom',
                history=[], conversation_id='cid')
    args.update(kwargs)
    stream = w.stream_turn(**args)
    assert next(stream) == {'type': 'status', 'message': 'Thinking...'}
    stream.close()
    prepare.assert_not_called()


def test_capture_draft_not_detached_or_duplicated(env, monkeypatch):
    prepare = Mock(side_effect=AssertionError('Shortcut must not run'))
    monkeypatch.setattr(fast, 'prepare', prepare)
    token = chat_capture.current_capture.set({'draft': {'status': 'draft', 'id': 'draft-one'}})
    try:
        stream = w.stream_turn('actor', 'personal', 'create a space called bathroom', [], 'cid')
        assert next(stream)['message'] == 'Thinking...'
        stream.close()
        prepare.assert_not_called()
    finally:
        chat_capture.current_capture.reset(token)
