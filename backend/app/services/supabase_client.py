from __future__ import annotations

import time
from functools import lru_cache
from typing import Callable, TypeVar

from supabase import Client, create_client

from app.core.config import get_settings

T = TypeVar("T")


@lru_cache
def get_supabase_admin() -> Client:
    settings = get_settings()
    return create_client(
        str(settings.supabase_url),
        str(settings.supabase_service_role_key),
    )


def supabase_execute_with_retry(fn: Callable[[], T], max_attempts: int = 3) -> T:
    for attempt in range(1, max_attempts + 1):
        try:
            return fn()
        except Exception as e:
            if attempt < max_attempts:
                print(f"Supabase error attempt={attempt}, retrying in 1s: {e}")
                time.sleep(1)
            else:
                raise
