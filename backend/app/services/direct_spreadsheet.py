"""Automatic imports retain every source row and field; never silently skip."""
import json
import re
from decimal import Decimal, InvalidOperation

from pydantic import ValidationError
from app.schemas.inventory import AddItemRequest
from app.services.connector_tables import ALIASES


def normalized(value):
    return re.sub(r'[^a-z0-9]', '', str(value).casefold())


EXTRA_ALIASES = {
    'name': ('product name', 'part name', 'title', 'product', 'item'),
    'quantity': ('on hand', 'stock', 'units', 'stock quantity', 'qty on hand', 'quantity on hand'),
    'part_number': ('part no', 'partnumber', 'pn', 'item number', 'item #', 'item code'),
    'category': ('class',), 'brand': ('vendor name', 'supplier'),
    'subcategory': ('size', 'size type', 'dimension', 'screw length', 'shaft size'),
    'purchase_source': ('supplier url', 'product url', 'where to buy'),
    'notes': ('note', 'comment', 'specifications'),
}


def automatic_rows(tables, *, filename, destination):
    result = []
    for table in tables:
        columns = {}
        for field, aliases in ALIASES.items():
            if field in ('location', 'exclude'):
                continue
            # Prefer the most explicit alias (Name before Description). All
            # other columns remain in import_data, including duplicate headers.
            for alias in (*aliases, *EXTRA_ALIASES.get(field, ())):
                hits = [i for i, h in enumerate(table['source_headers']) if normalized(h) == normalized(alias)]
                if len(hits) > 1 and field == 'quantity':
                    raise ValueError(f"{table['name']}: multiple quantity columns have the same heading. Give them distinct headings before importing. Nothing was saved.")
                if len(hits) == 1:
                    columns[field] = hits[0]
                    break
        for n, source in enumerate(table['source_rows']):
            number = table.get('row_numbers', [])[n] if table.get('row_numbers') else n + 2
            def text(value):
                if isinstance(value, (dict, list)):
                    return json.dumps(value, ensure_ascii=False)
                return '' if value is None else str(value).strip()
            values = list(source)
            computed = table.get('computed_rows', [[]] * len(table['source_rows']))[n]
            for col, value in enumerate(values):
                if isinstance(value, str) and value.startswith('=') and col < len(computed) and computed[col] is not None:
                    values[col] = computed[col]
            item = {field: text(values[col]) if col < len(values) else '' for field, col in columns.items()}
            item['name'] = item.get('name') or item.get('part_number') or f"{table['name']} — row {number}"
            item['category'] = item.get('category') or 'Supplies'
            item['location'] = destination['name']
            try:
                qty = Decimal(item.get('quantity') or '1')
                if not qty.is_finite() or qty != qty.to_integral_value() or not 0 <= qty <= 100000:
                    raise ValueError()
                item['quantity'] = int(qty)
            except (ValueError, InvalidOperation):
                raise ValueError(f"{table['name']}, row {number}: Quantity must be a whole number from 0 to 100000. Nothing was saved.") from None
            if any(value.startswith('=') for value in item.values() if isinstance(value, str)):
                raise ValueError(f"{table['name']}, row {number}: export formula results as values before importing. Nothing was saved.")
            try:
                item = AddItemRequest.model_validate(item).model_dump(exclude_none=True)
            except ValidationError as exc:
                field = exc.errors()[0]['loc'][0]
                raise ValueError(f"{table['name']}, row {number}: {field} does not fit the item field. Correct that cell before importing. Nothing was saved.") from None
            item['space_id'] = destination['id']
            item['import_data'] = {'filename': filename, 'sheet': table['name'], 'row': number,
                                   'fields': [{'name': h, 'value': source[i] if i < len(source) else None,
                                               **({'computed_value': values[i]} if i < len(source) and values[i] != source[i] else {})}
                                              for i, h in enumerate(table['source_headers'])]}
            result.append({'index': len(result), 'source_row': number, 'item': item,
                           'errors': [], 'duplicates': [], 'duplicate_rows': [], 'excluded': False})
    if not result:
        raise ValueError('No inventory rows were found. Nothing was saved.')
    return result
