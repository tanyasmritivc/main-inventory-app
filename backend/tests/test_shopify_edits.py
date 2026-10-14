from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
import base64
import json
import httpx
import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from app.core.auth import AuthenticatedUser, get_current_user
from app.api.routes import shopify_edits as routes
from app.services import shopify_edits as edits, shopify_api as api

TEAM="10000000-0000-0000-0000-000000000001"
ACTOR="20000000-0000-0000-0000-000000000001"
CONNECTION="30000000-0000-0000-0000-000000000001"
OP="40000000-0000-0000-0000-000000000001"
PRODUCT="gid://shopify/Product/1"
VARIANT="gid://shopify/ProductVariant/1"
ITEM="gid://shopify/InventoryItem/1"
LOCATION="gid://shopify/Location/1"


@pytest.fixture
def settings():
    return SimpleNamespace(shopify_enabled=True,shopify_writes_enabled=True,shopify_client_id="test-client",shopify_client_secret="test-secret",
        shopify_pilot_shop="findez-test.myshopify.com",shopify_redirect_uri="https://api.findez.test/integrations/shopify/callback",
        frontend_url="https://www.findez.test",shopify_token_keys=json.dumps({"v1":base64.urlsafe_b64encode(b"x"*32).decode()}),shopify_active_key_id="v1")


def token_body(scopes):
    return {"scope":scopes,"access_token":"test-access","refresh_token":"test-refresh","expires_in":100,"refresh_token_expires_in":200}


def test_write_grants_require_exact_owner_selection_and_support_implied_reads():
    wanted={"write_products","read_inventory"}
    _,granted,_,_=api.token_metadata(token_body("write_products,read_inventory"),wanted)
    assert api.effective_scopes(granted)=={"read_products","write_products","read_inventory"}
    for scopes in ("write_products,read_inventory,write_inventory","read_products,read_inventory","write_products,read_inventory,read_orders"):
        with pytest.raises(api.ShopifyError):api.token_metadata(token_body(scopes),wanted)
    with pytest.raises(api.ShopifyError):api.token_metadata(token_body("write_products,read_inventory"))


def test_stock_mutation_uses_fixed_api_idempotency_and_no_raw_query_proxy(settings):
    seen=[]
    def handle(request):
        seen.append(json.loads(request.content));return httpx.Response(200,json={"data":{"inventoryAdjustQuantities":{}}},headers={"X-Shopify-API-Version":api.API_VERSION})
    with httpx.Client(transport=httpx.MockTransport(handle)) as client:
        adapter=api.ShopifyAPI(settings,settings.shopify_pilot_shop,client)
        adapter.mutation("inventory",{"key":OP,"input":{"changes":[]}},"test-access")
        assert "@idempotent(key: $key)" in seen[0]["query"]
        assert seen[0]["variables"]["key"]==OP
        with pytest.raises(api.ShopifyError):adapter.mutation("deleteProduct",{},"test-access")
        with pytest.raises(api.ShopifyError):adapter.query(api.PRODUCT_MUTATION,{},"test-access")
        assert len(seen)==1


@pytest.mark.parametrize("payload",[
    {"kind":"inventory","variant_gid":VARIANT,"location_gid":LOCATION,"delta":0},
    {"kind":"inventory","variant_gid":VARIANT,"location_gid":LOCATION,"delta":True},
    {"kind":"inventory","variant_gid":VARIANT,"location_gid":LOCATION,"delta":1.2},
    {"kind":"product","variant_gid":VARIANT,"changes":{"price":"20"}},
    {"kind":"product","variant_gid":VARIANT,"changes":{"title":"  "}},
    {"kind":"product","variant_gid":VARIANT,"changes":{"title":"Name\nInjected"}},
    {"kind":"product","variant_gid":VARIANT,"changes":{},"delta":2},
    {"kind":"inventory","variant_gid":"gid://shopify/Product/1","location_gid":LOCATION,"delta":2},
])
def test_validation_excludes_arbitrary_mutations_and_invalid_intents(payload):
    with pytest.raises(ValueError):routes.Prepare(**payload)


class Query:
    def __init__(self,data):self.data=data
    def __getattr__(self,name):return lambda *args,**kwargs:self
    def execute(self):return self


def setup_action(monkeypatch,kind="inventory",state="prepared",failure=None):
    calls=[]
    c={"connection_id":CONNECTION,"generation":"generation","io_lease":"lease","granted_scopes":list(api.ALLOWED_SCOPES),"edit_inventory":True,"edit_products":True}
    snapshot={"id":PRODUCT,"title":"Hoodie","vendor":"","productType":"Clothing","tags":[],"updatedAt":"2026-10-13T10:00:00Z","checked_at":"2026-10-13T10:00:00Z","variant_title":"Black M"}
    intent={"product_gid":PRODUCT,"changes":{"title":"New hoodie"}} if kind=="product" else {"inventory_item_gid":ITEM,"location_gid":LOCATION,"delta":2}
    original={"operation_id":OP,"kind":kind,"state":state,"intent":intent,"snapshot":snapshot}
    class Adapter:
        def query(self,query,variables,token):
            if query==api.PRODUCT_QUERY:return {"product":{**snapshot,"updatedAt":snapshot["updatedAt"]}},0
            if query==api.INVENTORY_QUERY:return {"inventoryItem":{"id":ITEM,"tracked":True,"inventoryLevel":{"location":{"id":LOCATION,"name":"Stockroom","isActive":True},"quantities":[{"name":"available","quantity":8}]}}},0
            raise AssertionError(query)
        def mutation(self,kind,variables,token):
            calls.append((kind,variables))
            if failure:raise failure
            if kind=="product":return {"productUpdate":{"product":{**snapshot,"title":"New hoodie"},"userErrors":[]}}
            return {"inventoryAdjustQuantities":{"inventoryAdjustmentGroup":{"createdAt":"2026-10-13T10:01:00Z","referenceDocumentUri":"findez://shopify/operations/"+OP,"changes":[{"name":"available","delta":2}]},"userErrors":[]}}
    @contextmanager
    def session(*args):yield c,Adapter(),"test-access"
    def call(name,**params):
        if name=="can_edit":return True
        if name=="dispatch_edit":return {**original,"state":"sending"}
        if name=="finish_edit":calls.append(("finish",params));return True
        raise AssertionError(name)
    monkeypatch.setattr(edits,"writes_ready",lambda:None)
    monkeypatch.setattr(edits,"session",session)
    monkeypatch.setattr(edits,"operation",lambda *args:original)
    monkeypatch.setattr(edits,"call",call)
    return calls,original,Adapter


def test_inventory_execution_returns_real_receipt_and_delta_not_absolute_count(monkeypatch):
    calls,_,_=setup_action(monkeypatch)
    result=edits.execute(TEAM,CONNECTION,ACTOR,OP)
    assert result["state"]=="succeeded"
    assert result["receipt"]["adjustment"]["changes"][0]["delta"]==2
    body=calls[0][1]
    assert body["key"]==OP and body["input"]["changes"][0]["delta"]==2
    assert "quantity" not in body["input"]["changes"][0]
    assert calls[-1][1]["state"]=="succeeded"


def test_product_execution_uses_current_revision_and_supported_fields(monkeypatch):
    calls,_,_=setup_action(monkeypatch,"product")
    result=edits.execute(TEAM,CONNECTION,ACTOR,OP)
    assert result["state"]=="succeeded"
    assert calls[0]==("product",{"product":{"id":PRODUCT,"title":"New hoodie"}})


def test_stale_product_preflight_never_dispatches_or_writes(monkeypatch):
    calls,original,_=setup_action(monkeypatch,"product")
    monkeypatch.setattr(edits,"_product",lambda *args:{"updatedAt":"changed"})
    with pytest.raises(HTTPException) as error:edits.execute(TEAM,CONNECTION,ACTOR,OP)
    assert error.value.status_code==409 and not calls
    assert original["state"]=="prepared"


@pytest.mark.parametrize("kind",["product","inventory"])
def test_timeout_is_unknown_and_never_replays_uncertain_operation(monkeypatch,kind):
    calls,original,_=setup_action(monkeypatch,kind,failure=api.ShopifyError("network"))
    result=edits.execute(TEAM,CONNECTION,ACTOR,OP)
    assert result["state"]=="unknown" and result["receipt"] is None
    original["state"]="unknown"
    before=len(calls)
    with pytest.raises(HTTPException):edits.execute(TEAM,CONNECTION,ACTOR,OP)
    assert len(calls)==before


def test_completed_operation_replay_reads_saved_receipt_without_mutation(monkeypatch):
    calls,original,_=setup_action(monkeypatch,state="succeeded")
    assert edits.execute(TEAM,CONNECTION,ACTOR,OP)==original and not calls


def test_permission_revocation_between_review_and_dispatch_blocks_write(monkeypatch):
    calls,_,_=setup_action(monkeypatch)
    def deny(*args,**kwargs):raise HTTPException(403,"Permission changed")
    monkeypatch.setattr(edits,"call",deny)
    with pytest.raises(HTTPException) as error:edits.execute(TEAM,CONNECTION,ACTOR,OP)
    assert error.value.status_code==403 and not calls


def test_mutation_rejection_is_recorded_without_false_success(monkeypatch):
    calls,_,adapter=setup_action(monkeypatch)
    adapter.mutation=lambda *args:{"inventoryAdjustQuantities":{"inventoryAdjustmentGroup":None,"userErrors":[{"message":"Private upstream detail"}]}}
    result=edits.execute(TEAM,CONNECTION,ACTOR,OP)
    assert result["state"]=="failed" and "Private upstream" not in json.dumps(result)
    assert calls[-1][1]["state"]=="failed"


def route_client(monkeypatch):
    app=FastAPI();app.include_router(routes.router)
    app.dependency_overrides[get_current_user]=lambda:AuthenticatedUser(user_id=ACTOR)
    monkeypatch.setattr(routes,"connection",lambda *args:{"connection_id":CONNECTION})
    return TestClient(app)


def test_owner_only_permissions_and_unknown_review(monkeypatch):
    client=route_client(monkeypatch)
    def denied(*args,**kwargs):raise HTTPException(403,"Owner required")
    monkeypatch.setattr(routes,"membership",denied)
    prefix=f"/teams/{TEAM}/shopify/{CONNECTION}"
    assert client.patch(prefix+"/permissions",json={"edit_products":True,"edit_inventory":True,"edit_access":"editors","expected_revision":0}).status_code==403
    assert client.post(prefix+f"/edits/{OP}/review-unknown",json={"checked_in_shopify":True}).status_code==403


def test_local_downgrade_remains_saved_when_external_revoke_is_unconfirmed(monkeypatch):
    client=route_client(monkeypatch)
    monkeypatch.setattr(routes,"membership",lambda *args,**kwargs:{"role":"owner"})
    calls=[]
    monkeypatch.setattr(edits,"call",lambda name,**kwargs:calls.append((name,kwargs)) or {"revision":4})
    def offline(*args):raise HTTPException(503,"Offline")
    monkeypatch.setattr(edits,"reconcile_permissions",offline)
    response=client.patch(f"/teams/{TEAM}/shopify/{CONNECTION}/permissions",json={"edit_products":False,"edit_inventory":False,"edit_access":"owner","expected_revision":3})
    assert response.status_code==200 and response.json()=={"saved":True,"revision":4,"needs_authorization":None,"revocation_pending":True}
    assert calls[0][1]["actor"]==ACTOR and calls[0][1]["revision"]==3


def test_execute_requires_explicit_confirmation_and_binds_signed_in_actor(monkeypatch):
    client=route_client(monkeypatch)
    monkeypatch.setattr(routes,"membership",lambda *args,**kwargs:{"role":"member"})
    seen=[]
    monkeypatch.setattr(edits,"execute",lambda *args:seen.append(args) or {"state":"succeeded"})
    path=f"/teams/{TEAM}/shopify/{CONNECTION}/edits/{OP}/execute"
    assert client.post(path,json={"confirmed":False}).status_code==422
    assert client.post(path,json={"confirmed":True,"actor_id":"someone-else"}).status_code==422
    assert client.post(path,json={"confirmed":True}).status_code==200
    assert seen==[(TEAM,CONNECTION,ACTOR,OP)]


def test_disabled_edits_are_not_a_permission_bypass(settings,monkeypatch):
    settings.shopify_writes_enabled=False
    monkeypatch.setattr(edits,"get_settings",lambda:settings)
    with pytest.raises(HTTPException) as error:edits.writes_ready()
    assert error.value.status_code==503
