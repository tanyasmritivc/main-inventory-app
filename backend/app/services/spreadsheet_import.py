"""Read common inventory files and map familiar columns without a model call."""

import csv
import io
import json
import re

import openpyxl


MAX_IMPORT_BYTES = 10 * 1024 * 1024


def _text(value: object) -> str:
    return '' if value is None else str(value).strip()


def _table(name: str, headers: list, rows) -> dict | None:
    clean_headers = [_text(header) for header in headers]
    clean_rows = [
        [_text(cell) for cell in row]
        for row in rows
        if any(_text(cell) for cell in row)
    ]
    if not any(clean_headers) or not clean_rows:
        return None
    return {'name': name, 'headers': clean_headers, 'rows': clean_rows}


def parse_import_tables(raw: bytes, filename: str) -> list[dict]:
    """Return tables in the shape expected by the existing import route."""
    if not raw:
        raise ValueError('The selected file is empty.')
    if len(raw) > MAX_IMPORT_BYTES:
        raise ValueError('Choose a file smaller than 10 MB.')

    name = filename.lower()
    tables = []
    if name.endswith(('.xlsx', '.xls')):
        try:
            workbook = openpyxl.load_workbook(
                io.BytesIO(raw), read_only=True, data_only=True,
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
        except Exception as exc:
            raise ValueError('This Excel file could not be read.') from exc
    elif name.endswith('.csv'):
        try:
            rows = csv.reader(io.StringIO(raw.decode('utf-8-sig')))
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

    if not tables:
        raise ValueError('No inventory rows were found in this file.')
    return tables


def infer_import_mapping(headers: list[str]) -> dict | None:
    """Map common column names locally; unknown layouts can use the gateway."""
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
    name = column('name', 'item name', 'part name', 'product name', 'title',
                  'description', 'part description', 'product', 'item')
    if not name:
        name = part
    if not name:
        return None

    mapping = {
        'name_columns': [name],
        'quantity_column': column('quantity', 'qty', 'count', 'on hand',
                                  'stock', 'units'),
        'category_column': column('category', 'type', 'class', 'group'),
        'part_number_column': part,
        'subcategory_column': column('subcategory', 'size', 'size type',
                                     'dimension', 'screw length', 'shaft size'),
        'brand_column': column('brand', 'manufacturer', 'vendor', 'supplier'),
        'purchase_source_column': column('purchase source', 'source',
                                         'vendor part number', 'supplier code'),
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
