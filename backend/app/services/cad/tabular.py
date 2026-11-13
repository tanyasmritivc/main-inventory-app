"""Read-only, bounded flat BOM imports; no inferred hierarchy or stock writes."""
import hashlib
import io
import re
import zipfile
from xml.etree import ElementTree
from openpyxl.utils.cell import range_boundaries, coordinate_to_tuple
from decimal import Decimal, InvalidOperation
from pathlib import PurePosixPath
from uuid import uuid4

import openpyxl
from pydantic import Field, StrictInt

from app.services.spreadsheet_import import parse_import_tables
from .snapshot import Definition, Document, Model, MAX_SNAPSHOT_BYTES

FIELDS = ('name', 'quantity', 'part_number', 'manufacturer', 'barcode', 'unit')
ALIASES = {
    'name': ('name', 'component', 'component name', 'description', 'part description', 'item name'),
    'quantity': ('quantity', 'qty', 'required', 'required quantity', 'quantity required', 'count'),
    'part_number': ('part number', 'part no', 'part #', 'mpn', 'manufacturer part number', 'pn'),
    'manufacturer': ('manufacturer', 'brand', 'mfr'),
    'barcode': ('barcode', 'gtin', 'upc', 'ean'),
    'unit': ('unit', 'units', 'uom', 'unit of measure'),
}


class Mapping(Model):
    name: StrictInt = Field(ge=0, le=199)
    quantity: StrictInt = Field(ge=0, le=199)
    part_number: StrictInt | None = Field(default=None, ge=0, le=199)
    manufacturer: StrictInt | None = Field(default=None, ge=0, le=199)
    barcode: StrictInt | None = Field(default=None, ge=0, le=199)
    unit: StrictInt | None = Field(default=None, ge=0, le=199)


class TabularRevision(Model):
    kind: str = 'tabular_import'
    id: str
    dirty: bool = False
    configuration: str = ''


class Line(Definition):
    required: int = Field(gt=0, le=1_000_000_000)


class TabularSnapshot(Model):
    provider: str = 'spreadsheet'
    extraction_id: str
    document: Document
    revision: TabularRevision
    completeness: str = 'partial'
    warnings: list[str]
    lines: list[Line]

    def requirements(self):
        return [{**line.model_dump(), 'unit': 'each', 'needs_review': False} for line in self.lines], self.warnings


def filename(value):
    return PurePosixPath((value or '').replace('\\', '/')).name[:200]


def tables(raw: bytes, name: str):
    if not raw or len(raw) > MAX_SNAPSHOT_BYTES:
        raise ValueError('Choose a nonempty BOM smaller than 5 MiB.')
    if not name.lower().endswith(('.csv', '.xlsx')):
        raise ValueError('Choose CSV or Excel (.xlsx). Save legacy .xls files as .xlsx first.')
    # Bound declared dimensions before the shared reader creates sparse rows.
    if name.lower().endswith('.xlsx'):
        try:
            with zipfile.ZipFile(io.BytesIO(raw)) as archive:
                entries = archive.infolist()
                if len(entries) > 1000 or sum(e.file_size for e in entries) > 50 * 1024 * 1024:
                    raise ValueError('The expanded workbook is too large.')
                if any(e.flag_bits & 1 or e.filename.lower().endswith('vbaproject.bin') for e in entries):
                    raise ValueError('Use an unencrypted workbook without macros.')
                # Reject entity/DTD declarations independently of optional XML libraries.
                for entry in entries:
                    if entry.filename.endswith(('.xml', '.rels')):
                        content = archive.read(entry).upper()
                        if b'<!DOCTYPE' in content or b'<!ENTITY' in content or b'\x00' in content:
                            raise ValueError('This workbook contains unsupported XML declarations.')
                        if entry.filename.startswith('xl/worksheets/') and entry.filename.endswith('.xml'):
                            bounds = None
                            for _, element in ElementTree.iterparse(io.BytesIO(archive.read(entry))):
                                tag = element.tag.rsplit('}', 1)[-1]
                                if tag == 'dimension':
                                    bounds = range_boundaries(element.attrib.get('ref', ''))
                                elif tag == 'row':
                                    if not element.attrib.get('r', '').isdigit() or not 1 <= int(element.attrib['r']) <= 5001:
                                        raise ValueError('Worksheet row positions exceed the supported range.')
                                elif tag == 'c':
                                    row, col = coordinate_to_tuple(element.attrib.get('r', ''))
                                    if row > 5001 or col > 200 or row < 1 or col < 1:
                                        raise ValueError('Use at most 5,000 data rows and 200 columns per sheet.')
                                    if bounds is None or not (bounds[0] <= col <= bounds[2] and bounds[1] <= row <= bounds[3]):
                                        raise ValueError('Worksheet dimensions are inconsistent. Save the workbook again in Excel.')
                                element.clear()
            book = openpyxl.load_workbook(io.BytesIO(raw), read_only=True, data_only=False, keep_links=False)
            try:
                if len(book.worksheets) > 20:
                    raise ValueError('Choose a workbook with at most 20 sheets.')
                for sheet in book.worksheets:
                    if sheet.max_row is None or sheet.max_column is None or sheet.max_row > 5001 or sheet.max_column > 200:
                        raise ValueError('Use at most 5,000 data rows and 200 columns per sheet.')
            finally:
                book.close()
        except ValueError:
            raise
        except Exception:
            raise ValueError('This Excel file could not be read. Save an unencrypted .xlsx workbook.') from None
    return parse_import_tables(raw, name, review=True)


def preview(raw, name):
    result = []
    for table in tables(raw, name):
        normalized = [re.sub(r'\s+', ' ', h.strip()).casefold() for h in table['headers']]
        mapping = {}
        for field, aliases in ALIASES.items():
            choices = [i for i, h in enumerate(normalized) if h in aliases]
            # Prefer the actual Name column when a CAD export also has Description.
            if field == 'name':
                preferred = [i for i in choices if normalized[i] not in ('description', 'part description')]
                choices = preferred or choices
            if len(choices) == 1:
                mapping[field] = choices[0]
        result.append({'name': table['name'], 'headers': table['headers'], 'row_count': len(table['rows']),
                       'sample': [[str(v)[:200] for v in row] for row in table['rows'][:5]], 'suggested_mapping': mapping})
    return {'file_sha256': hashlib.sha256(raw).hexdigest(), 'sheets': result}


def snapshot(raw, name, sheet_name, mapping, confirmed):
    if not confirmed:
        raise ValueError('Confirm this is a flat parts list with total quantities and no assembly or subtotal rows.')
    mapping = Mapping.model_validate(mapping).model_dump(exclude_none=True)
    if len(set(mapping.values())) != len(mapping):
        raise ValueError('Choose a different column for each field.')
    selected = next((t for t in tables(raw, name) if t['name'] == sheet_name), None)
    if selected is None:
        raise ValueError('Choose a worksheet from this file.')
    if max(mapping.values()) >= len(selected['headers']):
        raise ValueError('A mapped column is outside this worksheet.')
    lines = []
    for number, row, source in zip(selected['row_numbers'], selected['rows'], selected['source_rows']):
        values = {}
        for field, column in mapping.items():
            value = row[column].strip() if column < len(row) else ''
            if value.startswith(('=', '+', '@')):
                raise ValueError(f'Row {number}: replace formulas in mapped columns with plain values.')
            if len(value) > 512:
                raise ValueError(f'Row {number}: {field.replace("_", " ")} exceeds 512 characters.')
            # Excel numeric identifiers can silently lose zeros or precision.
            if field in ('part_number', 'barcode') and column < len(source) and isinstance(source[column], (int, float)):
                raise ValueError(f'Row {number}: format {field.replace("_", " ")} as Text and re-enter its full identifier before importing.')
            values[field] = value
        if not values['name']:
            raise ValueError(f'Row {number}: component name is required. Remove subtotal or non-part rows.')
        try:
            if not re.fullmatch(r'[0-9]+(?:\.0+)?', values['quantity']):
                raise InvalidOperation
            qty = Decimal(values['quantity'])
            if not qty.is_finite() or qty != qty.to_integral_value() or not 0 < qty <= 1_000_000_000:
                raise InvalidOperation
        except InvalidOperation:
            raise ValueError(f'Row {number}: quantity must be a positive whole number, without separators.') from None
        if values.get('unit', '').casefold() not in ('', 'each', 'ea', 'pc', 'pcs', 'piece', 'pieces', 'unit', 'units'):
            raise ValueError(f'Row {number}: only individual units (each) are supported; convert lengths, weights or packs first.')
        lines.append(Line(key=f'row:{number}', name=values['name'], required=int(qty),
                          part_number=values.get('part_number', ''), manufacturer=values.get('manufacturer', ''),
                          barcode=values.get('barcode', ''), part_number_is_default=not bool(values.get('part_number')),
                          procurement_policy='purchase', source_document=sheet_name, source_token=f'row:{number}'))
    digest = hashlib.sha256(raw).hexdigest()
    return TabularSnapshot(extraction_id=str(uuid4()), document=Document(external_id=digest, name=filename(name)),
                           revision=TabularRevision(id=digest, configuration=sheet_name), lines=lines,
                           warnings=['Spreadsheet import: quantities are user-supplied totals for individual parts. CAD hierarchy, suppression and design revision were not verified.',
                                     'Repeated rows are counted separately and share the same available stock. Only the selected worksheet is included.'])
