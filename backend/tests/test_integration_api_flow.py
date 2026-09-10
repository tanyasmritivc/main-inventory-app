"""HTTP key lifecycle and request contracts; PostgreSQL RLS has separate SQL tests."""

from copy import deepcopy
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import MagicMock
from uuid import uuid4

import pytest
from fastapi import FastAPI, HTTPException, Request
from fastapi.testclient import TestClient

from app.api.routes import api_v1
from app.core import api_key_auth
from app.core.auth import AuthenticatedUser, get_current_user

OWNER = "20000000-0000-0000-0000-000000000001"
WORKSPACE = "10000000-0000-0000-0000-000000000001"
OTHER = "10000000-0000-0000-0000-000000000002"


class MemoryQuery:
    def __init__(self, rows):
        self.rows = rows
        self.filters = []
        self.operation = None
        self.payload = None
        self.columns = None

    def select(self, columns):
        self.columns = columns.split(",")
        return self

    def eq(self, field, value):
        self.filters.append(lambda row: row.get(field) == value)
        return self

    def is_(self, field, _value):
        self.filters.append(lambda row: row.get(field) is None)
        return self

    def order(self, *_args, **_kwargs):
        return self

    def limit(self, *_args):
        return self

    def insert(self, payload):
        self.operation, self.payload = "insert", deepcopy(payload)
        return self

    def update(self, payload):
        self.operation, self.payload = "update", deepcopy(payload)
        return self

    def execute(self):
        if self.operation == "insert":
            row = {"id": str(uuid4()), "created_at": datetime.now(timezone.utc).isoformat(),
                   "last_used_at": None, "expires_at": None, "revoked_at": None, **self.payload}
            self.rows.append(row)
            return SimpleNamespace(data=[deepcopy(row)])
        rows = [row for row in self.rows if all(check(row) for check in self.filters)]
        if self.operation == "update":
            for row in rows:
                row.update(self.payload)
        if self.columns:
            rows = [{key: row.get(key) for key in self.columns} for row in rows]
        return SimpleNamespace(data=deepcopy(rows))


@pytest.fixture
def api(monkeypatch):
    rows = {"api_keys": [], "teams": [{"team_id": WORKSPACE, "owner_user_id": OWNER, "name": "Team"}]}
    admin = SimpleNamespace(table=lambda table: MemoryQuery(rows[table]))
    monkeypatch.setattr(api_v1, "get_supabase_admin", lambda: admin)
    monkeypatch.setattr(api_key_auth, "get_supabase_admin", lambda: admin)
    settings = SimpleNamespace(env="production", api_key_requests_per_minute=120,
                               api_key_bulk_requests_per_minute=10, api_key_bulk_max_items=500)
    monkeypatch.setattr(api_v1, "get_settings", lambda: settings)
    monkeypatch.setattr(api_key_auth, "get_settings", lambda: settings)
    counts = {}

    def consume(principal, bucket, limit):
        key = (principal.key_id, bucket)
        counts[key] = counts.get(key, 0) + 1
        return counts[key] <= limit

    monkeypatch.setattr(api_key_auth, "_consume_rate_limit", consume)
    data = MagicMock()
    data.__enter__.return_value = data
    data.rpc.return_value.execute.return_value = SimpleNamespace(data={"resource": "items", "aggregate": "count", "value": 7})
    factory = MagicMock(return_value=data)
    monkeypatch.setattr(api_v1, "create_api_key_rls_client", factory)
    app = FastAPI()
    app.include_router(api_v1.router)

    def web_user(request: Request):
        if request.headers.get("authorization") != "Bearer web-session":
            raise HTTPException(401, "Sign in required")
        return AuthenticatedUser(user_id=OWNER)

    app.dependency_overrides[get_current_user] = web_user
    with TestClient(app) as client:
        yield SimpleNamespace(client=client, rows=rows, data=data, factory=factory, settings=settings, counts=counts)


def create(api, scopes=None, **extra):
    return api.client.post("/api/v1/keys", headers={"Authorization": "Bearer web-session"}, json={
        "name": "Reporting", "workspace_id": WORKSPACE, "scopes": scopes or ["items:read"], **extra,
    })


def bearer(key):
    return {"Authorization": f"Bearer {key}"}


def test_create_query_last_used_revoke_lifecycle(api):
    response = create(api)
    assert response.status_code == 201
    assert response.headers["cache-control"] == "no-store"
    issued = response.json()
    assert issued["key"].startswith("findez_live_sk_")
    assert "key_hash" not in issued
    assert api.rows["api_keys"][0]["key_hash"].startswith("$argon2")
    assert issued["key"] not in str(api.rows)
    result = api.client.post("/api/v1/query", headers=bearer(issued["key"]), json={"resource": "items", "aggregate": "count"})
    assert result.status_code == 200 and result.json()["value"] == 7
    assert api.rows["api_keys"][0]["last_used_at"] is not None
    api.data.rpc.assert_called_with("api_query_items", {
        "p_workspace_id": WORKSPACE, "p_filters": [], "p_aggregate": "count", "p_page": 1, "p_page_size": 50,
    })
    api.data.__exit__.assert_called_once()
    listing = api.client.get("/api/v1/keys", headers=bearer("web-session"))
    assert issued["key"] not in listing.text and "key_hash" not in listing.text
    revoked = api.client.delete(f"/api/v1/keys/{issued['id']}", headers=bearer("web-session"))
    assert revoked.status_code == 200
    rejected = api.client.get("/api/v1/whoami", headers=bearer(issued["key"]))
    assert rejected.status_code == 401 and rejected.json()["detail"]["code"] == "revoked_api_key"


def test_key_cannot_manage_other_keys(api):
    key = create(api).json()["key"]
    assert api.client.get("/api/v1/keys", headers=bearer(key)).status_code == 401
    assert api.client.post("/api/v1/keys", headers=bearer(key), json={"name": "x", "scopes": ["org:read"]}).status_code == 401


def test_only_owned_workspaces_offered_and_accepted(api):
    response = api.client.get("/api/v1/keys/workspaces", headers=bearer("web-session"))
    assert response.json() == {"workspaces": [{"team_id": WORKSPACE, "name": "Team"}]}
    assert create(api, workspace_id=OTHER).status_code == 403
    api.rows["teams"] = []
    assert create(api, workspace_id=None, scopes=["org:read"]).status_code == 403


@pytest.mark.parametrize("scopes", [["org:read"], ["admin"], ["items:read", "org:write"]])
def test_rejects_invalid_workspace_scopes(api, scopes):
    assert create(api, scopes=scopes).status_code == 400


@pytest.mark.parametrize("key", ["", "not-a-key", "findez_test_sk_" + "a" * 32, "findez_live_sk_" + "a" * 32])
def test_invalid_unknown_and_wrong_environment_keys(api, key):
    assert api.client.get("/api/v1/whoami", headers=bearer(key)).status_code == 401


def test_expired_key_and_past_expiration(api):
    issued = create(api).json()
    past = (datetime.now(timezone.utc) - timedelta(days=1)).isoformat()
    api.rows["api_keys"][0]["expires_at"] = past
    response = api.client.get("/api/v1/whoami", headers=bearer(issued["key"]))
    assert response.status_code == 401 and response.json()["detail"]["code"] == "expired_api_key"
    assert create(api, expires_at=past).status_code == 400


def test_rate_limit_is_per_key(api):
    first, second = create(api).json()["key"], create(api).json()["key"]
    api.settings.api_key_requests_per_minute = 1
    assert api.client.get("/api/v1/whoami", headers=bearer(first)).status_code == 200
    rejected = api.client.get("/api/v1/whoami", headers=bearer(first))
    assert rejected.status_code == 429 and rejected.headers["retry-after"] == "60"
    assert api.client.get("/api/v1/whoami", headers=bearer(second)).status_code == 200


def test_read_key_cannot_write_and_write_key_cannot_query(api):
    reader = create(api).json()["key"]
    writer = create(api, scopes=["items:write"]).json()["key"]
    assert api.client.post("/api/v1/items", headers=bearer(reader), json={"name": "Motor", "location": "Shelf A"}).status_code == 403
    assert api.client.get("/api/v1/items", headers=bearer(writer)).status_code == 403
    assert api.client.post("/api/v1/query", headers=bearer(writer), json={"aggregate": "count"}).status_code == 403
    api.factory.assert_not_called()


def test_cross_workspace_query_rejected_before_db(api):
    key = create(api).json()["key"]
    response = api.client.post("/api/v1/query", headers=bearer(key), json={"workspace_id": OTHER})
    assert response.status_code == 403
    api.factory.assert_not_called()


@pytest.mark.parametrize("body", [
    {"sql": "select * from items"}, {"resource": "api_keys"},
    {"filters": [{"field": "user_id", "op": "eq", "value": OWNER}]},
    {"filters": [{"field": "name", "op": "or", "value": "x"}]},
    {"filters": [{"field": "quantity", "op": "gt", "value": "0;drop table items"}]},
    {"filters": [{"field": "name", "op": "gt", "value": "x"}]},
    {"page_size": 101}, {"aggregate": "raw_sql"},
])
def test_query_validation_rejects_unbounded_or_unsafe_input(api, body):
    key = create(api).json()["key"]
    assert api.client.post("/api/v1/query", headers=bearer(key), json=body).status_code == 422
    api.factory.assert_not_called()


def test_query_preserves_literal_filter_values(api):
    key = create(api).json()["key"]
    value = "'; DROP TABLE items; --"
    filters = [{"field": "name", "op": "eq", "value": value}]
    response = api.client.post("/api/v1/query", headers=bearer(key), json={"filters": filters})
    assert response.status_code == 200
    assert api.data.rpc.call_args.args[1]["p_filters"] == filters


def test_data_failure_closes_client_and_hides_internal_detail(api):
    key = create(api).json()["key"]
    api.data.rpc.return_value.execute.side_effect = RuntimeError("secret SQL traceback")
    response = api.client.post("/api/v1/query", headers=bearer(key), json={})
    assert response.status_code == 503 and "secret SQL" not in response.text
    api.data.__exit__.assert_called_once()


@pytest.mark.parametrize("body", [{"quantity": None}, {"name": " "}, {"location": None}, {"workspace_id": OTHER}, {"quantity": -1}])
def test_patch_rejects_null_required_fields_or_workspace_change(api, body):
    key = create(api, scopes=["items:write"]).json()["key"]
    response = api.client.patch(f"/api/v1/items/{uuid4()}", headers=bearer(key), json=body)
    assert response.status_code == 422
    api.factory.assert_not_called()
