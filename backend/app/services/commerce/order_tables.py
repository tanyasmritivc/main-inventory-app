"""Read supplier tables without assigning columns by position or executing file contents."""

import io
import json
import re
import zipfile
from pathlib import PurePosixPath

from app.services.spreadsheet_import import (
    MAX_IMPORT_BYTES as MAX_BYTES,
    parse_import_tables,
)

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


def read_tables(content, filename):
    ext = PurePosixPath(filename).suffix.lower()
    if ext not in (".xlsx", ".csv", ".json"):
        raise ValueError("Choose an Excel (.xlsx), CSV, or JSON spreadsheet.")
    if ext == ".xlsx":
        if not zipfile.is_zipfile(io.BytesIO(content)):
            raise ValueError("Choose a valid Excel (.xlsx) workbook.")
        from python_calamine import CalamineWorkbook

        with zipfile.ZipFile(io.BytesIO(content)) as archive:
            entries = archive.infolist()
            if (
                len(entries) > 1000
                or sum(e.file_size for e in entries) > 50 * 1024 * 1024
                or any(e.filename.lower().endswith("vbaproject.bin") for e in entries)
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
                                    value = str(value).zfill(len(cell.number_format))
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
    if ext == ".csv" and (
        content.lstrip().startswith((b"%PDF-", b"PK\x03\x04", b"<html", b"<!DOCTYPE"))
        or any(byte < 32 and byte not in (9, 10, 13) for byte in content)
    ):
        raise ValueError("Choose a CSV containing spreadsheet rows.")
    result = []
    for source in parse_import_tables(content, filename, review=True):
        header = 1
        records = [
            (header, source["source_headers"]),
            *zip(source["row_numbers"], source["rows"]),
        ]
        result.append(table(filename, "Records" if ext == ".json" else "", records))
    return [t for t in result if t]


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
