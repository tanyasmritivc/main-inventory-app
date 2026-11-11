import base64
import hashlib
import hmac
import json
from types import SimpleNamespace
from unittest.mock import patch, MagicMock
from uuid import uuid4

import httpx
import pytest
from fastapi import HTTPException, FastAPI
from fastapi.testclient import TestClient

from app.services.commerce import purchase_email as mail
from app.services.commerce.config import CommerceSettings
from app.api.routes import purchase_email as routes
from app.core.auth import get_current_user, AuthenticatedUser

ORDER = '123-1234567-1234567'
ASIN = 'B012345678'
TEXT = f'Amazon order {ORDER}\nNEMA 17 motor\nASIN {ASIN}\nQuantity: 2'


def test_html_extraction_never_renders_fetches_or_retains_active_content():
    text = mail.plain_email({'subject': 'Order', 'html': '<head>secret</head><script>evil()</script><p>Motor</p><img src="https://evil.test/x"><p>Quantity: 2</p>'})
    assert 'Motor' in text and 'Quantity: 2' in text
    assert all(s not in text for s in ('secret', 'evil', '<img'))
    with pytest.raises(ValueError):
        mail.plain_email({'text': 'a' * (mail.MAX_TEXT + 1)})


def test_html_product_link_retains_asin_without_fetching_or_keeping_tracking_url():
    text = mail.plain_email({'html': '<a href="https://www.amazon.com/dp/B012345678?tracking=private">Motor</a><a href="https://evil.test/dp/Z012345678">Ad</a>'})
    assert 'ASIN B012345678' in text and 'Motor' in text
    assert 'Z012345678' not in text and 'tracking' not in text and 'https://' not in text


def line(**kwargs):
    return {'title': 'NEMA 17 motor', 'order_id': ORDER, 'asin': ASIN, 'quantity': 2,
            'status': 'purchased', 'quantity_quote': 'Quantity: 2', 'evidence_quote': 'NEMA 17 motor\nASIN '+ASIN+'\nQuantity: 2', **kwargs}


def completion(lines):
    return SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=json.dumps({'amazon_purchase_email': True, 'lines': lines})))])


def test_gateway_uses_isolated_no_tool_extraction_and_quoted_evidence():
    with patch.object(mail, 'gateway_completion', return_value=completion([line()])) as gateway:
        assert mail.extract(TEXT, 'message-1')[0]['quantity'] == 2
        assert gateway.call_args.kwargs['tools'] == []
        assert gateway.call_args.kwargs['conversation_id'] == 'purchase-email-message-1'
        assert gateway.call_args.kwargs['messages'][1]['content'] == TEXT


@pytest.mark.parametrize('change', [{'title': 'invented'}, {'asin': 'Z012345678'}, {'order_id': '999-1234567-1234567'}, {'evidence_quote': 'invented'}])
def test_hallucinated_identity_is_never_saved(change):
    with patch.object(mail, 'gateway_completion', return_value=completion([line(**change)])), pytest.raises(ValueError):
        mail.extract(TEXT, 'message')


@pytest.mark.parametrize('quote', ['2-pack', '$2', 'model 2', 'Quantity: 3', None])
def test_pack_size_price_and_unquoted_numbers_remain_unknown(quote):
    with patch.object(mail, 'gateway_completion', return_value=completion([line(quantity_quote=quote)])):
        assert mail.extract(TEXT, 'message')[0]['quantity'] is None


def message(id, *lines):
    return {'id': id, 'result': {'lines': list(lines)}}


def test_shipment_delivery_repeat_and_partial_returns_never_add_to_order_count():
    summary = mail.purchase_summary([message('a', line()), message('b', line()),
        message('c', line(status='delivered', quantity=1)), message('d', line(status='returned', quantity=1))])
    assert len(summary) == 1
    assert summary[0]['ordered_quantity'] == 2
    assert summary[0]['physically_verified'] is False
    assert summary[0]['needs_review'] is True
    assert summary[0]['statuses'] == ['delivered', 'purchased', 'returned']


def test_ambiguous_line_ids_conflicting_quantities_missing_orders_and_asins():
    assert mail.purchase_summary([message('a', line(), line())])[0]['ordered_quantity'] is None
    assert mail.purchase_summary([message('a', line()), message('b', line(quantity=4))])[0]['ordered_quantity'] is None
    assert len(mail.purchase_summary([message('a', line(asin=None)), message('b', line(asin=None))])) == 2
    assert mail.purchase_summary([message('a', line(status='delivered'))])[0]['ordered_quantity'] is None
    assert len(mail.purchase_summary([message('a', line()), message('b', line(order_id='321-1234567-1234567'))])) == 2


def test_worker_transient_error_retries_without_raw_email_or_exception_storage():
    job = {'id': str(uuid4()), 'email_id': str(uuid4()), 'lease': str(uuid4()), 'body_ciphertext': 'encrypted'}
    with patch.object(mail, 'settings'), patch.object(mail, 'rpc', side_effect=[job, {}]) as rpc, \
         patch.object(mail, 'unseal', side_effect=ValueError('PRIVATE MESSAGE')):
        assert mail.process_one()
        assert rpc.call_args.args == ('fail', {'id': job['id'], 'lease': job['lease']})


def client(auth=True):
    app = FastAPI(); app.include_router(routes.router)
    if auth:
        app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(user_id=str(uuid4()))
    return TestClient(app)


def test_gmail_connect_requires_authentication():
    assert client(False).post('/gmail/connect', json={'inventory_id': str(uuid4())}).status_code == 401


def test_foreign_inventory_read_denied_before_mail_storage_query():
    with patch.object(routes.repo, 'authorize', side_effect=HTTPException(403, 'Denied')), \
         patch.object(routes.repo, 'get_supabase_raw') as db:
        assert client().get('/gmail?inventory_id='+str(uuid4())).status_code == 403
        db.assert_not_called()
