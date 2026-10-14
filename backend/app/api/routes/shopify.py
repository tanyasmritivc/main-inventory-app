"""Optional Shopify pilot routes. Credentials never cross the client boundary."""
import hmac
import json
import secrets
from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from fastapi.responses import RedirectResponse

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.config import get_settings
from app.services.supabase_client import get_supabase_admin
from app.services.shopify_api import (
    API_VERSION, SHOP_QUERY, TOPICS, ShopifyAPI, ShopifyError, Vault, auth_url,
    canonical_shop, ready, state_hash, verify_callback, verify_webhook, requested_scopes, SCOPES,
)
from app.services.shopify_sync import rpc

router = APIRouter(tags=["shopify"])
COOKIE = "findez_shopify_state"
PUBLIC_COLUMNS = "connection_id,team_id,shop_domain,shop_name,status,last_attempt_at,last_success_at,error_code,edit_products,edit_inventory,edit_access,permission_revision,granted_scopes"


def membership(team, actor, owner=False):
    db = get_supabase_admin()
    rows = db.table("team_memberships").select("role").eq("team_id", str(team)).eq("user_id", actor).limit(1).execute().data or []
    if not rows:
        raise HTTPException(403, "You are not a member of this team.")
    if owner:
        teams = db.table("teams").select("owner_user_id").eq("team_id", str(team)).eq("owner_user_id", actor).limit(1).execute().data or []
        if not teams:
            raise HTTPException(403, "Only the team owner can manage this connection.")
    return rows[0]


def enabled():
    settings = get_settings()
    if not ready(settings):
        raise HTTPException(503, "Shopify connection is not configured yet.")
    return settings


def connection(team, connection_id):
    rows = get_supabase_admin().table("shopify_connections").select(PUBLIC_COLUMNS).eq(
        "team_id", str(team)).eq("connection_id", str(connection_id)).limit(1).execute().data or []
    if not rows:
        raise HTTPException(404, "This store is not connected to this team.")
    return rows[0]


@router.get("/teams/{team_id}/shopify")
def status(team_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    member = membership(team_id, user.user_id)
    settings = get_settings()
    if not ready(settings):
        return {"enabled": False, "connections": [], "can_manage": False, "pilot_shop": None}
    db = get_supabase_admin()
    rows = db.table("shopify_connections").select(PUBLIC_COLUMNS).eq("team_id", str(team_id)).execute().data or []
    for row in rows:
        owner = bool(db.table("teams").select("team_id").eq("team_id", str(team_id)).eq("owner_user_id", user.user_id).limit(1).execute().data)
        allowed = owner or (row.get("edit_access") == "editors" and member["role"] in ("mentor", "member"))
        writes = getattr(settings, "shopify_writes_enabled", False) and row["status"] == "connected" and allowed
        scopes = row.get("granted_scopes", [])
        row["can_edit_products"] = bool(writes and row.get("edit_products") and "write_products" in scopes)
        row["can_edit_inventory"] = bool(writes and row.get("edit_inventory") and "write_inventory" in scopes)
        jobs = db.table("shopify_sync_jobs").select("attempts,available_at").eq("connection_id", row["connection_id"]).execute().data or []
        row["sync_status"] = ("failed" if jobs and jobs[0]["available_at"] == "infinity" else
            "syncing" if jobs else "queued" if row["status"] == "connected" and not row["last_success_at"] else "idle")
        # Pending webhook/manual requests should not be displayed as current.
        pending = db.table("shopify_connections").select("sync_requested").eq("connection_id", row["connection_id"]).execute().data or []
        if row["sync_status"] == "idle" and pending and pending[0]["sync_requested"]:
            row["sync_status"] = "queued"
    return {"enabled": True, "connections": rows, "can_manage": member["role"] == "owner", "pilot_shop": settings.shopify_pilot_shop,
        "edits_enabled": getattr(settings, "shopify_writes_enabled", False)}


@router.post("/teams/{team_id}/shopify/authorize")
def authorize(team_id: UUID, response: Response, user: AuthenticatedUser = Depends(get_current_user)):
    membership(team_id, user.user_id, owner=True)
    settings = enabled()
    if not getattr(settings, "shopify_writes_enabled", False):
        policies = get_supabase_admin().table("shopify_connections").select("edit_products,edit_inventory").eq(
            "team_id", str(team_id)).eq("shop_domain", settings.shopify_pilot_shop).limit(1).execute().data or []
        if any(row.get("edit_products") or row.get("edit_inventory") for row in policies):
            raise HTTPException(503, "Disable edits in connection permissions before reconnecting without edit support.")
    nonce = secrets.token_urlsafe(32)
    try:
        started = rpc("begin_auth", team=str(team_id), actor=user.user_id, shop=settings.shopify_pilot_shop, state_hash=state_hash(nonce))
    except Exception:
        raise HTTPException(409, "The store cannot be connected to this team. Check its existing connection.") from None
    # The nonce is also bound to the browser that initiated the owner action.
    response.set_cookie(COOKIE, nonce, max_age=600, secure=True, httponly=True, samesite="lax",
        path="/integrations/shopify/callback")
    response.headers["Cache-Control"] = "no-store"
    scopes = started.get("requested_scopes", SCOPES) if isinstance(started, dict) else SCOPES
    if not getattr(settings, "shopify_writes_enabled", False) and set(scopes) - SCOPES:
        raise HTTPException(503, "Shopify edits are not enabled yet.")
    return {"authorization_url": auth_url(settings, nonce, scopes)}


@router.get("/integrations/shopify/callback")
def callback(request: Request):
    pairs = list(request.query_params.multi_items())
    # Uvicorn/proxy access logs must not retain authorization codes or nonces.
    # Upstream reverse proxies must separately disable callback query logging.
    request.scope["query_string"] = b""
    settings = enabled()
    result = "failed"
    team_id = None
    api = None
    try:
        params = verify_callback(pairs, settings.shopify_client_secret)
        cookie = request.cookies.get(COOKIE, "")
        if not cookie or not hmac.compare_digest(cookie, params["state"]):
            raise ShopifyError()
        consumed = rpc("consume_state", hash=state_hash(params["state"]), shop=params["shop"])
        if not consumed:
            raise ShopifyError()
        c = consumed["connection"]
        team_id = str(UUID(c["team_id"]))
        api = ShopifyAPI(settings, params["shop"])
        expected = consumed.get("requested_scopes", SCOPES)
        if not getattr(settings, "shopify_writes_enabled", False) and set(expected) - SCOPES:
            raise ShopifyError()
        tokens, scopes, access, refresh = api.tokens(code=params["code"], expected=expected)
        data, _ = api.query(SHOP_QUERY, {}, tokens["access"])
        shop = data["shop"]
        if shop["myshopifyDomain"] != c["shop_domain"]:
            raise ShopifyError()
        saved = rpc("finish_auth", connection=c["connection_id"], generation=c["generation"], actor=consumed["actor_id"],
            gid=shop["id"], name=shop["name"], scopes=scopes, tokens=Vault(settings).encrypt(tokens, c["connection_id"], c["generation"]),
            access_expiry=access, refresh_expiry=refresh)
        if saved:
            result = "connected"
    except Exception:
        # Browser gets a fixed failure marker, never query/code/token details.
        pass
    finally:
        if api:
            api.close()
    destination = settings.frontend_url.rstrip("/") + "/teams?shopify=" + result
    if team_id:
        destination += "&team=" + team_id
    response = RedirectResponse(destination, status_code=303)
    response.delete_cookie(COOKIE, secure=True, httponly=True, samesite="lax", path="/integrations/shopify/callback")
    response.headers.update({"Cache-Control": "no-store", "Referrer-Policy": "no-referrer"})
    return response


@router.post("/teams/{team_id}/shopify/{connection_id}/sync")
def sync(team_id: UUID, connection_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    membership(team_id, user.user_id, owner=True)
    enabled()
    connection(team_id, connection_id)
    if not rpc("request_sync", connection=str(connection_id), actor=user.user_id):
        raise HTTPException(409, "Reconnect this store before syncing.")
    return {"queued": True}


@router.delete("/teams/{team_id}/shopify/{connection_id}")
def disconnect(team_id: UUID, connection_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    membership(team_id, user.user_id, owner=True)
    # Disconnection remains possible even when app configuration is removed.
    connection(team_id, connection_id)
    if not rpc("disconnect", connection=str(connection_id), actor=user.user_id):
        raise HTTPException(409, "This store could not be disconnected.")
    return {"disconnected": True}


@router.get("/teams/{team_id}/shopify/{connection_id}/catalog")
def catalog(team_id: UUID, connection_id: UUID, after: str | None = None, user: AuthenticatedUser = Depends(get_current_user)):
    membership(team_id, user.user_id)
    enabled()
    connection(team_id, connection_id)
    if after and (len(after) > 100 or not after.startswith("gid://shopify/ProductVariant/")):
        raise HTTPException(400, "Invalid catalog page.")
    db = get_supabase_admin()
    query = db.table("shopify_variants").select("variant_gid,product_gid,product_title,variant_title,product_status,options,sku,barcodes,image_url,inventory_item_gid,tracked,source_updated_at,synced_at").eq(
        "connection_id", str(connection_id)).is_("deleted_at", "null")
    if after:
        query = query.gt("variant_gid", after)
    rows = query.order("variant_gid").limit(21).execute().data or []
    next_page = rows[19]["variant_gid"] if len(rows) > 20 else None
    rows = rows[:20]
    # Page each stock connection too: no hidden PostgREST row-cap truncation.
    for row in rows:
        levels, offset = [], 0
        while True:
            page = db.table("shopify_inventory_levels").select("location_gid,location_name,location_active,quantities,source_updated_at,synced_at").eq(
                "connection_id", str(connection_id)).eq("inventory_item_gid", row["inventory_item_gid"]).order("location_gid").range(offset, offset+99).execute().data or []
            levels.extend(page)
            if len(page) < 100:
                break
            offset += 100
        row["shopify_inventory"] = levels
    return {"variants": rows, "next_cursor": next_page}


@router.post("/integrations/shopify/webhooks")
async def webhook(request: Request):
    settings = get_settings()
    # Compliance/disconnect deliveries remain processable with the feature flag off.
    if not settings.shopify_client_secret:
        raise HTTPException(503, "Shopify webhook is not configured.")
    body = bytearray()
    async for chunk in request.stream():
        body.extend(chunk)
        if len(body) > 2 * 1024 * 1024:
            raise HTTPException(413, "Webhook is too large.")
    if not verify_webhook(bytes(body), request.headers.get("X-Shopify-Hmac-Sha256"), settings.shopify_client_secret):
        raise HTTPException(401, "Invalid webhook signature.")
    try:
        shop = canonical_shop(request.headers.get("X-Shopify-Shop-Domain"))
        delivery = str(UUID(request.headers.get("X-Shopify-Webhook-Id", "")))
        topic = request.headers.get("X-Shopify-Topic", "")
        if topic not in TOPICS:
            raise ValueError()
        payload = json.loads(body)
        if not isinstance(payload, dict):
            raise ValueError()
        shop_gid = None
        if topic == "app/uninstalled":
            # HMAC covers the body, not the headers. A signed Shop payload must
            # identify the same store before it can revoke an installation.
            if "shop_owner" not in payload or "myshopify_domain" not in payload:
                raise ValueError()
            identifier = str(payload["id"])
            if not identifier.isdecimal():
                raise ValueError()
            shop_gid = "gid://shopify/Shop/" + identifier
            if payload["myshopify_domain"] and payload["myshopify_domain"] != shop:
                raise ValueError()
        elif topic in {"shop/redact", "customers/redact", "customers/data_request"}:
            if payload.get("shop_domain") != shop or not str(payload.get("shop_id", "")).isdecimal():
                raise ValueError()
            shop_gid = "gid://shopify/Shop/" + str(payload["shop_id"])
        triggered = datetime.fromisoformat(request.headers.get("X-Shopify-Triggered-At", "").replace("Z", "+00:00"))
        if triggered.tzinfo is None:
            raise ValueError()
        if request.headers.get("X-Shopify-API-Version") != API_VERSION and topic not in {"customers/data_request", "customers/redact", "shop/redact"}:
            raise ValueError()
    except (ShopifyError, ValueError, TypeError):
        raise HTTPException(400, "Invalid webhook headers.") from None
    # Synchronous RPC off the event loop; commit delivery and dirty flag before ACK.
    from starlette.concurrency import run_in_threadpool
    await run_in_threadpool(rpc, "receive_webhook", delivery=delivery,
        event=request.headers.get("X-Shopify-Event-Id", "")[:200], shop=shop, topic=topic,
        triggered=triggered.isoformat(), shop_gid=shop_gid)
    return Response(status_code=200)
