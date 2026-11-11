"""Explicit consumer CSV template; not an Amazon consumer-account API."""
import csv
import hashlib
import io
from datetime import datetime

from fastapi import HTTPException
from pydantic import ValidationError

from .models import SourceRecord

MAX_BYTES = 2 * 1024 * 1024
REQUIRED = {'order_id', 'line_id', 'title', 'quantity', 'ordered_at'}
OPTIONAL = {'asin', 'status'}
STATUSES = {'purchased', 'shipped', 'delivered', 'cancelled', 'returned', 'unknown'}


def preview(raw):
    if len(raw) > MAX_BYTES:
        raise HTTPException(413, 'Purchase CSV must be at most 2 MB.')
    try:
        reader = csv.DictReader(io.StringIO(raw.decode('utf-8-sig')), strict=True)
        headers = reader.fieldnames or []
        if len(headers) != len(set(headers)) or not REQUIRED.issubset(headers) or set(headers) - REQUIRED - OPTIONAL:
            raise ValueError()
        records = []
        seen = set()
        for row in reader:
            if len(records) >= 5000 or None in row or any(value is None for value in row.values()):
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
