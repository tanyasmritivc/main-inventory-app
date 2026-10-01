import json
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

from app.api.routes import ai, conversations
from app.core.auth import AuthenticatedUser, get_current_user
from app.services import ai_agent, project_kits_service
from app.services.ask_presentation import answer_context_from_reads, project_answer_context, project_answer_text


def _project():
    return {'id': 'kit-1', 'name': 'Loft shelving', 'location': 'Garage', 'items': [
        {'id': 'a', 'name': 'Masonry bit', 'required_quantity': 1, 'available_quantity': 0},
        {'id': 'b', 'name': 'Shelf pin', 'required_quantity': 24, 'available_quantity': 0},
        {'id': 'c', 'name': 'Hex bolt', 'required_quantity': 40, 'available_quantity': 14},
        {'id': 'd', 'name': 'Steel bracket', 'required_quantity': 8, 'available_quantity': 8},
    ]}


def test_project_badges_and_text_use_real_quantities_not_units_as_part_counts():
    detail = _project()
    public = project_answer_context(detail)
    assert [row['status'] for row in public['rows']] == ['missing', 'missing', 'low', 'have']
    assert public['rows'][2]['available_quantity'] == 14
    assert public['rows'][2]['required_quantity'] == 40
    assert '1 of the 4 required parts' in project_answer_text(detail)
    assert 'Hex bolt: 14 of 40 available' in project_answer_text(detail)
    assert len(public['sources']) == 2


def test_empty_project_does_not_claim_that_it_is_ready():
    assert 'no requirements' in project_answer_text({'items': []})
    assert project_answer_context({'items': []})['rows'] == []


def test_public_context_does_not_expose_tool_arguments_errors_or_private_fields():
    result = answer_context_from_reads({}, [
        {'tool': 'inventory_search', 'args': {'api_key': 'SECRET'}, 'result': [
            {'item_id': 'a', 'name': 'Drill', 'quantity': 2, 'location': 'Garage', 'user_id': 'private-owner', 'internal_model': 'INTERNAL'},
        ]},
        {'tool': 'failed_tool', 'result': {'error': 'SECRET internal failure'}},
    ])
    encoded = json.dumps(result)
    assert 'SECRET' not in encoded and 'INTERNAL' not in encoded and 'private-owner' not in encoded
    assert 'args' not in encoded and 'tool_trace' not in encoded
    assert result['rows'][0]['available_quantity'] == 2
    assert 'required_quantity' not in result['rows'][0]
    assert 'status' not in result['rows'][0]


def test_context_records_only_supplied_previews_and_deduplicates_actual_item_reads():
    item = {'item_id': 'a', 'name': 'Drill', 'quantity': 1}
    context = {'inventory_preview': [item], 'inventory_count': 5000, 'documents_preview': [{'filename': 'Manual.pdf', 'extracted_text': 'SECRET'}]}
    result = answer_context_from_reads(context, [{'tool': 'inventory_search', 'result': [item, item]}])
    assert len(result['rows']) == 1
    assert '5000' not in json.dumps(result)
    assert 'SECRET' not in json.dumps(result)
    assert any(source['label'] == 'Manual.pdf' for source in result['sources'])


def test_large_results_are_bounded_and_explicitly_marked():
    result = answer_context_from_reads({}, [{'tool': 'inventory_search', 'result': [
        {'item_id': str(i), 'name': 'Bolt', 'quantity': 1} for i in range(101)
    ]}])
    assert len(result['rows']) == 100 and result['rows_truncated'] is True


def test_project_question_resolves_exact_named_authorized_kit():
    with patch.object(ai_agent, '_inventory_knowledge', return_value={'project_kits': [
        {'name': 'Loft shelving', 'project_kit_id': 'kit-1'},
        {'name': 'Robot', 'project_kit_id': 'kit-2'},
    ]}) as knowledge, patch.object(ai_agent, 'get_project_readiness', return_value=_project()) as read:
        result = ai_agent._project_readiness_for_question(user_id='user-1', message='What do I still need to finish the loft shelving?')
    knowledge.assert_called_once_with(user_id='user-1', query='')
    read.assert_called_once_with(kit_id='kit-1', user_id='user-1')
    assert result['id'] == 'kit-1'


def test_ambiguous_projects_ask_for_clarification_without_stock_claims():
    with patch.object(ai_agent, '_inventory_knowledge', return_value={'project_kits': [
        {'name': 'Robot', 'project_kit_id': 'kit-1'}, {'name': 'Shelving', 'project_kit_id': 'kit-2'},
    ]}), patch.object(ai_agent, 'get_project_readiness') as read:
        result = ai_agent._project_readiness_for_question(user_id='user-1', message='What do I need for my project?')
    assert 'Which project' in result['_clarification']
    read.assert_not_called()


def test_unmatched_project_is_not_substituted_with_a_different_only_project():
    with patch.object(ai_agent, '_inventory_knowledge', return_value={'project_kits': [{'name': 'Robot', 'project_kit_id': 'kit-1'}]}):
        result = ai_agent._project_readiness_for_question(user_id='user-1', message='What do I need for my shelving project?')
    assert 'could not find' in result['_clarification']


@pytest.mark.parametrize('message', ['Add the missing screws', 'Please add missing screws to my project', 'Delete my finished project', 'Hello'])
def test_project_preflight_does_not_intercept_mutations_or_general_chat(message):
    with patch.object(ai_agent, '_inventory_knowledge') as knowledge:
        assert ai_agent._project_readiness_for_question(user_id='user-1', message=message) is None
    knowledge.assert_not_called()


def test_project_answer_stream_uses_same_public_snapshot_without_calling_gateway():
    with patch.object(ai_agent, '_project_readiness_for_question', return_value=_project()), \
         patch.object(ai_agent, '_get_state', return_value=ai_agent._SessionState()), \
         patch.object(ai_agent, '_persist_state'), patch.object(ai_agent, '_get_chat_provider') as gateway:
        events = list(ai_agent._iter_agent_streaming(user_id='user-1', message='What do I need to finish loft shelving?', first_name=None))
    gateway.assert_not_called()
    assert events[0]['type'] == 'delta'
    assert events[-1]['answer_context']['rows'][2]['status'] == 'low'
    assert events[-1]['nav_hint']['id'] == 'kit-1'


def _query(data):
    query = MagicMock()
    for name in ('select', 'eq', 'limit', 'range', 'order', 'insert', 'update'):
        getattr(query, name).return_value = query
    query.execute.return_value = SimpleNamespace(data=data)
    return query


def test_project_read_rejects_foreign_personal_kit_before_reading_inventory():
    client = MagicMock()
    client.table.return_value = _query([{'id': 'kit-1', 'created_by_user_id': 'other-user', 'share_id': None}])
    with patch.object(project_kits_service, 'get_supabase_admin', return_value=client), \
         patch.object(project_kits_service, '_analyze') as analyze:
        with pytest.raises(HTTPException) as exc:
            project_kits_service.get_project_readiness(kit_id='kit-1', user_id='user-1')
    assert exc.value.status_code == 403
    analyze.assert_not_called()


def test_revoked_shared_project_access_is_rechecked_before_stock_read():
    client = MagicMock()
    client.table.return_value = _query([{'id': 'kit-1', 'share_id': 'share-1', 'owner_user_id': 'other', 'location': 'Garage'}])
    with patch.object(project_kits_service, 'get_supabase_admin', return_value=client), \
         patch('app.services.sharing_service.get_share_access', side_effect=ValueError('Access revoked')), \
         patch.object(project_kits_service, '_analyze') as analyze:
        with pytest.raises(HTTPException):
            project_kits_service.get_project_readiness(kit_id='kit-1', user_id='user-1')
    analyze.assert_not_called()


def test_project_readiness_deducts_other_reservations_and_ignores_other_locations():
    with patch.object(project_kits_service, 'list_items', return_value=[
        {'item_id': 'a', 'name': 'Bolt', 'part_number': 'M4', 'quantity': 20, 'location': 'Garage'},
        {'item_id': 'b', 'name': 'Bolt', 'part_number': 'M4', 'quantity': 100, 'location': 'Other'},
        {'item_id': 'c', 'name': 'Bolt', 'part_number': 'M5', 'quantity': 100, 'location': 'Garage'},
    ]), patch.object(project_kits_service, '_list_reservations', return_value=[
        {'kit_id': 'other', 'kit_item_id': 'other-line', 'inventory_item_id': 'a', 'quantity': 6},
        {'kit_id': 'kit-1', 'kit_item_id': 'line-1', 'inventory_item_id': 'a', 'quantity': 4},
    ]):
        result = project_kits_service._analyze(rows=[{'id': 'line-1', 'name': 'Bolt', 'part_number': 'M4', 'required_quantity': 40}], owner_user_id='user-1', location='Garage', kit_id='kit-1')
    assert result['items'][0]['available_quantity'] == 14
    assert result['items'][0]['missing_quantity'] == 26


def test_duplicate_project_requirements_do_not_double_count_the_same_stock():
    with patch.object(project_kits_service, 'list_items', return_value=[
        {'item_id': 'a', 'name': 'Bolt', 'quantity': 4, 'location': 'Garage'},
    ]), patch.object(project_kits_service, '_list_reservations', return_value=[]):
        result = project_kits_service._analyze(rows=[
            {'id': 'line-1', 'name': 'Bolt', 'required_quantity': 4},
            {'id': 'line-2', 'name': 'Bolt', 'required_quantity': 4},
        ], owner_user_id='user-1', location='Garage', kit_id='kit-1')
    assert [row['available_quantity'] for row in result['items']] == [4, 0]
    assert result['summary']['ready_lines'] == 1


def test_stock_reduction_cannot_leave_a_phantom_available_reservation():
    with patch.object(project_kits_service, 'list_items', return_value=[
        {'item_id': 'a', 'name': 'Bolt', 'quantity': 0, 'location': 'Garage'},
    ]), patch.object(project_kits_service, '_list_reservations', return_value=[
        {'kit_id': 'kit-1', 'kit_item_id': 'line-1', 'inventory_item_id': 'a', 'quantity': 4},
    ]):
        result = project_kits_service._analyze(rows=[{'id': 'line-1', 'name': 'Bolt', 'required_quantity': 4}], owner_user_id='user-1', location='Garage', kit_id='kit-1')
    assert result['items'][0]['available_quantity'] == 0
    assert result['items'][0]['status'] == 'missing'


def _api_client():
    app = FastAPI()
    app.include_router(ai.router)
    app.include_router(conversations.router)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(user_id='user-1')
    return TestClient(app)


@pytest.fixture
def stub_ai_io():
    client = MagicMock()
    client.table.return_value = _query([{'id': 'conversation-1'}])
    with patch.object(ai, 'get_supabase_admin', return_value=client), \
         patch.object(ai, 'check_and_increment_chat'), \
         patch.object(ai, 'fetch_user_memory', new=AsyncMock(return_value='')), \
         patch.object(ai, 'fetch_similar_history', new=AsyncMock(return_value='')), \
         patch.object(ai, 'extract_and_save_memory', new=AsyncMock()), \
         patch.object(ai, 'log_query', new=AsyncMock()), \
         patch.object(ai, 'save_conversation', new=AsyncMock()):
        yield client


def test_public_sse_preserves_context_and_conversation_without_raw_trace(stub_ai_io):
    context = project_answer_context(_project())
    async def events(**kwargs):
        assert kwargs['user_id'] == 'user-1'
        yield {'type': 'delta', 'delta': 'Grounded answer'}
        yield {'type': 'done', 'answer_context': context, 'result': {'tool_trace': [{'secret': 'SECRET'}]}, 'assistant_message': 'Grounded answer'}
    with patch.object(ai, 'iter_ai_command_events_async', new=events):
        response = _api_client().post('/ai_command?stream=true', json={'message': 'Question'})
    assert response.status_code == 200
    assert 'SECRET' not in response.text and 'tool_trace' not in response.text
    assert 'answer_context' in response.text and 'conversation-1' in response.text
    saved = [call.args[0] for call in stub_ai_io.table.return_value.insert.call_args_list]
    assert any(row.get('answer_context') == context for row in saved)


def test_sse_internal_exception_is_not_exposed(stub_ai_io):
    async def events(**kwargs):
        raise RuntimeError('SECRET upstream provider stack trace')
        yield  # pragma: no cover
    with patch.object(ai, 'iter_ai_command_events_async', new=events):
        response = _api_client().post('/ai_command?stream=true', json={'message': 'Question'})
    assert 'SECRET' not in response.text
    assert 'temporarily unavailable' in response.text


def test_conversation_read_denies_other_user_before_loading_context():
    client = MagicMock()
    client.table.return_value = _query([])
    with patch.object(conversations, 'get_supabase_admin', return_value=client):
        response = _api_client().get('/conversations/foreign')
    assert response.status_code == 404
    assert client.table.call_args_list[0].args == ('conversations',)
    assert client.table.call_count == 1
