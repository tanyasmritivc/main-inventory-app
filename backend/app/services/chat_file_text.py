"""Bounded text extraction for chat attachments, without inventory import rules."""
import csv
import json
import re
from datetime import date, datetime, time
from io import BytesIO, StringIO
from zipfile import ZipFile

from defusedxml.ElementTree import fromstring

MAX_EXPANDED = 50 * 1024 * 1024
MAX_ROWS = 5000
MAX_COLUMNS = 200
MAX_SHEETS = 30
WORD = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'


class Excerpt:
    def __init__(self, limit):
        self.limit, self.text, self.truncated = limit, '', False

    def append(self, text):
        if not text:
            return True
        value = ('\n' if self.text else '') + text
        remaining = self.limit - len(self.text)
        self.text += value[:remaining]
        if len(value) > remaining:
            self.truncated = True
            return False
        return True


def decode_text(content):
    encoding = 'utf-16' if content.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig'
    text = content.decode(encoding)
    if '\x00' in text:
        raise ValueError('Binary text file')
    return text


def checked_archive(content):
    archive = ZipFile(BytesIO(content))
    try:
        entries = archive.infolist()
        if len(entries) > 1000 or sum(e.file_size for e in entries) > MAX_EXPANDED:
            raise ValueError('Expanded document exceeds the reading limit')
        if len({e.filename for e in entries}) != len(entries):
            raise ValueError('Duplicate document parts')
        if any(e.flag_bits & 1 or e.filename.lower().endswith('vbaproject.bin') for e in entries):
            raise ValueError('Encrypted or macro-enabled document')
        return archive
    except Exception:
        archive.close()
        raise


def row_text(index, cells):
    def value(cell):
        if isinstance(cell, (date, datetime, time)):
            return cell.isoformat()
        return cell
    return f'Row {index}: ' + json.dumps([value(c) for c in cells], ensure_ascii=False, default=str)


def spreadsheet(content, limit):
    import openpyxl
    with checked_archive(content) as archive:
        if 'xl/workbook.xml' not in archive.namelist():
            raise ValueError('Not an Excel workbook')
    # Preserve stored formulas as text, rather than evaluating expressions or
    # replacing uncached formulas with empty cells. No external links are read.
    workbook = openpyxl.load_workbook(BytesIO(content), read_only=True, data_only=False, keep_links=False)
    out = Excerpt(limit)
    try:
        out.truncated = len(workbook.worksheets) > MAX_SHEETS
        for sheet in workbook.worksheets[:MAX_SHEETS]:
            if (sheet.max_row or 0) > MAX_ROWS or (sheet.max_column or 0) > MAX_COLUMNS:
                out.truncated = True
            started = False
            rows = sheet.iter_rows(max_row=min(sheet.max_row or MAX_ROWS, MAX_ROWS),
                                   max_col=min(sheet.max_column or MAX_COLUMNS, MAX_COLUMNS), values_only=True)
            for index, row in enumerate(rows, 1):
                cells = list(row)
                while cells and cells[-1] is None:
                    cells.pop()
                if not any(c is not None and str(c).strip() for c in cells):
                    continue
                if not started:
                    if not out.append(f'Sheet: {sheet.title} (formulas are stored expressions, not recalculated)'):
                        return out.text, out.truncated
                    started = True
                if not out.append(row_text(index, cells)):
                    return out.text, out.truncated
        return out.text, out.truncated
    finally:
        workbook.close()


def delimited(content, extension, limit):
    text = decode_text(content)
    if extension == 'tsv':
        dialect = csv.excel_tab
    else:
        try:
            dialect = csv.Sniffer().sniff(text[:8192], delimiters=',;\t')
        except csv.Error:
            dialect = csv.excel
    out = Excerpt(limit)
    for index, row in enumerate(csv.reader(StringIO(text), dialect=dialect, strict=True), 1):
        if index > MAX_ROWS:
            out.truncated = True
            break
        if len(row) > MAX_COLUMNS:
            out.truncated = True
        if any(c.strip() for c in row) and not out.append(row_text(index, row[:MAX_COLUMNS])):
            break
    return out.text, out.truncated


def paragraph(node):
    return ''.join(element.text or '' if element.tag == WORD + 't' else
                   '\t' if element.tag == WORD + 'tab' else
                   '\n' if element.tag in (WORD + 'br', WORD + 'cr') else ''
                   for element in node.iter()).strip()


def word_blocks(node, depth=0):
    if depth > 100:
        raise ValueError('Document nesting exceeds the reading limit')
    for child in node:
        if child.tag == WORD + 'p':
            yield paragraph(child)
        elif child.tag == WORD + 'tbl':
            yield 'Table:'
            for index, row in enumerate(child.findall(WORD + 'tr'), 1):
                cells = ['\n'.join(paragraph(p) for p in cell.iter(WORD + 'p'))
                         for cell in row.findall(WORD + 'tc')]
                yield row_text(index, cells)
        else:
            yield from word_blocks(child, depth + 1)


def word_document(content, limit):
    out = Excerpt(limit)
    with checked_archive(content) as archive:
        if 'word/document.xml' not in archive.namelist():
            raise ValueError('Not a Word document')
        parts = ['word/document.xml'] + sorted(name for name in archive.namelist()
            if re.fullmatch(r'word/(?:header\d+|footer\d+|footnotes|endnotes)\.xml', name))
        for name in parts:
            root = fromstring(archive.read(name), forbid_dtd=True)
            if name == 'word/document.xml' and root.find(WORD + 'body') is None:
                raise ValueError('Missing document body')
            started = False
            for text in word_blocks(root):
                if not text:
                    continue
                if not started and name != 'word/document.xml':
                    if not out.append(name.rsplit('/', 1)[-1].removesuffix('.xml') + ':'):
                        return out.text, out.truncated
                started = True
                if not out.append(text):
                    return out.text, out.truncated
    return out.text, out.truncated


def extract_structured(extension, content, limit):
    if extension == 'xlsx':
        return spreadsheet(content, limit)
    if extension == 'docx':
        return word_document(content, limit)
    if extension in ('csv', 'tsv'):
        return delimited(content, extension, limit)
    if extension == 'json':
        text = decode_text(content)
        json.loads(text)  # Accept any JSON document, not only inventory rows.
        return text[:limit], len(text) > limit
    raise ValueError('Unsupported document type')
