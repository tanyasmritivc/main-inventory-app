"""Synthetic question evaluation with actual scoped repository queries, no AI I/O."""
from collections import defaultdict
from copy import deepcopy
import json
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, patch
import statistics
import time
import pytest
from app.services import ai_agent, inventory_query, items_repo
from app.services.inventory_scope import InventoryScope, current_inventory
from app.services.assistant_tool_safety import rejection
from backend.tests.test_inventory_journeys import api as http_api, A, B, FOREIGN, TEAM_INV, VIEWER
DATA = json.loads((Path(__file__).parent / 'fixtures/physical_memory_questions.json').read_text())

class Query:

    def __init__(self, store, table):
        self.store, self.table = (store, table)
        self.filters, self.fields, self.operation, self.payload = ([], '*', 'read', None)
        self.maximum = 1000
        self.offset = 0
        self.sorts = []

    def select(self, fields='*', **kwargs):
        self.fields = fields
        return self

    def eq(self, key, value):
        self.filters.append(lambda row: row.get(key) == value)
        return self

    def is_(self, key, value):
        self.filters.append(lambda row: row.get(key) is None if value == 'null' else row.get(key) == value)
        return self

    def in_(self, key, values):
        self.filters.append(lambda row: row.get(key) in values)
        return self

    def limit(self, value):
        self.maximum = value
        return self

    def range(self, start, end):
        self.offset, self.maximum = start, end - start + 1
        return self

    def order(self, key, desc=False):
        self.sorts.append((key, desc))
        return self

    def or_(self, expression):
        parts = [p.split('.', 2) for p in expression.split(',')]
        self.filters.append(lambda row: any((str(row.get(key) or '').casefold().find(value.strip('%').casefold()) >= 0 if op == 'ilike' else row.get(key) == value for key, op, value in parts)))
        return self

    def update(self, payload):
        self.operation, self.payload = ('update', payload)
        return self

    def execute(self):
        if self.store.failure:
            raise RuntimeError('synthetic private detail that must not escape')
        if self.operation == 'update' and self.store.before_write:
            self.store.before_write()
            self.store.before_write = None
        self.store.reads.append((self.table, self.operation, self.maximum))
        rows = [r for r in self.store.rows[self.table] if all((f(r) for f in self.filters))]
        for key, desc in reversed(self.sorts):
            rows.sort(key=lambda r: str(r.get(key) or ''), reverse=desc)
        if self.operation == 'update':
            for row in rows:
                row.update(self.payload)
            self.store.writes += len(rows)
        rows = rows[self.offset:self.offset + self.maximum]
        if self.fields != '*':
            rows = [{key.strip(): row.get(key.strip()) for key in self.fields.split(',')} for row in rows]
        return SimpleNamespace(data=deepcopy(rows))

@pytest.fixture
def memory(monkeypatch):
    db = SimpleNamespace(rows=defaultdict(list), reads=[], writes=0, failure=False, before_write=None)
    db.table = lambda table: Query(db, table)
    db.rows['items'] = deepcopy(DATA['items'])
    db.rows['documents'] = deepcopy(DATA['documents'])
    db.rows['item_events'] = deepcopy(DATA['events'])
    monkeypatch.setattr('app.services.supabase_client.get_supabase_raw', lambda: db)
    monkeypatch.setattr('app.services.items_repo._execute_with_retry', lambda fn: fn())
    monkeypatch.setattr('app.services.documents_repo._execute_with_retry', lambda fn: fn())
    token = current_inventory.set(InventoryScope('inventory-a', 'owner', 'owner', None, 'owner'))
    yield db
    current_inventory.reset(token)
    items_repo._INVENTORY_CACHE.clear()

def seed_references(db, ids, *, user='owner', inventory='inventory-a', conversation='conversation-a'):
    db.rows['conversations'].append({'id': conversation, 'user_id': user, 'inventory_id': inventory})
    db.rows['messages'].append({'conversation_id': conversation, 'inventory_id': inventory, 'role': 'assistant', 'created_at': '2026-10-15', 'answer_context': {'rows': [{'id': id_} for id_ in ids]}})

def test_conditional_edit_rejects_concurrent_changes_and_replay_is_noop(memory):
    item = memory.rows['items'][0]
    memory.before_write = lambda: item.update({'quantity': 88})
    assert items_repo.update_item_from_chat(user_id='owner', item_id=item['item_id'], updates={'notes': 'New note'}) is None
    assert item['notes'] == 'little black video adapter'
    assert memory.writes == 0
    result = items_repo.update_item_from_chat(user_id='owner', item_id=item['item_id'], updates={'notes': 'New note'})
    assert result['notes'] == 'New note' and memory.writes == 1
    assert items_repo.update_item_from_chat(user_id='owner', item_id=item['item_id'], updates={'notes': 'New note'})['notes'] == 'New note'
    assert memory.writes == 1
    stale = deepcopy(item)
    item['notes'] = 'Changed while the model was choosing a tool'
    items_repo._INVENTORY_CACHE['inventory-a:owner:owner'] = ([stale], time.time())
    assert items_repo.update_item_from_chat(user_id='owner', item_id=item['item_id'], updates={'notes': 'Stale edit'}, expected_item=stale) is None
    assert memory.writes == 1
    assert not items_repo._INVENTORY_CACHE

def test_viewer_and_cross_inventory_edits_cannot_write(memory):
    item = memory.rows['items'][0]
    token = current_inventory.set(InventoryScope('inventory-a', 'owner', 'owner', None, 'viewer'))
    try:
        with pytest.raises(Exception):
            items_repo.update_item_from_chat(user_id='owner', item_id=item['item_id'], updates={'notes': 'Forged'})
    finally:
        current_inventory.reset(token)
    foreign = DATA['items'][-1]
    assert items_repo.update_item_from_chat(user_id='owner', item_id=foreign['item_id'], updates={'notes': 'Forged'}) is None
    assert memory.writes == 0

def test_unknown_write_outcome_is_not_retried(memory):
    item = memory.rows['items'][0]

    def interrupt():
        memory.failure = True
    memory.before_write = interrupt
    original = Query.execute

    def fail_write(query):
        if query.operation == 'update':
            raise RuntimeError('response lost')
        return original(query)
    with patch.object(Query, 'execute', fail_write), patch.object(items_repo, 'invalidate_inventory_cache') as invalidate:
        with pytest.raises(RuntimeError):
            items_repo.update_item_from_chat(user_id='owner', item_id=item['item_id'], updates={'notes': 'New'})
    invalidate.assert_called_once()
    assert memory.writes == 0

def test_named_conversation_never_uses_another_thread_history(memory):
    state = ai_agent._SessionState(conversation_history=[{'role': 'assistant', 'content': 'OTHER_THREAD_FACT'}])
    seed_references(memory, [DATA['items'][0]['item_id']], user='another')
    assert ai_agent._question_history(user_id='owner', conversation_id='conversation-a', supplied=None, state=state, message='Hello') == []
    assert ai_agent._question_history(user_id='owner', conversation_id='new-thread', supplied=None, state=state, message='Hello') == []
    memory.failure = True
    assert ai_agent._question_history(user_id='owner', conversation_id='conversation-a', supplied=None, state=state, message='Hello') == []

def test_literal_note_edit_uses_real_conditional_service_and_replay_receipt(memory):
    item = memory.rows['items'][4]
    args = {'item_id': item['item_id'], 'updates': {'notes': 'Inspected'}}
    trace = [{'tool': 'inventory_search', 'result': [deepcopy(item)]}]
    results = {}
    for _ in range(2):
        answer = ai_agent._guarded_tool_call(user_id='owner', tool_name='inventory_update_item', args=args, enabled=True, message='Change Red handle pliers notes to Inspected', trace=trace, results=results)
        assert answer.get('notes') == 'Inspected'
    assert item['notes'] == 'Inspected' and memory.writes == 1

def test_stream_scope_and_actor_survive_dependency_cleanup_and_concurrent_streams():
    import asyncio
    from app.api.routes.ai import _authorized_stream
    from app.services.resource_access import request_actor, ActorAccess

    async def run(id_):
        token = current_inventory.set(InventoryScope(id_, id_, 'owner', None, 'viewer'))
        actor = request_actor.set(ActorAccess(id_))

        async def body():
            await asyncio.sleep(0)
            yield (current_inventory.get().inventory_id, request_actor.get().actor_id)
        stream = _authorized_stream(body())
        current_inventory.reset(token)
        request_actor.reset(actor)
        return [row async for row in stream]

    async def together():
        result = await asyncio.gather(run('first'), run('second'))
        assert current_inventory.get() is None
        assert request_actor.get() is None
        return result
    assert asyncio.run(together()) == [[('first', 'first')], [('second', 'second')]]

def test_interrupted_stream_and_background_memory_keep_scope_and_cleanup():
    import asyncio
    from app.api.routes.ai import _authorized_stream, _authorized_background

    async def run():
        observed = []
        token = current_inventory.set(InventoryScope('inventory-a', 'actor', 'owner', None, 'editor'))

        async def body():
            try:
                yield 'first'
                yield 'second'
            finally:
                observed.append(current_inventory.get().inventory_id)

        async def background():
            observed.append(current_inventory.get().inventory_id)
        stream, task = (_authorized_stream(body()), _authorized_background(background))
        current_inventory.reset(token)
        assert await stream.__anext__() == 'first'
        await stream.aclose()
        assert current_inventory.get() is None
        await task()
        assert current_inventory.get() is None
        return observed
    assert asyncio.run(run()) == ['inventory-a', 'inventory-a']

@pytest.mark.parametrize('case', DATA['cases'], ids=lambda case: case['id'])
@pytest.mark.parametrize('streaming', [False, True])
def test_every_previous_question_family_reaches_model_without_answer_shortcuts(case, memory, streaming):
    if case.get('kind') == 'tool':
        assert rejection(tool_name=case['tool'], args=case['args'], definitions=ai_agent._TOOLS, enabled=True, message=case['question'], trace=[])
    expected = 'Model response for ' + case['id']
    create = Mock(return_value=SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=expected, tool_calls=[]))]))
    if case.get('kind') == 'provider':
        if case['failure'] == 'provider_error':
            create.side_effect = RuntimeError('PRIVATE_PROVIDER_DETAIL')
        else:
            create.return_value.choices[0].message.content = ''
    provider = ai_agent._ChatProvider(client=SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=create))), model='unchanged-route', conversation_id='thread', timezone='UTC')
    state = ai_agent._SessionState()
    with patch.object(ai_agent, '_get_chat_provider', return_value=provider), patch.object(ai_agent, '_load_context', return_value={}), patch.object(ai_agent, '_get_state', return_value=state), patch.object(ai_agent, '_persist_state'):

        def run():
            args = dict(user_id='owner', message=case['question'], first_name=None)
            return list(ai_agent._iter_agent_streaming(**args))[-1] if streaming else ai_agent.run_ai_command(**args)
        if case.get('kind') == 'provider':
            with pytest.raises(RuntimeError):
                run()
            assert state.conversation_history == []
        else:
            answer = run()
            assert answer['assistant_message'] == expected
            assert state.conversation_history[-1]['content'] == expected
    assert create.call_count == (1 if case.get('kind') == 'provider' else 2)
    assert 'tools' in create.call_args_list[0].kwargs
    if case.get('kind') != 'provider':
        assert 'tools' not in create.call_args.kwargs
    assert memory.writes == 0

@pytest.mark.parametrize('terms,filters,names', [(['hdmi', 'adapter'], {}, ['HDMI adapter']), (['battery'], {}, ['AA battery', 'AA battery']), ([], {'location': 'Garage shelf'}, ['USB-C charger', 'AA battery']), ([], {'quantity_op': 'at least', 'quantity_value': 8}, ['AA battery', 'M3 screw']), ([], {'created_op': 'before', 'created_date': '2026-10-01'}, []), (['A-101'], {}, []), (['000112'], {}, [])])
def test_model_selected_filters_return_scoped_facts_not_answer_text(memory, terms, filters, names):
    result = inventory_query.query_inventory(user_id='owner', terms=terms, filters=filters)
    assert sorted((row['name'] for row in result['items'])) == sorted(names)
    assert result['complete'] is True
    assert 'assistant_message' not in result
    assert 'FOREIGN_SECRET' not in json.dumps(result)
    assert memory.writes == 0

def test_query_preserves_unknown_quantities_and_partial_counts(memory):
    result = inventory_query.query_inventory(user_id='owner', terms=['battery'])
    assert result['known_units'] == 8 and result['unknown_quantity_records'] == 1
    memory.rows['items'] = [{**DATA['items'][0], 'item_id': str(i)} for i in range(510)]
    result = inventory_query.query_inventory(user_id='owner', terms=['adapter'])
    assert result['complete'] is False and result['truncated'] is True
    assert result['record_count'] == 500 and result['known_units'] == 1000
    assert max((maximum for _, _, maximum in memory.reads)) <= 501

def test_failed_query_is_not_an_empty_result(memory):
    memory.failure = True
    with pytest.raises(RuntimeError):
        inventory_query.query_inventory(user_id='owner', terms=['adapter'])

@pytest.mark.parametrize('filters', [{'created_op': 'after', 'created_date': '2026-99-01'}, {'quantity_op': 'above'}, {'space_id': 'not-a-uuid'}])
def test_invalid_model_filters_fail_before_item_read(memory, filters):
    with pytest.raises(ValueError):
        inventory_query.query_inventory(user_id='owner', terms=[], filters=filters)
    assert not memory.reads

@pytest.mark.parametrize('query', ['PN-F', 'pn f156', 'PNF156', 'F156', 'steel black',
    'drawer spring', 'supplies acme', 'fragile', 'McMaster', 'stainless', 'black sprign'])
def test_smart_search_reads_saved_details_and_identifiers(memory, query):
    memory.rows['items'] = [
        {'item_id': 'target', 'user_id': 'owner', 'inventory_id': 'inventory-a',
         'name': 'Black steel spring', 'part_number': 'PN-F156', 'category': 'Supplies',
         'brand': 'Acme', 'location': 'Drawer B', 'tags': ['fragile'],
         'purchase_source': 'McMaster', 'import_data': {'fields': [{'name': 'Finish', 'value': 'stainless'}]},
         'quantity': 14},
        {'item_id': 'foreign', 'user_id': 'other', 'inventory_id': 'inventory-b',
         'name': 'Black steel spring', 'part_number': 'PN-F156'},
    ]
    assert [r['item_id'] for r in items_repo.search_items_basic(user_id='owner', q=query)] == ['target']
    answer = inventory_query.query_inventory(user_id='owner', terms=[query])
    assert [r['item_id'] for r in answer['items']] == ['target']
    assert answer['known_units'] == 14 and answer['complete']
    assert memory.writes == 0


def test_smart_query_finds_rare_match_beyond_first_database_page(memory):
    base = {'user_id': 'owner', 'inventory_id': 'inventory-a', 'created_at': '2026-10-01', 'quantity': 1}
    memory.rows['items'] = [{**base, 'item_id': f'{i:04}', 'name': 'Bolt'} for i in range(620)]
    memory.rows['items'].append({**base, 'item_id': '9999', 'name': 'HDMI adaptor', 'notes': 'Black cable'})
    result = inventory_query.query_inventory(user_id='owner', terms=['black adpator'])
    assert [row['item_id'] for row in result['items']] == ['9999']
    assert result['items'][0]['_match_basis'] == 'likely text match'
    assert result['complete'] and result['known_units'] == 1


def test_smart_query_scan_limit_discloses_incomplete_result(memory):
    base = {'user_id': 'owner', 'inventory_id': 'inventory-a', 'name': 'Bolt'}
    memory.rows['items'] = [{**base, 'item_id': str(i)} for i in range(10001)]
    result = inventory_query.query_inventory(user_id='owner', terms=['spring'])
    assert not result['complete'] and result['truncated'] and result['items'] == []
    assert len(memory.reads) == 20
