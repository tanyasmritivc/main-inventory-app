"""Run from backend: python -m scripts.shopify_worker. Requires migration 042."""
import signal
import time

from app.core.config import get_settings
from app.services.shopify_api import ready
from app.services.shopify_sync import work_once


def main():
    if not ready(get_settings()):
        raise SystemExit("Shopify worker configuration is incomplete or disabled.")
    stopping = False

    def stop(*_):
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    while not stopping:
        try:
            worked = work_once()
        except Exception:
            # DB outages cannot erase durable work. Avoid logging credentials in
            # exception objects; the service supervisor observes the safe message.
            print("Shopify worker could not access its queue; retrying.", flush=True)
            worked = False
        time.sleep(1 if worked else 5)


if __name__ == "__main__":
    main()
