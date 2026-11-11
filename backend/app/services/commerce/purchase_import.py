"""Bounded Amazon order-history CSV/ZIP import. Never writes physical stock."""
import csv
import hashlib
import io
from datetime import datetime

from fastapi import HTTPException
from pydantic import ValidationError

from .models import SourceRecord

MAX_BYTES = 10 * 1024 * 1024
MAX_EXPANDED = 32 * 1024 * 1024
MAX_ROWS = 10000
REQUIRED = {'order_id', 'line_id', 'title', 'quantity', 'ordered_at'}
OPTIONAL = {'asin', 'status'}
STATUSES = {'purchased', 'shipped', 'delivered', 'cancelled', 'returned', 'unknown'}


def _template(raw):
    if len(raw) > MAX_BYTES:
        raise HTTPException(413, 'Order history must be at most 10 MB.')
    try:
        reader = csv.DictReader(io.StringIO(raw.decode('utf-8-sig')), strict=True)
        headers = reader.fieldnames or []
        if len(headers) != len(set(headers)) or not REQUIRED.issubset(headers) or set(headers) - REQUIRED - OPTIONAL:
            raise ValueError()
        records = []
        seen = set()
        for row in reader:
            if len(records) >= MAX_ROWS or None in row or any(value is None for value in row.values()):
                raise ValueError()
            status = row.get('status') or 'purchased'
            quantity = row['quantity']
            ordered_at = datetime.fromisoformat(row['ordered_at'].replace('Z', '+00:00'))
            if status not in STATUSES or not quantity.isascii() or not quantity.isdigit() or ordered_at.tzinfo is None:
                raise ValueError()
            # Encode the tuple, avoiding delimiter collisions in user-provided IDs.
            import json
            key = json.dumps([row['order_id'], row['line_id']], separators=(',', ':'))
            if not row['line_id'].strip() or not row['order_id'].strip() or key in seen:
                raise ValueError()
            seen.add(key)
            records.append(SourceRecord(kind='purchase_line', external_id=key, order_id=row['order_id'],
                title=row['title'], quantity=int(quantity), asin=row.get('asin') or None,
                ordered_at=ordered_at, source_status=status, evidence='user_file').model_dump(mode='json'))
        if not records:
            raise ValueError()
    except (UnicodeError, ValueError, csv.Error, ValidationError):
        raise HTTPException(422, 'Invalid purchase CSV. Use the documented template, unique order/line IDs, integer quantities, and dates with a timezone.') from None
    return {'sha256': hashlib.sha256(raw).hexdigest(), 'records': records, 'count': len(records),
            'stock_effect': 'none', 'warning': 'These are user-provided purchase claims, not verified physical inventory.'}


def _header(value):
    return ''.join(c for c in value.lower() if c.isalnum())


def _native(raw):
    """Read allowlisted purchase fields; discard addresses/payment data entirely."""
    import json
    import re
    from datetime import timezone
    reader = csv.DictReader(io.StringIO(raw.decode('utf-8-sig')), strict=True)
    columns = [_header(h) for h in (reader.fieldnames or [])]
    if len(columns) != len(set(columns)):
        raise ValueError('duplicate columns')
    aliases = {
        'order_id': ('orderid',), 'title': ('productname', 'title', 'itemname'),
        'quantity': ('quantity', 'quantityordered', 'originalquantity'), 'ordered_at': ('orderdate',),
        'asin': ('asin', 'asinisbn', 'asinisbnproductcode'),
        'line_id': ('orderitemid', 'lineid'), 'status': ('orderstatus', 'status'),
    }
    selected = {key: next((v for v in options if v in columns), None) for key, options in aliases.items()}
    if not all(selected[k] for k in ('order_id', 'title', 'quantity', 'ordered_at')):
        raise ValueError('missing columns')
    output = []
    for index, row in enumerate(reader, 2):
        if index > MAX_ROWS + 1 or None in row or any(v is None for v in row.values()):
            raise ValueError('invalid row')
        values = {_header(k): v.strip() for k, v in row.items()}
        get = lambda key: values.get(selected[key], '')
        order, title, quantity = get('order_id'), get('title'), get('quantity')
        if not order or not title or not re.fullmatch(r'[0-9]+(?:\.0+)?', quantity):
            raise ValueError('missing identity or invalid quantity')
        amount = int(quantity.split('.')[0])
        if amount <= 0:
            raise ValueError('invalid quantity')
        stamp = get('ordered_at')
        try:
            ordered = datetime.fromisoformat(stamp.replace('Z', '+00:00').replace(' UTC', '+00:00'))
        except ValueError:
            ordered = datetime.strptime(stamp, '%m/%d/%Y')
        # Exports with only a date do not supply a timezone. Keep their date at UTC.
        if ordered.tzinfo is None:
            ordered = ordered.replace(tzinfo=timezone.utc)
        asin = get('asin').upper()
        if asin in ('', 'NOT AVAILABLE', 'N/A', 'NULL'):
            asin = None
        elif not re.fullmatch(r'[A-Z0-9]{10}', asin):
            raise ValueError('invalid ASIN')
        status_value = get('status').lower().replace('canceled', 'cancelled')
        status = status_value if status_value in STATUSES else 'unknown'
        # Do not derive identity from row number, quantity or status: those can
        # change between exports. Native rows without IDs group by order/product.
        identity = ('line:' + get('line_id')) if get('line_id') else ('asin:' + asin if asin else 'title:' + hashlib.sha256(title.casefold().encode()).hexdigest())
        key = json.dumps([order, 'amazon:' + identity], separators=(',', ':'))
        record = SourceRecord(kind='purchase_line', external_id=key, order_id=order,
            title=title, quantity=amount, asin=asin, ordered_at=ordered,
            source_status=status, evidence='user_file').model_dump(mode='json')
        # Hash only in memory to distinguish shipment rows and overlapping files.
        fingerprint = hashlib.sha256(json.dumps(values, sort_keys=True).encode()).hexdigest()
        output.append((record, fingerprint))
    if not output:
        raise ValueError('no rows')
    return output


def preview(raw):
    import json
    import zipfile
    from pathlib import PurePosixPath
    if len(raw) > MAX_BYTES:
        raise HTTPException(413, 'Order history must be at most 10 MB.')
    try:
        files = [raw]
        if raw.startswith(b'PK'):
            with zipfile.ZipFile(io.BytesIO(raw)) as archive:
                entries = archive.infolist()
                if len(entries) > 1000:
                    raise ValueError('too many files')
                chosen = [e for e in entries if not e.is_dir() and e.filename.lower().endswith('.csv')
                    and ('orderhistory' in _header(PurePosixPath(e.filename).name)
                         or PurePosixPath(e.filename).name.lower() == 'orders.csv')]
                if not chosen or len(chosen) > 100 or sum(e.file_size for e in chosen) > MAX_EXPANDED:
                    raise ValueError('unsupported archive')
                files = []
                for entry in chosen:
                    if entry.flag_bits & 1 or entry.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED):
                        raise ValueError('unsupported archive')
                    with archive.open(entry) as stream:
                        data = stream.read(MAX_EXPANDED + 1)
                    if len(data) > MAX_EXPANDED:
                        raise ValueError('expanded file too large')
                    files.append(data)
        records, fingerprints = {}, set()
        duplicates, row_count = 0, 0
        for data in files:
            header = next(csv.reader(io.StringIO(data.decode('utf-8-sig'))), [])
            if REQUIRED.issubset(header):
                incoming = [(r, None) for r in _template(data)['records']]
            else:
                incoming = _native(data)
            row_count += len(incoming)
            if row_count > MAX_ROWS:
                raise ValueError('too many rows')
            for record, fingerprint in incoming:
                if fingerprint and fingerprint in fingerprints:
                    duplicates += 1
                    continue
                if fingerprint:
                    fingerprints.add(fingerprint)
                key = record['external_id']
                if key in records:
                    old = records[key]
                    if fingerprint is None:
                        if old != record:
                            raise ValueError('conflicting line IDs')
                        duplicates += 1
                        continue
                    if 'amazon:line:' in key:
                        raise ValueError('conflicting native line IDs')
                    old['quantity'] += record['quantity']
                    if old['source_status'] != record['source_status']:
                        old['source_status'] = 'unknown'
                    SourceRecord(**old)  # Validate the aggregated quantity too.
                else:
                    records[key] = record
        if not records:
            raise ValueError('empty file')
        output = list(records.values())
    except (UnicodeError, ValueError, csv.Error, ValidationError, zipfile.BadZipFile, RuntimeError, NotImplementedError, EOFError):
        raise HTTPException(422, 'Could not read this order history. Upload the Amazon order-history CSV (Order ID, Product Name or Title, Quantity, Order Date), its ZIP, or the FindEZ CSV template. Check dates, positive quantities and unique line IDs. Maximum 10,000 rows; no records were saved.') from None
    return {'sha256': hashlib.sha256(raw).hexdigest(), 'records': output, 'count': len(output),
        'order_count': len({r['order_id'] for r in output}), 'duplicates_in_file': duplicates,
        'stock_effect': 'none', 'warning': 'Previously purchased, not confirmed as currently owned. Returned, cancelled, gifted or used items may no longer be available.'}
