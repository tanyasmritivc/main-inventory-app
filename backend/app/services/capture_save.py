"""Save reviewed capture records without name-based merging or unsafe retries."""

from datetime import datetime, timezone
import logging
from uuid import NAMESPACE_URL, uuid4, uuid5

from app.services.catalog_service import verified_catalog_id_for_identity
from app.services.items_repo import _resolve_space_id, invalidate_inventory_cache
from app.services.supabase_client import get_supabase_admin
from app.services.inventory_scope import current_inventory
from app.services.item_photos import retain_capture_original


_FIELDS = (
    'name', 'category', 'subcategory', 'brand', 'part_number', 'quantity',
    'location', 'image_url', 'barcode', 'purchase_source', 'notes', 'tags',
    'confidence', 'import_data',
)
logger = logging.getLogger(__name__)


def _same_record(row: dict, payload: dict) -> bool:
    for key in _FIELDS:
        left, right = row.get(key), payload.get(key)
        if key not in ('quantity', 'confidence'):
            left, right = left or None, right or None
        if isinstance(left, bool) or left != right:
            return False
    return True


def save_capture_items(*, user_id: str, items: list[dict], max_new_items: int | None = None):
    """Return one actual saved receipt or indexed failure for every input.

    A stable client request ID produces an owner-bound item UUID. Repeating a
    request can retrieve that receipt, but cannot increment quantity or replace
    a saved record. Older clients without IDs still get separate capture rows.
    """
    client = get_supabase_admin()
    prepared = []
    failures = []
    seen = set()
    for index, item in enumerate(items):
        request_id = item.get('client_request_id')
        scope = current_inventory.get()
        identity = f'{user_id}:{scope.inventory_id}' if scope else user_id
        item_id = str(uuid5(NAMESPACE_URL, f'findez:capture:v1:{identity}:{request_id}')) if request_id else str(uuid4())
        if item_id in seen:
            failures.append({'index': index, 'reason': 'This capture appears twice. Keep one copy and retry.'})
            continue
        seen.add(item_id)
        payload = {key: item.get(key) for key in _FIELDS}
        for key in ('name', 'category', 'location'):
            payload[key] = str(payload.get(key) or '').strip()
        if not all(payload[key] for key in ('name', 'category', 'location')):
            failures.append({'index': index, 'reason': 'Name, category and location are required.'})
            continue
        payload.update(item_id=item_id, user_id=user_id)
        prepared.append((index, payload))
    if not prepared:
        return [], failures

    ids = [payload['item_id'] for _, payload in prepared]

    def read_receipts():
        rows = client.table('items').select('*').eq('user_id', user_id).in_('item_id', ids).execute().data or []
        return {row['item_id']: row for row in rows if row.get('user_id') == user_id and row.get('item_id') in ids}

    # A failed read aborts before any inserts. Unknown state is never a zero count.
    existing = read_receipts()
    accepted = {}
    pending = []
    spaces = {}
    now = datetime.now(timezone.utc).isoformat()
    for index, payload in prepared:
        old = existing.get(payload['item_id'])
        if old:
            if _same_record(old, payload):
                accepted[index] = old
            else:
                failures.append({'index': index, 'reason': 'This capture was already saved with different details. Open the saved item to edit it.'})
            continue
        if max_new_items is not None and len(pending) >= max_new_items:
            failures.append({'index': index, 'reason': 'Your item limit has been reached. This item has not been saved.'})
            continue
        location = payload['location']
        if location not in spaces:
            spaces[location] = _resolve_space_id(user_id=user_id, location=location)
        if not spaces[location] and location.lower() != 'unsorted':
            failures.append({'index': index, 'reason': 'The destination Space could not be confirmed. Try again.'})
            continue
        payload.update(
            space_id=spaces[location], created_at=now,
            catalog_id=verified_catalog_id_for_identity(brand=payload.get('brand'), part_number=payload.get('part_number')),
        )
        pending.append((index, payload))

    if pending:
        try:
            # Do not blindly repeat an insert after a lost response. Read the
            # stable IDs below to establish which rows actually persisted.
            client.table('items').insert([payload for _, payload in pending]).execute()
        except Exception:
            logger.warning('Capture insert response unavailable; checking saved receipts')
        try:
            saved = read_receipts()
        except Exception:
            logger.warning('Capture receipts unavailable; reporting unconfirmed saves')
            saved = {}
        for index, payload in pending:
            row = saved.get(payload['item_id'])
            if row and _same_record(row, payload):
                accepted[index] = row
            else:
                failures.append({'index': index, 'reason': 'Saving could not be confirmed. Your draft is safe to retry.'})
        invalidate_inventory_cache(user_id)
    # Saving the crop alone is not a completed capture. Keep the stable item ID
    # on a gallery failure, report the draft unconfirmed, and repair on retry.
    for index, row in list(accepted.items()):
        try:
            retain_capture_original(user_id=user_id, item=row,
                                    source_frame_url=items[index].get('source_frame_url'))
        except Exception:
            logger.warning('Original capture photo could not be confirmed')
            accepted.pop(index)
            failures.append({'index': index, 'reason': 'The item was saved, but its original photo could not be confirmed. Retry this draft to finish saving.'})
    return [accepted[index] for index in sorted(accepted)], sorted(failures, key=lambda row: row['index'])
