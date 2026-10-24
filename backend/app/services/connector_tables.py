"""Provider-independent deterministic mapping, validation and duplicate review."""
import csv
import io
import re
from decimal import Decimal, InvalidOperation
from difflib import SequenceMatcher
from pathlib import PurePosixPath

from pydantic import ValidationError
from app.schemas.inventory import AddItemRequest
from app.services.spreadsheet_import import parse_import_tables
from app.services.project_kits_service import available_stock, allocate_stock

FIELDS = ('name', 'category', 'quantity', 'location', 'barcode', 'part_number',
          'brand', 'subcategory', 'purchase_source', 'notes')
ALIASES = {
    'name': ('name', 'item name', 'description', 'part description', 'value', 'component'),
    'quantity': ('quantity', 'qty', 'count', 'required', 'amount'),
    'category': ('category', 'type', 'group'),
    'location': ('location', 'space', 'storage', 'shelf'),
    'barcode': ('barcode', 'upc', 'ean', 'gtin'),
    'part_number': ('mpn', 'manufacturer part number', 'part number', 'part #', 'sku', 'product code'),
    'brand': ('brand', 'manufacturer', 'vendor'),
    'subcategory': ('subcategory', 'footprint'),
    'purchase_source': ('purchase source', 'supplier', 'purchase url', 'source'),
    'notes': ('notes', 'comments', 'reference', 'references', 'designator'),
    'exclude': ('dnp', 'do not populate', 'do not fit'),
}


def key(value):
    return re.sub(r'\s+', ' ', str(value or '').strip()).casefold()


def safe_filename(filename):
    return PurePosixPath(filename.replace('\\', '/')).name[:200] or 'inventory.csv'


def parse_source(raw, filename, mime=None):
    ext = filename.lower().rsplit('.', 1)[-1]
    allowed = {
        'csv': {'text/csv', 'text/plain', 'application/csv', 'application/vnd.ms-excel'},
        'xlsx': {'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'},
    }
    if ext not in allowed:
        raise ValueError('Choose CSV or Excel (.xlsx). Legacy .xls files must be saved as .xlsx first.')
    if mime and mime.split(';')[0].lower() not in allowed[ext] | {'application/octet-stream'}:
        raise ValueError('The file type does not match its extension.')
    tables = parse_import_tables(raw, filename, review=True)
    for table in tables:
        headers = table['headers']
        mapping = {}
        for field, aliases in ALIASES.items():
            indices = [i for i, h in enumerate(headers) if key(h) in aliases]
            if len(indices) == 1:
                mapping[field] = indices[0]
        table['suggested_mapping'] = mapping
        table['warnings'] = []
        normalized = [key(h) for h in table['source_headers']]
        if len(set(normalized)) != len(normalized):
            table['warnings'].append('Duplicate headers: choose columns by their numbered positions.')
        if any(not h for h in normalized):
            table['warnings'].append('Some columns have no header. Check their mapping.')
    return tables


def identity_keys(item):
    result = [('identity', *(key(item.get(f)) for f in ('name', 'category', 'location')))]
    if item.get('barcode'):
        result.append(('barcode', key(item['barcode'])))
    if item.get('part_number'):
        result.append(('part', key(item['part_number']), key(item.get('brand'))))
    return result


class DuplicateIndex:
    def __init__(self, inventory=()):
        self.entries = {}
        for item in inventory:
            self.add(item, item)

    def add(self, item, value):
        for identity in identity_keys(item):
            self.entries.setdefault(identity, []).append(value)

    def matches(self, item):
        found, seen = [], set()
        for identity in identity_keys(item):
            for value in self.entries.get(identity, []):
                marker = id(value) if isinstance(value, dict) else value
                if marker not in seen:
                    found.append(value)
                    seen.add(marker)
        return found


def duplicates(item, inventory):
    return [{f: old.get(f) for f in ('item_id', 'name', 'quantity', 'location')}
            for old in DuplicateIndex(inventory).matches(item)]


def review_table(table, *, filename, columns, defaults, inventory, locations, bom=False):
    if any(field not in (*FIELDS, 'exclude') or type(index) is not int or index < 0 or index >= len(table['headers'])
           for field, index in columns.items()):
        raise ValueError('Choose a valid numbered column for each field.')
    if 'name' not in columns and not (bom and 'part_number' in columns):
        raise ValueError('Map the Name column before continuing.')
    if bom and 'quantity' not in columns:
        raise ValueError('Map Required quantity before analyzing a BOM.')
    locations_by_key = {key(row['name']): row for row in locations}
    seen = DuplicateIndex()
    existing = DuplicateIndex(inventory)
    rows = []
    for index, source in enumerate(table['source_rows']):
        errors = []
        item = {field: str(source[col] if col < len(source) and source[col] is not None else '').strip()
                for field, col in columns.items()}
        excluded = bom and key(item.pop('exclude', '')) in ('yes', 'true', '1', 'dnp', 'x')
        item.pop('exclude', None)
        if bom and not item.get('name'):
            item['name'] = item.get('part_number', '')
        for field in ('category', 'location', 'quantity'):
            if field not in columns:
                item[field] = defaults.get(field)
        if any(str(v).startswith('=') for v in item.values()):
            errors.append('Formula cells are not evaluated. Export values and upload again.')
        try:
            quantity = Decimal(str(item.get('quantity', '')))
            if not quantity.is_finite() or quantity != quantity.to_integral_value() or quantity < (1 if bom else 0) or quantity > 100000:
                raise ValueError()
            item['quantity'] = int(quantity)
        except (ValueError, InvalidOperation):
            errors.append('Quantity must be a whole number from %s to 100000.' % (1 if bom else 0))
        for field in ('name', 'category', 'location'):
            if not item.get(field):
                errors.append(f'{field.title()} is required.')
        location = locations_by_key.get(key(item.get('location')))
        if not bom and not location:
            errors.append('Choose an existing Space. Create new Spaces before importing.')
        if location:
            item['location'] = location['name']
            item['space_id'] = location['id']
        try:
            validated = AddItemRequest.model_validate({f: v for f, v in item.items() if f != 'space_id'})
            item.update(validated.model_dump(exclude_none=True))
        except ValidationError as exc:
            errors.extend(f"{e['loc'][0]}: {e['msg']}" for e in exc.errors() if e['loc'][0] != 'quantity')
        if table.get('row_widths', [len(source)] * len(table['source_rows']))[index] != table.get('header_width', len(table['source_headers'])):
            errors.append('The row has a different number of cells from the headers.')
        matches = [{f: old.get(f) for f in ('item_id', 'name', 'quantity', 'location')} for old in existing.matches(item)] if not errors and not bom else []
        repeated = seen.matches(item) if not errors else []
        if not errors:
            seen.add(item, index)
        item['import_data'] = {'filename': filename, 'sheet': table['name'], 'fields': [
            {'name': h, 'value': source[i] if i < len(source) else None}
            for i, h in enumerate(table['source_headers'])]}
        rows.append({'index': index, 'source_row': table.get('row_numbers', [])[index] if table.get('row_numbers') else index + 2,
                     'item': item, 'errors': list(dict.fromkeys(errors)), 'duplicates': matches,
                     'duplicate_rows': repeated, 'excluded': excluded})
    return rows


def match_bom(rows, inventory, reservations):
    """Allocate real available units once; uncertain matches never count as stock."""
    remaining = available_stock(inventory, reservations)
    result = []
    for row in rows:
        if row['errors'] or row.get('excluded'):
            continue
        item = row['item']
        field = 'barcode' if item.get('barcode') else 'part_number' if item.get('part_number') else 'name'
        matches = [i for i in inventory if key(i.get(field)) == key(item.get(field)) and
                   (not item.get('brand') or key(item['brand']) == key(i.get('brand')))]
        identities = {(key(i.get('brand')), key(i.get('part_number')), key(i.get('name'))) for i in matches}
        ambiguous = len(identities) > 1
        suggestions = matches if ambiguous else []
        if not matches:
            suggestions = [i for i in inventory if SequenceMatcher(None, key(item['name']), key(i['name'])).ratio() >= .8][:5]
        confirmed = matches if not ambiguous else []
        available = sum(remaining[i['item_id']] for i in confirmed)
        required = item['quantity']
        allocate_stock(confirmed, remaining, required)
        result.append({'index': row['index'], 'name': item['name'], 'part_number': item.get('part_number'),
                       'required_quantity': required, 'available_quantity': available,
                       'missing_quantity': max(0, required - available),
                       'match_status': 'confirmed' if confirmed else 'review' if suggestions else 'missing',
                       'matches': [{f: i.get(f) for f in ('item_id', 'name', 'location', 'quantity')} for i in confirmed or suggestions]})
    return result


def shortage_csv(rows):
    stream = io.StringIO(newline='')
    writer = csv.writer(stream)
    writer.writerow(['Name', 'Part number', 'Required', 'Available', 'Shortage', 'Match status'])
    def cell(value):
        text = str(value or '')
        return "'" + text if (text.startswith(('\t', '\r', '\n')) or text.lstrip().startswith(('=', '+', '-', '@'))) else text
    for row in rows:
        if row['missing_quantity']:
            writer.writerow([cell(row.get(f)) for f in ('name', 'part_number', 'required_quantity', 'available_quantity', 'missing_quantity', 'match_status')])
    return stream.getvalue()
