import json
from pathlib import Path
from collections import defaultdict
from copy import deepcopy
from types import SimpleNamespace
from unittest.mock import patch, Mock
import pytest
from app.services import memory_context, ai_agent, inventory_query
from app.services.inventory_scope import current_inventory, InventoryScope
from backend.tests.test_physical_memory_questions import Query
from backend.tests.test_ask_photo_questions import route_io
A = '10000000-0000-0000-0000-000000000001'
B = '10000000-0000-0000-0000-000000000002'
INV = '20000000-0000-0000-0000-000000000001'
SPACE = '30000000-0000-0000-0000-000000000001'
CASES = json.loads((Path(__file__).parent / 'fixtures/account_memory_cases.json').read_text())

@pytest.fixture
def db(monkeypatch):
    db = SimpleNamespace(rows=defaultdict(list), reads=[], writes=0, failure=False, before_write=None)
    db.table = lambda table: Query(db, table)
    monkeypatch.setattr(memory_context, 'get_supabase_raw', lambda: db)
    monkeypatch.setattr('app.services.supabase_client.get_supabase_raw', lambda: db)
    token = current_inventory.set(InventoryScope(INV, A, B, None, 'viewer'))
    yield db
    current_inventory.reset(token)

def seed(db, *, enabled=True, layout='bullets', length='brief', owner=A, kind='preference', confirmed=True):
    db.rows['user_memory'] = [{'user_id': owner, 'key': '__settings_v1', 'memory_kind': 'settings', 'payload': {'enabled': enabled}}, {'user_id': owner, 'key': 'answer_format', 'memory_kind': kind, 'payload': {'value': layout}, 'confirmed_at': '2026-10-16' if confirmed else None}, {'user_id': owner, 'key': 'answer_length', 'memory_kind': kind, 'payload': {'value': length}, 'confirmed_at': '2026-10-16' if confirmed else None}]

@pytest.mark.parametrize('case', CASES, ids=lambda c: c['id'])
def test_explicit_memory_evaluation(case, db):
    seed(db, enabled=case['enabled'], layout=case.get('format'), length=case.get('length'), kind=case.get('kind', 'preference'), confirmed=case.get('confirmed', True), owner=B if case.get('foreign') else A)
    preferences = memory_context.load_preferences(B)
    answer = {'assistant_message': 'Saved motor: 4 units in Cabinet. Quantity unknown for the spare. Not physically confirmed.', 'answer_context': {'rows': [{'id': 'motor', 'quantity': 4, 'location': 'Cabinet'}]}}
    output = memory_context.personalize(answer, preferences)
    assert output['assistant_message'].startswith(case['expected_prefix'])
    for fact in ['4 units', 'Cabinet', 'Quantity unknown', 'Not physically confirmed']:
        assert fact in output['assistant_message']
    assert ('live inspection' in output['assistant_message']) == case.get('detail', False)
    assert output['answer_context'] == answer['answer_context']
    assert db.writes == 0

def test_new_session_refetches_corrections_and_disable_without_cache(db):
    seed(db)
    assert memory_context.load_preferences(B)['answer_format'] == 'bullets'
    db.rows['user_memory'][1]['payload']['value'] = 'paragraphs'
    assert memory_context.load_preferences(B)['answer_format'] == 'paragraphs'
    db.rows['user_memory'][0]['payload']['enabled'] = False
    assert memory_context.load_preferences(B) == {}
    db.failure = True
    assert memory_context.load_preferences(B) == {}

@pytest.mark.parametrize('mode', ['sync', 'stream'])
def test_gateway_receives_only_allowlisted_style_in_both_paths(db, mode):
    seed(db)
    create = Mock(return_value=SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content='No saved evidence.', tool_calls=[]))]))
    provider = ai_agent._ChatProvider(client=SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=create))), model='unchanged-model', conversation_id='new', timezone='UTC')
    with patch.object(ai_agent, '_get_chat_provider', return_value=provider), patch.object(ai_agent, '_load_context', return_value={}), patch.object(ai_agent, '_get_state', return_value=ai_agent._SessionState()), patch.object(ai_agent, '_question_history', return_value=[]), patch.object(ai_agent, '_persist_state'), patch.object(ai_agent, '_update_memory_from_trace'):
        kwargs = {'user_id': B, 'message': 'Explain the saved evidence', 'first_name': None}
        result = ai_agent.run_ai_command(**kwargs) if mode == 'sync' else list(ai_agent._iter_agent_streaming(**kwargs))[-1]
    assert result['assistant_message'] == 'No saved evidence.'
    assert 'Use a bullet list' in create.call_args.kwargs['messages'][0]['content']
    assert create.call_args.kwargs['model'] == 'unchanged-model'

def test_alias_retrieval_uses_authorized_space_id_not_fuzzy_name(db):
    seed(db)
    db.rows['inventory_user_memory'] = [{'user_id': A, 'inventory_id': INV, 'memory_kind': 'alias', 'confirmed_at': 'now', 'payload': {'alias': 'bench', 'space_id': SPACE}}, {'user_id': B, 'inventory_id': INV, 'memory_kind': 'alias', 'confirmed_at': 'now', 'payload': {'alias': 'bench', 'space_id': 'FOREIGN'}}]
    db.rows['spaces'] = [{'id': SPACE, 'inventory_id': INV, 'name': 'Cabinet 2'}]
    db.rows['items'] = [{'item_id': 'mine', 'inventory_id': INV, 'name': 'Motor', 'quantity': 4, 'space_id': SPACE, 'location': 'Cabinet 2'}, {'item_id': 'wrong-space', 'inventory_id': INV, 'name': 'Motor', 'quantity': 99, 'space_id': 'elsewhere', 'location': 'bench'}, {'item_id': 'foreign', 'inventory_id': 'OTHER', 'name': 'FOREIGN_SECRET', 'quantity': 900, 'space_id': SPACE}]
    prefs = memory_context.load_preferences(B)
    answer = inventory_query.query_inventory(user_id=B, terms=[], filters={'space_id': prefs['aliases'][0]['space_id']})
    assert [row['item_id'] for row in answer['items']] == ['mine']
    assert answer['items'][0]['location'] == 'Cabinet 2' and 'FOREIGN_SECRET' not in str(answer)
    db.rows['spaces'] = []
    answer = inventory_query.query_inventory(user_id=B, terms=[], filters={'space_id': prefs['aliases'][0]['space_id']})
    assert answer['error'] == 'space_unavailable' and answer['complete'] is False

def test_old_background_tasks_do_not_duplicate_private_conversations():
    import asyncio
    from app.services.ai_memory import save_conversation, extract_and_save_memory, fetch_similar_history
    with patch('app.services.supabase_client.create_supabase_admin') as database, patch('app.services.agent_gateway_client.AgentGatewayClient') as gateway:
        asyncio.run(save_conversation(A, 'PRIVATE_QUESTION', 'PRIVATE_ANSWER'))
        asyncio.run(extract_and_save_memory(A, 'PRIVATE_QUESTION', 'PRIVATE_ANSWER'))
        assert asyncio.run(fetch_similar_history(A, 'PRIVATE_QUESTION')) == ''
    database.assert_not_called()
    gateway.assert_not_called()

def test_query_signal_omits_content_and_does_not_retry_unknown_inserts():
    import asyncio
    import httpx
    from app.services.ai_memory import log_query
    query = Mock()
    query.insert.return_value = query
    db = Mock()
    db.table.return_value = query
    with patch('app.services.supabase_client.create_supabase_admin', return_value=db):
        asyncio.run(log_query(A, 'Where is PRIVATE_OBJECT?'))
        assert query.insert.call_args.args[0]['query_text'] == '[content omitted]'
        assert query.insert.call_args.args[0]['query_type'] == 'location_lookup'
        query.execute.side_effect = httpx.ReadError('Unknown outcome')
        asyncio.run(log_query(A, 'PRIVATE_OBJECT'))
        assert query.insert.call_count == 2
