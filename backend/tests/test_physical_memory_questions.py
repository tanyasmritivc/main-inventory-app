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

from app.services import ai_agent, inventory_questions, items_repo
from app.services.inventory_scope import InventoryScope, current_inventory
from app.services.assistant_tool_safety import rejection
from backend.tests.test_inventory_journeys import api as http_api, A, B, FOREIGN, TEAM_INV, VIEWER

DATA = json.loads((Path(__file__).parent / 'fixtures/physical_memory_questions.json').read_text())


class Query:
    def __init__(self, store, table):
        self.store, self.table = store, table
        self.filters, self.fields, self.operation, self.payload = [], '*', 'read', None
        self.maximum = 1000
        self.sorts = []
    def select(self, fields='*', **kwargs): self.fields = fields; return self
    def eq(self, key, value): self.filters.append(lambda row: row.get(key) == value); return self
    def is_(self, key, value): self.filters.append(lambda row: row.get(key) is None if value == 'null' else row.get(key) == value); return self
    def in_(self, key, values): self.filters.append(lambda row: row.get(key) in values); return self
    def limit(self, value): self.maximum = value; return self
    def order(self, key, desc=False): self.sorts.append((key, desc)); return self
    def or_(self, expression):
        parts = [p.split('.', 2) for p in expression.split(',')]
        self.filters.append(lambda row: any(
            str(row.get(key) or '').casefold().find(value.strip('%').casefold()) >= 0
            if op == 'ilike' else row.get(key) == value
            for key, op, value in parts))
        return self
    def update(self, payload): self.operation, self.payload = 'update', payload; return self
    def execute(self):
        if self.store.failure:
            raise RuntimeError('synthetic private detail that must not escape')
        if self.operation == 'update' and self.store.before_write:
            self.store.before_write()
            self.store.before_write = None
        self.store.reads.append((self.table, self.operation, self.maximum))
        rows = [r for r in self.store.rows[self.table] if all(f(r) for f in self.filters)]
        for key, desc in reversed(self.sorts):
            rows.sort(key=lambda r: str(r.get(key) or ''), reverse=desc)
        if self.operation == 'update':
            for row in rows:
                row.update(self.payload)
            self.store.writes += len(rows)
        rows = rows[:self.maximum]
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
    db.rows['messages'].append({'conversation_id': conversation, 'inventory_id': inventory, 'role': 'assistant', 'created_at': '2026-10-15',
                               'answer_context': {'rows': [{'id': id_} for id_ in ids]}})


@pytest.mark.parametrize('case', DATA['cases'], ids=lambda case: case['id'])
def test_question_dataset(case, memory):
    before = deepcopy(memory.rows)
    if case.get('kind') == 'tool':
        reason = rejection(tool_name=case['tool'], args=case['args'], definitions=ai_agent._TOOLS,
                           enabled=True, message=case['question'], trace=[])
        assert bool(reason) == case['expected_rejection']
    elif case.get('kind') == 'provider':
        create = Mock(side_effect=RuntimeError('synthetic provider detail')) if case['failure'] == 'provider_error' else Mock(
            return_value=SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content='', tool_calls=[]))]))
        provider = ai_agent._ChatProvider(client=SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=create))),
                                           model='configured-test-route', conversation_id='thread', timezone='UTC')
        with patch.object(ai_agent, 'answer_question', return_value=None), \
             patch.object(ai_agent, '_project_readiness_for_question', return_value=None), \
             patch.object(ai_agent, '_get_chat_provider', return_value=provider), \
             patch.object(ai_agent, '_get_state', return_value=ai_agent._SessionState()), \
             patch.object(ai_agent, '_load_context', return_value={}), \
             patch.object(ai_agent, '_persist_state'), patch.object(ai_agent, '_execute_tool_call') as execute:
            events = list(ai_agent._iter_agent_streaming(user_id='owner', message=case['question'], first_name=None))
        assert 'unavailable' in events[-1]['assistant_message']
        assert 'synthetic provider detail' not in json.dumps(events)
        execute.assert_not_called()
    else:
        conversation = None
        if 'refs' in case:
            conversation = 'conversation-a'
            seed_references(memory, case['refs'])
        if case.get('failure'):
            memory.failure = True
        result = inventory_questions.answer_question(user_id='owner', message=case['question'], conversation_id=conversation)
        assert result is not None
        assert result['capability'] == case['expected_capability']
        assert result['capability_state'] == case['expected_state']
        ids = [row['id'] for row in (result.get('answer_context') or {}).get('rows', [])]
        assert sorted(ids) == sorted(case['expected_ids'])
        seeds = {row['item_id']: row for row in DATA['items']}
        for row in (result.get('answer_context') or {}).get('rows', []):
            expected = seeds[row['id']]
            assert row['name'] == expected['name']
            assert row['available_quantity'] == expected['quantity']
            assert row['location'] == (expected['location'] or '')
        for phrase in case['contains']:
            assert phrase.casefold() in result['assistant_message'].casefold()
        serialized = json.dumps(result)
        assert 'FOREIGN_SECRET' not in serialized
        assert 'https://private.test' not in serialized
        assert 'owner/private.pdf' not in serialized
        assert 'synthetic private detail' not in serialized
        if case['expected_capability'] == 'item.documents' and case['expected_ids'] == [DATA['items'][6]['item_id']]:
            assert 'Printer manual.pdf' in result['assistant_message']
            assert 'not read document contents' in result['assistant_message']
        if case['expected_capability'] == 'item.history' and case['expected_ids'] == [DATA['items'][4]['item_id']]:
            assert 'Inspected red handle' in result['assistant_message']
    assert memory.writes == 0
    assert memory.rows['items'] == before['items']


def test_followup_rechecks_item_and_conversation_permissions(memory):
    first = DATA['items'][0]
    seed_references(memory, [first['item_id']], user='other')
    result = inventory_questions.answer_question(user_id='owner', message='Where is it?', conversation_id='conversation-a')
    assert result['capability_state'] == 'ambiguous'
    assert not any(table == 'items' for table, _, _ in memory.reads)
    memory.rows['conversations'][0]['user_id'] = 'owner'
    first['location']  # The seed object is not the live read.
    memory.rows['items'][0]['location'] = 'Moved drawer'
    result = inventory_questions.answer_question(user_id='owner', message='Where is it?', conversation_id='conversation-a')
    assert 'Moved drawer' in result['assistant_message']
    assert 'Top desk drawer' not in result['assistant_message']
    token = current_inventory.set(InventoryScope('inventory-b', 'owner', 'owner', None, 'owner'))
    try:
        result = inventory_questions.answer_question(user_id='owner', message='Where is it?', conversation_id='conversation-a')
        assert result['capability_state'] == 'ambiguous'
    finally:
        current_inventory.reset(token)


def test_partial_counts_are_not_reported_as_complete(memory):
    memory.rows['items'] = [{**DATA['items'][0], 'item_id': f'row-{n}'} for n in range(510)]
    result = inventory_questions.answer_question(user_id='owner', message='How many adapters?')
    assert result['capability_state'] == 'incomplete'
    assert 'partial' in result['assistant_message']
    assert result['answer_context']['rows_truncated'] is True
    assert max(maximum for _, _, maximum in memory.reads) <= 501


@pytest.mark.parametrize('question', ['Find something', 'Where is 充电器?', 'Where is that?'])
def test_unresolved_words_do_not_turn_into_an_all_inventory_query(memory, question):
    result = inventory_questions.answer_question(user_id='owner', message=question)
    assert result['capability_state'] == 'ambiguous'
    assert not result['answer_context']['rows']
    assert not any(table == 'items' for table, _, _ in memory.reads)


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


def test_both_agent_paths_share_grounded_answers_without_provider_calls(memory):
    with patch.object(ai_agent, '_project_readiness_for_question', return_value=None), patch.object(ai_agent, '_get_chat_provider') as provider:
        answer = ai_agent.run_ai_command(user_id='owner', message='Where is my HDMI adapter?')
        events = list(ai_agent._iter_agent_streaming(user_id='owner', message='Where is my HDMI adapter?', first_name=None))
    provider.assert_not_called()
    assert answer['assistant_message'] == events[0]['delta'] == events[-1]['assistant_message']
    assert answer['answer_context']['rows'] == events[-1]['answer_context']['rows']


def test_unknown_write_outcome_is_not_retried(memory):
    item = memory.rows['items'][0]
    def interrupt():
        memory.failure = True
    memory.before_write = interrupt
    # Simulate a transport interruption at execute, not a successful receipt.
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


def test_synthetic_lookup_baseline_and_measurement(memory):
    cases = [case for case in DATA['cases'] if case.get('kind') not in ('tool', 'provider') and case['expected_capability'] == 'item.find'
             and 'refs' not in case and not case.get('failure') and 'filters' not in case]
    baseline, improved, latencies = 0, 0, []
    for case in cases:
        query = ai_agent._normalized_knowledge_query(case['question'])
        old = [row['item_id'] for row in DATA['items'] if row['inventory_id'] == 'inventory-a'
               and any(query in str(row.get(field) or '').casefold() for field in inventory_questions._FIELDS)]
        baseline += sorted(old) == sorted(case['expected_ids'])
        started = time.perf_counter()
        result = inventory_questions.answer_question(user_id='owner', message=case['question'])
        latencies.append((time.perf_counter() - started) * 1000)
        ids = [row['id'] for row in result['answer_context']['rows']]
        improved += sorted(ids) == sorted(case['expected_ids'])
    assert improved == len(cases)
    assert improved > baseline
    print(json.dumps({'synthetic_cases': len(cases), 'baseline_exact_set_pass': baseline,
                      'improved_exact_set_pass': improved, 'median_ms': statistics.median(latencies),
                      'p95_ms': sorted(latencies)[int(len(latencies) * .95)]}))


def test_named_conversation_never_uses_another_thread_history(memory):
    state = ai_agent._SessionState(conversation_history=[{'role': 'assistant', 'content': 'OTHER_THREAD_FACT'}])
    seed_references(memory, [DATA['items'][0]['item_id']], user='another')
    assert ai_agent._question_history(user_id='owner', conversation_id='conversation-a', supplied=None, state=state, message='Hello') == []
    assert ai_agent._question_history(user_id='owner', conversation_id='new-thread', supplied=None, state=state, message='Hello') == []
    memory.failure = True
    assert ai_agent._question_history(user_id='owner', conversation_id='conversation-a', supplied=None, state=state, message='Hello') == []


def test_existing_http_sse_contract_persists_grounded_sources_and_rechecks_followups(http_api):
    from unittest.mock import AsyncMock
    client, db = http_api
    def ask(inventory, question, conversation=None, headers=None):
        response = client.post(f'/inventories/{inventory}/ai_command?stream=true',
                               json={'message': question, 'conversation_id': conversation}, headers=headers)
        assert response.status_code == 200, response.text
        events = [json.loads(line[6:]) for line in response.text.splitlines()
                  if line.startswith('data: {')]
        return next(event for event in events if event.get('type') == 'done')
    with patch('app.api.routes.ai.check_and_increment_chat'), \
         patch('app.api.routes.ai.fetch_user_memory', new=AsyncMock(return_value='')), \
         patch('app.api.routes.ai.fetch_similar_history', new=AsyncMock(return_value='')), \
         patch('app.api.routes.ai.extract_and_save_memory', new=AsyncMock()), \
         patch('app.api.routes.ai.log_query', new=AsyncMock()), \
         patch('app.api.routes.ai.save_conversation', new=AsyncMock()), \
         patch.object(ai_agent, '_get_chat_provider') as provider:
        first = ask(A, 'How many items do I own?')
        assert [row['id'] for row in first['answer_context']['rows']] == [A]
        assert '1 recorded units' in first['assistant_message']
        saved = [m for m in db.rows['messages'] if m.get('role') == 'assistant'][-1]
        assert saved['answer_context'] == first['answer_context']
        db.rows['items'][0]['quantity'] = 7
        followup = ask(A, 'How many of those?', first['conversation_id'])
        assert '7 recorded units' in followup['assistant_message']
        other = ask(B, 'How many items do I own?')
        assert [row['id'] for row in other['answer_context']['rows']] == [B]
        assert '1 recorded units' in other['assistant_message']
        shared = ask(TEAM_INV, 'How many items do I own?', headers={'x-test-actor': VIEWER})
        assert [row['id'] for row in shared['answer_context']['rows']] == [TEAM_INV]
        conversation = next(c for c in db.rows['conversations'] if c['id'] == shared['conversation_id'])
        assert conversation['user_id'] == VIEWER
        denied = client.post(f'/inventories/{FOREIGN}/ai_command?stream=true', json={'message': 'How many items?'})
        assert denied.status_code == 403
        denied_thread = client.post(f'/inventories/{B}/ai_command?stream=true',
                                    json={'message': 'Where is it?', 'conversation_id': first['conversation_id']})
        assert denied_thread.status_code == 404
    provider.assert_not_called()
    assert all(table != 'items' for table, _, _ in db.writes)


def test_literal_note_edit_uses_real_conditional_service_and_replay_receipt(memory):
    item = memory.rows['items'][4]
    args = {'item_id': item['item_id'], 'updates': {'notes': 'Inspected'}}
    trace = [{'tool': 'inventory_search', 'result': [deepcopy(item)]}]
    results = {}
    for _ in range(2):
        answer = ai_agent._guarded_tool_call(user_id='owner', tool_name='inventory_update_item',
                                            args=args, enabled=True, message='Change Red handle pliers notes to Inspected',
                                            trace=trace, results=results)
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
        stream, task = _authorized_stream(body()), _authorized_background(background)
        current_inventory.reset(token)
        assert await stream.__anext__() == 'first'
        await stream.aclose()
        assert current_inventory.get() is None
        await task()
        assert current_inventory.get() is None
        return observed
    assert asyncio.run(run()) == ['inventory-a', 'inventory-a']


@pytest.mark.parametrize('message',[
    'what items do I need in my database for this ftc season?',
    'What parts do we need for our build?',
    'What tools do I need for the workshop?',
    'What should we stock for the season?',
])
def test_planning_goes_to_existing_advice_path_instead_of_literal_item_search(memory,message):
    assert inventory_questions.is_planning_question(message)
    assert inventory_questions.answer_question(user_id='owner',message=message) is None
    assert ai_agent._should_enable_tools(message=message) is False

@pytest.mark.parametrize('message',['What items do I have in Garage?','How many batteries do I have?','Where is my soldering iron?'])
def test_planning_routing_preserves_grounded_lookup(memory,message):
    assert not inventory_questions.is_planning_question(message)
    assert inventory_questions.answer_question(user_id='owner',message=message) is not None


@pytest.mark.parametrize('mode', ['sync', 'stream'])
def test_first_purpose_question_browses_saved_items_without_requiring_purpose_in_name(memory, mode):
    message = 'what items do I have for ftc robotics'
    with patch.object(ai_agent, '_project_readiness_for_question', return_value=None), \
         patch.object(ai_agent, '_get_chat_provider') as provider:
        args = {'user_id': 'owner', 'message': message, 'first_name': None}
        result = ai_agent.run_ai_command(**args) if mode == 'sync' else list(ai_agent._iter_agent_streaming(**args))[-1]
    assert len(result['answer_context']['rows']) == 8
    assert 'M3 screw' in result['assistant_message']
    assert 'current inventory' in result['assistant_message']
    assert "haven't verified" in result['assistant_message']
    assert 'ftc robotics' in result['assistant_message']
    assert 'FOREIGN_SECRET' not in json.dumps(result)
    provider.assert_not_called()
    assert memory.writes == 0


def test_empty_selected_inventory_is_explained_on_first_question(memory):
    memory.rows['items'] = [row for row in memory.rows['items'] if row['inventory_id'] != 'inventory-a']
    result = inventory_questions.answer_question(user_id='owner', message='what items do I have for ftc robotics')
    assert 'current inventory has no saved items' in result['assistant_message']
    assert 'switch' in result['assistant_message'].lower()
    assert 'Capture' in result['assistant_message']
    assert not result['answer_context']['rows']
    assert 'FOREIGN_SECRET' not in json.dumps(result)


def test_purpose_does_not_erase_the_requested_item_or_location(memory):
    result = inventory_questions.answer_question(user_id='owner', message='What screws do I have for robotics?')
    assert [r['id'] for r in result['answer_context']['rows']] == [DATA['items'][5]['item_id']]
    result = inventory_questions.answer_question(user_id='owner', message='What items do I have in Garage shelf for robotics?')
    assert len(result['answer_context']['rows']) == 2
    assert all(r['location'] == 'Garage shelf' for r in result['answer_context']['rows'])


def test_no_match_explains_scope_and_next_step_without_claiming_inventory_empty(memory):
    result = inventory_questions.answer_question(user_id='owner', message='Where is my soldering iron?')
    assert 'soldering iron' in result['assistant_message']
    assert 'current inventory' in result['assistant_message']
    assert 'no saved items' not in result['assistant_message']
    assert 'name' in result['assistant_message']
    assert not result['answer_context']['rows']


@pytest.mark.parametrize('message', [
    'What parts do I have for FTC robotics?',
    'Which equipment do we have for the workshop?',
    'Show my inventory for a new build',
    'What items do I have for this FTC season?',
])
def test_generic_purpose_browse_keeps_current_scope(memory, message):
    result = inventory_questions.answer_question(user_id='owner', message=message)
    assert len(result['answer_context']['rows']) == 8
    assert "haven't verified" in result['assistant_message']
    assert 'FOREIGN_SECRET' not in json.dumps(result)


def test_exact_identifier_search_is_not_broadened_into_purpose_browse(memory):
    question = inventory_questions.interpret('Find part number A-101 for robotics')
    assert not question.purpose
    result = inventory_questions.answer_question(user_id='owner', message='Find part number A-101')
    assert not result['answer_context']['rows']
    assert 'A-100' not in result['assistant_message']


def test_purpose_browse_is_bounded_and_discloses_partial_results(memory):
    memory.rows['items'] = [{**DATA['items'][0], 'item_id': f'row-{n}'} for n in range(510)]
    result = inventory_questions.answer_question(user_id='owner', message='What items do I have for robotics?')
    assert result['capability_state'] == 'incomplete'
    assert result['answer_context']['rows_truncated']
    assert len(result['answer_context']['rows']) == 100
    assert 'partial' in result['assistant_message']
    assert '500 saved item records' in result['assistant_message']
    assert max(limit for _, _, limit in memory.reads) <= 501


def test_purpose_overview_uses_saved_categories_and_varied_examples(memory):
    memory.rows['items'] += [
        {**DATA['items'][5], 'item_id': f'variant-{n}', 'name': f'M{n} screw'}
        for n in range(4, 30)
    ]
    result = inventory_questions.answer_question(user_id='owner', message='What items do I have for robotics?')
    answer = result['assistant_message']
    assert '- **Electronics**: 3 saved records.' in answer
    assert '- **Hardware**: 27 saved records.' in answer
    assert '- **Tools**: 2 saved records.' in answer
    assert len(answer) < 1200
    assert '4242' not in answer and '999' not in answer
    direct = inventory_questions.answer_question(user_id='owner', message='Find HDMI adapter')
    assert direct['assistant_message'].startswith('- HDMI adapter:')


def test_failed_empty_inventory_probe_does_not_claim_absence(memory):
    with patch.object(inventory_questions, 'search_memory_candidates', side_effect=[
        {'items': [], 'truncated': False}, RuntimeError('PRIVATE DETAIL')
    ]):
        result = inventory_questions.answer_question(user_id='owner', message='Where is my soldering iron?')
    assert result['capability_state'] == 'unavailable'
    assert 'could not verify' in result['assistant_message']
    assert 'PRIVATE DETAIL' not in json.dumps(result)


def test_first_purpose_question_has_same_authorization_in_http_sse(http_api):
    from unittest.mock import AsyncMock
    client, db = http_api
    with patch('app.api.routes.ai.check_and_increment_chat'), \
         patch('app.api.routes.ai.fetch_user_memory', new=AsyncMock(return_value='')), \
         patch('app.api.routes.ai.fetch_similar_history', new=AsyncMock(return_value='')), \
         patch('app.api.routes.ai.extract_and_save_memory', new=AsyncMock()), \
         patch('app.api.routes.ai.log_query', new=AsyncMock()), \
         patch('app.api.routes.ai.save_conversation', new=AsyncMock()), \
         patch.object(ai_agent, '_get_chat_provider') as provider:
        response = client.post(f'/inventories/{TEAM_INV}/ai_command?stream=true',
                               json={'message': 'what items do I have for ftc robotics'},
                               headers={'x-test-actor': VIEWER})
    assert response.status_code == 200
    events = [json.loads(line[6:]) for line in response.text.splitlines() if line.startswith('data: {')]
    done = next(e for e in events if e.get('type') == 'done')
    assert [row['id'] for row in done['answer_context']['rows']] == [TEAM_INV]
    assert 'current inventory' in done['assistant_message']
    assert "haven't verified" in done['assistant_message']
    provider.assert_not_called()
    assert all(table != 'items' for table, _, _ in db.writes)

@pytest.mark.parametrize('mode',['sync','stream'])
def test_season_planning_reaches_gateway_with_current_context_and_honest_requirements(memory,mode):
    create=Mock(return_value=SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content='Which build or game requirements should we plan for?',tool_calls=[]))]))
    provider=ai_agent._ChatProvider(client=SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=create))),model='unchanged-model',conversation_id='planning-fixture',timezone='UTC')
    context={'inventory_count':1,'inventory_preview':[{'name':'Synthetic fixture motor','quantity':2,'location':'Fixture cabinet'}]}
    with patch.object(ai_agent,'_project_readiness_for_question',return_value=None),patch.object(ai_agent,'_get_chat_provider',return_value=provider),patch.object(ai_agent,'_load_context',return_value=context),patch.object(ai_agent,'_get_state',return_value=ai_agent._SessionState()),patch.object(ai_agent,'_question_history',return_value=[]),patch.object(ai_agent,'_requires_inventory_knowledge',return_value=False),patch.object(ai_agent,'_persist_state'),patch.object(ai_agent,'_update_memory_from_trace'):
        args={'user_id':'owner','message':'what items do I need in my database for this ftc season?','first_name':None}
        result=ai_agent.run_ai_command(**args) if mode=='sync' else list(ai_agent._iter_agent_streaming(**args))[-1]
    assert 'Which build or game' in result['assistant_message']
    kwargs=create.call_args.kwargs
    assert kwargs['model']=='unchanged-model' and 'tools' not in kwargs
    assert 'Synthetic fixture motor' in kwargs['messages'][1]['content']
    assert 'explicit project requirement list' in kwargs['messages'][0]['content']
    assert 'Previous assistant replies' in kwargs['messages'][0]['content']
