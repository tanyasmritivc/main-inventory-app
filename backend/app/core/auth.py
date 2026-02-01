from __future__ import annotations

import time
from dataclasses import dataclass

import httpx
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import jwt

from app.core.config import get_settings
from app.core.errors import unauthorized
from app.services.supabase_client import get_supabase_admin


bearer_scheme = HTTPBearer(auto_error=False)


@dataclass
class AuthenticatedUser:
    user_id: str
    first_name: str | None = None


class JWKSCache:
    def __init__(self) -> None:
        self._jwks: dict | None = None
        self._fetched_at: float | None = None

    async def get(self, jwks_url: str) -> dict:
        now = time.time()
        if self._jwks is not None and self._fetched_at is not None and (now - self._fetched_at) < 3600:
            return self._jwks

        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(jwks_url)
            resp.raise_for_status()
            data = resp.json()

        self._jwks = data
        self._fetched_at = now
        return data


_jwks_cache = JWKSCache()


def _select_jwk(*, jwks: dict, token: str) -> dict:
    try:
        header = jwt.get_unverified_header(token)
    except Exception:
        raise unauthorized("Invalid token header")

    kid = header.get("kid")
    if not kid:
        raise unauthorized("Invalid token header")

    keys = jwks.get("keys") if isinstance(jwks, dict) else None
    if not isinstance(keys, list):
        raise unauthorized("Invalid JWKS")

    for k in keys:
        if isinstance(k, dict) and k.get("kid") == kid:
            return k

    raise unauthorized("Unknown signing key")


async def get_current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> AuthenticatedUser:
    if creds is None or not creds.credentials:
        raise unauthorized("Missing bearer token")

    token = creds.credentials
    settings = get_settings()

    jwks = await _jwks_cache.get(str(settings.supabase_jwks_url))
    jwk = _select_jwk(jwks=jwks, token=token)

    try:
        claims = jwt.decode(
            token,
            jwk,
            algorithms=["ES256", "RS256"],
            audience=settings.supabase_jwt_audience,
            options={"verify_iss": False},
        )
    except Exception:
        raise unauthorized("Invalid token")

    user_id = claims.get("sub")
    if not user_id:
        raise unauthorized("Invalid token payload")

    first_name: str | None = None
    try:
        supabase = get_supabase_admin()
        resp = supabase.table("profiles").select("first_name").eq("id", str(user_id)).maybe_single().execute()
        data = resp.data if isinstance(resp.data, dict) else None
        fn = (data or {}).get("first_name")
        if isinstance(fn, str):
            fn = fn.strip()
            first_name = fn if fn else None
    except Exception:
        first_name = None

    return AuthenticatedUser(user_id=str(user_id), first_name=first_name)
