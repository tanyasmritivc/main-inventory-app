import base64
import hashlib
import hmac
import json
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from urllib.parse import urlencode

import httpx
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.routes import shopify as routes
from app.core.auth import AuthenticatedUser, get_current_user
from app.services import shopify_api as api, shopify_sync as sync

TEAM = "10000000-0000-0000-0000-000000000001"
ACTOR = "20000000-0000-0000-0000-000000000001"
CONNECTION = "30000000-0000-0000-0000-000000000001"
GENERATION = "40000000-0000-0000-0000-000000000001"


@pytest.fixture
def settings():
    return SimpleNamespace(shopify_enabled=True, shopify_client_id="test-client", shopify_client_secret="test-secret",
        shopify_pilot_shop="findez-test.myshopify.com", shopify_redirect_uri="https://api.findez.test/integrations/shopify/callback",
        frontend_url="https://www.findez.test", shopify_token_keys=json.dumps({"v1": base64.urlsafe_b64encode(b"x"*32).decode()}),
        shopify_active_key_id="v1")


def signed_params(settings, **overrides):
    params = {"shop": settings.shopify_pilot_shop, "code": "test-code", "state": "test-state",
        "timestamp": str(int(datetime.now(timezone.utc).timestamp())), **overrides}
    message = "&".join(f"{k}={v}" for k, v in sorted(params.items()))
    return list(params.items()) + [("hmac", hmac.new(settings.shopify_client_secret.encode(), message.encode(), hashlib.sha256).hexdigest())]


@pytest.mark.parametrize("shop", ["https://test.myshopify.com", "test.myshopify.com.evil.test", "evil@a.myshopify.com",
    "127.0.0.1", "a.myshopify.com/path", "a.myshopify.com:443", "a\n.myshopify.com", "A.myshopify.com"])
def test_rejects_arbitrary_network_hosts(shop):
    with pytest.raises(api.ShopifyError): api.canonical_shop(shop)


def test_disabled_or_incomplete_config_fails_closed(settings):
    assert api.ready(settings)
    settings.shopify_enabled = False
    assert not api.ready(settings)
    settings.shopify_enabled = True
    settings.shopify_token_keys = "{}"
    assert not api.ready(settings)


def test_vault_rotation_and_tenant_install_binding(settings):
    vault = api.Vault(settings)
    encrypted = vault.encrypt({"access": "test-access", "refresh": "test-refresh"}, CONNECTION, GENERATION)
    assert "test-access" not in encrypted
    assert vault.decrypt(encrypted, CONNECTION, GENERATION)["access"] == "test-access"
    with pytest.raises(Exception): vault.decrypt(encrypted, TEAM, GENERATION)
    with pytest.raises(Exception): vault.decrypt(encrypted, CONNECTION, TEAM)
    settings.shopify_token_keys = json.dumps({"v1": base64.urlsafe_b64encode(b"x"*32).decode(), "v2": base64.urlsafe_b64encode(b"y"*32).decode()})
    settings.shopify_active_key_id = "v2"
    rotated = api.Vault(settings)
    assert rotated.decrypt(encrypted, CONNECTION, GENERATION)["refresh"] == "test-refresh"
    assert rotated.encrypt({}, CONNECTION, GENERATION).startswith("v2.")


def test_callback_hmac_freshness_and_duplicate_rejection(settings):
    assert api.verify_callback(signed_params(settings), settings.shopify_client_secret)["code"] == "test-code"
    with pytest.raises(api.ShopifyError): api.verify_callback(signed_params(settings)+[("shop", "other.myshopify.com")], settings.shopify_client_secret)
    with pytest.raises(api.ShopifyError): api.verify_callback(signed_params(settings, timestamp="1"), settings.shopify_client_secret)
    with pytest.raises(api.ShopifyError): api.verify_callback(signed_params(settings), "wrong")


def test_webhook_uses_raw_body_constant_time_signature(settings):
    raw = b'{"shop_id": 7}'
    signature = base64.b64encode(hmac.new(settings.shopify_client_secret.encode(), raw, hashlib.sha256).digest()).decode()
    assert api.verify_webhook(raw, signature, settings.shopify_client_secret)
    assert not api.verify_webhook(b'{"shop_id":7}', signature, settings.shopify_client_secret)


def tokens():
    return {"scope": ",".join(sorted(api.SCOPES)), "access_token": "test-access", "refresh_token": "test-refresh", "expires_in": 100, "refresh_token_expires_in": 200}


@pytest.mark.parametrize("change", [{"scope": "read_products"}, {"scope": "read_products,read_inventory,write_inventory"}, {"expires_in": 0}, {"refresh_token": ""}])
def test_refuses_missing_extra_or_nonexpiring_authorization(change):
    with pytest.raises(api.ShopifyError): api.token_metadata({**tokens(), **change})


def test_reads_actual_token_lifetimes():
    _, scopes, access, refresh = api.token_metadata(tokens())
    now = datetime.now(timezone.utc)
    assert 95 < (datetime.fromisoformat(access)-now).total_seconds() <= 100
    assert 195 < (datetime.fromisoformat(refresh)-now).total_seconds() <= 200
    assert set(scopes) == api.SCOPES


@pytest.mark.parametrize("body,status,version,code", [
    ({"errors": [{"message": "secret upstream detail", "extensions": {"code": "THROTTLED"}}]},200,api.API_VERSION,"throttled"),
    ({"data": {"shop": {}}, "errors": [{"message": "private detail"}]},200,api.API_VERSION,"api_error"),
    ({},401,api.API_VERSION,"reconnect"), ({},200,"2026-07","api_version"), ({},302,api.API_VERSION,"api_error"),
])
def test_graphql_partial_errors_throttle_auth_version_and_redirect(settings,body,status,version,code):
    client = httpx.Client(transport=httpx.MockTransport(lambda req: httpx.Response(status,json=body,headers={"X-Shopify-API-Version": version})))
    adapter = api.ShopifyAPI(settings,settings.shopify_pilot_shop,client)
    with pytest.raises(api.ShopifyError) as error: adapter.query(api.SHOP_QUERY,{},"test-access")
    assert str(error.value) == code
    client.close()


def test_token_refresh_and_query_only_allow_fixed_reads(settings):
    calls = []
    def handle(request):
        calls.append(request)
        return httpx.Response(200,json=tokens())
    with httpx.Client(transport=httpx.MockTransport(handle)) as client:
        adapter = api.ShopifyAPI(settings,settings.shopify_pilot_shop,client)
        adapter.tokens(code="test-code")
        assert b"expiring=1" in calls[-1].content
        adapter.tokens(refresh="test-refresh")
        assert b"grant_type=refresh_token" in calls[-1].content
        with pytest.raises(api.ShopifyError): adapter.query("mutation { inventoryAdjustQuantities }",{},"test-access")
        assert len(calls)==2


def variant_node():
    return {"id":"gid://shopify/ProductVariant/1", "title":"Black / M", "updatedAt":"2026-10-12T10:00:00Z",
        "selectedOptions":[{"name":"Size","value":"M"}], "barcodes":{"nodes":[{"value":"0012","type":None},{"value":"0034","type":None}],"pageInfo":{"hasNextPage":False}},
        "media":{"nodes":[]}, "product":{"id":"gid://shopify/Product/1","title":"Hoodie","status":"ACTIVE","featuredImage":None},
        "inventoryItem":{"id":"gid://shopify/InventoryItem/1","sku":"Case-SKU","tracked":False}}


def test_catalog_preserves_variants_duplicate_sku_barcodes_and_unknown_count():
    node = variant_node()
    other = {**node,"id":"gid://shopify/ProductVariant/2","title":"Black / L"}
    rows = api.map_variants({"nodes":[node,other]})
    assert len(rows)==2 and rows[0]["sku"]==rows[1]["sku"]=="Case-SKU"
    assert rows[0]["barcodes"][0]["value"]=="0012"
    assert "quantity" not in rows[0] and "location" not in rows[0]
    assert api.map_levels({"tracked":False}) == []
    node["barcodes"]["pageInfo"]["hasNextPage"] = True
    with pytest.raises(api.ShopifyError): api.map_variants({"nodes":[node]})


class Query:
    def __init__(self, db, name): self.db,self.name,self.filters,self.limit_value = db,name,{},None
    def select(self,*args): return self
    def eq(self,key,value): self.filters[key]=value; return self
    def is_(self,*args): return self
    def gt(self,*args): return self
    def order(self,*args): return self
    def range(self,*args): return self
    def limit(self,value): self.limit_value=value; return self
    def execute(self):
        self.db.calls.append((self.name, self.filters))
        rows=self.db.rows.get(self.name, [])
        rows=[dict(row) for row in rows if all(row.get(key)==value for key,value in self.filters.items())]
        return SimpleNamespace(data=rows[:self.limit_value] if self.limit_value else rows)


class DB:
    def __init__(self,rows): self.rows,self.calls=rows,[]
    def table(self,name): return Query(self,name)


@pytest.fixture
def route_client(monkeypatch,settings):
    db=DB({"team_memberships":[{"team_id":TEAM,"user_id":ACTOR,"role":"owner"}],
        "teams":[{"team_id":TEAM,"owner_user_id":ACTOR}],
        "shopify_connections":[{"team_id":TEAM,"connection_id":CONNECTION,"status":"connected","last_success_at":None,"sync_requested":True}]})
    monkeypatch.setattr(routes,"get_settings",lambda:settings)
    monkeypatch.setattr(routes,"get_supabase_admin",lambda:db)
    app=FastAPI(); app.include_router(routes.router)
    app.dependency_overrides[get_current_user]=lambda:AuthenticatedUser(user_id=ACTOR)
    return TestClient(app,base_url="https://api.findez.test"),db


def test_owner_only_connection_and_cross_team_catalog(route_client,monkeypatch):
    client,db=route_client
    called=[]; monkeypatch.setattr(routes,"rpc",lambda *a,**k:called.append((a,k)) or True)
    response=client.post(f"/teams/{TEAM}/shopify/authorize")
    assert response.status_code==200 and "Secure" in response.headers["set-cookie"] and "HttpOnly" in response.headers["set-cookie"]
    assert "read_inventory%2Cread_products" in response.json()["authorization_url"]
    assert len(called)==1
    db.rows["teams"]=[]
    assert client.post(f"/teams/{TEAM}/shopify/{CONNECTION}/sync").status_code==403
    assert len(called)==1
    db.rows["team_memberships"]=[]
    assert client.get(f"/teams/{TEAM}/shopify/{CONNECTION}/catalog").status_code==403
    assert client.delete(f"/teams/{TEAM}/shopify/{CONNECTION}").status_code==403


def test_disabled_status_does_not_query_missing_migration(route_client,settings):
    client,db=route_client; settings.shopify_enabled=False
    assert client.get(f"/teams/{TEAM}/shopify").json()["enabled"] is False
    assert all(table=="team_memberships" for table,_ in db.calls)


def test_callback_requires_browser_state_and_rejects_replay(route_client,settings,monkeypatch):
    client,_=route_client
    called=[]
    monkeypatch.setattr(routes,"rpc",lambda *a,**k:called.append((a,k)) or None)
    url="/integrations/shopify/callback?"+urlencode(signed_params(settings))
    response=client.get(url,follow_redirects=False)
    assert response.status_code==303 and response.headers["location"].endswith("shopify=failed")
    assert not called
    client.cookies.set(routes.COOKIE,"test-state")
    response=client.get(url,follow_redirects=False)
    assert response.headers["location"].endswith("shopify=failed") and called[0][0]==("consume_state",)
    assert "test-code" not in response.text and response.headers["referrer-policy"]=="no-referrer"


def test_callback_success_encrypts_tokens_and_redirects_to_team(route_client,settings,monkeypatch):
    client,_=route_client; calls=[]
    def rpc(operation,**kwargs):
        calls.append((operation,kwargs))
        if operation=="consume_state": return {"connection":{"connection_id":CONNECTION,"generation":GENERATION,"team_id":TEAM,"shop_domain":settings.shopify_pilot_shop},"actor_id":ACTOR}
        return True
    monkeypatch.setattr(routes,"rpc",rpc)
    class Adapter:
        def __init__(self,*args): pass
        def tokens(self,**kwargs): return api.token_metadata(tokens())
        def query(self,*args): return {"shop":{"id":"gid://shopify/Shop/1","name":"Test shop","myshopifyDomain":settings.shopify_pilot_shop}},0
        def close(self): pass
    monkeypatch.setattr(routes,"ShopifyAPI",Adapter)
    client.cookies.set(routes.COOKIE,"test-state")
    response=client.get("/integrations/shopify/callback?"+urlencode(signed_params(settings)),follow_redirects=False)
    assert response.headers["location"]==f"https://www.findez.test/teams?shopify=connected&team={TEAM}"
    assert "test-access" not in calls[-1][1]["tokens"]
    assert calls[-1][1]["generation"]==GENERATION


def test_webhook_signature_durable_before_ack_and_header_validation(route_client,settings,monkeypatch):
    client,_=route_client; calls=[]
    monkeypatch.setattr(routes,"rpc",lambda *a,**k:calls.append((a,k)))
    body=b"{}"
    headers={"X-Shopify-Hmac-Sha256":base64.b64encode(hmac.new(settings.shopify_client_secret.encode(),body,hashlib.sha256).digest()).decode(),
        "X-Shopify-Shop-Domain":settings.shopify_pilot_shop,"X-Shopify-Webhook-Id":GENERATION,"X-Shopify-Topic":"products/update",
        "X-Shopify-Triggered-At":"2026-10-12T10:00:00Z","X-Shopify-API-Version":api.API_VERSION}
    assert client.post("/integrations/shopify/webhooks",content=body,headers=headers).status_code==200
    assert calls[0][0]==("receive_webhook",) and "body" not in calls[0][1]
    assert client.post("/integrations/shopify/webhooks",content=b"[]",headers=headers).status_code==401
    headers["X-Shopify-Shop-Domain"]="evil.test"
    assert client.post("/integrations/shopify/webhooks",content=body,headers=headers).status_code==400
    assert len(calls)==1


@pytest.mark.parametrize("stage", ["variants","levels","complete"])
def test_worker_checkpoints_pages_and_refreshes_under_lease(monkeypatch,settings,stage):
    c={"connection_id":CONNECTION,"generation":GENERATION,"shop_domain":settings.shopify_pilot_shop}
    cursor={"stage":"variants"} if stage=="variants" else {"stage":"levels","item":"gid://shopify/InventoryItem/1"} if stage=="levels" else {"stage":"levels"}
    j={"job_id":"run-id","lease_id":"lease-id","attempts":0,"cursor":cursor}
    calls=[]
    def rpc(name,**kwargs):
        calls.append((name,kwargs)); return {"connection":c,"job":j} if name=="claim_job" else True
    monkeypatch.setattr(sync,"rpc",rpc)
    vault=api.Vault(settings)
    expired=(datetime.now(timezone.utc)-timedelta(seconds=1)).isoformat()
    future=(datetime.now(timezone.utc)+timedelta(days=1)).isoformat()
    monkeypatch.setattr(sync,"current_credentials",lambda *_: {"encrypted_tokens":vault.encrypt({"access":"old","refresh":"old-refresh"},CONNECTION,GENERATION),"access_expires_at":expired,"refresh_expires_at":future})
    monkeypatch.setattr(sync,"next_inventory",lambda *args:None)
    class Adapter:
        def __init__(self,*args): pass
        def tokens(self,**kwargs): assert kwargs["refresh"]=="old-refresh"; return api.token_metadata(tokens())
        def query(self,query,variables,token):
            assert token=="test-access"
            if query==api.VARIANTS_QUERY: return {"productVariants":{"nodes":[variant_node()],"pageInfo":{"hasNextPage":True,"endCursor":"next"}}},2
            return {"inventoryItem":{"id":"gid://shopify/InventoryItem/1","tracked":True,"inventoryLevels":{"nodes":[],"pageInfo":{"hasNextPage":False,"endCursor":None}}}},0
        def close(self): pass
    monkeypatch.setattr(sync,"ShopifyAPI",Adapter)
    assert sync.work_once(settings)
    assert calls[1][0]=="save_tokens" and calls[1][1]["lease"]=="lease-id"
    name,commit=calls[-1]
    assert name=="commit_page" and commit["generation"]==GENERATION
    assert commit["complete"]==(stage=="complete")
    assert commit["cursor"].get("after")==("next" if stage=="variants" else None)


def test_failed_refresh_never_commits_catalog(monkeypatch,settings):
    c={"connection_id":CONNECTION,"generation":GENERATION,"shop_domain":settings.shopify_pilot_shop}
    j={"lease_id":"lease-id","attempts":1,"cursor":{"stage":"variants"}}
    calls=[]
    monkeypatch.setattr(sync,"rpc",lambda name,**kwargs:calls.append((name,kwargs)) or ({"connection":c,"job":j} if name=="claim_job" else True))
    monkeypatch.setattr(sync,"current_credentials",lambda *_:None)
    assert sync.work_once(settings)
    assert calls[-1][0]=="fail_job" and calls[-1][1]["error"]=="reconnect"
    assert all(name!="commit_page" for name,_ in calls)


def test_cost_budget_delays_the_next_page(settings):
    payload={"data":{"shop":{"id":"shop-1"}},"extensions":{"cost":{"requestedQueryCost":333,"throttleStatus":{"currentlyAvailable":12,"restoreRate":50}}}}
    with httpx.Client(transport=httpx.MockTransport(lambda request:httpx.Response(200,json=payload,headers={"X-Shopify-API-Version":api.API_VERSION}))) as client:
        data,delay=api.ShopifyAPI(settings,settings.shopify_pilot_shop,client).query(api.SHOP_QUERY,{},"test-access")
    assert data["shop"]["id"]=="shop-1" and delay==7


def test_cross_team_connection_cannot_be_read_by_own_team_member(route_client):
    client,db=route_client
    db.rows["shopify_connections"][0]["team_id"]="10000000-0000-0000-0000-000000000002"
    assert client.get(f"/teams/{TEAM}/shopify/{CONNECTION}/catalog").status_code==404
    assert all(table!="shopify_variants" for table,_ in db.calls)


def test_credential_use_checks_active_lease_and_install(monkeypatch):
    c={"connection_id":CONNECTION,"generation":GENERATION}
    db=DB({"shopify_connections":[{**c,"status":"connected"}],"shopify_sync_jobs":[{**c,"lease_id":"current-lease","lease_until":(datetime.now(timezone.utc)+timedelta(seconds=120)).isoformat()}],"shopify_credentials":[{"connection_id":CONNECTION,"encrypted_tokens":"opaque"}]})
    monkeypatch.setattr(sync,"get_supabase_admin",lambda:db)
    assert sync.current_credentials(c,"expired-lease") is None
    assert sync.current_credentials(c,"current-lease")["encrypted_tokens"]=="opaque"
    db.rows["shopify_connections"][0]["status"]="disconnected"
    assert sync.current_credentials(c,"current-lease") is None


def test_callback_scrubs_query_before_access_logging(route_client,settings):
    client,_=route_client; captured=[]
    @client.app.middleware("http")
    async def observe(request,call_next):
        response=await call_next(request)
        captured.append(request.scope["query_string"])
        return response
    client.get("/integrations/shopify/callback?"+urlencode(signed_params(settings)),follow_redirects=False)
    assert captured==[b""]


def test_destructive_webhook_binds_signed_body_identity(route_client,settings,monkeypatch):
    client,_=route_client; calls=[]
    monkeypatch.setattr(routes,"rpc",lambda *args,**kwargs:calls.append(kwargs))
    def post(payload,topic="app/uninstalled",domain=settings.shopify_pilot_shop):
        body=json.dumps(payload).encode()
        signature=base64.b64encode(hmac.new(settings.shopify_client_secret.encode(),body,hashlib.sha256).digest()).decode()
        return client.post("/integrations/shopify/webhooks",content=body,headers={"X-Shopify-Hmac-Sha256":signature,
            "X-Shopify-Shop-Domain":domain,"X-Shopify-Webhook-Id":GENERATION,"X-Shopify-Topic":topic,
            "X-Shopify-Triggered-At":"2026-10-12T10:00:00Z","X-Shopify-API-Version":api.API_VERSION})
    assert post({"id":1}).status_code==400  # A product payload cannot become an uninstall.
    assert post({"id":1,"shop_owner":None,"myshopify_domain":settings.shopify_pilot_shop}).status_code==200
    assert calls[-1]["shop_gid"]=="gid://shopify/Shop/1"
    assert post({"shop_id":1,"shop_domain":"other.myshopify.com"},"shop/redact").status_code==400
    settings.shopify_enabled=False  # Compliance must still run with the feature off.
    assert post({"shop_id":1,"shop_domain":settings.shopify_pilot_shop},"shop/redact").status_code==200
    assert len(calls)==2
