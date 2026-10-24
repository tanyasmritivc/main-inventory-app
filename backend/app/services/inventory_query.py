"""Data-only model tool. It never interprets a question or writes answer prose."""
from datetime import date
from uuid import UUID

from app.services.ask_presentation import recorded_quantity
from app.services.items_repo import search_memory_candidates
from app.services.supabase_client import get_supabase_admin

from app.services.item_search import tokens as _tokens, word as _word, score_item, match_basis


def match_item(row: dict, terms: list[str]) -> str | None:
    score = score_item(row, ' '.join(terms))
    return match_basis(score) if score else None


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
        if not tokens:
            raise ValueError('Use inventory_search for this saved name')
        normalized.append(term)
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
    data = search_memory_candidates(user_id=user_id, terms=normalized)
    items = []
    for row in data['items']:
        basis = match_item(row, normalized)
        if basis and _filter(row, filters):
            items.append({**row, '_match_basis': basis})
    items.sort(key=lambda row: score_item(row, ' '.join(normalized)), reverse=True)
    counts = [recorded_quantity(row.get('quantity')) for row in items]
    return {'record_count': len(items),
            'known_units': sum(count for count in counts if count is not None),
            'unknown_quantity_records': sum(count is None for count in counts),
            'complete': not data['truncated'], 'truncated': data['truncated'],
            'items': items}
