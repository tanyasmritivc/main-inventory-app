import base64
import hashlib
import hmac
import json
from datetime import datetime, timezone, timedelta

from fastapi import HTTPException

from .security import shop_domain

TOPICS = {'app/uninstalled', 'customers/data_request', 'customers/redact', 'shop/redact'}


def verified_event(raw, headers, secret):
    signature = headers.get('x-shopify-hmac-sha256', '')
    expected = base64.b64encode(hmac.new(secret.encode(), raw, hashlib.sha256).digest()).decode()
    if not signature.isascii() or not hmac.compare_digest(expected, signature):
        raise HTTPException(401, 'Invalid Shopify webhook signature.')
    try:
        payload = json.loads(raw)
        topic = headers.get('x-shopify-topic', '')
        if topic not in TOPICS:
            raise ValueError()
        shop = shop_domain(headers.get('x-shopify-shop-domain', ''))
        payload_shop = payload.get('myshopify_domain') if topic == 'app/uninstalled' else payload.get('shop_domain')
        if payload_shop != shop:
            raise ValueError()
        triggered = datetime.fromisoformat(headers.get('x-shopify-triggered-at', '').replace('Z', '+00:00'))
        if triggered.tzinfo is None or triggered > datetime.now(timezone.utc) + timedelta(minutes=5):
            raise ValueError()
        orders = payload.get('orders_to_redact' if topic == 'customers/redact' else 'orders_requested', [])
        if not isinstance(orders, list) or len(orders) > 10000:
            raise ValueError()
        ids = []
        for order in orders:
            if isinstance(order, bool) or not str(order).isascii() or not str(order).isdigit() or len(str(order)) > 30:
                raise ValueError()
            ids.append('gid://shopify/Order/' + str(order))
        request_id = str((payload.get('data_request') or {}).get('id', ''))
        if topic == 'customers/data_request' and (not request_id.isascii() or not request_id.isdigit() or len(request_id) > 30):
            raise ValueError()
    except (ValueError, TypeError, AttributeError):
        raise HTTPException(422, 'Invalid Shopify webhook metadata.') from None
    return {'p_shop': shop, 'p_topic': topic,
            'p_event_hash': hashlib.sha256(topic.encode() + b'\x00' + shop.encode() + b'\x00' + raw).hexdigest(),
            'p_triggered_at': triggered.isoformat(), 'p_order_ids': ids, 'p_request_id': request_id}
