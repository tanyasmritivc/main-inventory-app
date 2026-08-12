
import logging
import threading as _auth_threading
import time
from dataclasses import dataclass

import httpx
from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import jwt

from app.core.config import get_settings
from app.core.errors import unauthorized
from app.services.supabase_client import get_supabase_admin

logger = logging.getLogger(__name__)


def _client_ip(request: Request) -> str:
    xff = request.headers.get("x-forwarded-for", "")
    if xff:
        return xff.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


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

_PROFILE_CACHE: dict[str, tuple[str | None, float]] = {}
_PROFILE_CACHE_LOCK = _auth_threading.Lock()
_PROFILE_CACHE_TTL = 300  # 5 minutes


def _get_cached_first_name(user_id: str) -> tuple[bool, str | None]:
    """Returns (found_in_cache, first_name)."""
    with _PROFILE_CACHE_LOCK:
        entry = _PROFILE_CACHE.get(user_id)
        if entry and (time.time() - entry[1]) < _PROFILE_CACHE_TTL:
            return True, entry[0]
    return False, None


def _cache_first_name(user_id: str, first_name: str | None) -> None:
    with _PROFILE_CACHE_LOCK:
        _PROFILE_CACHE[user_id] = (first_name, time.time())


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
    request: Request,
    creds: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> AuthenticatedUser:
    ip = _client_ip(request)
    path = request.url.path

    if creds is None or not creds.credentials:
        logger.warning("[SECURITY] missing_token | ip=%s | path=%s", ip, path)
        raise unauthorized("Missing bearer token")

    token = creds.credentials
    settings = get_settings()

    # HS256 path (self-hosted Supabase only). Branching on the token's declared `alg`
    # is safe: HS256 tokens verify against settings.supabase_jwt_secret, which is a
    # separate secret that never appears in the JWKS (public keys only) — an attacker
    # cannot forge or downgrade tokens without knowing it. On cloud this setting is
    # unset (None), so the branch is unreachable there. This is an additional
    # verification path, not a fallback for any asymmetric token.
    try:
        header_alg = jwt.get_unverified_header(token).get("alg")
    except Exception:
        header_alg = None

    if header_alg == "HS256":
        if not settings.supabase_jwt_secret:
            logger.warning("[SECURITY] hs256_token_no_secret | ip=%s | path=%s", ip, path)
            raise unauthorized("HS256 token but supabase_jwt_secret is not configured")
        try:
            claims = jwt.decode(
                token,
                settings.supabase_jwt_secret,
                algorithms=["HS256"],
                audience=settings.supabase_jwt_audience,
                options={"verify_iss": False},
            )
        except Exception:
            logger.warning("[SECURITY] invalid_token | ip=%s | path=%s", ip, path)
            raise unauthorized("Invalid token")
    else:
        jwks = await _jwks_cache.get(str(settings.supabase_jwks_url))
        try:
            jwk = _select_jwk(jwks=jwks, token=token)
        except Exception:
            logger.warning("[SECURITY] invalid_token | ip=%s | path=%s", ip, path)
            raise

        try:
            claims = jwt.decode(
                token,
                jwk,
                algorithms=["ES256", "RS256"],
                audience=settings.supabase_jwt_audience,
                options={"verify_iss": False},
            )
        except Exception:
            logger.warning("[SECURITY] invalid_token | ip=%s | path=%s", ip, path)
            raise unauthorized("Invalid token")

    user_id = claims.get("sub")
    if not user_id:
        logger.warning("[SECURITY] invalid_token | ip=%s | path=%s", ip, path)
        raise unauthorized("Invalid token payload")

    cached, first_name = _get_cached_first_name(user_id)
    if not cached:
        first_name = None
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
        _cache_first_name(user_id, first_name)

    return AuthenticatedUser(user_id=str(user_id), first_name=first_name)
