"""Separate deployment key for encrypted CAD credentials and expiring review receipts."""
import json
import os

from cryptography.fernet import Fernet, InvalidToken
from fastapi import HTTPException


def configured():
    return bool(os.getenv('CAD_SECRET_KEY'))


def cipher():
    try:
        return Fernet(os.environ['CAD_SECRET_KEY'].encode())
    except (KeyError, ValueError):
        raise HTTPException(503, 'CAD connections and saved corrections are not enabled yet.') from None


def seal(purpose, payload):
    return cipher().encrypt(json.dumps({'purpose': purpose, **payload}, separators=(',', ':')).encode()).decode()


def unseal(purpose, token, ttl=None):
    try:
        data = json.loads(cipher().decrypt(token.encode(), ttl=ttl))
        if data.pop('purpose') != purpose:
            raise ValueError()
        return data
    except (InvalidToken, ValueError, KeyError, TypeError):
        raise HTTPException(409, 'This CAD review expired or changed. Compare again.') from None
