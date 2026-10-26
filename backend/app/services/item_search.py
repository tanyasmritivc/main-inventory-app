"""Deterministic, read-only relevance over saved inventory fields.

Formatting differences are safe for identifiers; fuzzy spelling is only for
words without digits. A match is evidence for discovery, never write authority.
"""
import re
import unicodedata

FIELDS = ('name', 'part_number', 'barcode', 'brand', 'category', 'subcategory',
          'notes', 'location', 'purchase_source')
ALIASES = {'adaptor': 'adapter', 'batteries': 'battery', 'shelves': 'shelf',
           'charging': 'charger', 'little': 'small'}


def normalize(value: str) -> str:
    return ''.join(c for c in unicodedata.normalize('NFKD', value.casefold())
                   if not unicodedata.combining(c))


def tokens(value: str) -> list[str]:
    return re.findall(r'[^\W_]+(?:[.][^\W_]+)*', normalize(value))


def word(value: str) -> str:
    return ALIASES.get(value, value[:-1] if len(value) > 3 and value.endswith('s')
                       and not value.endswith(('ss', 'us')) else value)


def compact(value: str) -> str:
    return ''.join(c for c in normalize(value) if c.isalnum())


def one_typo(a: str, b: str) -> bool:
    if min(len(a), len(b)) < 4 or any(c.isdigit() for c in a + b) or abs(len(a) - len(b)) > 1:
        return False
    if len(a) == len(b):
        diffs = [i for i, (x, y) in enumerate(zip(a, b)) if x != y]
        return len(diffs) == 1 or (len(diffs) == 2 and diffs[1] == diffs[0] + 1
                                  and a[diffs[0]] == b[diffs[1]] and a[diffs[1]] == b[diffs[0]])
    short, long = sorted((a, b), key=len)
    return any(long[:i] + long[i + 1:] == short for i in range(len(long)))


def values(row: dict) -> list[str]:
    result = [str(row.get(field) or '') for field in FIELDS]
    result.extend(str(tag) for tag in (row.get('tags') or []) if isinstance(tag, str))
    data = row.get('import_data')
    if isinstance(data, dict):
        for field in data.get('fields') or []:
            if isinstance(field, dict) and isinstance(field.get('value'), (str, int, float)):
                result.append(str(field['value']))
    return result


def score_item(row: dict, query: str) -> int:
    requested = tokens(query)
    if not requested:
        return 1 if not query.strip() else 0
    key = compact(query)
    for field in ('part_number', 'barcode'):
        saved = str(row.get(field) or '')
        identifier = compact(saved)
        if key and identifier == key:
            return 1000
        # Prefixes and components are useful while typing PN-F / F156. No
        # numeric edit distance: F156 can never become F157.
        if len(key) >= 2 and (identifier.startswith(key) or key in tokens(saved)):
            return 800
    fields = values(row)
    saved_words = {variant for value in fields for t in tokens(value) for variant in (t, word(t))}
    score = 600 if normalize(query).strip() == normalize(str(row.get('name') or '')).strip() else 400
    for term in requested:
        canonical = word(term)
        if canonical in saved_words:
            continue
        if len(term) >= 3 and not any(c.isdigit() for c in term) and any(t.startswith(canonical) for t in saved_words):
            score = min(score, 200)
        elif any(one_typo(canonical, t) for t in saved_words):
            score = min(score, 100)
        else:
            return 0
    return score


def match_basis(score: int) -> str:
    return 'likely text match' if score < 400 else 'saved field match'
