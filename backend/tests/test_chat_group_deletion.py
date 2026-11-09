"""Group review uses complete scoped stock, not ranked or truncated previews."""
from copy import deepcopy
from types import SimpleNamespace as NS
from unittest.mock import Mock
from uuid import UUID
import json

import pytest
from fastapi import HTTPException

from app.services import chat_group_deletion as group, chat_item_actions as actions, world_chat as w
from app.services.personalization.scoring import require_clear_mutation_target

INV = str(UUID(int=1000))
SPACE = str(UUID(int=2000))
MESSAGE = 'can you remove all unknown items from things on my table'


def item(index, **kwargs):
    return dict(item_id=str(UUID(int=index + 1)), name='Unknown item', space_id=SPACE,
                inventory_id=INV, location='Things on My Table', quantity=1,
                _personalization_tiebreak=True, **kwargs)


class Store:
    def __init__(self):
        self.rows = [item(i) for i in range(9)]
        self.spaces = [dict(id=SPACE, name='Things on My Table')]
        self.calls = []
        self.snapshot_hook = lambda: None

    def table(self, table):
        assert table in ('items', 'spaces')
        return Query(self, table)

    def rpc(self, name, args):
        assert name == 'findez_chat_delete_snapshot', 'No write RPC in proposal preparation'
        assert args['p_inventory'] == INV and args['p_actor'] == 'actor'
        self.calls.append(deepcopy(args['p_items']))
        rows = [dict(item_id=r['item_id'], name=r['name'], quantity=r['quantity'],
                     location=r['location'], snapshot='fingerprint') for r in self.rows
                if r['item_id'] in args['p_items']]
        self.snapshot_hook()
        return NS(execute=lambda: NS(data=rows))


class Query:
    def __init__(self, store, table):
        self.store, self.table = store, table
        self.filters, self.count, self.fields = [], 1000, []

    def select(self, fields):
        self.fields = fields.split(',')
        return self

    def eq(self, field, value):
        self.filters.append(lambda row: row.get(field) == value)
        return self

    def ilike(self, field, value):
        value = value.replace('\\%', '%').replace('\\_', '_').replace('\\\\', '\\')
        self.filters.append(lambda row: str(row.get(field, '')).casefold() == value.casefold())
        return self

    def order(self, field):
        assert field == 'item_id'
        return self

    def limit(self, count):
        self.count = count
        return self

    def execute(self):
        rows = self.store.rows if self.table == 'items' else self.store.spaces
        rows = [r for r in rows if all(f(r) for f in self.filters)]
        return NS(data=deepcopy([{k: r[k] for k in self.fields} for r in rows[:self.count]]))


@pytest.fixture
def env(monkeypatch):
    store = Store()
    inv = dict(inventory_id=INV, owner_user_id='owner', role='owner', can_edit=True,
               name='Inventory', workspace={'name': 'Personal'})
    authorize = Mock()
    scope = Mock(return_value=inv)
    monkeypatch.setattr(w, 'authorize', authorize)
    monkeypatch.setattr(w, 'inventory_scope', scope)
    monkeypatch.setattr(group, 'get_supabase_admin', lambda: store)
    monkeypatch.setattr(actions, 'get_supabase_raw', lambda: store)
    args = dict(inventory_id=INV, item_ids=[r['item_id'] for r in store.rows[:8]])
    trace = [dict(tool='world_query', result=dict(items=deepcopy(store.rows), complete=True))]
    return NS(store=store, inv=inv, scope=scope, args=args, trace=trace)


def prepare(env, message=MESSAGE):
    return group.prepare('actor', 'personal', message, env.args, env.trace)


def test_nine_records_with_only_eight_preview_ids_prepare_all_without_writes(env):
    with pytest.raises(ValueError):
        require_clear_mutation_target(MESSAGE, env.args['item_ids'][0], [env.trace[0]['result']])
    result = prepare(env)
    assert result['selected_count'] == 9 and result['selection_complete'] is True
    assert result['inventory_changed'] is False
    action = result['pending_action']
    assert action['operation'] == 'delete' and action['status'] == 'pending'
    assert len(action['items']) == 9 and action['world'] == 'personal'
    assert 'press Confirm' in result['next_step']
    assert len(env.store.calls) == 1 and len(env.store.calls[0]) == 9
    env.scope.assert_called_once_with('actor', 'personal', INV)


def test_partial_search_rows_are_not_the_full_selection(env):
    env.trace[0]['result']['items'] = env.trace[0]['result']['items'][:8]
    env.trace[0]['result']['complete'] = False
    assert prepare(env)['selected_count'] == 9


@pytest.mark.parametrize('message', [
    'delete the unknown item from things on my table', 'yes confirm',
    'do not remove all unknown items from things on my table',
    'remove one unknown item from things on my table',
    'remove all unknown items', 'what if I remove all unknown items from things on my table?',
])
def test_singular_contextual_and_negated_requests_keep_existing_guard(env, message):
    assert prepare(env, message) is None
    assert not env.store.calls
    with pytest.raises(ValueError):
        require_clear_mutation_target(message, env.args['item_ids'][0], [env.trace[0]['result']])


@pytest.mark.parametrize('message', [
    'Please delete all "Unknown item" in "Things on My Table".',
    'remove all the Unknown items from Things on My Table!',
    'could you remove all unknown items from things on my table?',
])
def test_exact_names_case_quotes_and_simple_plural(env, message):
    assert prepare(env, message)['selected_count'] == 9


@pytest.mark.parametrize('case', [
    'wrong_name', 'wrong_space', 'mixed_spaces', 'mixed_names', 'no_search',
    'foreign_inventory', 'unobserved_id', 'duplicates', 'view_only', 'no_space',
    'empty', 'over_limit', 'removed', 'moved', 'other_tool',
])
def test_unsafe_or_incomplete_selections_never_propose(env, case):
    message = MESSAGE
    seeds = env.trace[0]['result']['items']
    if case == 'wrong_name': message = MESSAGE.replace('unknown', 'screw')
    elif case == 'wrong_space': message = MESSAGE.replace('things on my table', 'Garage')
    elif case == 'mixed_spaces': seeds[0]['space_id'] = 'other'
    elif case == 'mixed_names': seeds[0]['name'] = 'Screw'
    elif case == 'no_search': env.trace = []
    elif case == 'foreign_inventory': env.args['inventory_id'] = str(UUID(int=999))
    elif case == 'unobserved_id': env.args['item_ids'].append(str(UUID(int=999)))
    elif case == 'duplicates': env.args['item_ids'].append(env.args['item_ids'][0])
    elif case == 'view_only': env.inv.update(can_edit=False, role='viewer')
    elif case == 'no_space': env.store.spaces = []
    elif case == 'empty': env.store.rows = []
    elif case == 'over_limit': env.store.rows = [item(i) for i in range(101)]
    elif case == 'removed': env.store.rows.pop(0)
    elif case == 'moved': env.store.rows[0]['space_id'] = 'other'
    elif case == 'other_tool': env.trace[0]['tool'] = 'world_recall'
    with pytest.raises(group.GroupSelectionError): prepare(env, message)
    assert not env.store.calls


def test_scope_authorization_rechecked(env):
    env.scope.side_effect = HTTPException(403, 'No longer accessible')
    with pytest.raises(HTTPException): prepare(env)
    assert not env.store.calls


def test_other_items_and_spaces_remain_outside_selection(env):
    env.store.rows.append({**item(20), 'name': 'Known item'})
    env.store.rows.append({**item(21), 'space_id': 'other'})
    assert prepare(env)['selected_count'] == 9
    assert len(env.store.rows) == 11


@pytest.mark.parametrize('change', ['move', 'rename', 'add', 'delete'])
def test_race_around_snapshot_does_not_emit_stale_group(env, change):
    def alter():
        if change == 'move': env.store.rows[0]['space_id'] = 'other'
        elif change == 'rename': env.store.rows[0]['name'] = 'Known item'
        elif change == 'add': env.store.rows.append(item(50))
        else: env.store.rows.pop(0)
    env.store.snapshot_hook = alter
    with pytest.raises(group.GroupSelectionError): prepare(env)


def test_literal_wildcards_are_escaped():
    assert group._literal('10%_part\\a') == '10\\%\\_part\\\\a'


def test_verified_counts_survive_large_model_preview(env):
    payload = {'items': [{**r, 'notes': 'x' * 1500} for r in env.store.rows],
               'record_count': 9, 'complete': True, 'rows_truncated': False,
               'token': 'secret-never-forward'}
    bounded = w.model_data(payload)
    assert bounded['record_count'] == 9 and bounded['complete'] is True
    assert bounded['rows_truncated'] is False
    assert 'secret-never-forward' not in json.dumps(bounded)
    assert isinstance(bounded['items'], dict) and bounded['items']['records_truncated'] is True


def test_real_stream_uses_complete_group_and_existing_card_contract(env, monkeypatch):
    from app.services import agent_gateway_client, completion_stream
    call = lambda name, args: NS(id=name, function=NS(name=name, arguments=json.dumps(args)))
    rounds = iter([
        dict(type='done', content='', tool_calls=[call('world_query', {'terms': ['Unknown item']})]),
        dict(type='done', content='', tool_calls=[call('world_delete_items', env.args)]),
        dict(type='done', content='Review all 9 matching items in the confirmation card.', tool_calls=[]),
    ])
    model = Mock(return_value=object())
    monkeypatch.setattr(agent_gateway_client, 'gateway_completion', model)
    monkeypatch.setattr(completion_stream, 'completion_events', lambda *a, **kw: iter([next(rounds)]))
    def read(actor, world, name, args):
        assert name == 'world_query', 'Deletion must use the verified group path'
        return deepcopy(env.trace[0]['result'])
    monkeypatch.setattr(w, 'execute', read)
    result = list(w.stream_turn('actor', 'personal', MESSAGE, [], 'cid'))[-1]
    assert result['type'] == 'done'
    action, = result['answer_context']['pending_actions']
    assert action['status'] == 'pending' and len(action['items']) == 9
    diagnostics = result['answer_context']['operation_diagnostics']
    assert diagnostics[-1]['result'] == 'proposal'
    assert len(env.store.calls) == 1
