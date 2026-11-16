from types import SimpleNamespace as NS
from unittest.mock import Mock
import json
import pytest
from fastapi import HTTPException
from app.services.cad import search as ai

GRANT = {'actor_id': 'actor', 'inventory_id': 'inventory', 'inventory_name': 'Lab'}


def row(key='bearing', name='8mm bearing', available=3):
    return {'item_id': key, 'name': name, 'part_number': '', 'brand': '', 'available': available,
            'on_hand': 8, 'reserved': 3, 'checked_out': 2, 'availability_known': True}


@pytest.fixture
def setup(monkeypatch):
    authorize = Mock(); monkeypatch.setattr(ai.workspace, '_inventory', authorize)
    records = Mock(return_value=([row(), row('other', '12mm bearing'), row('motor', 'Motor')], []))
    monkeypatch.setattr(ai.workspace, 'inventory_rows', records)
    gateway = Mock(return_value=NS(choices=[NS(message=NS(content=json.dumps({
        'terms': ['bearing'], 'constraints': ['8mm'], 'required_quantity': 5}))) ]))
    monkeypatch.setattr(ai, 'gateway_completion', gateway)
    return authorize, records, gateway


def test_ai_retrieves_real_scoped_rows_and_computes_shortage(setup):
    authorize, records, gateway = setup
    result = ai.search(GRANT, ai.SearchRequest(query='Find 5 bearings for an 8mm shaft', location='Bin A'))
    records.assert_called_once_with(GRANT, location='Bin A')
    assert [r['item_id'] for r in result['items']] == ['bearing', 'other']
    assert result['items'][0]['shortage_for_request'] == 2
    assert result['items'][0]['available'] == 3
    assert result['items'][1]['search_evidence']['unverified_constraints'] == ['8mm']
    assert all(r['search_evidence']['compatibility'] == 'needs_review' for r in result['items'])
    assert authorize.call_count == 2
    request = gateway.call_args.kwargs
    assert request['conversation_id'].startswith('fusion-search-')
    assert 'test-only-token' not in str(request)
    assert 'items' not in request['messages'][1]['content']


def test_revoked_access_never_publishes_ai_results(setup):
    authorize, _, _ = setup
    authorize.side_effect = [None, HTTPException(403, 'Revoked')]
    with pytest.raises(HTTPException) as exc:
        ai.search(GRANT, ai.SearchRequest(query='bearings'))
    assert exc.value.status_code == 403


def test_bad_model_output_does_not_invent_inventory_or_echo_private_errors(setup):
    _, _, gateway = setup
    gateway.return_value.choices[0].message.content = '{"items":[{"name":"Invented","available":999}]}'
    with pytest.raises(HTTPException) as exc:
        ai.search(GRANT, ai.SearchRequest(query='bearings'))
    assert exc.value.status_code == 503
    assert 'Invented' not in exc.value.detail


def test_catalog_results_are_not_owned_inventory(setup, monkeypatch):
    _, records, _ = setup
    catalog = Mock(return_value={'parts': [{'catalog_id': 'public', 'canonical_name': '8mm bearing', 'specifications': {}}], 'next_offset': None})
    monkeypatch.setattr(ai.workspace, 'catalog', catalog)
    result = ai.search(GRANT, ai.SearchRequest(query='Find 5 bearings', source='catalog'))
    records.assert_not_called()
    assert result['items'] == [] and len(result['parts']) == 1
    assert result['parts'][0]['shortage_for_request'] is None
    assert 'available' not in result['parts'][0]
    assert {call.args[2] for call in catalog.call_args_list} == {'canonical_name', 'part_number', 'brand'}


def test_empty_query_never_calls_model(setup):
    _, _, gateway = setup
    with pytest.raises(HTTPException): ai.search(GRANT, ai.SearchRequest(query='   '))
    gateway.assert_not_called()


def test_unknown_stock_does_not_claim_a_shortage(setup):
    _, records, _ = setup
    records.return_value = ([{**row(), 'availability_known': False}], [])
    result = ai.search(GRANT, ai.SearchRequest(query='Find 5 bearings'))
    assert result['items'][0]['shortage_for_request'] is None


def test_model_cannot_invent_a_requested_quantity_from_a_dimension(setup):
    _, _, gateway = setup
    gateway.return_value.choices[0].message.content=json.dumps({'terms':['bearing'],'constraints':['8 mm'],'required_quantity':8})
    result=ai.search(GRANT,ai.SearchRequest(query='Find bearings for an 8 mm shaft'))
    assert result['interpreted']['required_quantity'] is None
    assert result['items'][0]['shortage_for_request'] is None
    assert result['items'][0]['search_evidence']['recorded_constraints']==['8mm']
