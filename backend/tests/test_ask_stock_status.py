"""Regression for Ask saying nothing is low when untracked items are at zero."""
from types import SimpleNamespace
from unittest.mock import MagicMock, call

import pytest
from app.services import inventory_query as stock
from app.services.world_insights import Query


@pytest.mark.parametrize('status, expected', [
    ('restock', {'empty', 'disabled zero', 'tracked zero', 'below', 'equal'}),
    ('low', {'tracked zero', 'below', 'equal'}),
    ('out', {'empty', 'disabled zero', 'tracked zero'}),
])
def test_stock_modes_preserve_zero_and_threshold_boundaries(monkeypatch, status, expected):
    filters = Query(filters={'stock_status': status}).filters.model_dump(exclude_none=True)
    samples = [
        ('empty', 0, None, None), ('disabled zero', 0, False, 3),
        ('tracked zero', 0, True, 0), ('below', 1, True, 2), ('equal', 2, True, 2),
        ('above', 3, True, 2), ('disabled', 1, False, 3), ('missing rule', 1, True, None),
        ('unknown', -1, True, 3), ('uncounted', None, True, 3),
    ]
    rows = [dict(name=name, quantity=q, reorder_enabled=e, reorder_threshold=t, location='Lab')
            for name, q, e, t in samples]
    db = MagicMock()
    query = db.table.return_value.select.return_value
    query.eq.return_value = query.or_.return_value = query.order.return_value = query
    query.range.return_value = query
    # Force a second page. As in the screenshot, a stockout is on the last page.
    query.execute.side_effect = [SimpleNamespace(data=[rows[-1]] * 500), SimpleNamespace(data=rows)]
    monkeypatch.setattr(stock, 'get_supabase_admin', lambda: db)
    result = stock.query_inventory(user_id='owner', terms=[], filters=filters)
    assert {r['name'] for r in result['items']} == expected
    assert result['record_count'] == len(expected)
    assert result['out_of_stock_count'] == (1 if status == 'low' else 3)
    assert result['complete'] and result['unknown_quantity_records'] == 0
    query.eq.assert_any_call('user_id', 'owner')
    assert query.range.call_args_list[-1].args == (500, 999)
    if status == 'restock':
        assert query.or_.call_args_list == [call('quantity.eq.0,reorder_enabled.eq.true')] * 2
    elif status == 'out':
        query.eq.assert_any_call('quantity', 0)
    else:
        query.eq.assert_any_call('reorder_enabled', True)
    assert not stock._filter(rows[0], {**filters, 'location': 'Garage'})


def test_organization_stockout_count_includes_matches_beyond_display_limit(monkeypatch):
    from contextlib import nullcontext
    from app.services import world_chat, world_insights
    from app.services.world_inventory_preview import inventory_preview

    authorized = [{'inventory_id': name, 'owner_user_id': name, 'name': name}
                  for name in ('Software', 'Hardware')]
    monkeypatch.setattr(world_chat, 'directory', lambda actor, world: {'inventories': authorized})

    def scope(actor, world, inventory):
        assert (actor, world) == ('member', 'selected')
        return nullcontext(next(row for row in authorized if row['name'] == inventory))

    def query(*, user_id, terms, filters):
        assert terms == [] and filters == {'stock_status': 'restock'}
        amounts = [1] * 100 if user_id == 'Software' else [0, 0]
        return {'items': [{'quantity': q} for q in amounts], 'record_count': len(amounts),
                'known_units': sum(amounts), 'unknown_quantity_records': 0,
                'out_of_stock_count': amounts.count(0), 'complete': True}

    monkeypatch.setattr(world_chat, 'in_inventory', scope)
    monkeypatch.setattr(stock, 'query_inventory', query)
    result = inventory_preview(world_insights.execute(
        'member', 'selected', 'world_query', {'filters': {'stock_status': 'restock'}}))
    assert result['complete'] and result['rows_truncated']
    assert result['record_count'] == 102 and result['out_of_stock_count'] == 2
    assert [s['out_of_stock_count'] for s in result['inventories']] == [0, 2]
