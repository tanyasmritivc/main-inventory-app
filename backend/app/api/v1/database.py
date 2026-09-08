import asyncio
import json
from contextlib import asynccontextmanager

import asyncpg
from fastapi import Request

from app.core.config import get_settings
from app.api.v1.errors import APIError


@asynccontextmanager
async def integration_lifespan(app):
    app.state.api_key_pool = None
    app.state.api_key_pool_lock = asyncio.Lock()
    try:
        yield
    finally:
        pool = app.state.api_key_pool
        if pool is not None:
            await pool.close()


async def get_pool(request: Request):
    state = request.app.state
    async with state.api_key_pool_lock:
        if state.api_key_pool is None:
            dsn = get_settings().api_keys_database_url
            if not dsn:
                raise APIError(503, "api_not_configured", "Integration API is not configured.")

            async def validate_role(conn):
                safe = await conn.fetchval("""
                    SELECT current_user = 'findez_api'
                      AND NOT rolsuper AND NOT rolbypassrls AND NOT rolcreaterole
                      AND NOT rolcreatedb AND NOT rolinherit
                      AND NOT EXISTS (SELECT 1 FROM pg_auth_members WHERE member = r.oid)
                      AND NOT EXISTS (SELECT 1 FROM pg_class WHERE relowner = r.oid)
                    FROM pg_roles r WHERE rolname = current_user
                """)
                if not safe:
                    raise APIError(503, "unsafe_database_role", "Integration database role is not restricted.")
            state.api_key_pool = await asyncpg.create_pool(
                dsn.get_secret_value(), min_size=1, max_size=10,
                init=validate_role, command_timeout=15, timeout=10,
                # Direct PostgreSQL or session pooling; no server-side prepared statement cache.
                statement_cache_size=0,
            )
        return state.api_key_pool


async def set_claims(conn, claims: dict):
    # LOCAL is essential: claims reset on commit/rollback, before pool reuse.
    await conn.execute("SELECT set_config('request.jwt.claims', $1, true)", json.dumps(claims))
    await conn.execute("SET LOCAL row_security = on")
