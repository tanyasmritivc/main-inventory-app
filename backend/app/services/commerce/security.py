import base64
import hashlib
import hmac
import json
import re
import secrets
import time

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from fastapi import HTTPException

from .config import settings


def shop_domain(value):
    value = value.lower()
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]{0,61}\.myshopify\.com', value):
        raise HTTPException(422, 'Enter the store hostname, such as example.myshopify.com.')
    return value


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


def _cipher():
    try:
        secret = settings().encryption_key
        key = base64.b64decode(secret.get_secret_value(), validate=True) if secret else b''
        if len(key) != 32:
            raise ValueError()
        return AESGCM(key)
    except (ValueError, TypeError):
        raise HTTPException(503, 'Commerce token encryption is not configured.') from None


def seal(tokens, connection_id):
    nonce = secrets.token_bytes(12)
    value = _cipher().encrypt(nonce, json.dumps(tokens).encode(), connection_id.encode())
    return base64.b64encode(nonce + value).decode()


def unseal(value, connection_id):
    cipher = _cipher()
    try:
        data = base64.b64decode(value, validate=True)
        return json.loads(cipher.decrypt(data[:12], data[12:], connection_id.encode()))
    except Exception:
        raise HTTPException(503, 'Stored commerce credentials cannot be opened. Reconnect this account.') from None


def validate_shopify_callback(params, expected_shop, secret):
    if shop_domain(params.get('shop', '')) != expected_shop:
        raise HTTPException(400, 'The authorization does not match this store.')
    try:
        if abs(time.time() - int(params['timestamp'])) > 600:
            raise ValueError()
    except (KeyError, ValueError):
        raise HTTPException(400, 'Authorization expired. Connect the store again.') from None
    message = '&'.join(f'{key}={params[key]}' for key in sorted(params) if key != 'hmac')
    expected = hmac.new(secret.encode(), message.encode(), hashlib.sha256).hexdigest()
    signature = params.get('hmac', '')
    if not re.fullmatch(r'[0-9a-f]{64}', signature) or not hmac.compare_digest(expected, signature):
        raise HTTPException(400, 'Invalid store authorization signature.')
