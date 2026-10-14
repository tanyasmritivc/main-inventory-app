"""Reviewed, bounded Shopify edits under current owner policy and live grants."""
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from app.core.config import get_settings
from app.services.supabase_client import get_supabase_admin
from app.services.shopify_sync import rpc
from app.services.shopify_api import (
    ACCESS_QUERY, PRODUCT_QUERY, INVENTORY_QUERY, OPTIONAL_SCOPES, SCOPES,
    ALLOWED_SCOPES, ShopifyAPI, ShopifyError, Vault, effective_scopes, ready,
    requested_scopes,
)

ERRORS = {
    "permission": (403, "You no longer have permission for this Shopify action."),
    "revision": (409, "The owner changed these permissions. Refresh before saving."),
    "busy": (409, "This store is busy. Wait a moment and try again."),
    "reconnect": (409, "Reconnect Shopify to renew its access."),
    "expired": (409, "This review expired. Prepare and review the change again."),
    "outcome_unknown": (409, "This action was already sent. Check its result in Shopify before preparing another change."),
}


def call(operation, **params):
    try:
        result = rpc(operation, **params)
    except Exception:
        raise HTTPException(503, "Could not load or save this Shopify action. Try again.") from None
    if isinstance(result, dict) and result.get("error"):
        code, message = ERRORS.get(result["error"], (400, "Invalid Shopify action."))
        raise HTTPException(code, message)
    return result


def writes_ready():
    settings = get_settings()
    if not ready(settings) or not settings.shopify_writes_enabled:
        raise HTTPException(503, "Shopify edits are not enabled yet.")
    return settings


def _time(value):
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


@contextmanager
def session(team, connection, actor):
    settings = get_settings()
    if not ready(settings):
        raise HTTPException(503, "Shopify connection is not configured yet.")
    c = call("claim_io", team=team, connection=connection, actor=actor)
    if not isinstance(c, dict) or not c.get("io_lease"):
        raise HTTPException(503, "Could not check this Shopify connection.")
    api = ShopifyAPI(settings, c["shop_domain"])
    fence = {"connection": connection, "generation": c["generation"], "lease": c["io_lease"]}
    try:
        db = get_supabase_admin()
        credentials = db.table("shopify_credentials").select("*").eq("connection_id", connection).limit(1).execute().data or []
        if not credentials:
            raise ShopifyError("reconnect")
        credential = credentials[0]
        vault = Vault(settings)
        tokens = vault.decrypt(credential["encrypted_tokens"], connection, c["generation"])
        now = datetime.now(timezone.utc)
        if _time(credential["access_expires_at"]) <= now+timedelta(seconds=60):
            if _time(credential["refresh_expires_at"]) <= now:
                raise ShopifyError("reconnect")
            tokens, scopes, access, refresh = api.tokens(refresh=tokens["refresh"], expected=c["granted_scopes"])
            if not call("io_tokens", **fence, tokens=vault.encrypt(tokens, connection, c["generation"]),
                access_expiry=access, refresh_expiry=refresh, scopes=scopes):
                raise ShopifyError("reconnect")
        live, _ = api.query(ACCESS_QUERY, {}, tokens["access"])
        scopes = {row["handle"] for row in live["currentAppInstallation"]["accessScopes"]}
        if not scopes <= ALLOWED_SCOPES or not SCOPES <= effective_scopes(scopes):
            raise ShopifyError("reconnect")
        if not call("io_scopes", **fence, scopes=sorted(scopes)):
            raise ShopifyError("reconnect")
        c["granted_scopes"] = sorted(scopes)
        yield c, api, tokens["access"]
    except ShopifyError as error:
        status, message = ERRORS.get(error.code, (503, "Shopify could not verify this action. Try again."))
        raise HTTPException(status, message) from None
    except (KeyError, ValueError, TypeError):
        raise HTTPException(503, "Shopify did not return verifiable information for this action.") from None
    finally:
        api.close()
        try:
            rpc("release_io", connection=connection, lease=c["io_lease"])
        except Exception:
            # The bounded database lease expires even if cleanup cannot be reached.
            pass


def reconcile_permissions(team, connection, actor):
    """Local downgrade is already saved. Report external revocation separately."""
    with session(team, connection, actor) as (c, api, token):
        desired = requested_scopes(c)
        remove = (set(c["granted_scopes"]) & OPTIONAL_SCOPES) - desired
        pending = False
        if remove:
            result = api.mutation("revoke", {"scopes": sorted(remove)}, token).get("appRevokeAccessScopes", {})
            pending = bool(result.get("userErrors"))
            live, _ = api.query(ACCESS_QUERY, {}, token)
            scopes = {row["handle"] for row in live["currentAppInstallation"]["accessScopes"]}
            if not scopes <= ALLOWED_SCOPES or not SCOPES <= effective_scopes(scopes):
                raise ShopifyError("reconnect")
            if not call("io_scopes", connection=connection, generation=c["generation"], lease=c["io_lease"], scopes=sorted(scopes)):
                raise ShopifyError("reconnect")
            c["granted_scopes"] = sorted(scopes)
            pending = pending or bool(scopes & remove)
        return {"needs_authorization": not desired <= effective_scopes(c["granted_scopes"]),
            "revocation_pending": pending, "granted_scopes": c["granted_scopes"]}


def variant(connection, gid):
    rows = get_supabase_admin().table("shopify_variants").select("variant_gid,product_gid,inventory_item_gid,tracked,product_title,variant_title").eq(
        "connection_id", connection).eq("variant_gid", gid).is_("deleted_at", "null").limit(1).execute().data or []
    if not rows:
        raise HTTPException(409, "This catalog variant is unavailable. Refresh the catalog.")
    return rows[0]


def _product(api, product, token):
    result, _ = api.query(PRODUCT_QUERY, {"id": product}, token)
    row = result.get("product")
    if not row or row.get("id") != product:
        raise HTTPException(409, "This Shopify product is no longer available.")
    return row


def _inventory(api, item, location, token):
    result, _ = api.query(INVENTORY_QUERY, {"id": item, "location": location}, token)
    row = result.get("inventoryItem")
    level = row.get("inventoryLevel") if row else None
    if not row or row.get("id") != item or not row.get("tracked") or not level or not level["location"]["isActive"] or level["location"]["id"] != location:
        raise HTTPException(409, "Stock is not tracked at this active Shopify location.")
    quantities = {q["name"]: q["quantity"] for q in level["quantities"]}
    if type(quantities.get("available")) is not int:
        raise HTTPException(409, "Shopify did not return a current available quantity.")
    return {"inventory_item_gid": item, "location_gid": location,
        "location_name": level["location"]["name"], "available": quantities["available"]}


def prepare(team, connection, actor, payload):
    writes_ready()
    if not call("can_edit", connection=connection, actor=actor, kind=payload["kind"]):
        raise HTTPException(403, "The owner has not enabled this Shopify edit for you.")
    row = variant(connection, payload["variant_gid"])
    with session(team, connection, actor) as (c, api, token):
        required = "write_products" if payload["kind"] == "product" else "write_inventory"
        if required not in c["granted_scopes"]:
            raise HTTPException(403, "The owner must approve this edit access in Shopify first.")
        allowed = call("can_edit", connection=connection, actor=actor, kind=payload["kind"])
        if not allowed:
            raise HTTPException(403, "The owner has not enabled this Shopify edit for you.")
        if payload["kind"] == "product":
            snapshot = _product(api, row["product_gid"], token)
            intent = {"product_gid": row["product_gid"], "changes": payload["changes"]}
        else:
            levels = get_supabase_admin().table("shopify_inventory_levels").select("location_gid").eq(
                "connection_id", connection).eq("inventory_item_gid", row["inventory_item_gid"]).eq(
                "location_gid", payload["location_gid"]).limit(1).execute().data or []
            if not levels or not row["tracked"]:
                raise HTTPException(409, "Choose an imported, tracked Shopify stock location.")
            snapshot = _inventory(api, row["inventory_item_gid"], payload["location_gid"], token)
            intent = {"inventory_item_gid": row["inventory_item_gid"], "location_gid": payload["location_gid"], "delta": payload["delta"]}
        snapshot["checked_at"] = datetime.now(timezone.utc).isoformat()
        snapshot["variant_title"] = row["variant_title"]
        return call("prepare_edit", connection=connection, actor=actor, lease=c["io_lease"], kind=payload["kind"], intent=intent, snapshot=snapshot)


def operation(team, connection, actor, operation_id):
    db = get_supabase_admin()
    c = db.table("shopify_connections").select("team_id").eq("connection_id", connection).eq("team_id", team).limit(1).execute().data or []
    if not c:
        raise HTTPException(404, "This store is unavailable to this Team.")
    rows = db.table("shopify_operations").select("*").eq("connection_id", connection).eq("operation_id", operation_id).eq("actor_id", actor).limit(1).execute().data or []
    if not rows:
        raise HTTPException(404, "This action is unavailable to your account.")
    row = rows[0]
    if row["state"] == "sending" and _time(row["dispatched_at"]) < datetime.now(timezone.utc)-timedelta(seconds=120):
        row["state"] = "unknown"
    return row


def execute(team, connection, actor, operation_id):
    writes_ready()
    original = operation(team, connection, actor, operation_id)
    if original["state"] == "succeeded":
        return original
    if original["state"] != "prepared":
        raise HTTPException(*ERRORS["outcome_unknown"])
    if not call("can_edit", connection=connection, actor=actor, kind=original["kind"]):
        raise HTTPException(403, "The owner has not enabled this Shopify edit for you.")
    with session(team, connection, actor) as (c, api, token):
        # Refresh product evidence before dispatch. Shopify has no product CAS here.
        if original["kind"] == "product":
            current = _product(api, original["intent"]["product_gid"], token)
            if current["updatedAt"] != original["snapshot"]["updatedAt"]:
                raise HTTPException(409, "This product changed in Shopify. Review a fresh change.")
        else:
            _inventory(api, original["intent"]["inventory_item_gid"], original["intent"]["location_gid"], token)
        sent = call("dispatch_edit", connection=connection, actor=actor, lease=c["io_lease"], operation=operation_id)
        if sent["state"] == "succeeded":
            return sent
        state, receipt = "unknown", None
        try:
            intent = sent["intent"]
            if sent["kind"] == "product":
                result = api.mutation("product", {"product": {"id": intent["product_gid"], **intent["changes"]}}, token).get("productUpdate", {})
                actual = result.get("product")
                if not result.get("userErrors") and actual and actual.get("id") == intent["product_gid"] and all(
                    set(actual.get(k, [])) == set(v) if k == "tags" else actual.get(k) == v for k, v in intent["changes"].items()):
                    state, receipt = "succeeded", {"product": actual}
                elif result.get("userErrors") and not actual:
                    state, receipt = "failed", {"message": "Shopify rejected this product change."}
            else:
                variables = {"key": operation_id, "input": {"reason": "correction", "name": "available",
                    "referenceDocumentUri": "findez://shopify/operations/"+operation_id,
                    "changes": [{"inventoryItemId": intent["inventory_item_gid"], "locationId": intent["location_gid"], "delta": intent["delta"]}]}}
                result = api.mutation("inventory", variables, token).get("inventoryAdjustQuantities", {})
                actual = result.get("inventoryAdjustmentGroup")
                if not result.get("userErrors") and actual and actual.get("referenceDocumentUri") == variables["input"]["referenceDocumentUri"] and any(change.get("name") == "available" and change.get("delta") == intent["delta"] for change in actual.get("changes", [])):
                    state, receipt = "succeeded", {"adjustment": actual}
                elif result.get("userErrors") and not actual:
                    state, receipt = "failed", {"message": "Shopify rejected this stock adjustment."}
        except (ShopifyError, KeyError, ValueError, TypeError):
            # A timeout or partial response cannot prove that a write failed.
            state = "unknown"
        saved = call("finish_edit", connection=connection, lease=c["io_lease"], operation=operation_id, state=state, receipt=receipt)
        if not saved:
            raise HTTPException(409, "Shopify's result could not be recorded. Check Shopify before making another change.")
        return {**sent, "state": state, "receipt": receipt}
