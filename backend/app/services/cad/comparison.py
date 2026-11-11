"""Conservative exact identity, finite shared stock, no inference or writes."""

from collections import defaultdict
from datetime import datetime, timezone
import hashlib
import json

from .snapshot import Snapshot, requirements


def normalized(value):
    # Do not remove punctuation: AB-12 and AB12 may be different products.
    return str(value or '').strip().casefold()


def count(value):
    # Unknown, fractional, negative and placeholder non-numeric data is not stock.
    return value if type(value) is int and 0 <= value <= 1_000_000_000 else 0


def compare(snapshot: Snapshot, inventory: list[dict], reservations: list[dict], checkouts: list[dict]) -> dict:
    rows, warnings = requirements(snapshot)
    items = {str(i['item_id']): i for i in inventory}
    if len(items) != len(inventory):
        raise ValueError('Inventory changed during paging. Try again.')
    obligations = defaultdict(int)
    blocked = set()
    for entry in reservations + checkouts:
        key = str(entry.get('inventory_item_id') or entry.get('item_id'))
        qty = entry.get('quantity')
        if type(qty) is not int or qty <= 0:
            blocked.add(key)
        else:
            obligations[key] += qty
    remaining = {key: 0 if key in blocked else max(0, count(item.get('quantity')) - obligations[key])
                 for key, item in items.items()}
    by_part, by_name, by_barcode = defaultdict(set), defaultdict(set), defaultdict(set)
    for key, item in items.items():
        for index, field in ((by_part, 'part_number'), (by_name, 'name'), (by_barcode, 'barcode')):
            value = normalized(item.get(field))
            if value:
                index[value].add(key)
    results = []
    for row in rows:
        part = '' if row['part_number_is_default'] else normalized(row['part_number'])
        brand, barcode = normalized(row['manufacturer']), normalized(row['barcode'])
        candidates = set(by_part.get(part, ())) | set(by_barcode.get(barcode, ()))
        if not candidates:
            candidates = set(by_name.get(normalized(row['name']), ()))
        too_many = len(candidates) > 100
        if too_many:
            warnings.append('Too many candidate stock records for ' + row['key'] + '; refine its identifiers.')
            candidates = set()
        exact, probable = [], []
        for key in sorted(candidates):
            item = items[key]
            item_part, item_brand, item_barcode = (normalized(item.get(f)) for f in ('part_number', 'brand', 'barcode'))
            conflict = ((part and item_part and part != item_part)
                        or (brand and item_brand and brand != item_brand)
                        or (barcode and item_barcode and barcode != item_barcode))
            if conflict:
                continue
            barcode_match = bool(barcode and barcode == item_barcode)
            part_match = bool(part and brand and part == item_part and brand == item_brand)
            if barcode_match or part_match:
                exact.append((key, 'Exact barcode' if barcode_match else 'Exact manufacturer and part number'))
            else:
                probable.append(key)
        eligible = not row['needs_review'] and row['procurement_policy'] == 'purchase'
        assigned, matches = 0, []
        for key, evidence in exact:
            take = min(row['required'] - assigned, remaining[key]) if eligible else 0
            remaining[key] -= take
            assigned += take
            matches.append({'item_id': key, 'name': str(items[key].get('name') or ''),
                            'location': str(items[key].get('location') or ''),
                            'assigned': take, 'evidence': evidence})
        needs_review = not eligible or too_many or (not exact and bool(probable))
        status = ('needs_review' if needs_review else 'covered' if assigned == row['required']
                  else 'short' if assigned else 'missing')
        results.append({'key': row['key'], 'name': row['name'], 'part_number': row['part_number'],
                        'manufacturer': row['manufacturer'], 'required': row['required'], 'unit': 'each',
                        'assigned': assigned, 'missing': row['required'] - assigned, 'status': status,
                        'match_type': 'exact' if exact else 'probable' if probable else 'none',
                        'procurement_policy': row['procurement_policy'], 'matches': matches,
                        'possible_matches': len(probable)})
    total = sum(r['required'] for r in results)
    covered = sum(r['assigned'] for r in results)
    fingerprint = hashlib.sha256(json.dumps([inventory, reservations, checkouts], sort_keys=True,
                                            separators=(',', ':'), default=str).encode()).hexdigest()
    return {'schema_version': 1, 'extraction_id': str(snapshot.extraction_id),
            'snapshot_sha256': hashlib.sha256(snapshot.model_dump_json().encode()).hexdigest(),
            'source_verification': 'client_export_unverified',
            'document': snapshot.document.model_dump(), 'revision': snapshot.revision.model_dump(),
            'inventory_as_of': datetime.now(timezone.utc).isoformat(), 'inventory_fingerprint': fingerprint,
            'completeness': 'partial' if warnings or snapshot.completeness == 'partial' else 'complete',
            'warnings': warnings, 'stock_basis': 'recorded_not_physically_verified',
            'consistency': 'read_only_nontransactional_preview',
            'summary': {'required_units': total, 'covered_units': covered,
                        'coverage_percent': round(covered * 100 / total, 1) if total else None,
                        'shortage_lines': sum(r['missing'] > 0 for r in results),
                        'review_lines': sum(r['status'] == 'needs_review' for r in results)},
            'items': results}
