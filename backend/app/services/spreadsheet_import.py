"""Read common inventory files and map familiar columns without a model call."""

import csv
import io
import json
import math
import re
import zipfile
from datetime import date, datetime, time

import openpyxl


MAX_IMPORT_BYTES = 10 * 1024 * 1024
MAX_IMPORT_ROWS = 5000
MAX_IMPORT_COLUMNS = 200
MAX_CELL_CHARS = 10000


def _text(value: object) -> str:
    return '' if value is None else str(value).strip()


def _table(name: str, headers: list, rows) -> dict | None:
    source_rows = []
    row_numbers = []
    for number, row in enumerate(rows, 2):
        if number > MAX_IMPORT_ROWS + 1:
            raise ValueError('Choose a file with at most 5,000 rows per sheet.')
        if len(row) > MAX_IMPORT_COLUMNS or any(len(_text(cell)) > MAX_CELL_CHARS for cell in row):
            raise ValueError('A sheet exceeds 200 columns or 10,000 characters per cell.')
        if any(_text(cell) for cell in row):
            source_rows.append(list(row))
            row_numbers.append(number)
    if len(headers) > MAX_IMPORT_COLUMNS or any(len(_text(cell)) > 1000 for cell in headers):
        raise ValueError('The column headers are too large.')
    if not source_rows:
        return None
    # Preserve position: duplicate and unnamed columns must not overwrite values.
    width = max((i + 1 for row in [headers, *source_rows]
                 for i, value in enumerate(row) if _text(value)), default=0)
    source_headers = [
        _header(headers[i]) if i < len(headers) else '' for i in range(width)
    ]
    return {
        'name': name,
        'row_numbers': row_numbers,
        'row_widths': [len(row) for row in source_rows],
        'header_width': len(headers),
        'headers': [h.strip() or f'Column {i + 1}' for i, h in enumerate(source_headers)],
        'rows': [[_text(cell) for cell in row] for row in source_rows],
        'source_headers': source_headers,
        'source_rows': [[_json_value(row[i]) if i < len(row) else None
                         for i in range(width)] for row in source_rows],
    }


def _header(value: object) -> str:
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return '' if value is None else str(value)


def _json_value(value):
    if isinstance(value, (date, datetime, time)):
        return value.isoformat()
    if isinstance(value, float) and not math.isfinite(value):
        raise ValueError('Non-finite numbers are not supported in inventory files.')
    if isinstance(value, dict):
        return {key: _json_value(cell) for key, cell in value.items()}
    if isinstance(value, list):
        return [_json_value(cell) for cell in value]
    return value


def parse_import_tables(raw: bytes, filename: str, *, review: bool = False) -> list[dict]:
    """Return tables in the shape expected by the existing import route."""
    if not raw:
        raise ValueError('The selected file is empty.')
    if len(raw) > MAX_IMPORT_BYTES:
        raise ValueError('Choose a file smaller than 10 MB.')

    name = filename.lower()
    tables = []
    if name.endswith('.xlsx'):
        try:
            with zipfile.ZipFile(io.BytesIO(raw)) as archive:
                entries = archive.infolist()
                if len(entries) > 1000 or sum(entry.file_size for entry in entries) > 50 * 1024 * 1024:
                    raise ValueError('The expanded workbook is too large.')
                if any(entry.flag_bits & 1 for entry in entries):
                    raise ValueError('Password-protected workbooks are not supported.')
                if any(entry.filename.lower().endswith('vbaproject.bin') for entry in entries):
                    raise ValueError('Macro-enabled workbooks are not supported.')
            workbook = openpyxl.load_workbook(
                io.BytesIO(raw), read_only=True, data_only=not review, keep_links=False,
            )
            try:
                for worksheet in workbook.worksheets:
                    rows = worksheet.iter_rows(values_only=True)
                    headers = next(
                        (row for row in rows if any(_text(cell) for cell in row)),
                        None,
                    )
                    if headers is None:
                        continue
                    table = _table(worksheet.title, list(headers), rows)
                    if table:
                        tables.append(table)
            finally:
                workbook.close()
        except ValueError:
            raise
        except Exception as exc:
            raise ValueError('This Excel file could not be read.') from exc
    elif name.endswith('.csv'):
        try:
            text = raw.decode('utf-8-sig')
            if '\x00' in text:
                raise ValueError('CSV files must contain UTF-8 text, not binary data.')
            try:
                dialect = csv.Sniffer().sniff(text[:8192], delimiters=',;\t')
            except csv.Error:
                dialect = csv.excel
            rows = csv.reader(io.StringIO(text), dialect=dialect, strict=True)
            headers = next(rows, None)
            if headers is not None:
                table = _table('Sheet1', headers, rows)
                if table:
                    tables.append(table)
        except (UnicodeDecodeError, csv.Error) as exc:
            raise ValueError('This CSV file could not be read as UTF-8.') from exc
    elif name.endswith('.json'):
        try:
            document = json.loads(raw.decode('utf-8-sig'))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise ValueError('This JSON file could not be read.') from exc
        records = document
        if isinstance(document, dict):
            for key in ('items', 'rows', 'data'):
                if isinstance(document.get(key), list):
                    records = document[key]
                    break
        if not isinstance(records, list) or not all(
            isinstance(row, dict) for row in records
        ):
            raise ValueError('JSON must contain a list of inventory objects.')
        headers = list(dict.fromkeys(key for row in records for key in row))
        table = _table(
            'JSON', headers,
            [[row.get(header) for header in headers] for row in records],
        )
        if table:
            tables.append(table)
    else:
        raise ValueError('Choose an Excel (.xlsx), CSV, or JSON file.')

    if sum(len(table['rows']) for table in tables) > MAX_IMPORT_ROWS or len(tables) > 20:
        raise ValueError('Choose a file with at most 5,000 rows and 20 sheets.')
    if not tables:
        raise ValueError('No inventory rows were found in this file.')
    return tables


def infer_import_mapping(headers: list[str]) -> dict | None:
    """Map familiar columns; arbitrary layouts keep a descriptive sheet-based name."""
    normalized = {
        re.sub(r'[^a-z0-9]', '', str(header).lower()): header
        for header in headers
        if str(header).strip()
    }

    def column(*names: str) -> str | None:
        for name in names:
            found = normalized.get(re.sub(r'[^a-z0-9]', '', name.lower()))
            if found:
                return found
        return None

    part = column('part number', 'part #', 'part no', 'partnumber', 'sku',
                  'item number', 'item #', 'item code', 'product code', 'pn')
    if not part:
        part = next((h for h in headers if re.fullmatch(r'\d+', h)), None)
    name = column('name', 'item name', 'part name', 'product name', 'title',
                  'description', 'part description', 'product', 'item')
    if not name:
        name = part
    derived_name = not name
    if not name:
        qty = column('quantity', 'qty', 'count', 'on hand', 'stock', 'units')
        name = next((h for h in headers if h != qty), headers[0] if headers else None)
    if not name:
        return None

    mapping = {
        'name_columns': [name],
        'derived_name': derived_name,
        'quantity_column': column('quantity', 'qty', 'count', 'on hand',
                                  'stock', 'units'),
        'category_column': column('category', 'type', 'class', 'group'),
        'part_number_column': part,
        'subcategory_column': column('subcategory', 'size', 'size type',
                                     'dimension', 'screw length', 'shaft size'),
        'brand_column': column('brand', 'manufacturer', 'vendor', 'vendor name', 'supplier'),
        'purchase_source_column': column('purchase source', 'source',
                                         'supplier url', 'purchase url', 'product url', 'where to buy'),
        'notes_columns': [],
        'category': 'Supplies',
    }
    notes = column('notes', 'note', 'comments', 'comment', 'specifications')
    if notes:
        mapping['notes_columns'].append(notes)
    description = column('description', 'part description')
    if description and description != name and description not in mapping['notes_columns']:
        mapping['notes_columns'].append(description)

    labels = {
        'name': 'Name', 'part_number': 'Part #', 'subcategory': 'Size/Type',
        'brand': 'Brand', 'purchase_source': 'Source', 'quantity': 'Qty',
        'notes': 'Notes',
    }
    fields = ['name']
    for field, key in (
        ('part_number', 'part_number_column'),
        ('subcategory', 'subcategory_column'),
        ('brand', 'brand_column'),
        ('purchase_source', 'purchase_source_column'),
        ('quantity', 'quantity_column'),
    ):
        if mapping[key]:
            fields.append(field)
    if mapping['notes_columns']:
        fields.append('notes')
    mapping['display_columns'] = [
        {'field': field, 'label': labels[field]} for field in fields
    ]
    return mapping


def build_import_items(tables: list[dict], *, filename: str, location: str) -> list[dict]:
    """Map each sheet independently and retain every original field on each item."""
    items = []
    for table in tables:
        mapping = infer_import_mapping(table['headers']) or {}
        headers = table['headers']
        for row, source in zip(table['rows'], table['source_rows']):
            def value(column):
                if column not in headers:
                    return ''
                index = headers.index(column)
                return row[index] if index < len(row) else ''

            name = ' - '.join(filter(None, (value(c) for c in mapping.get('name_columns', []))))
            if not name:
                name = next((cell for cell in row if cell), '')
            if mapping.get('derived_name'):
                name = f"{table['name']} - {mapping['name_columns'][0]} {name}"
            if not name:
                continue
            try:
                quantity = max(0, int(float(value(mapping.get('quantity_column')) or '1')))
            except (ValueError, OverflowError):
                quantity = 1
            items.append({
                'name': name[:500],
                'category': value(mapping.get('category_column')) or mapping.get('category', 'Supplies'),
                'subcategory': value(mapping.get('subcategory_column')) or None,
                'part_number': value(mapping.get('part_number_column')) or None,
                'brand': value(mapping.get('brand_column')) or None,
                'purchase_source': value(mapping.get('purchase_source_column')) or None,
                'notes': ' | '.join(filter(None, (value(c) for c in mapping.get('notes_columns', [])))) or None,
                'quantity': quantity,
                'location': location,
                'import_data': {
                    'filename': filename,
                    'sheet': table['name'],
                    'fields': [{'name': header, 'value': cell}
                               for header, cell in zip(table['source_headers'], source)],
                },
            })
    return items
