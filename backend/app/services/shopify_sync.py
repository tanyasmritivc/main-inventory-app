"""Restart-safe one-page worker over the service-only PostgreSQL queue."""
from datetime import datetime, timedelta, timezone
import random

from app.core.config import get_settings
from app.services.supabase_client import get_supabase_admin
from app.services.shopify_api import (
    LEVELS_QUERY, VARIANTS_QUERY, ShopifyAPI, ShopifyError, Vault,
    map_levels, map_variants, next_cursor, ready,
)


def rpc(operation, **params):
    return get_supabase_admin().rpc("shopify_" + operation, {"p_" + k: v for k, v in params.items()}).execute().data


def current_credentials(connection, lease_id):
    # Recheck installation immediately before token use. Commits are fenced too.
    db = get_supabase_admin()
    active = db.table("shopify_connections").select("connection_id").eq(
        "connection_id", connection["connection_id"]).eq("generation", connection["generation"]).eq("status", "connected").execute().data
    if not active:
        return None
    leases = db.table("shopify_sync_jobs").select("lease_until").eq("connection_id", connection["connection_id"]).eq(
        "generation", connection["generation"]).eq("lease_id", lease_id).execute().data or []
    if not leases or datetime.fromisoformat(leases[0]["lease_until"].replace("Z", "+00:00")) <= datetime.now(timezone.utc):
        return None
    rows = db.table("shopify_credentials").select("*").eq("connection_id", connection["connection_id"]).execute().data or []
    return rows[0] if rows else None


def next_inventory(connection_id, run, after):
    query = get_supabase_admin().table("shopify_variants").select("inventory_item_gid").eq(
        "connection_id", connection_id).eq("seen_run", run).eq("tracked", True)
    if after:
        query = query.gt("inventory_item_gid", after)
    rows = query.order("inventory_item_gid").limit(1).execute().data or []
    return rows[0]["inventory_item_gid"] if rows else None


def work_once(settings=None):
    """No in-process queue; safe for several workers with per-store DB leases."""
    settings = settings or get_settings()
    if not ready(settings):
        return False
    claimed = rpc("claim_job")
    if not claimed:
        return False
    c, j = claimed["connection"], claimed["job"]
    fence = {"connection": c["connection_id"], "generation": c["generation"], "lease": j["lease_id"]}
    api = ShopifyAPI(settings, c["shop_domain"])
    try:
        credentials = current_credentials(c, j["lease_id"])
        if not credentials:
            raise ShopifyError("reconnect")
        vault = Vault(settings)
        tokens = vault.decrypt(credentials["encrypted_tokens"], c["connection_id"], c["generation"])
        now = datetime.now(timezone.utc)
        if datetime.fromisoformat(credentials["access_expires_at"].replace("Z", "+00:00")) <= now + timedelta(seconds=60):
            if datetime.fromisoformat(credentials["refresh_expires_at"].replace("Z", "+00:00")) <= now:
                raise ShopifyError("reconnect")
            tokens, _, access, refresh = api.tokens(refresh=tokens["refresh"])
            if not rpc("save_tokens", **fence, tokens=vault.encrypt(tokens, c["connection_id"], c["generation"]),
                access_expiry=access, refresh_expiry=refresh):
                return True
        cursor = j["cursor"]
        variants, levels, complete, delay = [], [], False, 0
        if cursor["stage"] == "variants":
            data, delay = api.query(VARIANTS_QUERY, {"after": cursor.get("after")}, tokens["access"])
            page = data["productVariants"]
            variants = map_variants(page)
            after = next_cursor(page)
            if after and after == cursor.get("after"):
                raise ShopifyError()
            cursor = {"stage": "variants", "after": after} if after else {"stage": "levels"}
        else:
            item_id = cursor.get("item") or next_inventory(c["connection_id"], j["job_id"], cursor.get("last_item"))
            if not item_id:
                complete = True
            else:
                data, delay = api.query(LEVELS_QUERY, {"id": item_id, "after": cursor.get("after")}, tokens["access"])
                item = data["inventoryItem"]
                # Deletion during import requires reconciliation, not invented stock.
                if not item:
                    raise ShopifyError()
                levels = map_levels(item)
                after = next_cursor(item["inventoryLevels"]) if item["tracked"] else None
                if after and after == cursor.get("after"):
                    raise ShopifyError()
                cursor = {"stage": "levels", "item": item_id, "after": after} if after else {"stage": "levels", "last_item": item_id}
        rpc("commit_page", **fence, variants=variants, levels=levels, cursor=cursor, complete=complete, delay=delay)
    except ShopifyError as error:
        rpc("fail_job", **fence, error=error.code, delay=min(3600, error.delay * (2 ** min(j["attempts"], 6))) + random.randint(0, 5))
    except Exception:
        # No upstream body or exceptions are persisted/logged; job stays retryable.
        rpc("fail_job", **fence, error="worker_error", delay=60)
    finally:
        api.close()
    return True
