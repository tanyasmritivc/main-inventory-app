"""Public documentation must match the executable API, not a stale route list."""
import ast
import json
from pathlib import Path
from types import SimpleNamespace

import pytest
from pydantic import ValidationError

from app.api.routes import api_v1
from backend.tests.test_integration_api_flow import api, bearer, create  # noqa: F401
from api_reference import ENDPOINTS, ERRORS, ITEM, ITEM_ID, OUTPUT, ROOT, build_spec, serialized_spec


def test_published_openapi_matches_current_routes_models_permissions_and_limits():
    assert OUTPUT.read_text() == serialized_spec(), (
        "Public docs are stale. Run python scripts/api_reference.py and review the contract changes."
    )


def test_every_error_code_is_documented():
    found = set()
    for relative in ["backend/app/core/api_key_auth.py", "backend/app/api/routes/api_v1.py", "backend/app/main.py"]:
        tree = ast.parse((ROOT / relative).read_text())
        for node in ast.walk(tree):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == "api_error" and len(node.args) > 2:
                status, code = node.args[1:3]
                if isinstance(status, ast.Constant) and isinstance(code, ast.Constant):
                    found.add((status.value, code.value))
    documented = {(status, code) for status, code, _ in ERRORS}
    assert found <= documented, f"Missing error codes: {found - documented}"
    assert {(400, "invalid_scope"), (400, "scope_type_mismatch"), (422, "invalid_request"), (500, "internal_error")} <= documented


def documented_bodies():
    for identity, data in ENDPOINTS.items():
        if "request" in data:
            yield identity, data["request"]
        for example in data.get("extraExamples", {}).values():
            yield identity, example["request"]


@pytest.mark.parametrize("identity,body", list(documented_bodies()))
def test_documented_json_requests_pass_real_request_validation(identity, body):
    method, path = identity.split(" ")
    route = next(route for route in api_v1.router.routes if route.path == path and method in route.methods)
    route.body_field.type_.model_validate(body)


@pytest.mark.parametrize("field", ["name", "category", "location", "quantity"])
def test_patch_docs_do_not_advertise_null_for_required_item_values(field):
    with pytest.raises(ValidationError):
        api_v1.APIItemPatch.model_validate({field: None})
    schema = build_spec()["components"]["schemas"]["APIItemPatch"]["properties"][field]
    assert "anyOf" not in schema
    assert schema["type"] != "null"


@pytest.mark.parametrize("body", [
    {"filters": [{"field": "quantity", "value": "5"}]},
    {"filters": [{"field": "quantity", "value": True}]},
    {"filters": [{"field": "quantity", "value": 5.0}]},
    {"filters": [{"field": "quantity", "value": -1}]},
    {"filters": [{"field": "quantity", "value": 100001}]},
    {"filters": [{"field": "location", "op": "gte", "value": "Shelf B"}]},
    {"filters": [{"field": "brand", "value": None}]},
    {"filters": [{"field": "space_id", "value": "x"}]},
    {"filters": [{"field": "name", "value": "x", "sql": "SELECT 1"}]},
    {"filters": [{"field": "name", "value": "x"}] * 11},
    {"page": 1000001}, {"page_size": 101}, {"sql": "select * from items"},
])
def test_documented_query_restrictions_are_enforced(body):
    with pytest.raises(ValidationError):
        api_v1.InventoryQuery.model_validate(body)


def _prepare_data(api):
    table = api.data.table.return_value
    for method in ["select", "eq", "order", "range", "insert", "update", "upsert"]:
        getattr(table, method).return_value = table
    table.execute.return_value = SimpleNamespace(data=[ITEM], count=1)

    def rpc(name, *_args):
        if name == "api_query_items":
            result = ENDPOINTS["POST /api/v1/query"]["example"]
        elif name == "api_distinct_locations":
            result = ENDPOINTS["GET /api/v1/spaces"]["example"]["spaces"]
        else:
            result = ENDPOINTS["GET /api/v1/workspaces/summary"]["example"]["workspaces"]
        return SimpleNamespace(execute=lambda: SimpleNamespace(data=result))
    api.data.rpc.side_effect = rpc


@pytest.mark.parametrize("identity", [identity for identity in ENDPOINTS if "/keys" not in identity and "/whoami" not in identity])
def test_documented_inventory_examples_reach_handlers_with_expected_response(api, monkeypatch, identity):
    """Execute request examples through HTTP. SQL behavior has the real RLS suite."""
    annotation = ENDPOINTS[identity]
    key = create(api, scopes=["items:read", "items:write", "workspace:read", "import:write"]).json()["key"]
    _prepare_data(api)
    monkeypatch.setattr(api_v1, "uuid4", lambda: ITEM_ID)
    method, path = identity.split(" ")
    path = path.replace("{item_id}", ITEM_ID)
    response = api.client.request(method, path, headers=bearer(key), json=annotation.get("request"), params=annotation.get("query"))
    assert response.status_code == (201 if identity == "POST /api/v1/items" else 200)
    assert response.json() == annotation["example"]


def test_docs_key_management_example_issues_lists_verifies_and_revokes(api):
    response = api.client.post("/api/v1/keys", headers=bearer("web-session"), json=ENDPOINTS["POST /api/v1/keys"]["request"])
    assert response.status_code == 201
    issued = response.json()
    assert set(issued) == set(ENDPOINTS["POST /api/v1/keys"]["example"])
    identity = api.client.get("/api/v1/whoami", headers=bearer(issued["key"])).json()
    assert identity == {"key_id": issued["id"], "workspace_id": issued["workspace_id"], "scopes": issued["scopes"]}
    listed = api.client.get("/api/v1/keys", headers=bearer("web-session"))
    assert listed.status_code == 200
    assert set(listed.json()["keys"][0]) == set(ENDPOINTS["GET /api/v1/keys"]["example"]["keys"][0])
    assert issued["key"] not in listed.text
    revoked = api.client.delete(f"/api/v1/keys/{issued['id']}", headers=bearer("web-session"))
    assert revoked.status_code == 200
    assert set(revoked.json()) == set(ENDPOINTS["DELETE /api/v1/keys/{key_id}"]["example"])
    assert api.client.delete(f"/api/v1/keys/{issued['id']}", headers=bearer("web-session")).status_code == 404
    assert api.client.get("/api/v1/whoami", headers=bearer(issued["key"])).status_code == 401


def test_query_parameters_are_not_promised_as_filters(api):
    key = create(api).json()["key"]
    _prepare_data(api)
    response = api.client.get("/api/v1/items?quantity=0&location=missing", headers=bearer(key))
    assert response.status_code == 200
    assert response.json()["items"] == [ITEM]


def test_bulk_defaults_replace_quantity_and_category_even_on_sync(api):
    key = create(api, scopes=["import:write"]).json()["key"]
    _prepare_data(api)
    response = api.client.post("/api/v1/items/bulk", headers=bearer(key), json={"items": [{"name": "Motor", "location": "Shelf B", "source_system": "erp", "external_id": "motor-001"}]})
    assert response.status_code == 200
    records = api.data.table.return_value.upsert.call_args.args[0]
    assert records[0]["quantity"] == 1 and records[0]["category"] == "Other"


def test_public_documentation_never_contains_a_usable_key_or_internal_credentials():
    import re
    text = OUTPUT.read_text()
    assert not re.search(r"findez_(live|test)_sk_[A-Za-z0-9_-]{32}", text)
    for secret_field in ["key_hash", "SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_JWT_SECRET"]:
        assert secret_field not in text


def test_all_schema_references_resolve():
    spec = json.loads(OUTPUT.read_text())
    def walk(node):
        if isinstance(node, dict):
            if "$ref" in node:
                target = spec
                for part in node["$ref"].removeprefix("#/").split("/"):
                    target = target[part]
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)
    walk(spec)
