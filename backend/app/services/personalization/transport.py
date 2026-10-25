"""Bounded optional I/O, independent of the inventory client's timeout/retries."""
from concurrent.futures import ThreadPoolExecutor
from threading import BoundedSemaphore, local
from supabase import ClientOptions, create_client
from app.core.config import get_settings

_local = local()
_executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix='personalization')
_slots = BoundedSemaphore(32)


def client():
    if not hasattr(_local, 'client'):
        settings = get_settings()
        _local.client = create_client(str(settings.supabase_url), str(settings.supabase_service_role_key),
            options=ClientOptions(postgrest_client_timeout=.5, auto_refresh_token=False, persist_session=False))
    return _local.client


def submit(function, *args):
    """Drop telemetry on overload; never accumulate an unbounded work queue."""
    if not _slots.acquire(blocking=False):
        return False
    def work():
        try:
            function(*args)
        finally:
            _slots.release()
    try:
        _executor.submit(work)
    except RuntimeError:
        _slots.release()
        return False
    return True
