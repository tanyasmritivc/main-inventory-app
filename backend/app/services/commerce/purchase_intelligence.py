"""Read-only, owner-scoped purchase library and before-buying evidence."""
from urllib.parse import urlparse
import re
from datetime import date, datetime, timezone
from typing import Literal
from fastapi import HTTPException
from pydantic import BaseModel, ConfigDict, Field, model_validator
from app.services.commerce import repository as repo

MAX_RECORDS = 10000
PAGE_SIZE = 25
FIELDS = ('order_id', 'title', 'asin', 'quantity', 'ordered_at', 'source_status')


class PurchaseQuery(BaseModel):
    model_config = ConfigDict(extra='forbid')
    query: str = Field(default='', max_length=1000)
    status: str = Field(default='all', pattern='^(all|active|purchased|shipped|delivered|cancelled|returned|unknown)$')
    offset: int = Field(default=0, ge=0, le=10000)
    category: str = Field(default='all', max_length=60)
    date_from: str | None = Field(default=None, pattern=r'^\d{4}-\d{2}-\d{2}$')
    date_to: str | None = Field(default=None, pattern=r'^\d{4}-\d{2}-\d{2}$')
    sort: Literal['newest', 'oldest', 'frequent', 'name'] = 'newest'
    inventory: Literal['all', 'matched', 'unmatched'] = 'all'
    repeated: bool = False

    @model_validator(mode='after')
    def valid_filters(self):
        if self.category != 'all' and self.category not in CATEGORIES:
            raise ValueError('Choose a listed purchase category.')
        for value in (self.date_from, self.date_to):
            if value:
                date.fromisoformat(value)
        if self.date_from and self.date_to and self.date_from > self.date_to:
            raise ValueError('Start date must be on or before end date.')
        return self


class PurchaseCheck(BaseModel):
    model_config = ConfigDict(extra='forbid')
    query: str = Field(min_length=2, max_length=1000)


def search_term(value):
    value = value.strip()
    if value.lower().startswith(('https://', 'http://')):
        url = urlparse(value)
        if not re.fullmatch(r'(?:www\.|smile\.)?amazon\.(?:com|ca|co\.uk|de|fr|it|es|in|com\.au|co\.jp)', url.hostname or ''):
            raise HTTPException(422, 'Use a product name, ASIN, or full Amazon product link.')
        match = re.search(r'/(?:dp|gp/product)/([A-Za-z0-9]{10})(?:/|$)', url.path)
        if not match:
            raise HTTPException(422, 'Use the full Amazon product link containing /dp/ or enter its product name or ASIN.')
        return match[1].upper()
    if len(value) > 200:
        raise HTTPException(422, 'Use a shorter product name or its ASIN.')
    return value


def _scope(world):
    if world == 'personal':
        return 'personal', None
    from uuid import UUID
    try:
        return 'organization', str(UUID(world))
    except (ValueError, TypeError):
        raise HTTPException(422, 'Choose Personal or an organization.') from None


def _load(actor, world):
    scope, organization = _scope(world)
    # The existing connection policy restricts organizations to owners/admins.
    repo.authorize_scope(scope, organization, actor)
    connections = repo.connections(None, actor, scope, organization)
    connections = [c for c in connections if c.get('scope_type') == scope
                   and c.get('organization_id') == organization and not c.get('inventory_id')]
    ids = [c['id'] for c in connections]
    if not ids:
        return [], True, 0
    by_id = {c['id']: c for c in connections}
    rows = []
    while len(rows) <= MAX_RECORDS:
        page = repo.execute(repo.get_supabase_raw().table('commerce_source_records')
            .select('connection_id,external_id,data,observed_at')
            .in_('connection_id', ids).eq('kind', 'purchase_line')
            .order('connection_id').order('external_id').range(len(rows), len(rows) + 499)) or []
        rows.extend(page)
        if len(page) < 500:
            break
    # Recheck access after the read, including disconnect/delete/ownership races.
    for c in connections:
        current = repo.connection(c['id'], actor)
        if current.get('scope_type') != scope or current.get('organization_id') != organization:
            raise HTTPException(409, 'The purchase destination changed. Refresh and try again.')
    clean = []
    for row in rows[:MAX_RECORDS]:
        connection = by_id.get(row.get('connection_id'))
        if not connection:
            continue
        data = row.get('data') or {}
        clean.append({**{k: data.get(k) for k in FIELDS}, 'source_status': data.get('source_status') or 'unknown', 'provider': connection['provider'],
                      'connection_status': connection['status'], 'imported_at': row.get('observed_at')})
    return clean, len(rows) <= MAX_RECORDS and len(connections) < 100, len(connections)


def _active(row):
    return (row.get('quantity') or 0) > 0 and row.get('source_status') not in ('cancelled', 'returned')


def _matches(row, query):
    if not query:
        return True
    if re.fullmatch(r'[A-Za-z0-9]{10}', query) and query.upper() == (row.get('asin') or '').upper():
        return True
    haystack = ' '.join(str(row.get(k) or '') for k in ('title', 'asin', 'order_id')).casefold()
    return all(word in haystack for word in query.casefold().split())


def organize(rows):
    groups = {}
    for row in rows:
        asin = (row.get('asin') or '').upper()
        key = 'asin:' + asin if asin else 'title:' + _name(row.get('title'))
        product = groups.setdefault(key, {'key': key, 'title': row.get('title') or 'Unnamed purchase',
            'asin': asin or None, 'ordered_units': 0, 'excluded_units': 0, 'orders': [],
            'last_ordered_at': '', 'statuses': set(), 'providers': set(), 'ownership': 'unconfirmed'})
        quantity = row.get('quantity') or 0
        product['ordered_units' if _active(row) else 'excluded_units'] += quantity
        product['last_ordered_at'] = max(product['last_ordered_at'], row.get('ordered_at') or '')
        product['statuses'].add(row.get('source_status') or 'unknown')
        product['providers'].add(row.get('provider') or 'import')
        product['orders'].append(row)
    for product in groups.values():
        product['statuses'] = sorted(product['statuses'])
        product['providers'] = sorted(product['providers'])
        product['orders'].sort(key=lambda r: r.get('ordered_at') or '', reverse=True)
        product['order_count'] = len({(r['provider'], r.get('order_id')) for r in product['orders']})
        product['active_order_count'] = len({(r['provider'], r.get('order_id')) for r in product['orders'] if _active(r)})
        product['history_truncated'] = len(product['orders']) > 20
        product['orders'] = product['orders'][:20]
    return sorted(groups.values(), key=lambda p: p['last_ordered_at'], reverse=True)


# Suggested groupings are derived locally from names, never from an AI provider.
CATEGORIES = {
    'Tools & hardware': r'\b(screws?|bolts?|nuts?|bearings?|drills?|wrenches?|screwdrivers?|saws?|pliers?|fasteners?|gears?|washers?|clamps?)\b',
    'Electronics': r'\b(motors?|arduino|raspberry pi|usb|cables?|chargers?|batter(?:y|ies)|sensors?|circuits?|headphones?|keyboards?|monitors?|adapters?)\b',
    'Home & kitchen': r'\b(kitchen|cookware|pans?|plates?|mugs?|towels?|pillows?|sheets?|lamps?|curtains?|storage|organizers?)\b',
    'Office & stationery': r'\b(notebooks?|pens?|pencils?|paper|stationery|staplers?|markers?|envelopes?|binders?)\b',
    'Clothing & accessories': r'\b(shirts?|pants?|socks?|shoes?|jackets?|hoodies?|dresses?|belts?|hats?|sunglasses?)\b',
    'Health & personal care': r'\b(shampoo|soap|toothpaste|toothbrush|vitamins?|lotion|skincare|deodorant|bandages?)\b',
    'Food & drink': r'\b(coffee|tea|snacks?|chocolate|cereal|pasta|rice|cookies?|protein powder)\b',
    'Books': r'\b(paperback|hardcover|textbook|workbook|novel)\b',
    'Other': r'(?!)',
}

def _category(title):
    return next((name for name, pattern in CATEGORIES.items() if re.search(pattern, title, re.I)), 'Other')


def _day(value):
    try:
        stamp = datetime.fromisoformat(str(value).replace('Z', '+00:00'))
        return (stamp.astimezone(timezone.utc) if stamp.tzinfo else stamp).date()
    except (TypeError, ValueError):
        return None


def _name(value):
    return ' '.join(str(value or '').casefold().split())


def _inventory_evidence(actor, world):
    """One scoped scan, not one inventory request for every purchase product."""
    from app.services import world_chat as w
    from app.services.supabase_client import get_supabase_admin
    choices = w.directory(actor, world)['inventories']
    names, asins = set(), set()
    complete, count = len(choices) <= 100, 0
    for choice in choices[:100]:
        with w.in_inventory(actor, world, choice['inventory_id']) as inv:
            rows = []
            client = get_supabase_admin()
            while len(rows) + count < MAX_RECORDS:
                size = min(500, MAX_RECORDS - count - len(rows))
                page = repo.execute(client.table('items').select('name,barcode,purchase_source')
                    .eq('user_id', inv['owner_user_id']).order('item_id')
                    .range(len(rows), len(rows) + size - 1)) or []
                rows.extend(page)
                if len(page) < size:
                    break
            # A revoked inventory cannot contribute even a candidate-match flag.
            w.inventory_scope(actor, world, choice['inventory_id'])
            for row in rows[:max(0, MAX_RECORDS - count)]:
                if row.get('name'):
                    names.add(_name(row['name']))
                # Only explicit identifiers, never an arbitrary ten-character name.
                barcode = str(row.get('barcode') or '').upper()
                if re.fullmatch(r'[A-Z0-9]{10}', barcode):
                    asins.add(barcode)
                source = str(row.get('purchase_source') or '')
                if source.startswith(('https://', 'http://')):
                    try:
                        asins.add(search_term(source))
                    except (HTTPException, ValueError):
                        pass
            count += len(rows)
        if count >= MAX_RECORDS:
            complete = False
            break
    return names, asins, complete


def library(actor, world, query='', status='all', offset=0, category='all', date_from=None,
            date_to=None, sort='newest', inventory='all', repeated=False):
    args = PurchaseQuery(query=query, status=status, offset=offset, category=category,
                         date_from=date_from, date_to=date_to, sort=sort, inventory=inventory, repeated=repeated)
    query = search_term(args.query)
    rows, complete, connections = _load(actor, world)
    all_products = organize(rows)
    names, asins, inventory_complete = _inventory_evidence(actor, world) if all_products else (set(), set(), True)
    inventory_keys = {p['key'] for p in all_products if (p['asin'] and p['asin'] in asins) or _name(p['title']) in names}
    categories = {p['key']: _category(p['title']) for p in all_products}
    counts = {name: sum(categories[p['key']] == name for p in all_products) for name in CATEGORIES}
    repeat_keys = {p['key'] for p in all_products if p['active_order_count'] > 1}
    filtered = []
    for row in rows:
        day = _day(row.get('ordered_at'))
        if (not _matches(row, query) or not (status == 'all' or status == 'active' and _active(row) or status == row.get('source_status'))
                or args.date_from and (day is None or day < date.fromisoformat(args.date_from))
                or args.date_to and (day is None or day > date.fromisoformat(args.date_to))):
            continue
        filtered.append(row)
    products = organize(filtered)
    for product in products:
        product['category'] = categories[product['key']]
        product['inventory_match'] = product['key'] in inventory_keys
    products = [p for p in products if (category == 'all' or p['category'] == category)
                and (inventory == 'all' or p['inventory_match'] == (inventory == 'matched'))
                and (not repeated or p['active_order_count'] > 1)]
    # Stable secondary key prevents products moving between pages on tied dates.
    if sort == 'name':
        products.sort(key=lambda p: (_name(p['title']), p['key']))
    elif sort == 'frequent':
        products.sort(key=lambda p: (-p['active_order_count'], p['key']))
    else:
        products.sort(key=lambda p: (p['last_ordered_at'], p['key']), reverse=sort == 'newest')
    return {'summary': {'products': len(all_products), 'orders': len({(r['provider'], r.get('order_id')) for r in rows}),
                       'records': len(rows), 'repeat_products': len(repeat_keys),
                       'inventory_matched_products': len(inventory_keys), 'not_matched_products': len(all_products) - len(inventory_keys),
                       'cancelled_or_returned_records': sum(r.get('source_status') in ('cancelled', 'returned') for r in rows)},
            'categories': [{'name': name, 'products': count} for name, count in counts.items() if count],
            'category_basis': 'suggested_from_product_name', 'inventory_complete': inventory_complete,
            'matched_products': len(products), 'page_size': PAGE_SIZE, 'offset': offset,
            'next_offset': offset + PAGE_SIZE if offset + PAGE_SIZE < len(products) else None,
            'complete': complete, 'rows_truncated': not complete, 'connections': connections,
            'scope': world, 'source': 'saved_purchase_imports', 'live_amazon_access': False,
            'ownership': 'unconfirmed', 'stock_effect': 'none',
            'note': 'Ordered units are not current stock. Inventory matches use exact identifiers or names, not confirmed ownership. Categories are suggested from names. Search covers saved imports up to the reported limit.',
            'products': products[offset:offset + PAGE_SIZE]}


def chat_library(actor, world, **args):
    """Keep a large library out of model context; subsequent pages remain searchable."""
    result = library(actor, world, **args)
    result['products'] = result['products'][:10]
    for product in result['products']:
        product['history_truncated'] = product['history_truncated'] or len(product['orders']) > 3
        product['orders'] = product['orders'][:3]
    offset = args.get('offset', 0)
    result['page_size'] = 10
    result['next_offset'] = offset + 10 if offset + 10 < result['matched_products'] else None
    return result


def check(actor, world, query):
    query = search_term(PurchaseCheck(query=query).query)
    if len(query) < 2:
        raise HTTPException(422, 'Enter a product name or ASIN.')
    purchases = chat_library(actor, world, query=query)
    from app.services import world_chat
    inventory = world_chat.execute(actor, world, 'world_search', {'query': query})
    # Imports can identify a product by ASIN when inventory only has its name.
    exact_products = [p for p in purchases['products'] if p.get('asin') == query.upper()]
    if not inventory.get('items') and exact_products:
        inventory = world_chat.execute(actor, world, 'world_search', {'query': exact_products[0]['title'][:200]})
    candidates = [{k: row.get(k) for k in ('name', 'quantity', 'location', 'inventory_name', 'workspace_name')}
                  for row in inventory.get('items', [])[:20]]
    products = purchases['products'][:10]
    exact = bool(products) and all(p.get('asin') == query.upper() for p in products)
    ordered = any(p['ordered_units'] > 0 for p in products)
    has_possible_stock = any(row.get('quantity') is None or row.get('quantity', 0) > 0 for row in candidates)
    suggestions = []
    if candidates and not has_possible_stock:
        suggestions.append('Matching inventory records show zero stock. Check whether a recent delivery or stock update is missing before reordering.')
    elif candidates:
        suggestions.append('Check the recorded items and their locations before buying. These are possible text matches; verify the exact part and available quantity.')
    if ordered:
        suggestions.append('You have prior purchase records for this item or search. Check whether you still have it, used it, gifted it, or returned it.')
    if products and not ordered:
        suggestions.append('Matching history contains no non-cancelled/non-returned ordered units. It does not establish that you own this item.')
    if not candidates and not products:
        suggestions.append('No match was found in the checked records. Try a shorter product name or another identifier before buying; missing records do not prove you do not own it.')
    suggestions.append('For suggestions about what to build or reuse, tell FIND your goal. Product fit and engineering compatibility still need verification.')
    return {'query': query, 'result': 'review_before_buying' if has_possible_stock or ordered else 'history_only' if products else 'recorded_zero_stock' if candidates else 'no_match_in_checked_records',
            'purchase_match_basis': 'exact_asin' if exact and products else 'text_candidate',
            'inventory_match_basis': 'possible_text_match',
            'inventory_complete': inventory.get('complete', False), 'purchases_complete': purchases['complete'] and purchases['matched_products'] <= 10,
            'purchase_match_count': purchases['matched_products'], 'inventory_match_count': len(inventory.get('items', [])),
            'suggestions': suggestions, 'live_amazon_access': False, 'stock_effect': 'none',
            'note': 'This check uses saved imports and recorded inventory. Ordered quantities are not owned quantities; inventory quantities may be allocated. No purchase is made and no stock is changed.',
            'inventory_matches': candidates, 'purchase_matches': products}
