
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


class _KidNotFound(Exception):
    """Raised by _select_jwk when the token's kid is absent from the cached JWKS."""
    def __init__(self, kid: str, cached_kids: list[str]) -> None:
        self.kid = kid
        self.cached_kids = cached_kids
        super().__init__(f"kid '{kid}' not in JWKS")


class JWKSCache:
    _FORCED_REFETCH_COOLDOWN = 60  # seconds — limits how often a kid-miss triggers a refetch

    def __init__(self) -> None:
        self._jwks: dict | None = None
        self._fetched_at: float | None = None
        self._last_forced_refetch: float | None = None

    async def get(self, jwks_url: str, *, force: bool = False) -> dict:
        now = time.time()

        if force:
            # Cooldown check: don't hammer the JWKS endpoint on repeated bad tokens.
            cooldown_active = (
                self._last_forced_refetch is not None
                and (now - self._last_forced_refetch) < self._FORCED_REFETCH_COOLDOWN
            )
            if cooldown_active and self._jwks is not None:
                return self._jwks
            # Cooldown passed (or no cache) — allowed to refetch.
            self._last_forced_refetch = now
        elif (
            self._jwks is not None
            and self._fetched_at is not None
            and (now - self._fetched_at) < 3600
        ):
            # Normal path: cache is fresh within the 1h TTL.
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

    cached_kids = [k.get("kid", "") for k in keys if isinstance(k, dict)]
    raise _KidNotFound(kid, cached_kids)


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
        jwks_url = str(settings.supabase_jwks_url)
        jwks = await _jwks_cache.get(jwks_url)

        try:
            jwk = _select_jwk(jwks=jwks, token=token)
        except _KidNotFound as exc:
            logger.warning(
                "[SECURITY] jwks_kid_miss | kid=%s | cached_kids=%s | ip=%s | path=%s"
                " — forcing JWKS refetch",
                exc.kid, exc.cached_kids, ip, path,
            )
            # Force one JWKS refetch and retry before rejecting. The cooldown inside
            # JWKSCache.get() ensures repeated bad tokens can't hammer the endpoint.
            jwks = await _jwks_cache.get(jwks_url, force=True)
            try:
                jwk = _select_jwk(jwks=jwks, token=token)
            except _KidNotFound:
                logger.warning("[SECURITY] invalid_token | ip=%s | path=%s", ip, path)
                raise unauthorized("Unknown signing key")
            except Exception:
                logger.warning("[SECURITY] invalid_token | ip=%s | path=%s", ip, path)
                raise
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
