import time

from jose import jwt
from postgrest import SyncPostgrestClient

from app.core.api_key_auth import APIKeyPrincipal
from app.core.config import get_settings


def create_api_key_rls_client(principal: APIKeyPrincipal) -> SyncPostgrestClient:
    """Create an anon-key PostgREST client carrying a short-lived RLS JWT.

    This deliberately never uses the service-role key for inventory access.
    PostgREST places these signed claims into request.jwt.claims, and PostgreSQL
    RLS is the tenant boundary.
    """
    settings = get_settings()
    if not settings.supabase_jwt_secret:
        raise RuntimeError("SUPABASE_JWT_SECRET is required for API-key RLS sessions")

    now = int(time.time())
    claims = {
        "sub": principal.key_id,
        "role": "authenticated",
        "aud": settings.supabase_jwt_audience,
        "iat": now,
        "exp": now + 90,
        "api_key_id": principal.key_id,
        "api_org_id": principal.org_id,
        "api_workspace_id": principal.workspace_id,
        "api_scopes": sorted(principal.scopes),
    }
    token = jwt.encode(claims, settings.supabase_jwt_secret, algorithm="HS256")
    # Callers use `with` so every request closes its HTTP connection pool. A
    # Supabase client per request also creates unused Auth/Storage clients.
    return SyncPostgrestClient(
        f"{str(settings.supabase_url).rstrip('/')}/rest/v1",
        headers={"apikey": settings.supabase_anon_key, "Authorization": f"Bearer {token}"},
        timeout=15,
    )
