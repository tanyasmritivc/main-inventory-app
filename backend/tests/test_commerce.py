import base64
import hashlib
import hmac
import json
import time
from datetime import datetime, timezone
from unittest.mock import MagicMock, patch
from uuid import UUID, uuid4

import httpx
import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

from app.api.routes import commerce
from app.core.auth import AuthenticatedUser, get_current_user
from app.services.commerce.config import CommerceSettings
from app.services.commerce.models import ProviderError
from app.services.commerce.providers import ProviderClient, authorization_url
from app.services.commerce.purchase_import import preview
from app.services.commerce.security import seal, unseal, shop_domain, validate_shopify_callback
from app.services.commerce import repository
from app.services.commerce.webhooks import verified_event

ACTOR = str(uuid4())
CID = str(uuid4())
INVENTORY = str(uuid4())
CONNECTION = dict(id=CID, actor_id=ACTOR, inventory_id=INVENTORY, provider='shopify',
                  external_account='example.myshopify.com', region='na', marketplace='ATVPDKIKX0DER',
                  status='connected', lease_id=str(uuid4()))


@pytest.fixture
def cfg():
    return CommerceSettings(enabled=True, encryption_key=base64.b64encode(b'x' * 32).decode(),
        shopify_client_id='test-client', shopify_client_secret='test-secret',
        shopify_redirect_uri='https://example.test/callback', amazon_client_id='amazon-client',
        amazon_client_secret='amazon-secret', amazon_application_id='application',
        amazon_redirect_uri='https://example.test/amazon-callback')


@pytest.fixture
def configured(cfg):
    with patch('app.services.commerce.security.settings', return_value=cfg), \
         patch('app.services.commerce.providers.settings', return_value=cfg), \
         patch('app.api.routes.commerce.settings', return_value=cfg):
        yield cfg


def provider(handler):
    return ProviderClient(httpx.Client(transport=httpx.MockTransport(handler)))


def test_tokens_encrypted_randomized_bound_to_connection(configured):
    value = {'access_token': 'secret-test', 'refresh_token': 'refresh-test'}
    encrypted = seal(value, CID)
    assert encrypted != seal(value, CID) and 'secret-test' not in encrypted
    assert unseal(encrypted, CID) == value
    with pytest.raises(HTTPException):
        unseal(encrypted, 'another-connection')
    with pytest.raises(HTTPException):
        unseal(encrypted[:-4] + 'AAAA', CID)


@pytest.mark.parametrize('host', ['localhost', '127.0.0.1', 'https://a.myshopify.com',
    'a.myshopify.com.evil.test', 'a@b.myshopify.com', 'a.myshopify.com:443', 'a/b.myshopify.com'])
def test_untrusted_shop_hosts_never_become_network_targets(host):
    with pytest.raises(HTTPException):
        shop_domain(host)


def signed_params():
    data = dict(shop='example.myshopify.com', state='state', code='code', timestamp=str(int(time.time())))
    data['hmac'] = hmac.new(b'test-secret', '&'.join(f'{k}={data[k]}' for k in sorted(data)).encode(), hashlib.sha256).hexdigest()
    return data


def test_callback_hmac_covers_all_fields_and_timestamp():
    data = signed_params()
    validate_shopify_callback(data, data['shop'], 'test-secret')
    with pytest.raises(HTTPException):
        validate_shopify_callback({**data, 'code': 'changed'}, data['shop'], 'test-secret')
    with pytest.raises(HTTPException):
        validate_shopify_callback({**data, 'timestamp': '0'}, data['shop'], 'test-secret')
    with pytest.raises(HTTPException):
        validate_shopify_callback(data, 'different.myshopify.com', 'test-secret')
    with pytest.raises(HTTPException):
        validate_shopify_callback({**data, 'hmac': '\u2603'}, data['shop'], 'test-secret')


def test_expiring_shopify_token_exchange_and_refresh(configured):
    seen = []
    def handler(request):
        seen.append(request.content.decode())
        return httpx.Response(200, json={'access_token': 'access', 'refresh_token': 'rotated',
            'expires_in': 3600, 'scope': 'read_products,read_inventory,read_orders'})
    p = provider(handler)
    first = p.tokens(CONNECTION, code='code')
    second = p.tokens(CONNECTION, refresh_token='old-refresh')
    assert 'expiring=1' in seen[0] and 'grant_type=refresh_token' in seen[1]
    assert first['expires_at'] > time.time() and second['refresh_token'] == 'rotated'
    url = authorization_url('shopify', CONNECTION['external_account'], 'na', 'state')
    assert 'write_' not in url and 'state=state' in url


@pytest.mark.parametrize('response', [dict(access_token='x', expires_in=3600),
    dict(access_token='x', refresh_token='r', expires_in=3600, scope='read_products')])
def test_missing_refresh_or_scopes_fail_closed(configured, response):
    p = provider(lambda r: httpx.Response(200, json=response))
    with pytest.raises(ProviderError):
        p.tokens(CONNECTION, code='code')


@pytest.mark.parametrize('status', [301, 401, 403, 429, 500])
def test_provider_errors_do_not_expose_response_or_follow_redirect(status):
    p = provider(lambda r: httpx.Response(status, json={'secret': 'LEAK-MARKER'}, headers={'Location': 'https://evil.test'}))
    with pytest.raises(ProviderError) as error:
        p.request('GET', 'https://example.test')
    assert 'LEAK-MARKER' not in str(error.value) and p.calls == 1


def page(nodes, next_cursor=None):
    return {'nodes': nodes, 'pageInfo': {'hasNextPage': next_cursor is not None, 'endCursor': next_cursor}}


def test_shopify_catalog_pagination_untracked_stock_unknown():
    calls = []
    def handler(request):
        variables = json.loads(request.content)['variables']
        calls.append(variables)
        i = '2' if variables['after'] else '1'
        row = dict(id=i, title='Default', sku='sku'+i, barcode=None, inventoryQuantity=12,
            inventoryItem={'tracked': i == '1'}, product={'id':'product'+i, 'title':'Motor', 'status':'ACTIVE', 'updatedAt':'2026-11-01T00:00:00Z'})
        return httpx.Response(200, json={'data': {'productVariants': page([row], 'next' if i == '1' else None)}})
    rows = provider(handler).sync(CONNECTION, 'token', 'catalog', '')
    assert len(rows) == 4 and calls == [{'after': None}, {'after': 'next'}]
    assert rows[1]['available_quantity'] == 12 and rows[3]['available_quantity'] is None
    assert all(r['physically_verified'] is False for r in rows)


def test_shopify_nested_order_lines_are_fully_paginated():
    calls = []
    def handler(request):
        body = json.loads(request.content)
        calls.append(body)
        if 'orders(' in body['query']:
            return httpx.Response(200, json={'data': {'orders': page([dict(id='o1', createdAt='2026-11-01T00:00:00Z',
                updatedAt='2026-11-02T00:00:00Z', cancelledAt=None, displayFulfillmentStatus='PARTIALLY_FULFILLED')])}})
        second = body['variables']['after'] is not None
        return httpx.Response(200, json={'data': {'order': {'lineItems': page([
            dict(id='l2' if second else 'l1', name='Bolt', sku='M3', quantity=10, currentQuantity=8, variant=None)
        ], None if second else 'more')}}})
    rows = provider(handler).sync(CONNECTION, 'token', 'orders', '2026-11-01T00:00:00+00:00')
    assert len(calls) == 3 and len(rows) == 2
    assert rows[0]['current_quantity'] == 8 and rows[0]['fulfilled_quantity'] is None
    assert rows[0]['kind'] == 'sale_line'


def test_amazon_orders_preserve_filters_and_exclude_pii():
    calls = []
    def handler(request):
        calls.append(dict(request.url.params))
        i = len(calls)
        order = dict(orderId='order'+str(i), createdTime='2026-11-01T00:00:00Z', lastUpdatedTime='2026-11-02T00:00:00Z',
            fulfillment={'fulfillmentStatus':'SHIPPED'}, buyer={'name':'DO NOT STORE'},
            orderItems=[dict(orderItemId='line', quantityOrdered=2, fulfillment={'quantityFulfilled':2},
                product={'asin':'B000000001', 'title':'Motor', 'sellerSku':'sku'})])
        return httpx.Response(200, json={'orders':[order], 'pagination':{'nextToken':'next'} if i == 1 else {}})
    rows = provider(handler).sync({**CONNECTION, 'provider':'amazon_seller'}, 'token', 'orders', '2026-11-01T00:00:00Z')
    assert len(rows) == 2 and 'DO NOT STORE' not in json.dumps(rows)
    assert calls[1]['lastUpdatedAfter'] == calls[0]['lastUpdatedAfter']
    assert calls[1]['includedData'] == 'FULFILLMENT' and calls[1]['paginationToken'] == 'next'
    assert rows[0]['source_status'] == 'SHIPPED' and not rows[0]['physically_verified']


def test_amazon_fba_stock_uses_available_not_total():
    p = provider(lambda r: httpx.Response(200, json={'payload': {'inventorySummaries': [dict(
        fnSku='fn', asin='B000000001', sellerSku='sku', totalQuantity=10, condition='NewItem',
        inventoryDetails={'fulfillableQuantity':6}, lastUpdatedTime='2026-11-01T00:00:00Z')]}}))
    rows = p.sync({**CONNECTION, 'provider':'amazon_seller'}, 'token', 'stock', '')
    assert rows[0]['quantity'] == 10 and rows[0]['available_quantity'] == 6


def test_amazon_fba_pages_are_paced_and_keep_marketplace_filter():
    calls = []
    def handler(request):
        calls.append(dict(request.url.params))
        return httpx.Response(200, json={'payload':{'inventorySummaries':[]},
            'pagination':{'nextToken':'next'} if len(calls) == 1 else {}})
    with patch('app.services.commerce.providers.time.sleep') as pause:
        assert provider(handler).sync({**CONNECTION,'provider':'amazon_seller'},'token','stock','') == []
    pause.assert_called_once_with(0.55)
    assert calls[1]['marketplaceIds'] == calls[0]['marketplaceIds']
    assert calls[1]['nextToken'] == 'next'


def test_repeated_pagination_and_graphql_error_abort_snapshot():
    p = provider(lambda r: httpx.Response(200, json={'data': {'productVariants': page([], 'same')}}))
    with pytest.raises(ProviderError):
        p.sync(CONNECTION, 'token', 'catalog', '')
    p = provider(lambda r: httpx.Response(200, json={'errors':[{'message':'secret'}], 'data':{}}))
    with pytest.raises(ProviderError) as error:
        p.sync(CONNECTION, 'token', 'catalog', '')
    assert 'secret' not in str(error.value)


CSV = b'order_id,line_id,title,quantity,ordered_at,asin,status\norder1,line1,Motor,2,2026-11-01T00:00:00Z,B000000001,delivered\n'


def test_consumer_preview_keeps_delivery_as_user_claim():
    result = preview(CSV)
    row = result['records'][0]
    assert result['sha256'] == hashlib.sha256(CSV).hexdigest()
    assert row['kind'] == 'purchase_line' and row['evidence'] == 'user_file'
    assert row['source_status'] == 'delivered' and row['physically_verified'] is False


@pytest.mark.parametrize('raw', [CSV + CSV.split(b'\n')[1] + b'\n', CSV.replace(b',2,', b',-2,'),
    CSV.replace(b',2,', b',1.5,'), CSV.replace(b'00:00:00Z', b'00:00:00'),
    CSV.replace(b'order_id,', b'address,'), CSV.replace(b'delivered', b'verified'), b''])
def test_consumer_invalid_or_duplicate_lines_fail(raw):
    with pytest.raises(HTTPException):
        preview(raw)


@pytest.fixture
def client(configured):
    app = FastAPI()
    app.include_router(commerce.router)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(user_id=ACTOR)
    return TestClient(app)


def test_anonymous_routes_require_login():
    app = FastAPI()
    app.include_router(commerce.router)
    c = TestClient(app)
    assert c.get('/commerce/capabilities').status_code == 401
    assert c.delete(f'/commerce/connections/{CID}').status_code == 401


def test_feature_disabled_does_not_claim_provider_ready():
    with patch.object(commerce, 'settings', return_value=CommerceSettings()):
        result = commerce.capabilities(AuthenticatedUser(user_id=ACTOR))
    assert all(not p['configured'] for p in result['providers'])


def test_private_connection_query_filters_actor_and_inventory_access():
    query = MagicMock()
    query.table.return_value.select.return_value.eq.return_value.eq.return_value.limit.return_value.execute.return_value.data = [CONNECTION]
    with patch.object(repository, 'get_supabase_raw', return_value=query), patch.object(repository, 'authorize') as access:
        repository.connection(CID, ACTOR)
    query.table.return_value.select.return_value.eq.return_value.eq.assert_called_once_with('actor_id', ACTOR)
    access.assert_called_once_with(INVENTORY, ACTOR)
    assert 'token_ciphertext' not in repository.public({**CONNECTION, 'token_ciphertext':'secret'})


def test_revoked_access_prevents_provider_calls(client):
    with patch.object(commerce.repo, 'connection', side_effect=HTTPException(403, 'Revoked')), patch.object(commerce, 'ProviderClient') as adapter:
        result = client.post(f'/commerce/connections/{CID}/sync', json={'resource':'orders'})
    assert result.status_code == 403
    adapter.assert_not_called()


def test_wrong_seller_callback_never_exchanges_code(client):
    c = {**CONNECTION, 'provider':'amazon_seller', 'external_account':'SELLER123'}
    with patch.object(commerce.repo, 'connection', return_value=c), patch.object(commerce.repo, 'transition') as mutation:
        result = client.post(f'/commerce/connections/{CID}/complete', json={'parameters':{'state':'s','selling_partner_id':'WRONG','spapi_oauth_code':'code'}})
    assert result.status_code == 400
    mutation.assert_not_called()


def test_oauth_claim_failure_never_calls_provider(client):
    with patch.object(commerce.repo, 'connection', return_value=CONNECTION), \
         patch.object(commerce.repo, 'transition', side_effect=HTTPException(409, 'Expired')), patch.object(commerce, 'ProviderClient') as provider_class:
        result = client.post(f'/commerce/connections/{CID}/complete', json={'parameters':signed_params()})
    assert result.status_code == 409
    provider_class.assert_not_called()


def test_sync_refresh_persisted_before_read_and_incomplete_batch_not_committed(client):
    c = {**CONNECTION, 'token_ciphertext': seal({'access_token':'old','refresh_token':'refresh','expires_at':0}, CID)}
    adapter = MagicMock()
    adapter.tokens.return_value = {'access_token':'new','refresh_token':'rotated','expires_at':time.time()+3600}
    adapter.sync.side_effect = ProviderError('Provider rate limit reached.', 429)
    with patch.object(commerce.repo, 'connection', return_value=c), \
         patch.object(commerce.repo, 'transition', return_value=c) as mutation, \
         patch.object(commerce, 'ProviderClient', return_value=adapter):
        result = client.post(f'/commerce/connections/{CID}/sync', json={'resource':'orders'})
    assert result.status_code == 429
    assert [call.args[2] for call in mutation.call_args_list] == ['sync_claim','tokens','fail']
    saved = mutation.call_args_list[1].args[3]['token_ciphertext']
    assert unseal(saved, CID)['refresh_token'] == 'rotated'


def test_consumer_confirm_checksum_and_explicit_commit(client):
    c = {**CONNECTION, 'provider':'amazon_consumer'}
    with patch.object(commerce.repo, 'connection', return_value=c), patch.object(commerce.repo, 'transition', return_value=c) as mutation:
        result = client.post(f'/commerce/connections/{CID}/purchase-file', files={'file':('orders.csv',CSV)})
        assert result.status_code == 200 and not result.json()['committed']
        mutation.assert_not_called()
        bad = client.post(f'/commerce/connections/{CID}/purchase-file', files={'file':('orders.csv',CSV)}, data={'confirmed_sha256':'wrong'})
        assert bad.status_code == 409
        mutation.assert_not_called()
        good = client.post(f'/commerce/connections/{CID}/purchase-file', files={'file':('orders.csv',CSV)}, data={'confirmed_sha256':result.json()['sha256']})
        assert good.status_code == 200 and good.json()['committed']
        assert [call.args[2] for call in mutation.call_args_list] == ['sync_claim','commit']


def test_disconnect_works_without_inventory_access_or_provider_configuration(client):
    with patch.object(commerce, 'settings', return_value=CommerceSettings()), \
         patch.object(commerce.repo, 'transition', return_value={'status':'disconnected','purged':True}) as mutation:
        result = client.delete(f'/commerce/connections/{CID}?purge=true')
    assert result.status_code == 200
    assert mutation.call_args.args == (ACTOR, UUID(CID), 'disconnect', {'purge': True})


def webhook(body, topic='customers/redact'):
    raw = json.dumps(body).encode()
    return raw, {'x-shopify-hmac-sha256':base64.b64encode(hmac.new(b'test-secret',raw,hashlib.sha256).digest()).decode(),
                 'x-shopify-shop-domain':'example.myshopify.com', 'x-shopify-topic':topic,
                 'x-shopify-triggered-at':datetime.now(timezone.utc).isoformat()}


def test_webhook_uses_only_verified_body_and_minimal_identifiers():
    raw, headers = webhook({'shop_domain':'example.myshopify.com','orders_to_redact':[123],
                            'customer':{'email':'not-retained@example.test'}})
    event = verified_event(raw, headers, 'test-secret')
    assert event['p_order_ids'] == ['gid://shopify/Order/123']
    assert 'not-retained' not in json.dumps(event)
    assert event['p_event_hash'] == verified_event(raw, headers, 'test-secret')['p_event_hash']
    with pytest.raises(HTTPException) as error:
        verified_event(raw+b' ', headers, 'test-secret')
    assert error.value.status_code == 401
    with pytest.raises(HTTPException):
        verified_event(raw, {**headers,'x-shopify-shop-domain':'victim.myshopify.com'}, 'test-secret')


@pytest.mark.parametrize('body,topic', [
    ({'shop_domain':'example.myshopify.com','orders_to_redact':[True]},'customers/redact'),
    ({'shop_domain':'example.myshopify.com','orders_requested':[123]},'customers/data_request'),
    ({'shop_domain':'example.myshopify.com'},'unknown'),
])
def test_invalid_webhook_metadata_rejected(body, topic):
    raw, headers = webhook(body,topic)
    with pytest.raises(HTTPException):
        verified_event(raw,headers,'test-secret')


def test_webhook_endpoint_signature_required_before_database(client):
    with patch.object(commerce.repo, 'get_supabase_raw') as db:
        result = client.post('/commerce/webhooks/shopify', content=b'{}', headers={'x-shopify-hmac-sha256':'invalid'})
    assert result.status_code == 401
    db.assert_not_called()


def test_signed_webhook_accepted_without_user_login(configured):
    app = FastAPI()
    app.include_router(commerce.router)
    raw, headers = webhook({'shop_domain':'example.myshopify.com','orders_to_redact':[123]})
    with patch.object(commerce.repo, 'execute',return_value={'received':True}), patch.object(commerce.repo, 'get_supabase_raw') as db:
        result = TestClient(app).post('/commerce/webhooks/shopify', content=raw, headers=headers)
    assert result.status_code == 200
    assert db.return_value.rpc.call_args.args[0] == 'findez_commerce_shopify_event'
