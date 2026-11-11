import io
import json
import zipfile
from unittest.mock import patch
from uuid import uuid4

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from app.api.routes import commerce
from app.core.auth import AuthenticatedUser, get_current_user
from app.services.commerce.config import CommerceSettings
from app.services.commerce.purchase_import import preview, MAX_BYTES

NATIVE = b'Order ID,Product Name,ASIN,Quantity,Order Date,Order Status,Shipping Address,Payment Instrument Type\n113-1,Motor,B000000001,2,2026-11-01,Delivered,PRIVATE ADDRESS,PRIVATE CARD\n'


def archive(files):
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, 'w', zipfile.ZIP_DEFLATED) as z:
        for name, data in files.items():
            z.writestr(name, data)
    return stream.getvalue()


def test_native_date_only_and_private_fields():
    result = preview(NATIVE)
    assert result['count'] == result['order_count'] == 1
    r = result['records'][0]
    assert r['quantity'] == 2 and r['ordered_at'] == '2026-11-01T00:00:00Z'
    assert r['source_status'] == 'delivered' and r['physically_verified'] is False
    assert r['evidence'] == 'user_file' and result['stock_effect'] == 'none'
    assert 'PRIVATE' not in json.dumps(result)


def test_native_export_reordering_status_and_quantity_preserve_identity():
    before = preview(NATIVE)['records'][0]
    after = preview(NATIVE.replace(b',2,', b',1.0,').replace(b'Delivered', b'Returned'))['records'][0]
    assert before['external_id'] == after['external_id']
    assert after['quantity'] == 1 and after['source_status'] == 'returned'


def test_native_split_shipments_aggregate_without_guessing_status():
    raw = NATIVE.replace(b'Payment Instrument Type', b'Ship Date')
    second = raw.splitlines()[1].replace(b'PRIVATE CARD', b'2026-11-04').replace(b'Delivered', b'Shipped')
    result = preview(raw + second + b'\n')
    assert result['count'] == 1 and result['records'][0]['quantity'] == 4
    assert result['records'][0]['source_status'] == 'unknown'


def test_zip_ignores_unrelated_private_files_and_deduplicates_overlap():
    raw = archive({'Retail.OrderHistory/Retail.OrderHistory.1.csv': NATIVE,
                   'Retail.OrderHistory/Retail.OrderHistory.2.csv': NATIVE,
                   'Addresses.csv': b'private irrelevant file', '../passwords.txt': b'not extracted'})
    result = preview(raw)
    assert result['count'] == 1 and result['duplicates_in_file'] == 1
    assert result['records'][0]['quantity'] == 2


@pytest.mark.parametrize('raw', [b'PKnot-a-zip', b'', NATIVE.replace(b',2,', b',-1,'),
    NATIVE.replace(b',2,', b',1.5,'), NATIVE.replace(b'2026-11-01', b'nonsense'),
    NATIVE.replace(b'Order ID', b'Unknown'), NATIVE.replace(b'Product Name', b'Order ID'),
    NATIVE.replace(b',Motor,', b',,'), archive({'private.csv': NATIVE})])
def test_bad_file_fails_without_echoing_private_rows(raw):
    with pytest.raises(HTTPException) as e:
        preview(raw)
    assert e.value.status_code == 422 and 'PRIVATE' not in e.value.detail


def test_zip_bomb_and_file_limit_rejected():
    with pytest.raises(HTTPException):
        preview(archive({'Retail.OrderHistory.1.csv': b'A' * (33 * 1024 * 1024)}))
    with pytest.raises(HTTPException) as e:
        preview(b'A' * (MAX_BYTES + 1))
    assert e.value.status_code == 413


def test_native_aliases_and_unknown_order_status():
    raw = NATIVE.replace(b'Product Name', b'Title').replace(b'ASIN,', b'ASIN/ISBN,').replace(b'Delivered', b'Closed')
    assert preview(raw)['records'][0]['source_status'] == 'unknown'


def test_purchase_only_flag_does_not_enable_other_integrations():
    cfg = CommerceSettings(enabled=False, purchase_import_enabled=True)
    cfg.require('amazon_consumer'); cfg.require()
    for provider in ['shopify', 'amazon_seller']:
        with pytest.raises(HTTPException): cfg.require(provider)
    with pytest.raises(HTTPException): cfg.require_gmail()


def test_preview_checks_access_before_read_and_has_no_writes():
    actor, inventory = str(uuid4()), str(uuid4())
    app = FastAPI(); app.include_router(commerce.router)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(user_id=actor)
    client = TestClient(app)
    with patch.object(commerce, 'settings', return_value=CommerceSettings(purchase_import_enabled=True)), \
         patch.object(commerce.repo, 'authorize') as access, patch.object(commerce.repo, 'transition') as write:
        result = client.post('/commerce/purchase-file/preview', files={'file': ('history.csv', NATIVE)}, data={'inventory_id': inventory})
        assert result.status_code == 200 and result.json()['committed'] is False
        access.assert_called_once(); write.assert_not_called()
        access.side_effect = HTTPException(403, 'No access')
        result = client.post('/commerce/purchase-file/preview', files={'file': ('history.csv', NATIVE)}, data={'inventory_id': inventory})
        assert result.status_code == 403
        write.assert_not_called()
    app.dependency_overrides.clear()
    assert client.post('/commerce/purchase-file/preview', files={'file': ('history.csv', NATIVE)}, data={'inventory_id': inventory}).status_code == 401
