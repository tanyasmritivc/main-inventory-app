"""Account-bound capture previews without Review queue writes."""

import base64
import hashlib
import hmac
import json
import time
from uuid import UUID, uuid4

from app.core.config import get_settings
from app.schemas.inventory import ExtractedInventoryItem


PREVIEW_LIFETIME_SECONDS = 86400


class InvalidCapturePreview(ValueError):
    pass


def _key() -> bytes:
    secret = get_settings().supabase_service_role_key
    if not secret:
        raise RuntimeError('Capture preview signing is unavailable')
    return hmac.new(secret.encode(), b'findez.capture.preview.v1', hashlib.sha256).digest()


def preview_uncertain_items(*, user_id: str, source_digest: str, items: list[dict]) -> list[dict]:
    output = []
    for index, raw in enumerate(items):
        item = ExtractedInventoryItem.model_validate(raw).model_dump(exclude_none=True)
        item.pop('review_token', None)
        item.pop('review_id', None)
        item.pop('review_status', None)
        if (item.get('scan_evidence') or {}).get('needs_review'):
            preview_id = str(uuid4())
            data = {'owner': user_id, 'id': preview_id,
                    'source_key': f'photo:{source_digest}:{preview_id}:{index}', 'item': item,
                    'expires': int(time.time()) + PREVIEW_LIFETIME_SECONDS}
            payload = base64.urlsafe_b64encode(json.dumps(data, separators=(',', ':')).encode()).decode().rstrip('=')
            signature = hmac.new(_key(), payload.encode(), hashlib.sha256).hexdigest()
            item = {**item, 'review_id': preview_id, 'review_status': 'preview',
                    'review_token': payload + '.' + signature}
        output.append(item)
    return output


def verify_capture_preview(*, user_id: str, preview_id: str, token: str) -> dict:
    try:
        if len(token) > 40000:
            raise ValueError()
        payload, signature = token.rsplit('.', 1)
        expected = hmac.new(_key(), payload.encode(), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(signature, expected):
            raise ValueError()
        data = json.loads(base64.urlsafe_b64decode(payload + '=' * (-len(payload) % 4)))
        if data['owner'] != user_id or data['id'] != preview_id or data['expires'] <= time.time():
            raise ValueError()
        UUID(data['id'])
        if not (data['item'].get('scan_evidence') or {}).get('needs_review'):
            raise ValueError()
        return data
    except (ValueError, KeyError, TypeError, UnicodeError) as exc:
        raise InvalidCapturePreview('This photo preview is unavailable. Scan the photo again.') from exc
