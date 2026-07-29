
import logging
import threading
import time
from functools import lru_cache
from typing import Callable, TypeVar

from supabase import Client, create_client

from app.core.config import get_settings

T = TypeVar("T")

logger = logging.getLogger(__name__)


@lru_cache
def get_supabase_admin() -> Client:
    settings = get_settings()
    return create_client(
        str(settings.supabase_url),
        str(settings.supabase_service_role_key),
    )


_thread_local = threading.local()


def create_supabase_admin() -> Client:
    """Thread-local admin client.

    Each worker thread gets its own Client (and its own httpx connection
    pool), so concurrent asyncio.to_thread calls never share one — but we
    do NOT create a new client per call, which leaks sockets.
    """
    client = getattr(_thread_local, "admin_client", None)
    if client is None:
        settings = get_settings()
        client = create_client(
            str(settings.supabase_url),
            str(settings.supabase_service_role_key),
        )
        _thread_local.admin_client = client
    return client


def supabase_execute_with_retry(fn: Callable[[], T], max_attempts: int = 3) -> T:
    for attempt in range(1, max_attempts + 1):
        try:
            return fn()
        except Exception as e:
            if attempt < max_attempts:
                logger.warning("Supabase error attempt=%d, retrying in 1s: %s", attempt, e)
                time.sleep(1)
            else:
                raise
