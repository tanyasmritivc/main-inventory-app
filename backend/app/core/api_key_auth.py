import logging
import re
import secrets
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Callable

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError
from fastapi import BackgroundTasks, Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.config import get_settings
from app.services.supabase_client import get_supabase_admin

logger = logging.getLogger(__name__)

API_KEY_PATTERN = re.compile(r"^findez_(live|test)_sk_([A-Za-z0-9_-]{32})$")
WORKSPACE_SCOPES = frozenset({"items:read", "items:write", "import:write", "workspace:read"})
GLOBAL_SCOPES = frozenset({"org:read", "org:write"})
ALL_SCOPES = WORKSPACE_SCOPES | GLOBAL_SCOPES

_hasher = PasswordHasher(time_cost=2, memory_cost=19456, parallelism=1)
_dummy_hash = _hasher.hash("findez-invalid-key-timing-padding")
_bearer = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class APIKeyPrincipal:
    key_id: str
    workspace_id: str | None
    org_id: str
    scopes: frozenset[str]
    created_by: str

    def allows(self, required_scope: str) -> bool:
        if required_scope in self.scopes:
            return True
        if required_scope in {"items:read", "workspace:read"}:
            return "org:read" in self.scopes
        if required_scope in {"items:write", "import:write"}:
            return "org:write" in self.scopes
        return False


def generate_api_key(environment: str) -> str:
    normalized = "live" if environment == "live" else "test"
    # 24 random bytes encode to exactly 32 URL-safe characters with no padding.
    return f"findez_{normalized}_sk_{secrets.token_urlsafe(24)}"


def hash_api_key(raw_key: str) -> str:
    return _hasher.hash(raw_key)


def verify_api_key(raw_key: str, key_hash: str) -> bool:
    try:
        return _hasher.verify(key_hash, raw_key)
    except (VerifyMismatchError, InvalidHashError):
        return False


def validate_scopes(*, workspace_id: str | None, scopes: list[str]) -> frozenset[str]:
    normalized = frozenset(scope.strip() for scope in scopes if scope.strip())
    if not normalized or not normalized.issubset(ALL_SCOPES):
        raise ValueError("invalid_scope")
    allowed = WORKSPACE_SCOPES if workspace_id else GLOBAL_SCOPES
    if not normalized.issubset(allowed):
        raise ValueError("scope_type_mismatch")
    return normalized


def api_error(request: Request, status_code: int, code: str, message: str) -> HTTPException:
    correlation_id = getattr(request.state, "correlation_id", "unknown")
    return HTTPException(
        status_code=status_code,
        detail={"code": code, "message": message, "correlation_id": correlation_id},
    )


def _parse_timestamp(value: str | datetime) -> datetime:
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def _is_expired(value: str | datetime | None) -> bool:
    if not value:
        return False
    parsed = _parse_timestamp(value)
    return parsed <= datetime.now(timezone.utc)


def _touch_last_used(key_id: str) -> None:
    try:
        get_supabase_admin().table("api_keys").update({
            "last_used_at": datetime.now(timezone.utc).isoformat(),
        }).eq("id", key_id).execute()
    except Exception:
        logger.exception("Could not update API key last_used_at key_id=%s", key_id)


async def authenticate_api_key(
    request: Request,
    background_tasks: BackgroundTasks,
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> APIKeyPrincipal:
    raw_key = credentials.credentials if credentials else ""
    match = API_KEY_PATTERN.fullmatch(raw_key)
    if not match:
        # Perform a real Argon2 verification even for malformed/unknown keys.
        verify_api_key(raw_key or "missing", _dummy_hash)
        raise api_error(request, 401, "invalid_api_key", "The API key is invalid.")

    expected_environment = "live" if get_settings().env == "production" else "test"
    if match.group(1) != expected_environment:
        verify_api_key(raw_key, _dummy_hash)
        raise api_error(request, 401, "wrong_environment", "The API key is for a different environment.")

    prefix = raw_key[:20]
    try:
        rows = get_supabase_admin().table("api_keys").select(
            "id,workspace_id,org_id,key_hash,scopes,created_by,last_used_at,expires_at,revoked_at"
        ).eq("key_prefix", prefix).execute().data or []
    except Exception:
        logger.exception("API key lookup failed correlation_id=%s", getattr(request.state, "correlation_id", "unknown"))
        raise api_error(request, 503, "authentication_unavailable", "API authentication is temporarily unavailable.")

    matched = None
    for row in rows:
        if verify_api_key(raw_key, row.get("key_hash", "")):
            matched = row
    if matched is None:
        if not rows:
            verify_api_key(raw_key, _dummy_hash)
        raise api_error(request, 401, "invalid_api_key", "The API key is invalid.")
    if matched.get("revoked_at"):
        raise api_error(request, 401, "revoked_api_key", "The API key has been revoked.")
    try:
        expired = _is_expired(matched.get("expires_at"))
    except (TypeError, ValueError):
        logger.error("Invalid expires_at on API key id=%s", matched.get("id"))
        expired = True
    if expired:
        raise api_error(request, 401, "expired_api_key", "The API key has expired.")

    principal = APIKeyPrincipal(
        key_id=str(matched["id"]),
        workspace_id=str(matched["workspace_id"]) if matched.get("workspace_id") else None,
        org_id=str(matched["org_id"]),
        scopes=frozenset(matched.get("scopes") or []),
        created_by=str(matched["created_by"]),
    )
    request.state.api_key = principal

    last_used = matched.get("last_used_at")
    should_touch = True
    if last_used:
        try:
            should_touch = (datetime.now(timezone.utc) - _parse_timestamp(last_used)).total_seconds() >= 300
        except (TypeError, ValueError):
            pass
    if should_touch:
        background_tasks.add_task(_touch_last_used, principal.key_id)
    return principal


def _consume_rate_limit(principal: APIKeyPrincipal, bucket: str, limit: int) -> bool:
    result = get_supabase_admin().rpc("consume_api_key_rate_limit", {
        "p_key_id": principal.key_id,
        "p_bucket": bucket,
        "p_limit": limit,
    }).execute()
    return result.data is True


def require_api_scope(required_scope: str, *, bulk: bool = False) -> Callable:
    async def dependency(
        request: Request,
        principal: APIKeyPrincipal = Depends(authenticate_api_key),
    ) -> APIKeyPrincipal:
        if not principal.allows(required_scope):
            raise api_error(request, 403, "insufficient_scope", f"This endpoint requires {required_scope}.")
        settings = get_settings()
        limit = settings.api_key_bulk_requests_per_minute if bulk else settings.api_key_requests_per_minute
        bucket = "bulk" if bulk else "standard"
        try:
            allowed = _consume_rate_limit(principal, bucket, limit)
        except Exception:
            logger.exception("API rate-limit check failed key_id=%s", principal.key_id)
            raise api_error(request, 503, "rate_limit_unavailable", "Rate limiting is temporarily unavailable.")
        if not allowed:
            raise api_error(request, 429, "rate_limit_exceeded", "The API key rate limit has been exceeded.")
        return principal

    return dependency
