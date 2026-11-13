from contextlib import contextmanager
from unittest.mock import Mock, patch
from uuid import uuid4

import pytest
from fastapi import HTTPException
from app.services import world_chat as w, world_imports as imports
from app.services.inventory_scope import current_inventory

ACTOR, OWNER, WORLD, INV = [str(uuid4()) for _ in range(4)]


def item(order='0012', status='CANCELLED', **extra):
    return {'item_id': str(uuid4()), 'name': 'Tool', 'quantity': 0, 'location': 'Cabinet',
            'import_data': {'filename': 'orders.xlsx', 'sheet': 'Orders', 'fields': [
                {'name': 'Order #', 'value': order}, {'name': 'Order status', 'value': status},
                {'name': 'Returned', 'value': ''}, {'name': 'Qty', 'value': '2'},
                *[{'name': name, 'value': value} for name, value in extra.items()]]}}


@contextmanager
def database(rows, world=WORLD):
    inv = {'inventory_id': INV, 'owner_user_id': OWNER, 'name': 'Haas', 'role': 'viewer',
           'can_edit': False, 'workspace': {'name': 'Personal', 'organization_id': world}}
    request = Mock()
    for method in ('select', 'eq', 'order'):
        getattr(request, method).return_value = request
    def page(start, end):
        assert current_inventory.get().inventory_id == INV
        assert current_inventory.get().actor_id == ACTOR
        request.execute.return_value.data = rows[start:end + 1]
        return request
    request.range.side_effect = page
    db = Mock(); db.table.return_value = request
    with patch.object(w, 'authorize'), patch.object(w, '_inventory', return_value=inv), patch.object(w, 'directory', return_value={'inventories': [inv]}), patch('app.services.supabase_client.get_supabase_admin', return_value=db):
        yield db, request
    assert current_inventory.get() is None


def run(**kwargs):
    return w.execute(ACTOR, WORLD, 'world_imports', kwargs)


def test_counts_all_rows_not_preview_and_distinct_orders_not_items():
    rows = [item('0012'), item('0012'), item('0013'), item('', 'CANCELLED'), *[item(str(n), 'DELIVERED') for n in range(700)]]
    with database(rows) as (_, request):
        result = run(filters=[{'field': 'Order status', 'value': 'cancelled'}], distinct_field='Order #')
    assert result['record_count'] == 4
    assert result['distinct_count'] == 2
    assert result['records_missing_distinct_value'] == 1
    assert result['complete'] is True
    assert result['imported_record_count'] == 704
    assert request.range.call_count == 2
    assert ('user_id', OWNER) in [c.args for c in request.eq.call_args_list]


def test_original_fields_survive_provider_sanitizer_and_keep_quantity_separate():
    with database([item(**{'Color': 'red', 'Price': '12.95'})]):
        result = w.model_data(run(item_id=str(uuid4())))
    fields = {f['name']: f['value'] for f in result['items'][0]['fields']}
    assert fields['Order #'] == '0012'
    assert fields['Order status'] == 'CANCELLED'
    assert fields['Qty'] == '2' and fields['Price'] == '12.95'
    assert result['items'][0]['quantity'] == 0
    assert 'original' in result['items'][0]['quantity_basis']


def test_status_groups_and_record_paging():
    rows = [item(str(n), 'DELIVERED' if n < 600 else 'CANCELLED') for n in range(750)]
    with database(rows):
        result = run(group_by='Order status', offset=745)
    assert result['record_count'] == 750
    assert result['complete'] and result['rows_truncated']
    assert result['groups'] == [{'value': 'cancelled', 'record_count': 150}, {'value': 'delivered', 'record_count': 600}]
    assert len(result['items']) == 5 and result['next_offset'] is None


def test_missing_and_unknown_fields_are_not_zero_evidence():
    missing = item(); missing['import_data']['fields'] = [{'name': 'Product', 'value': 'Tool'}]
    with database([item(), missing]):
        result = run(filters=[{'field': 'Order status', 'value': 'cancelled'}])
        unknown = run(filters=[{'field': 'Imaginary', 'value': 'cancelled'}])
    assert result['record_count'] == 1 and result['records_missing_filter_fields'] == 1
    assert unknown['error'] and unknown['record_count'] is None


def test_duplicate_headers_are_reported_instead_of_silently_choosing():
    row = item(); row['import_data']['fields'].append({'name': 'Order status', 'value': 'DELIVERED'})
    with database([row]):
        result = run(filters=[{'field': 'Order status', 'value': 'cancelled'}])
    assert result['ambiguous_fields'] == ['Order status'] and result['record_count'] is None


def test_foreign_inventory_rejected_before_read():
    with database([item()], world='foreign') as (db, _):
        with pytest.raises(HTTPException) as error:
            run(inventory_id=INV)
    assert error.value.status_code == 403
    db.table.assert_not_called()


def test_scan_cap_never_claims_complete_or_zero_for_unseen_records():
    with database([item()] * 10001):
        result = run(filters=[{'field': 'Order status', 'value': 'DELIVERED'}])
    assert result['complete'] is False and result['scanned_item_count'] == 10000


def test_wide_source_fields_can_be_paged_without_losing_columns():
    row = item(**{f'Extra {n}': str(n) for n in range(60)})
    with database([row]):
        result = run(field_offset=40)
    assert result['items'][0]['next_field_offset'] == 60
    assert result['items'][0]['fields'][0] == {'column': 41, 'name': 'Extra 36', 'value': '36'}


@pytest.mark.parametrize('op,value,expected', [('equals', 'cancelled', True), ('equals', 'cancel', False), ('contains', 'cancel', True), ('above', '1', False)])
def test_explicit_source_value_comparison(op, value, expected):
    assert imports.matches('CANCELLED', imports.SourceFilter(field='Status', op=op, value=value)) is expected


def test_registered_read_only_tool_with_resolved_schema():
    from app.services.assistant_tool_safety import READ_TOOLS
    assert 'world_imports' in READ_TOOLS
    schema = next(t for t in w.TOOLS if t['function']['name'] == 'world_imports')
    assert '$ref' not in str(schema)


def test_groups_count_distinct_orders_and_unknown_numeric_values():
    rows = [item('0012'), item('0012'), item('0013', 'DELIVERED')]
    rows[-1]['import_data']['fields'][-1]['value'] = 'unknown'
    with database(rows):
        result = run(group_by='Order status', distinct_field='Order #')
        numeric = run(filters=[{'field': 'Qty', 'op': 'above', 'value': '1'}])
    assert result['groups'][0] == {'value': 'cancelled', 'record_count': 2, 'distinct_count': 1}
    assert numeric['record_count'] == 2 and numeric['records_unusable_numeric_fields'] == 1


def test_invalid_numeric_boundary_rejected_before_io():
    with database([]) as (db, _):
        with pytest.raises(ValueError):
            run(filters=[{'field': 'Qty', 'op': 'above', 'value': 'NaN'}])
    db.table.assert_not_called()


def test_aggregate_evidence_precedes_large_source_schema():
    row = item(**{f'column {n} ' + 'x' * 150: str(n) for n in range(100)})
    with database([row] * 6):
        result = w.model_data(run(distinct_field='Order #', group_by='Order status'))
    assert result['record_count'] == 6 and result['distinct_count'] == 1
    assert result['complete'] is True and result['next_offset'] == 5
    assert result['groups'][0]['distinct_count'] == 1


def test_chat_turn_receives_original_records_and_counts_instead_of_empty_purchase_claim():
    import json
    from types import SimpleNamespace as NS
    call = NS(id='source-read', function=NS(name='world_imports', arguments=json.dumps({
        'filters': [{'field': 'Order status', 'value': 'cancelled'}], 'distinct_field': 'Order #'})))
    def completion(content='', calls=None):
        return NS(choices=[NS(message=NS(content=content, tool_calls=calls or []))])
    responses = iter([completion(calls=[call]), completion('The imported spreadsheet has 2 cancelled orders across 3 item rows.')])
    def gateway(**kwargs):
        messages = kwargs['messages']
        assert any('DIFFERENT saved sources' in str(m.get('content')) for m in messages)
        results = [json.loads(m['content']) for m in messages if m['role'] == 'tool']
        if results:
            assert results[-1]['distinct_count'] == 2
            assert results[-1]['record_count'] == 3
            assert results[-1]['items'][0]['fields'][1]['value'] == 'CANCELLED'
        return next(responses)
    with database([item('0012'), item('0012'), item('0013')]), patch('app.services.agent_gateway_client.gateway_completion', side_effect=gateway):
        result = list(w.stream_turn(ACTOR, WORLD, 'How many cancelled orders do I have?', [], 'cid'))[-1]
    assert '2 cancelled orders' in result['assistant_message']


def test_empty_connections_result_explicitly_excludes_inventory_imports():
    import json
    from types import SimpleNamespace as NS
    calls = [NS(id='purchases', function=NS(name='world_purchases', arguments='{}'))]
    responses = iter([NS(choices=[NS(message=NS(content='', tool_calls=calls))]),
                      NS(choices=[NS(message=NS(content='The Connections library is empty; inventory imports need a separate check.', tool_calls=[]))])])
    def gateway(**kwargs):
        for message in kwargs['messages']:
            if message['role'] == 'tool':
                result = json.loads(message['content'])
                assert 'NOT searched' in result['coverage_note']
                assert 'world_imports' in result['coverage_note']
        return next(responses)
    tools = [*w.TOOLS, w.tool('world_purchases', 'Connections library', {})]
    with database([]), patch.object(w, 'TOOLS', tools), patch.object(w, 'execute', return_value={'products': [], 'matched_products': 0}), patch('app.services.agent_gateway_client.gateway_completion', side_effect=gateway):
        result = list(w.stream_turn(ACTOR, WORLD, 'How many cancelled orders do I have?', [], 'cid'))[-1]
    assert 'separate check' in result['assistant_message']
