from dataclasses import dataclass
from datetime import datetime, timezone
from uuid import UUID

from fastapi import Depends, Header, Request
from fastapi.security import HTTPAuthorizationCredentials

from app.core.auth import AuthenticatedUser, bearer_scheme, get_current_user
from app.core.config import get_settings
from app.api.v1.crypto import KEY_PATTERN, verify_secret
from app.api.v1.database import get_pool, set_claims
from app.api.v1.errors import APIError


@dataclass(frozen=True)
class APIKeyPrincipal:
    id: UUID
    org_id: UUID
    workspace_id: UUID | None
    created_by: UUID
    scopes: tuple[str, ...]
    environment: str

    def permits(self, scope: str) -> bool:
        if self.workspace_id is not None:
            return scope in self.scopes
        global_scope = "org:write" if scope in {"items:write", "import:write"} else "org:read"
        return global_scope in self.scopes

    def claims(self, scope: str) -> dict:
        return {"sub": str(self.created_by), "role": "findez_api", "auth_kind": "api_key",
                "api_key_id": str(self.id), "api_scope": scope,
                "environment": self.environment}


async def authenticate_api_key(
    request: Request,
    creds: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> APIKeyPrincipal:
    raw = creds.credentials if creds else ""
    match = KEY_PATTERN.fullmatch(raw)
    if not match or match.group(1) != get_settings().api_keys_environment:
        raise APIError(401, "invalid_api_key", "API key is invalid or inactive.")
    pool = await get_pool(request)
    async with pool.acquire() as conn:
        candidates = await conn.fetch("SELECT * FROM api_private.lookup_key($1)", raw[:20])
    for row in candidates:
        if not await verify_secret(raw, row["key_hash"]):
            continue
        if row["revoked_at"] or (row["expires_at"] and row["expires_at"] <= datetime.now(timezone.utc)):
            break
        return APIKeyPrincipal(row["id"], row["org_id"], row["workspace_id"], row["created_by"],
                               tuple(row["scopes"]), match.group(1))
    raise APIError(401, "invalid_api_key", "API key is invalid or inactive.")


@dataclass
class APIAccess:
    principal: APIKeyPrincipal
    conn: object


def require_api_scope(scope: str, *, bulk: bool = False):
    async def dependency(request: Request, key: APIKeyPrincipal = Depends(authenticate_api_key)):
        if not key.permits(scope):
            raise APIError(403, "insufficient_scope", f"This endpoint requires {scope}.")
        pool = await get_pool(request)
        # A short committed transaction makes the rate limit apply even when the data
        # operation fails. Counters are atomic and shared across workers/replicas.
        async with pool.acquire() as conn:
            async with conn.transaction():
                await set_claims(conn, key.claims(scope))
                result = await conn.fetchval("SELECT api_private.admit_request($1)", bulk)
        if result == "inactive":
            raise APIError(401, "invalid_api_key", "API key is invalid or inactive.")
        if result == "limited":
            raise APIError(429, "rate_limited", "API-key rate limit exceeded.", {"Retry-After": "60"})
        async with pool.acquire() as conn:
            async with conn.transaction():
                await set_claims(conn, key.claims(scope))
                yield APIAccess(key, conn)
    return dependency


async def session_only(
    request: Request,
    creds: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> AuthenticatedUser:
    if not creds or creds.credentials.startswith("findez_"):
        raise APIError(401, "session_required", "Key management requires a user session.")
    return await get_current_user(request, creds)


@dataclass
class KeyManager:
    user_id: UUID
    org_id: UUID
    conn: object


async def key_manager(
    request: Request,
    user: AuthenticatedUser = Depends(session_only),
    org_id: UUID | None = Header(default=None, alias="X-FindEZ-Org-ID"),
):
    pool = await get_pool(request)
    async with pool.acquire() as conn:
        async with conn.transaction():
            await set_claims(conn, {"sub": user.user_id, "role": "findez_api", "auth_kind": "session"})
            orgs = await conn.fetch("SELECT org_id FROM api_private.managed_orgs()")
            allowed = {row["org_id"] for row in orgs}
            if org_id is None:
                if not allowed:
                    raise APIError(403, "org_forbidden", "Organization administrator access is required.")
                if len(allowed) != 1:
                    raise APIError(400, "org_required", "Select an organization with X-FindEZ-Org-ID.")
                org_id = next(iter(allowed))
            if org_id not in allowed:
                raise APIError(403, "org_forbidden", "Organization administrator access is required.")
            yield KeyManager(UUID(user.user_id), org_id, conn)
