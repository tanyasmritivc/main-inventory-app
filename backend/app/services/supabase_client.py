from __future__ import annotations

from functools import lru_cache

from supabase import Client, create_client

from app.core.config import get_settings


@lru_cache
def get_supabase_admin() -> Client:
    settings = get_settings()
    return create_client(str(settings.supabase_url), settings.supabase_service_role_key)
