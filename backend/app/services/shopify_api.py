"""Bounded Shopify adapter. Only fixed read queries and OAuth token exchange."""
import base64
import hashlib
import hmac
import json
import os
import re
from datetime import datetime, timedelta, timezone
from urllib.parse import urlencode, urlsplit

import httpx
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

API_VERSION = "2026-10"
SCOPES = frozenset({"read_products", "read_inventory"})
TOPICS = frozenset({"products/create", "products/update", "products/delete",
    "inventory_items/create", "inventory_items/update", "inventory_items/delete",
    "inventory_levels/update", "inventory_levels/connect", "inventory_levels/disconnect",
    "app/uninstalled", "app/scopes_update",
    "customers/data_request", "customers/redact", "shop/redact"})
SHOP_QUERY = "query FindEZShop { shop { id name myshopifyDomain } }"
VARIANTS_QUERY = """query FindEZVariants($after: String) {
  productVariants(first: 20, after: $after) {
    pageInfo { hasNextPage endCursor }
    nodes {
      id title updatedAt selectedOptions { name value }
      barcodes(first: 20) { nodes { value type } pageInfo { hasNextPage } }
      media(first: 1) { nodes { preview { image { url } } } }
      product { id title status featuredMedia { preview { image { url } } } }
      inventoryItem { id sku tracked }
    }
  }
}"""
LEVELS_QUERY = """query FindEZLevels($id: ID!, $after: String) {
  inventoryItem(id: $id) {
    id tracked
    inventoryLevels(first: 50, after: $after) {
      pageInfo { hasNextPage endCursor }
      nodes { updatedAt location { id name isActive }
        quantities(names: [\"available\", \"on_hand\", \"committed\", \"incoming\"]) { name quantity }
      }
    }
  }
}"""


class ShopifyError(Exception):
    """Safe error codes only. Never include upstream body, token or exception."""
    def __init__(self, code="api_error", delay=30):
        super().__init__(code)
        self.code, self.delay = code, delay


def canonical_shop(value: str) -> str:
    if not isinstance(value, str) or len(value) > 253 or not re.fullmatch(
        r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.myshopify\.com", value
    ):
        raise ShopifyError()
    return value


def ready(settings) -> bool:
    if not settings.shopify_enabled:
        return False
    try:
        canonical_shop(settings.shopify_pilot_shop)
        uri = urlsplit(settings.shopify_redirect_uri or "")
        frontend = urlsplit(settings.frontend_url)
        if (uri.scheme != "https" or not uri.hostname or uri.username or uri.password
            or uri.query or uri.fragment or uri.path != "/integrations/shopify/callback"
            or frontend.scheme != "https" or not frontend.hostname):
            return False
        Vault(settings)
        return bool(settings.shopify_client_id and settings.shopify_client_secret)
    except (ShopifyError, ValueError, TypeError, KeyError):
        return False


class Vault:
    """AEAD binds ciphertext to connection and install generation; supports old keys."""
    def __init__(self, settings):
        self.active = settings.shopify_active_key_id
        raw = json.loads(settings.shopify_token_keys or "{}")
        if not isinstance(raw, dict):
            raise ValueError("Invalid Shopify vault configuration")
        self.keys = {k: base64.urlsafe_b64decode(v) for k, v in raw.items()}
        if self.active not in self.keys or any(len(v) != 32 for v in self.keys.values()):
            raise ValueError("Invalid Shopify vault configuration")
        if any(not re.fullmatch(r"[a-zA-Z0-9_-]{1,32}", k) for k in self.keys):
            raise ValueError("Invalid Shopify key identifier")

    @staticmethod
    def _aad(connection, generation):
        return f"shopify:{connection}:{generation}".encode()

    def encrypt(self, tokens, connection, generation):
        nonce = os.urandom(12)
        data = AESGCM(self.keys[self.active]).encrypt(nonce, json.dumps(tokens).encode(), self._aad(connection, generation))
        return self.active + "." + base64.urlsafe_b64encode(nonce + data).decode()

    def decrypt(self, ciphertext, connection, generation):
        key, data = ciphertext.split(".", 1)
        data = base64.urlsafe_b64decode(data)
        return json.loads(AESGCM(self.keys[key]).decrypt(data[:12], data[12:], self._aad(connection, generation)))


def state_hash(value):
    return hashlib.sha256(value.encode()).hexdigest()


def verify_callback(pairs, secret):
    # Reject duplicate parameters rather than canonicalizing an ambiguous request.
    if len(pairs) != len(dict(pairs)) or len(pairs) > 20:
        raise ShopifyError()
    params = dict(pairs)
    supplied = params.pop("hmac", "")
    message = "&".join(f"{k}={v}" for k, v in sorted(params.items()))
    expected = hmac.new(secret.encode(), message.encode(), hashlib.sha256).hexdigest()
    if not re.fullmatch(r"[a-f0-9]{64}", supplied) or not hmac.compare_digest(expected, supplied):
        raise ShopifyError()
    try:
        stamp = int(params["timestamp"])
        if abs(datetime.now(timezone.utc).timestamp() - stamp) > 600:
            raise ValueError()
        canonical_shop(params["shop"])
        if not params.get("code") or not params.get("state"):
            raise ValueError()
    except (ValueError, KeyError):
        raise ShopifyError() from None
    return params


def verify_webhook(body, signature, secret):
    expected = base64.b64encode(hmac.new(secret.encode(), body, hashlib.sha256).digest()).decode()
    return isinstance(signature, str) and bool(re.fullmatch(r"[A-Za-z0-9+/]{43}=", signature)) and hmac.compare_digest(expected, signature)


def auth_url(settings, state):
    return f"https://{canonical_shop(settings.shopify_pilot_shop)}/admin/oauth/authorize?" + urlencode({
        "client_id": settings.shopify_client_id, "scope": ",".join(sorted(SCOPES)),
        "redirect_uri": settings.shopify_redirect_uri, "state": state,
    })


def token_metadata(data):
    try:
        granted = set(data["scope"].split(","))
        # This pilot never accepts overbroad customer/order/write scopes.
        if granted != SCOPES or not data["access_token"] or not data["refresh_token"]:
            raise ValueError()
        access, refresh = int(data["expires_in"]), int(data["refresh_token_expires_in"])
        if access <= 0 or refresh <= 0:
            raise ValueError()
        now = datetime.now(timezone.utc)
        return {"access": data["access_token"], "refresh": data["refresh_token"]}, sorted(granted), (
            now + timedelta(seconds=access)).isoformat(), (now + timedelta(seconds=refresh)).isoformat()
    except (KeyError, ValueError, TypeError, OverflowError):
        raise ShopifyError("reconnect") from None


class ShopifyAPI:
    def __init__(self, settings, shop, client=None):
        self.settings, self.shop = settings, canonical_shop(shop)
        self.client = client or httpx.Client(timeout=20, follow_redirects=False)
        self.owns_client = client is None

    def close(self):
        if self.owns_client:
            self.client.close()

    def tokens(self, *, code=None, refresh=None):
        payload = {"client_id": self.settings.shopify_client_id, "client_secret": self.settings.shopify_client_secret}
        if code:
            payload.update(code=code, expiring=1)
        else:
            payload.update(grant_type="refresh_token", refresh_token=refresh)
        response = self._post("/admin/oauth/access_token", data=payload)
        return token_metadata(self._json(response))

    def _post(self, path, **kwargs):
        try:
            response = self.client.post(f"https://{self.shop}{path}", **kwargs)
        except httpx.HTTPError:
            raise ShopifyError("network") from None
        if response.status_code in (401, 403):
            raise ShopifyError("reconnect")
        if response.status_code == 400 and path == "/admin/oauth/access_token":
            raise ShopifyError("reconnect")
        if response.status_code == 429:
            raise ShopifyError("throttled", 60)
        if response.status_code >= 500:
            raise ShopifyError("network")
        if response.status_code != 200:
            raise ShopifyError()
        return response

    @staticmethod
    def _json(response):
        try:
            return response.json()
        except ValueError:
            raise ShopifyError() from None

    def query(self, query, variables, token):
        if query not in (SHOP_QUERY, VARIANTS_QUERY, LEVELS_QUERY):
            raise ShopifyError()
        response = self._post(f"/admin/api/{API_VERSION}/graphql.json",
            json={"query": query, "variables": variables}, headers={"X-Shopify-Access-Token": token})
        if response.headers.get("X-Shopify-API-Version") != API_VERSION:
            raise ShopifyError("api_version")
        data = self._json(response)
        errors = data.get("errors")
        if errors:
            codes = {e.get("extensions", {}).get("code") for e in errors if isinstance(e, dict)}
            if "THROTTLED" in codes:
                raise ShopifyError("throttled", 60)
            if "ACCESS_DENIED" in codes:
                raise ShopifyError("reconnect")
            # Even a partial GraphQL result is not a successful page.
            raise ShopifyError()
        if not isinstance(data.get("data"), dict):
            raise ShopifyError()
        cost = data.get("extensions", {}).get("cost", {})
        throttle = cost.get("throttleStatus", {})
        rate = throttle.get("restoreRate", 0)
        available = throttle.get("currentlyAvailable", 0)
        # Next durable step is delayed when Shopify reports a low cost budget.
        requested = cost.get("requestedQueryCost", 500)
        delay = max(0, int((requested - available) / rate) + 1) if rate and available < requested else 0
        return data["data"], min(delay, 60)


def next_cursor(connection):
    page = connection["pageInfo"]
    after = page.get("endCursor")
    if page["hasNextPage"] and not after:
        raise ShopifyError()
    return after if page["hasNextPage"] else None


def map_variants(connection):
    rows = []
    for node in connection["nodes"]:
        item, product = node["inventoryItem"], node["product"]
        if node["barcodes"]["pageInfo"]["hasNextPage"]:
            # 2026-10 allows at most 20. Fail safely if that contract ever changes.
            raise ShopifyError()
        rows.append({"variant_gid": node["id"], "product_gid": product["id"],
            "product_title": product["title"], "variant_title": node["title"],
            "product_status": product["status"], "options": node["selectedOptions"],
            "sku": item.get("sku"), "barcodes": node["barcodes"]["nodes"],
            "image_url": next((media.get("preview", {}).get("image", {}).get("url")
                for media in node.get("media", {}).get("nodes", []) if media.get("preview") and media["preview"].get("image")),
                (((product.get("featuredMedia") or {}).get("preview") or {}).get("image") or {}).get("url")),
            "inventory_item_gid": item["id"], "tracked": item["tracked"], "source_updated_at": node["updatedAt"]})
    return rows


def map_levels(item):
    if not item or not item["tracked"]:
        return []
    return [{"inventory_item_gid": item["id"], "location_gid": level["location"]["id"],
        "location_name": level["location"]["name"], "location_active": level["location"]["isActive"],
        "quantities": {q["name"]: q["quantity"] for q in level["quantities"]},
        "source_updated_at": level["updatedAt"]} for level in item["inventoryLevels"]["nodes"]]
