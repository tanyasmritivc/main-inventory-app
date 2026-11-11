"""Read-only official provider APIs, with bounded, complete pagination.

No arbitrary URLs, redirects, customer addresses, or provider payload logging.
"""
import time
from urllib.parse import urlencode

import httpx
from pydantic import ValidationError

from .config import settings
from .models import ProviderError, SourceRecord
from .security import shop_domain

SHOPIFY_VERSION = '2026-10'
SHOPIFY_SCOPES = ('read_products', 'read_inventory', 'read_orders')
REGIONS = {
    'na': ('https://sellercentral.amazon.com', 'https://sellingpartnerapi-na.amazon.com',
           {'ATVPDKIKX0DER', 'A2EUQ1WTGCTBG2', 'A1AM78C64UM0Y8'}),
    'eu': ('https://sellercentral-europe.amazon.com', 'https://sellingpartnerapi-eu.amazon.com',
           {'A1F83G8C2ARO7P', 'A1PA6795UKMFR9', 'A13V1IB3VIYZZH', 'APJ6JRA9NG5V4', 'A1RKKUPIHCS9HS'}),
    'fe': ('https://sellercentral.amazon.co.jp', 'https://sellingpartnerapi-fe.amazon.com',
           {'A1VC38T7YXB528', 'A39IBJ37TRP1C6', 'A19VAU5U5O7RUS'}),
}
MAX_CALLS = 100
MAX_RECORDS = 10000


def authorization_url(provider, account, region, state):
    cfg = settings()
    cfg.require(provider)
    if provider == 'shopify':
        return f'https://{shop_domain(account)}/admin/oauth/authorize?' + urlencode({
            'client_id': cfg.shopify_client_id, 'scope': ','.join(SHOPIFY_SCOPES),
            'redirect_uri': cfg.shopify_redirect_uri, 'state': state})
    query = {'application_id': cfg.amazon_application_id, 'state': state,
             'redirect_uri': cfg.amazon_redirect_uri}
    if cfg.amazon_draft:
        query['version'] = 'beta'
    return REGIONS[region][0] + '/apps/authorize/consent?' + urlencode(query)


class ProviderClient:
    def __init__(self, client=None):
        self.client = client or httpx.Client(timeout=15, follow_redirects=False)
        self.calls = 0
        self.started = time.monotonic()

    def close(self):
        self.client.close()

    def request(self, method, url, **kwargs):
        self.calls += 1
        if self.calls > MAX_CALLS or time.monotonic() - self.started > 75:
            raise ProviderError('Sync exceeds the current batch limit. Use a smaller order date range.', 422)
        try:
            with self.client.stream(method, url, **kwargs) as response:
                if response.status_code == 429:
                    raise ProviderError('Provider rate limit reached. Retry later; previous data is unchanged.', 429)
                if response.status_code in (401, 403):
                    raise ProviderError('Provider access was denied. Check permissions or reconnect.', 409)
                if not 200 <= response.status_code < 300:
                    raise ProviderError()
                data = bytearray()
                for chunk in response.iter_bytes():
                    data.extend(chunk)
                    if len(data) > 8 * 1024 * 1024:
                        raise ProviderError('Provider response exceeded the supported size.', 422)
                import json
                result = json.loads(data)
                if not isinstance(result, dict):
                    raise ValueError()
                return result
        except (httpx.HTTPError, ValueError):
            raise ProviderError() from None

    def tokens(self, connection, *, code=None, refresh_token=None):
        cfg = settings()
        shopify = connection['provider'] == 'shopify'
        prefix = 'shopify' if shopify else 'amazon'
        cfg.require(connection['provider'])
        body = {'client_id': getattr(cfg, prefix + '_client_id'),
                'client_secret': getattr(cfg, prefix + '_client_secret').get_secret_value()}
        if refresh_token:
            body.update(grant_type='refresh_token', refresh_token=refresh_token)
        elif shopify:
            body.update(code=code, expiring=1)
        else:
            body.update(grant_type='authorization_code', code=code, redirect_uri=cfg.amazon_redirect_uri)
        url = (f"https://{shop_domain(connection['external_account'])}/admin/oauth/access_token"
               if shopify else 'https://api.amazon.com/auth/o2/token')
        raw = self.request('POST', url, data=body)
        # Never persist arbitrary token response fields (which may contain PII).
        if not isinstance(raw.get('access_token'), str) or not raw['access_token']:
            raise ProviderError('Provider did not return an access token.')
        refresh = raw.get('refresh_token') or refresh_token
        if not isinstance(refresh, str) or not refresh:
            raise ProviderError('Provider did not return an offline refresh token.')
        try:
            expires = int(raw['expires_in'])
            if expires <= 0:
                raise ValueError()
        except (KeyError, ValueError, TypeError):
            raise ProviderError('Provider did not return token expiry metadata.') from None
        scope = raw.get('scope', '')
        if shopify and not refresh_token and not set(SHOPIFY_SCOPES).issubset(set(scope.split(','))):
            raise ProviderError('Required Shopify read permissions were not granted.', 409)
        return {'access_token': raw['access_token'], 'refresh_token': refresh,
                'expires_at': time.time() + expires, 'scope': scope,
                'refresh_expires_at': time.time() + int(raw['refresh_token_expires_in'])
                if raw.get('refresh_token_expires_in') else None}

    def graphql(self, connection, token, query, variables):
        raw = self.request('POST', f"https://{shop_domain(connection['external_account'])}/admin/api/{SHOPIFY_VERSION}/graphql.json",
                           headers={'X-Shopify-Access-Token': token}, json={'query': query, 'variables': variables})
        if raw.get('errors') or not isinstance(raw.get('data'), dict):
            raise ProviderError('Shopify could not complete the query. Check app permissions and retry.')
        return raw['data']

    def shopify_pages(self, connection, token, query, field, variables=None):
        cursor = None
        seen = set()
        while True:
            data = self.graphql(connection, token, query, {**(variables or {}), 'after': cursor})
            page = data
            for part in field.split('.'):
                page = page[part]
            yield from page['nodes']
            info = page['pageInfo']
            if not info['hasNextPage']:
                return
            cursor = info['endCursor']
            if not cursor or cursor in seen:
                raise ProviderError('Shopify returned invalid pagination; previous data is unchanged.')
            seen.add(cursor)

    def sync(self, connection, token, resource, since):
        try:
            rows = []
            iterator = (self.shopify_records(connection, token, resource, since)
                        if connection['provider'] == 'shopify'
                        else self.amazon_records(connection, token, resource, since))
            keys = set()
            for row in iterator:
                validated = SourceRecord.model_validate(row).model_dump(mode='json')
                key = (validated['kind'], validated['external_id'])
                if key in keys:
                    raise ProviderError('Provider returned duplicate record identifiers; retry the sync.')
                keys.add(key)
                rows.append(validated)
                if len(rows) > MAX_RECORDS:
                    raise ProviderError('Sync exceeds the current record limit. Use a smaller order date range.', 422)
            return rows
        except (KeyError, TypeError, ValueError, ValidationError):
            raise ProviderError('Provider data did not match the expected schema; previous data is unchanged.') from None

    def shopify_records(self, connection, token, resource, since):
        if resource == 'catalog':
            query = '''query($after:String){productVariants(first:100,after:$after){
              nodes{id title sku barcode inventoryQuantity inventoryItem{tracked}
              product{id title status updatedAt}} pageInfo{hasNextPage endCursor}}}'''
            for row in self.shopify_pages(connection, token, query, 'productVariants'):
                base = dict(external_id=row['id'], title=row['product']['title'] + ' / ' + row['title'],
                            product_id=row['id'], sku=row.get('sku'), barcode=row.get('barcode'),
                            source_status=row['product']['status'], source_updated_at=row['product']['updatedAt'])
                yield dict(base, kind='catalog_variant')
                # Untracked products do not have a trustworthy stock quantity.
                yield dict(base, kind='merchant_stock', available_quantity=row.get('inventoryQuantity')
                           if (row.get('inventoryItem') or {}).get('tracked') else None)
            return
        query = '''query($after:String,$query:String!){orders(first:50,after:$after,query:$query,sortKey:UPDATED_AT){
          nodes{id createdAt updatedAt cancelledAt displayFulfillmentStatus}
          pageInfo{hasNextPage endCursor}}}'''
        lines = '''query($id:ID!,$after:String){order(id:$id){lineItems(first:100,after:$after){
          nodes{id name sku quantity currentQuantity variant{id barcode}}
          pageInfo{hasNextPage endCursor}}}}'''
        for order in self.shopify_pages(connection, token, query, 'orders', {'query': f"updated_at:>='{since}'"}):
            for row in self.shopify_pages(connection, token, lines, 'order.lineItems', {'id': order['id']}):
                variant = row.get('variant') or {}
                yield dict(kind='sale_line', external_id=row['id'], order_id=order['id'], title=row['name'],
                           product_id=variant.get('id'), barcode=variant.get('barcode'), sku=row.get('sku'),
                           quantity=row['quantity'], current_quantity=row['currentQuantity'],
                           source_status='CANCELLED' if order.get('cancelledAt') else order['displayFulfillmentStatus'],
                           ordered_at=order['createdAt'], source_updated_at=order['updatedAt'])

    def amazon_records(self, connection, token, resource, since):
        base = REGIONS[connection['region']][1]
        headers = {'x-amz-access-token': token}
        marketplace = connection['marketplace']
        if resource == 'stock':
            path = '/fba/inventory/v1/summaries'
            params = {'granularityType': 'Marketplace', 'granularityId': marketplace,
                      'marketplaceIds': marketplace, 'details': 'true'}
        else:
            path = '/orders/2026-01-01/orders'
            params = {'marketplaceIds': marketplace, 'lastUpdatedAfter': since,
                      'maxResultsPerPage': 100, 'includedData': 'FULFILLMENT'}
        seen = set()
        while True:
            result = self.request('GET', base + path, headers=headers, params=params)
            if resource == 'stock':
                for row in result['payload']['inventorySummaries']:
                    # FNSKU distinguishes conditions/fulfillment listings for the same ASIN.
                    yield dict(kind='merchant_stock', external_id=marketplace + ':' + row['fnSku'],
                               title=row.get('productName', ''), asin=row['asin'], sku=row['sellerSku'],
                               quantity=row.get('totalQuantity'), source_status=row['condition'],
                               available_quantity=(row.get('inventoryDetails') or {}).get('fulfillableQuantity'),
                               source_updated_at=row.get('lastUpdatedTime'))
            else:
                for order in result['orders']:
                    for row in order['orderItems']:
                        product = row['product']
                        yield dict(kind='sale_line', external_id=order['orderId'] + ':' + row['orderItemId'],
                                   order_id=order['orderId'], title=product.get('title', ''),
                                   asin=product.get('asin'), sku=product.get('sellerSku'),
                                   quantity=row['quantityOrdered'],
                                   fulfilled_quantity=(row.get('fulfillment') or {}).get('quantityFulfilled'),
                                   source_status=(order.get('fulfillment') or {}).get('fulfillmentStatus', 'unknown'),
                                   ordered_at=order['createdTime'], source_updated_at=order['lastUpdatedTime'])
            cursor = (result.get('pagination') or {}).get('nextToken')
            if not cursor:
                return
            if cursor in seen:
                raise ProviderError('Amazon returned repeated pagination; previous data is unchanged.')
            seen.add(cursor)
            if resource == 'stock':
                # Default FBA quota is 2 requests/second. Keep pagination within
                # that rate instead of repeatedly exhausting the two-call burst.
                time.sleep(0.55)
            elif len(seen) >= 20:
                # searchOrders defaults to 0.0056 requests/second, burst 20.
                # Larger ranges need queued continuation, not a busy retry loop.
                raise ProviderError('Amazon order sync exceeds the interactive page limit. Choose a smaller date range.', 422)
            params['nextToken' if resource == 'stock' else 'paginationToken'] = cursor
