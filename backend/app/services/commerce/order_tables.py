"""Read supplier tables without assigning columns by position or executing file contents."""

import csv
import io
import json
import re
from html.parser import HTMLParser
import zipfile
from pathlib import PurePosixPath

from defusedxml.ElementTree import fromstring

FIELDS = {
    "order": (
        "order",
        "order id",
        "order number",
        "order no",
        "order #",
        "purchase order",
        "po number",
    ),
    "line": ("line", "line id", "line number", "order line"),
    "sku": (
        "sku",
        "product sku",
        "product code",
        "part number",
        "item number",
        "item #",
        "vendor sku",
    ),
    "name": (
        "name",
        "description",
        "product name",
        "item name",
        "product",
        "part description",
    ),
    "quantity": (
        "quantity",
        "qty",
        "ordered quantity",
        "quantity ordered",
        "qty ordered",
    ),
    "pack": ("units per pack", "pack size", "units per package", "pieces per pack"),
    "status": ("status", "order status", "line status"),
}
MAX_BYTES = 4 * 1024 * 1024
MAX_ROWS = 500
MAX_COLUMNS = 200


def norm(value):
    return re.sub(r"[\W_]+", "", str(value).casefold().replace("#", " number "))


def suggest(cells):
    result = {}
    for field, aliases in FIELDS.items():
        options = {norm(alias) for alias in aliases}
        positions = [i for i, cell in enumerate(cells) if norm(cell) in options]
        if len(positions) == 1:
            result[field] = positions[0]
    if "quantity" in result:
        column = norm(cells[result["quantity"]])
        other_quantities = {
            "qtyshipped",
            "shippedqty",
            "shippedquantity",
            "quantityshipped",
            "qtyreceived",
            "receivedqty",
            "quantityreceived",
            "qtybackordered",
            "backorderedqty",
        }
        if column in ("qty", "quantity") and any(
            norm(c) in other_quantities for c in cells
        ):
            result.pop("quantity")
    return result


def display(value):
    if isinstance(value, (dict, list)):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return "" if value is None else str(value)


def table(filename, sheet, records):
    rows = []
    for number, cells in records:
        if len(cells) > MAX_COLUMNS or any(len(display(v)) > 10000 for v in cells):
            raise ValueError("A source table exceeds the column or cell-size limit.")
        if any(v is not None and str(v).strip() for v in cells):
            rows.append({"number": number, "cells": [display(v) for v in cells]})
        if len(rows) > MAX_ROWS + 30:
            raise ValueError("Use up to 500 order lines per import.")
    if not rows:
        return None
    header = max(
        range(min(25, len(rows))), key=lambda i: len(suggest(rows[i]["cells"]))
    )
    return {
        "file": filename,
        "sheet": sheet,
        "records": rows,
        "header": rows[header]["number"],
        "suggestions": suggest(rows[header]["cells"]),
    }


class HTMLTables(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tables, self.row, self.cell = [], None, None
        self.depth = 0
        self.ambiguous = False

    def handle_starttag(self, tag, attrs):
        if tag == "table":
            self.depth += 1
            if self.depth == 1:
                self.tables.append([])
        elif self.depth == 1:
            if tag == "tr":
                self.row = []
            elif tag in ("td", "th") and self.row is not None:
                spans = dict(attrs)
                if spans.get("colspan", "1") != "1" or spans.get("rowspan", "1") != "1":
                    self.ambiguous = True
                self.cell = []

    def handle_data(self, data):
        if self.depth == 1 and self.cell is not None:
            self.cell.append(data)

    def handle_endtag(self, tag):
        if tag == "table":
            self.depth = max(0, self.depth - 1)
        elif self.depth == 1 and tag in ("td", "th") and self.cell is not None:
            self.row.append("".join(self.cell))
            self.cell = None
        elif self.depth == 1 and tag == "tr" and self.row is not None:
            self.tables[-1].append(self.row)
            self.row = None


def document_tables(content, filename, ext):
    if ext in (".html", ".htm"):
        parser = HTMLTables()
        parser.feed(content.decode("utf-8-sig"))
        return (
            []
            if parser.ambiguous
            else [(f"Table {i}", grid) for i, grid in enumerate(parser.tables, 1)]
        )
    if ext == ".docx":
        from app.services.chat_file_text import checked_archive, WORD
        from defusedxml.ElementTree import fromstring

        with checked_archive(content) as archive:
            root = fromstring(archive.read("word/document.xml"))
        if any(
            n.tag in (WORD + "gridSpan", WORD + "vMerge", WORD + "gridBefore")
            for n in root.iter()
        ):
            return []
        return [
            (
                f"Table {i}",
                [
                    [
                        "".join(n.text or "" for n in cell.iter(WORD + "t"))
                        for cell in row.findall(WORD + "tc")
                    ]
                    for row in grid.findall(WORD + "tr")
                ],
            )
            for i, grid in enumerate(root.iter(WORD + "tbl"), 1)
        ]
    import pdfplumber
    from pdfminer.pdfparser import PDFSyntaxError
    from pdfplumber.utils.exceptions import PdfminerException, MalformedPDFException

    try:
        with pdfplumber.open(io.BytesIO(content)) as pdf:
            if len(pdf.pages) > 80:
                raise ValueError("Choose a PDF of up to 80 pages.")
            return [
                (f"Page {n}, table {i}", grid)
                for n, page in enumerate(pdf.pages, 1)
                for i, grid in enumerate(page.extract_tables(), 1)
            ]
    except (PDFSyntaxError, PdfminerException, MalformedPDFException):
        raise ValueError("The PDF could not be read.") from None


def object_tables(content, filename):
    def unique(pairs):
        if len(dict(pairs)) != len(pairs):
            raise ValueError("Repeated JSON keys cannot safely be assigned to columns.")
        return dict(pairs)

    doc = json.loads(content.decode("utf-8-sig"), object_pairs_hook=unique)
    found = []

    def walk(value, path, depth=0):
        if depth > 12 or len(found) > 32:
            raise ValueError("The structured order file is too large or deeply nested.")
        if isinstance(value, list):
            if value and all(isinstance(v, dict) for v in value):
                keys = list(
                    dict.fromkeys(
                        k
                        for row in value
                        for k, v in row.items()
                        if not isinstance(v, (list, dict))
                    )
                )
                if keys:
                    grid = [keys, *[[r.get(k) for k in keys] for r in value]]
                    found.append(table(filename, path or "Records", enumerate(grid, 1)))
                for n, row in enumerate(value):
                    for k, v in row.items():
                        if isinstance(v, (list, dict)):
                            walk(v, path + "/" + str(n + 1) + "/" + k, depth + 1)
        elif isinstance(value, dict):
            for k, v in value.items():
                if isinstance(v, (dict, list)):
                    walk(v, path + "/" + k, depth + 1)

    walk(doc, "")
    return [t for t in found if t]


def xml_tables(content, filename):
    root = fromstring(content)
    result = []
    for index, node in enumerate(root.iter()):
        if index > 20000 or len(result) > 32:
            raise ValueError("The XML document is too large.")
        groups = {}
        for child in node:
            if len(child) and all(not len(field) for field in child):
                groups.setdefault(child.tag, []).append(child)
        for tag, children in groups.items():
            if not children or not any(len(child) > 1 for child in children):
                continue
            keys = list(dict.fromkeys(f.tag for child in children for f in child))
            # Repeated keys in one record cannot be aligned safely.
            if any(len(set(f.tag for f in child)) != len(child) for child in children):
                continue
            grid = [
                keys,
                *[[child.findtext(k, default="") for k in keys] for child in children],
            ]
            result.append(table(filename, f"{index+1}/{tag}", enumerate(grid, 1)))
    return result


def read_tables(content, filename):
    """Unknown containers remain manual evidence. A recognized broken table fails visibly."""
    ext = PurePosixPath(filename).suffix.lower()
    if ext not in (
        ".zip",
        ".xlsx",
        ".xlsm",
        ".xlsb",
        ".ods",
        ".docx",
    ) and zipfile.is_zipfile(io.BytesIO(content)):
        with zipfile.ZipFile(io.BytesIO(content)) as container:
            names = set(container.namelist())
        if "xl/workbook.xml" in names:
            ext = ".xlsx"
        elif "xl/workbook.bin" in names:
            ext = ".xlsb"
        elif "word/document.xml" in names:
            ext = ".docx"
        elif "content.xml" in names and "META-INF/manifest.xml" in names:
            ext = ".ods"
    if ext == ".xml":
        return xml_tables(content, filename)
    if ext in (".html", ".htm", ".docx", ".pdf") or content.startswith(b"%PDF-"):
        grids = document_tables(content, filename, ext)
        return [
            t
            for sheet, grid in grids
            if (t := table(filename, sheet, enumerate(grid, 1)))
        ]
    if ext in (".xlsx", ".xlsm", ".xlsb", ".ods", ".xls") or content.startswith(
        b"\xd0\xcf\x11\xe0"
    ):
        from python_calamine import CalamineWorkbook

        if zipfile.is_zipfile(io.BytesIO(content)):
            with zipfile.ZipFile(io.BytesIO(content)) as archive:
                entries = archive.infolist()
                if (
                    len(entries) > 1000
                    or sum(e.file_size for e in entries) > 32 * 1024 * 1024
                    or any(e.flag_bits & 1 for e in entries)
                ):
                    raise ValueError(
                        "This workbook exceeds the supported size or is encrypted."
                    )
        try:
            with CalamineWorkbook.from_filelike(io.BytesIO(content)) as book:
                if len(book.sheet_names) > 32:
                    raise ValueError("Choose a workbook with up to 32 sheets.")
                result = []
                bounds = {}
                for name in book.sheet_names:
                    sheet = book.get_sheet_by_name(name)
                    if sheet.end is None:
                        continue
                    if sheet.end[0] > 5000 or sheet.end[1] >= MAX_COLUMNS:
                        raise ValueError(
                            "Worksheet dimensions exceed the supported range."
                        )
                    bounds[name] = sheet.end
                    if ext not in (".xlsx", ".xlsm"):
                        result.append(
                            table(
                                filename,
                                name,
                                enumerate(sheet.to_python(skip_empty_area=False), 1),
                            )
                        )
                if ext in (".xlsx", ".xlsm"):
                    # Text SKU values and explicit zero-padding in Excel both carry identity.
                    from openpyxl import load_workbook

                    xml_book = load_workbook(
                        io.BytesIO(content),
                        read_only=True,
                        data_only=False,
                        keep_links=False,
                    )
                    try:
                        for name, (last_row, last_col) in bounds.items():
                            records = []
                            for number, cells in enumerate(
                                xml_book[name].iter_rows(
                                    max_row=last_row + 1, max_col=last_col + 1
                                ),
                                1,
                            ):
                                values = []
                                for cell in cells:
                                    value = cell.value
                                    if type(value) is int and re.fullmatch(
                                        r"0{2,}", cell.number_format or ""
                                    ):
                                        value = str(value).zfill(
                                            len(cell.number_format)
                                        )
                                    values.append(value)
                                records.append((number, values))
                            result.append(table(filename, name, records))
                    finally:
                        xml_book.close()
                return [t for t in result if t]
        except ValueError:
            raise
        except Exception:
            raise ValueError(
                "The spreadsheet could not be read. Check for encryption or file damage."
            ) from None
    if not ext or ext not in (".csv", ".tsv", ".tab", ".txt", ".psv", ".json"):
        # Some purchasing systems export an extensionless or vendor-specific text file.
        sample = content[:8192]
        if (
            not any(byte < 32 and byte not in (9, 10, 13) for byte in sample)
            and b"\n" in sample
        ):
            try:
                csv.Sniffer().sniff(sample.decode("utf-8-sig"), delimiters=",;\t|")
                ext = ".txt"
            except (UnicodeError, csv.Error):
                pass
    if ext in (".csv", ".tsv", ".tab", ".txt", ".psv"):
        try:
            text = content.decode(
                "utf-16"
                if content.startswith((b"\xff\xfe", b"\xfe\xff"))
                else "utf-8-sig"
            )
        except UnicodeError:
            # Windows exports commonly use a single-byte encoding. Reject binary CSV.
            text = content.decode("cp1252", errors="strict")
        if "\x00" in text:
            raise ValueError("This text file contains binary data.")
        try:
            dialect = csv.Sniffer().sniff(text[:8192], delimiters=",;\t|")
            delimiter = dialect.delimiter
        except csv.Error:
            if ext == ".txt":
                return []
            # Preambles and summary rows can have different widths.
            preferred = {".csv": ",", ".tsv": "\t", ".tab": "\t", ".psv": "|"}.get(
                ext, ","
            )
            delimiter = max(
                [preferred, *[x for x in ",;\t|" if x != preferred]],
                key=lambda d: sum(d in line for line in text.splitlines()[:30]),
            )
        return [
            t
            for t in [
                table(
                    filename,
                    "",
                    enumerate(
                        csv.reader(
                            io.StringIO(text, newline=""),
                            delimiter=delimiter,
                            strict=True,
                        ),
                        1,
                    ),
                )
            ]
            if t
        ]
    if ext == ".json":
        return object_tables(content, filename)
    return []


def check_mapping(t, header, mapping):
    records = t["records"]
    row = next((r for r in records if r["number"] == header), None)
    if header != 0 and row is None:
        raise ValueError("Select a header row from this sheet.")
    width = max(len(r["cells"]) for r in records)
    if set(mapping) - FIELDS.keys() or any(
        type(i) is not int or not 0 <= i < width for i in mapping.values()
    ):
        raise ValueError("A mapped column is outside the selected sheet.")
    if len(set(mapping.values())) != len(mapping):
        raise ValueError("Choose a distinct source column for each field.")
    return row["cells"] if row else []


def map_rows(t, header, mapping):
    check_mapping(t, header, mapping)
    result = []
    for record in t["records"]:
        if record["number"] <= header:
            continue
        cells = record["cells"]
        values = {
            k: (
                cells[i].strip()
                if (i := mapping.get(k)) is not None and i < len(cells)
                else ""
            )
            for k in FIELDS
        }
        values["status"] = values["status"].lower() or "unknown"
        values["line"] = values["line"] or values["sku"]
        result.append(
            {
                **values,
                "source_file": t["file"],
                "source_sheet": t["sheet"],
                "source_row": record["number"],
            }
        )
    return result
