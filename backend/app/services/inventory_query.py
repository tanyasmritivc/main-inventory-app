"""Data-only model tool. It never interprets a question or writes answer prose."""
from datetime import date
from difflib import SequenceMatcher
import re
from uuid import UUID

from app.services.ask_presentation import recorded_quantity
from app.services.items_repo import search_memory_candidates
from app.services.supabase_client import get_supabase_admin

_FIELDS = ('name', 'part_number', 'barcode', 'brand', 'category', 'subcategory', 'notes', 'location')

def _tokens(text: str) -> list[str]:
    return re.findall(r'[a-z0-9]+(?:[.-][a-z0-9]+)*', text.casefold())


def _word(word: str) -> str:
    aliases = {'adaptor': 'adapter', 'chargers': 'charger', 'charging': 'charger',
               'batteries': 'battery', 'shelves': 'shelf', 'little': 'small'}
    return aliases.get(word, word[:-1] if len(word) > 3 and word.endswith('s')
                       and not word.endswith(('ss', 'us')) else word)


def match_item(row: dict, terms: list[str]) -> str | None:
    words = {_word(t) for field_name in _FIELDS for t in _tokens(str(row.get(field_name) or ''))}
    likely = False
    for term in terms:
        if term in words:
            continue
        if not any(c.isdigit() for c in term) and any(word.startswith(term) for word in words if len(term) >= 3):
            likely = True
        elif len(term) >= 4 and not any(c.isdigit() for c in term) and any(
            SequenceMatcher(None, term, word).ratio() >= .8 for word in words if len(word) >= 4
        ):
            likely = True
        else:
            return None
    return 'likely text match' if likely else 'saved field match'


def _filter(row: dict, filters: dict) -> bool:
    for key, value in filters.items():
        if key in ('location', 'category', 'brand'):
            if not all(_word(token) in {_word(t) for t in _tokens(str(row.get(key) or ''))}
                       for token in _tokens(value)):
                return False
        elif key == 'space_id':
            if str(row.get('space_id')) != value:
                return False
        elif key == 'missing':
            field_name = 'image_url' if value == 'image' else value
            if (recorded_quantity(row.get(field_name)) is not None if value == 'quantity'
                    else bool(str(row.get(field_name) or '').strip())):
                return False
        elif key == 'quantity':
            quantity = recorded_quantity(row.get('quantity'))
            op, n = value
            if quantity is None or not {'below': quantity < n, 'under': quantity < n, '<': quantity < n,
                                      'above': quantity > n, 'over': quantity > n, '>': quantity > n,
                                      'at least': quantity >= n, 'at most': quantity <= n,
                                      'exactly': quantity == n, '=': quantity == n}[op]:
                return False
        elif key == 'created':
            try:
                created = date.fromisoformat(str(row.get('created_at') or '')[:10])
                boundary = date.fromisoformat(value[1])
            except ValueError:
                return False
            if not {'since': created >= boundary, 'after': created > boundary,
                    'before': created < boundary}[value[0]]:
                return False
    return True


def query_inventory(*, user_id: str, terms: list[str], filters: dict | None = None) -> dict:
    """Apply explicit model arguments through the current authorized repository."""
    filters = dict(filters or {})
    normalized = []
    for term in terms:
        tokens = _tokens(term)
        if not tokens or any(ord(char) > 127 for char in term):
            raise ValueError('Use inventory_search for this saved name')
        normalized.extend(_word(token) for token in tokens)
    normalized = list(dict.fromkeys(normalized))[:12]
    if ('quantity_op' in filters) != ('quantity_value' in filters):
        raise ValueError('Both quantity fields are required')
    if 'quantity_op' in filters:
        filters['quantity'] = [filters.pop('quantity_op'), filters.pop('quantity_value')]
    if ('created_op' in filters) != ('created_date' in filters):
        raise ValueError('Both date fields are required')
    if 'created_op' in filters:
        date.fromisoformat(filters['created_date'])
        filters['created'] = [filters.pop('created_op'), filters.pop('created_date')]
    if 'space_id' in filters:
        filters['space_id'] = str(UUID(filters['space_id']))
        rows = get_supabase_admin().table('spaces').select('id').eq('id', filters['space_id']).limit(1).execute().data or []
        if not rows:
            return {'error': 'space_unavailable', 'items': [], 'complete': False}
    candidates = normalized + [term[:3] for term in normalized if len(term) >= 4 and not any(char.isdigit() for char in term)]
    for key in ('location', 'brand', 'category'):
        candidates.extend(_tokens(filters.get(key, '')))
    data = search_memory_candidates(user_id=user_id, terms=candidates)
    items = []
    for row in data['items']:
        basis = match_item(row, normalized)
        if basis and _filter(row, filters):
            items.append({**row, '_match_basis': basis})
    counts = [recorded_quantity(row.get('quantity')) for row in items]
    return {'record_count': len(items),
            'known_units': sum(count for count in counts if count is not None),
            'unknown_quantity_records': sum(count is None for count in counts),
            'complete': not data['truncated'], 'truncated': data['truncated'],
            'items': items}
