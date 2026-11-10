from types import SimpleNamespace
from unittest.mock import Mock, patch
import pytest
from fastapi import HTTPException
from app.services.camera_barcode import internal_item_id, resolve_internal_item

ITEM = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'

@pytest.mark.parametrize('code', [ITEM, f'findez://item/inventory/{ITEM}', f'https://www.findez.ai/items/{ITEM}'])
def test_internal_labels(code):
    assert internal_item_id(code) == ITEM

@pytest.mark.parametrize('code', ['012345678905', '3802-0102-0300', 'https://example.com/item'])
def test_public_codes_do_not_query_private_items(code):
    with patch('app.services.supabase_client.get_supabase_raw') as db:
        assert resolve_internal_item('actor', 'personal', code) is None
        db.assert_not_called()

@patch('app.services.world_chat.resolve_resource')
@patch('app.services.world_chat.authorize')
@patch('app.services.supabase_client.get_supabase_raw')
def test_internal_label_requires_fresh_world_permission(db, authorize, resolve):
    query = Mock()
    db.return_value.table.return_value = query
    query.select.return_value = query.eq.return_value = query.limit.return_value = query
    query.execute.return_value = SimpleNamespace(data=[{'inventory_id': 'inventory'}])
    resolve.return_value = {'inventory_id': 'inventory', 'resource': {'item_id': ITEM, 'name': 'Drill', 'quantity': 2, 'user_id': 'private'}}
    result = resolve_internal_item('actor', 'organization', ITEM)
    authorize.assert_called_once_with('actor', 'organization')
    resolve.assert_called_once_with('actor', 'organization', 'inventory', 'item', ITEM)
    assert result['existing_item']['name'] == 'Drill'
    assert 'user_id' not in result['existing_item']
    resolve.side_effect = HTTPException(403, 'private detail')
    with pytest.raises(HTTPException) as error:
        resolve_internal_item('actor', 'other-world', ITEM)
    assert error.value.status_code == 404
    assert 'private detail' not in error.value.detail

@pytest.mark.parametrize('code', ['findez://item/not-valid', 'https://findez.ai/join/access'])
def test_non_item_findez_labels_do_not_become_public_products(code):
    with pytest.raises(HTTPException):
        internal_item_id(code)

def test_public_catalog_failure_returns_unknown_without_model_guess():
    import asyncio
    from unittest.mock import AsyncMock
    from app.api.routes.items import lookup_barcode_product
    with patch('app.api.routes.items.lookup_in_catalog', return_value=None), \
         patch('app.api.routes.items.lookup_upcitemdb', new_callable=AsyncMock, return_value=None), \
         patch('app.api.routes.items.lookup_go_upc', new_callable=AsyncMock, return_value=None), \
         patch('app.api.routes.items.lookup_openfoodfacts', new_callable=AsyncMock, return_value=None), \
         patch('app.api.routes.items.interpret_barcode') as model:
        result = asyncio.run(lookup_barcode_product('012345678905', 'actor'))
        assert result.name == 'Unknown item'
        model.assert_not_called()


def test_public_product_uses_later_provider_after_miss():
    import asyncio
    from unittest.mock import AsyncMock
    from app.api.routes.items import lookup_barcode_product
    with patch('app.api.routes.items.lookup_in_catalog', return_value=None), \
         patch('app.api.routes.items.lookup_upcitemdb', new_callable=AsyncMock, return_value=None), \
         patch('app.api.routes.items.lookup_go_upc', new_callable=AsyncMock, return_value=None), \
         patch('app.api.routes.items.lookup_openfoodfacts', new_callable=AsyncMock, return_value={'name': 'Sample product'}), \
         patch('app.api.routes.items.save_to_catalog'), \
         patch('app.api.routes.items.increment_usage', new_callable=AsyncMock):
        result = asyncio.run(lookup_barcode_product('012345678905', 'actor'))
        assert result.name == 'Sample product'
        assert result.found_in_inventory is False
