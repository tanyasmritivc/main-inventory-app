"""Build the public integration reference from the mounted FastAPI router.

Run with the backend test environment: python scripts/api_reference.py [--check].
No backend, database, user credentials, or external service is contacted.
Request schemas, parameters, scopes, and limits come from executable code. Human
annotations describe behavior that FastAPI cannot infer (SQL results, retries).
"""

import argparse
import inspect
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "frontend/public/docs/api/openapi.json"
WORKSPACE = "10000000-0000-0000-0000-000000000001"
ITEM_ID = "30000000-0000-0000-0000-000000000001"
KEY_ID = "40000000-0000-0000-0000-000000000001"
USER_ID = "20000000-0000-0000-0000-000000000001"
STAMP = "2026-09-10T12:00:00Z"


def ref(name):
    return {"$ref": f"#/components/schemas/{name}"}


def obj(properties, required=None):
    return {"type": "object", "properties": properties,
            "required": list(properties) if required is None else required}


def array(schema):
    return {"type": "array", "items": schema}


def scalar(kind, description, nullable=False, **extra):
    return {"type": [kind, "null"] if nullable else kind, "description": description, **extra}


TEXT = {
    "workspace_id": "Team UUID. A workspace key may omit it; if supplied it must match the key. Organization keys must supply it for each item write and may supply it to narrow item reads or queries.",
    "name": "Item name. Leading/trailing whitespace is removed; blank values are rejected.",
    "category": "Category label. Leading/trailing whitespace is removed; blank values are rejected. No fixed category enumeration.",
    "quantity": "Stored unit quantity, as a whole number from 0 to 100000 inclusive. Writes set the absolute quantity; they do not increment it.",
    "location": "Exact, case-sensitive name of one existing Space linked to the target Team. Surrounding whitespace is trimmed. Unknown or ambiguous names are rejected; create, link, or rename Spaces in FindEZ first.",
    "image_url": "Image reference string; this endpoint does not upload a file or return a newly signed image URL. Use a URL your intended readers can access.",
    "barcode": "Barcode string. Preserve leading zeroes; no barcode lookup or normalization is performed by this API.",
    "purchase_source": "Purchase source or vendor text.",
    "notes": "Free-text notes.",
    "brand": "Brand or manufacturer text.",
    "part_number": "Part identifier string. Preserve formatting and leading zeroes for exact matching.",
    "source_system": "External integration namespace, for example erp. Together with workspace_id and external_id, identifies a row for bulk upsert.",
    "external_id": "Stable record identifier in the source system. Reuse the same value for later syncs; do not generate a new ID each run.",
}

ITEM = {"item_id": ITEM_ID, "workspace_id": WORKSPACE, "name": "Motor", "category": "Hardware",
        "quantity": 4, "location": "Shelf B", "image_url": None, "barcode": None,
        "purchase_source": None, "notes": None, "brand": None, "part_number": "5202",
        "source_system": "erp", "external_id": "motor-001", "created_at": STAMP}
CREATE = {"name": "Motor", "category": "Hardware", "quantity": 4, "location": "Shelf B", "part_number": "5202"}
BULK = {"items": [{**CREATE, "source_system": "erp", "external_id": "motor-001"}]}
KEY = {"id": KEY_ID, "workspace_id": WORKSPACE, "name": "Team reporting", "key_prefix": "findez_live_sk_EXAMPL",
       "scopes": ["items:read", "workspace:read"], "created_at": STAMP, "last_used_at": None,
       "expires_at": None, "revoked_at": None}

# Each route must have an annotation; the builder refuses silent omissions.
ENDPOINTS = {
    "GET /api/v1/whoami": {
        "summary": "Test authentication", "tag": "Connection", "response": "Identity",
        "description": "Returns the key ID, its fixed workspace (null for an organization key), and its explicit scopes. Any valid key can call this endpoint. Success verifies authentication only: it does not prove inventory is visible, that the team is still owned, or that a write will succeed. It consumes the standard request budget.",
        "example": {"key_id": KEY_ID, "workspace_id": WORKSPACE, "scopes": ["items:read", "workspace:read"]},
    },
    "GET /api/v1/items": {
        "summary": "List inventory", "tag": "Inventory", "response": "ItemPage",
        "description": "Returns visible item records, newest created_at first, then item_id ascending for ties. Pagination starts at 1. total counts all matching records, not units. An out-of-range page returns an empty items array. Only page, page_size, and workspace_id are supported query parameters; use POST /query for filters. Unknown URL query parameters are currently ignored, so misspelled filters will not filter results. Organization reads of an unowned workspace return no visible rows. Pagination is not a snapshot: concurrent inventory changes can move records between pages.",
        "query": {"page": 1, "page_size": 50},
        "example": {"items": [ITEM], "page": 1, "page_size": 50, "total": 1},
    },
    "POST /api/v1/query": {
        "summary": "Filter inventory and total quantities", "tag": "Inventory", "response": "QueryResult",
        "description": "Structured queries over items only. Filters are ANDed; at most 10 are accepted. Text equality and inequality are exact and case-sensitive, with no wildcard expansion; null fields match neither eq nor neq. Quantity comparisons require JSON integers, not strings, decimals, or booleans. Omit aggregate (or send null) for a paginated list in the same order as GET /items. count counts records; sum_quantity totals stored units across every matching record regardless of page or page_size. Both aggregates return 0 for no matches. Aggregate calls still validate pagination fields. SQL, OR groups, joins, arbitrary fields, text search, and custom sorting are unavailable.",
        "request": {"resource": "items", "filters": [{"field": "part_number", "op": "eq", "value": "5202"}], "aggregate": "sum_quantity"},
        "example": {"resource": "items", "aggregate": "sum_quantity", "value": 4},
        "extraExamples": {
            "Low stock list": {"request": {"filters": [{"field": "quantity", "op": "lte", "value": 5}], "page": 1, "page_size": 50}, "response": {"resource": "items", "items": [ITEM], "page": 1, "page_size": 50, "total": 1}},
            "Count location records": {"request": {"filters": [{"field": "location", "value": "Shelf B"}], "aggregate": "count"}, "response": {"resource": "items", "aggregate": "count", "value": 1}},
            "No matching units": {"request": {"filters": [{"field": "part_number", "value": "NO-MATCH"}], "aggregate": "sum_quantity"}, "response": {"resource": "items", "aggregate": "sum_quantity", "value": 0}},
        },
    },
    "POST /api/v1/items": {
        "summary": "Create an item", "tag": "Inventory", "response": "CreatedItem",
        "description": "Creates a new record in an existing linked Space. Does not merge matching names. The response echoes normalized submitted fields, defaults, the resolved workspace_id, and the new item_id. It is not a database read-back: created_at and omitted optional fields are not returned. To get the stored representation, use a read-enabled key and list/query the inventory. The new item belongs to the Space's actual owner. A location does not create a Space. Organization keys must include workspace_id. This operation has no idempotency-key support; retrying after an ambiguous timeout can create duplicates. Use bulk upsert with stable external identities for repeatable imports.",
        "request": CREATE,
        "example": {"item": {**CREATE, "workspace_id": WORKSPACE, "item_id": ITEM_ID}},
    },
    "PATCH /api/v1/items/{item_id}": {
        "summary": "Update an item", "tag": "Inventory", "response": "UpdatedItem",
        "description": "Updates only supplied fields. At least one field is required. name, category, quantity, and location cannot be null; nullable optional fields can be cleared with null. Quantity replaces the stored total, rather than adding a delta. Changing location moves the item to one unambiguous linked Space within the same workspace. workspace_id, space_id, user_id, item_id, and created_at are not writable here. A missing or inaccessible item returns 404. The response is an acknowledgement, not the updated record. There is no ETag, version precondition, or atomic increment: concurrent updates may overwrite one another.",
        "request": {"quantity": 6, "notes": None},
        "pathValues": {"item_id": ITEM_ID},
        "example": {"updated": True, "item_id": ITEM_ID},
    },
    "POST /api/v1/items/bulk": {
        "summary": "Sync items by external identity", "tag": "Inventory", "response": "BulkResult",
        "description": "Accepts a JSON object containing 1–500 items (the server may configure a lower cap). Every item requires name, location, source_system, and external_id. The last two are trimmed and must not be blank. Matching is by (workspace_id, source_system, external_id); repeating an identity updates that row and preserves its item_id. Duplicate identities within one request return 400 before writing. Workspace keys cannot mix workspaces; organization keys provide workspace_id on every item. The batch is one database upsert: a validation, permission, or location failure prevents a partial batch commit. processed is the number of submitted rows, not units, inserted rows, or returned IDs. Omitted category and quantity take their create defaults (Other and 1), even on an existing row. Supply the complete intended state on every sync; omitted nullable values are not a documented preservation or clearing mechanism. Use PATCH to explicitly clear a field. Rows absent from the batch remain in inventory. There is no deletion, dry-run, file upload, or background job in this endpoint.",
        "request": BULK, "example": {"processed": 1},
    },
    "GET /api/v1/spaces": {
        "summary": "List inventory locations", "tag": "Workspaces", "response": "Locations",
        "description": "Returns distinct (workspace_id, location) pairs visible to the key, ordered by location. item_count counts records, not units. This is a view of item locations, not the full application Space directory: empty Spaces are absent, and there is no Space UUID. A row with quantity 0 still counts as a record. An organization key receives all visible workspaces; this endpoint has no workspace filter or pagination. Use /keys/workspaces with a user session to discover owned Team IDs, including empty teams.",
        "example": {"spaces": [{"workspace_id": WORKSPACE, "location": "Shelf B", "item_count": 1}]},
    },
    "GET /api/v1/workspaces/summary": {
        "summary": "Summarize workspaces", "tag": "Workspaces", "response": "WorkspaceSummary",
        "description": "Returns visible owned Teams, ordered by name, including Teams with no inventory. item_count is the number of item records. space_count is the number of distinct location strings represented by inventory, not the number of linked Spaces. Empty Spaces do not contribute; identically named locations in a team count once. A workspace key sees its fixed team; an organization key sees currently owned teams. No pagination or workspace query filter is supported.",
        "example": {"workspaces": [{"workspace_id": WORKSPACE, "name": "Robotics team", "item_count": 1, "space_count": 1}]},
    },
    "GET /api/v1/keys/workspaces": {
        "summary": "Find teams you own", "tag": "Key management", "response": "OwnedWorkspaces",
        "description": "Requires the signed-in owner's Supabase user access token. Returns teams owned by that user, ordered by name. Membership alone does not qualify. The returned team_id is the workspace_id used when creating keys. Includes empty teams. Returns an empty workspaces array if none are owned. This endpoint does not accept integration API keys.",
        "example": {"workspaces": [{"team_id": WORKSPACE, "name": "Robotics team"}]},
    },
    "POST /api/v1/keys": {
        "summary": "Create an API key", "tag": "Key management", "response": "IssuedKey",
        "description": "Requires an owner's Supabase user access token, not an API key. With workspace_id, only workspace scopes are accepted and the caller must own that team. With workspace_id omitted or null, only org scopes are accepted and the caller must own at least one team. Scope names are trimmed and deduplicated. expires_at must be in the future; omitted/null means no expiration. Prefer an ISO 8601 timestamp with Z or an offset; a timezone-free value is interpreted as UTC. The web form defaults to 90 days, while this HTTP endpoint defaults to no expiration. Returns metadata plus the complete key once, with Cache-Control: no-store. FindEZ stores an Argon2 hash and cannot recover the secret. No endpoint edits an issued key's name, scopes, workspace, or expiration; replace it and revoke the old key. Do not automatically retry issuance after a timeout: it may have created a key whose secret was not received; review the key list and revoke that key before replacing it.",
        "request": {"name": "Team reporting", "workspace_id": WORKSPACE, "scopes": ["items:read", "workspace:read"], "expires_at": None},
        "example": {**KEY, "org_id": USER_ID, "created_by": USER_ID, "key": "findez_live_sk_EXAMPLE_NOT_A_REAL_KEY"},
        "extraExamples": {"Organization read key": {"request": {"name": "All-team reporting", "workspace_id": None, "scopes": ["org:read"]}}},
    },
    "GET /api/v1/keys": {
        "summary": "List key metadata", "tag": "Key management", "response": "KeyList",
        "description": "Requires a Supabase user access token. Returns that user's keys newest first, including expired and revoked keys. Neither the raw key nor its hash is returned. No pagination or status filter is supported. Cache-Control is no-store. last_used_at is approximate: authentication schedules an update at most once per five minutes, and a successful authentication may precede a later permission or request failure. A null timestamp means no recorded use, not proof of no requests. It is not an audit log or successful-write receipt.",
        "example": {"keys": [KEY]},
    },
    "DELETE /api/v1/keys/{key_id}": {
        "summary": "Revoke a key", "tag": "Key management", "response": "RevokedKey",
        "description": "Requires a Supabase user access token for the account that issued the key. Uses the metadata id, not the secret or prefix. Revocation is permanent; retained metadata stays in the list. The secret will be rejected on subsequent authentication. Revocation cannot undo writes already committed. Unknown, other-account, and already-revoked IDs all return 404 key_not_found; a repeated revoke does not return a second success. Create and test a replacement before revoking a key used by an active integration.",
        "pathValues": {"key_id": KEY_ID},
        "example": {"revoked": True, "id": KEY_ID, "revoked_at": STAMP},
    },
}

ERRORS = [
    (400, "invalid_scope", "Scopes are empty after normalization or contain an unknown scope. Use the permission table."),
    (400, "scope_type_mismatch", "Workspace and organization scope types do not match workspace_id."),
    (400, "invalid_expiration", "Choose an expires_at in the future."),
    (400, "workspace_required", "Add workspace_id to each organization-key item write."),
    (400, "empty_update", "Supply at least one supported PATCH field."),
    (400, "duplicate_external_id", "Remove repeated external identities within a bulk request."),
    (400, "invalid_inventory_request", "Check the query and exact linked Space name; resolve ambiguous names in FindEZ."),
    (401, "invalid_api_key", "Supply the complete integration key in the Bearer header; check for copy errors."),
    (401, "wrong_environment", "Use a key issued by this environment. Production uses findez_live_sk_."),
    (401, "revoked_api_key", "Replace the revoked key; it cannot be restored."),
    (401, "expired_api_key", "Create a replacement key with an appropriate expiry."),
    (403, "insufficient_scope", "Create a key with the required permission; writing does not imply reading."),
    (403, "workspace_access_denied", "Check the team owner and key workspace. A workspace key cannot select another team."),
    (403, "organization_required", "Create or own a Team before issuing an organization key."),
    (404, "item_not_found", "Check item_id and current workspace visibility."),
    (404, "key_not_found", "Check the key metadata id and issuing account; already-revoked keys return this too."),
    (409, "duplicate_external_id", "The identity already exists. Use bulk upsert or a distinct identity."),
    (413, "bulk_payload_too_large", "Split the batch below the configured server cap. More than 500 rows fails schema validation with 422."),
    (422, "invalid_request", "Check JSON structure, unknown properties, UUIDs, required fields, types, lengths, and numeric limits. Field-level details are not returned."),
    (429, "rate_limit_exceeded", "Wait for Retry-After (the per-key limiter sends 60 seconds), then retry with bounded backoff."),
    (503, "authentication_unavailable", "Authentication storage is temporarily unavailable."),
    (503, "rate_limit_unavailable", "The request-budget check is temporarily unavailable."),
    (503, "key_creation_unavailable", "Key issuance failed. Check the saved key list before trying again."),
    (503, "key_list_unavailable", "Key metadata could not be loaded."),
    (503, "workspace_list_unavailable", "Owned teams could not be loaded."),
    (503, "key_revocation_unavailable", "Revocation could not be completed; check status before retrying."),
    (503, "database_unavailable", "The inventory operation failed. Reconcile ambiguous writes before retrying."),
    (500, "internal_error", "An unexpected application error occurred. Keep the correlation ID for support."),
]


def response_schemas():
    string = {"type": "string"}
    integer = {"type": "integer"}
    uid = {"type": "string", "format": "uuid"}
    date = {"type": ["string", "null"], "format": "date-time"}
    item = obj({"item_id": uid, "workspace_id": uid,
                **{key: scalar("integer" if key == "quantity" else "string", description,
                               nullable=key not in {"name", "category", "quantity", "location"}) for key, description in TEXT.items() if key != "workspace_id"},
                "created_at": {"type": "string", "description": "Stored creation timestamp. Older inventory records may omit a timezone offset; this is not a modification checkpoint."}})
    metadata = obj({"id": uid, "workspace_id": {"type": ["string", "null"], "format": "uuid"},
                    "name": string, "key_prefix": string, "scopes": array(string),
                    "created_at": {"type": "string", "format": "date-time"},
                    "last_used_at": date, "expires_at": date, "revoked_at": date})
    return {
        "Item": item,
        "ItemPage": obj({"items": array(ref("Item")), "page": integer, "page_size": integer, "total": integer}),
        "QueryPage": obj({"resource": {"const": "items"}, "items": array(ref("Item")), "page": integer, "page_size": integer, "total": integer}),
        "Aggregate": obj({"resource": {"const": "items"}, "aggregate": {"type": "string", "enum": ["count", "sum_quantity"]}, "value": integer}),
        "QueryResult": {"oneOf": [ref("QueryPage"), ref("Aggregate")]},
        "CreatedItem": obj({"item": {**item, "required": ["item_id", "workspace_id", "name", "category", "quantity", "location"]}}),
        "UpdatedItem": obj({"updated": {"const": True}, "item_id": uid}),
        "BulkResult": obj({"processed": integer}),
        "Identity": obj({"key_id": uid, "workspace_id": {"type": ["string", "null"], "format": "uuid"}, "scopes": array(string)}),
        "Location": obj({"workspace_id": uid, "location": string, "item_count": integer}),
        "Locations": obj({"spaces": array(ref("Location"))}),
        "Workspace": obj({"workspace_id": uid, "name": string, "item_count": integer, "space_count": integer}),
        "WorkspaceSummary": obj({"workspaces": array(ref("Workspace"))}),
        "OwnedWorkspace": obj({"team_id": uid, "name": string}),
        "OwnedWorkspaces": obj({"workspaces": array(ref("OwnedWorkspace"))}),
        "KeyMetadata": metadata,
        "IssuedKey": obj({**metadata["properties"], "org_id": uid, "created_by": uid, "key": string}),
        "KeyList": obj({"keys": array(ref("KeyMetadata"))}),
        "RevokedKey": obj({"revoked": {"const": True}, "id": uid, "revoked_at": {"type": "string", "format": "date-time"}}),
        "APIError": obj({"detail": obj({"code": string, "message": string, "correlation_id": string})}),
        "ErrorResponse": obj({"detail": {"oneOf": [string, obj({"code": string, "message": string, "correlation_id": string})]}}),
    }


def build_spec():
    from fastapi import FastAPI
    from app.api.routes import api_v1
    from app.core.auth import get_current_user
    from app.core.config import Settings

    app = FastAPI(title="FindEZ Integration API", version="1")
    app.include_router(api_v1.router)
    spec = app.openapi()
    spec["info"].update({"description": "Public integration API for inventory in linked Team Spaces. Documentation: https://findez.ai/docs/api. Examples use synthetic IDs and do not contain usable credentials.", "contact": {"name": "FindEZ support", "email": "info@findez.ai"}})
    spec["servers"] = [{"url": "https://api.findez.ai", "description": "Production"}]
    spec["tags"] = [{"name": name} for name in ["Connection", "Inventory", "Workspaces", "Key management"]]
    spec["x-error-codes"] = [{"status": status, "code": code, "description": description} for status, code, description in ERRORS]
    spec["x-limits"] = {field: Settings.model_fields[field].default for field in ["api_key_requests_per_minute", "api_key_bulk_requests_per_minute", "api_key_bulk_max_items"]}
    spec["components"]["schemas"].update(response_schemas())
    # Production replaces FastAPI's default field-level validation response.
    for name in ["HTTPValidationError", "ValidationError"]:
        spec["components"]["schemas"].pop(name, None)
    spec["components"]["securitySchemes"] = {
        "IntegrationKey": {"type": "http", "scheme": "bearer", "bearerFormat": "findez_live_sk_…", "description": "Secret API key created in Settings → API keys. Keep server-side."},
        "UserSession": {"type": "http", "scheme": "bearer", "bearerFormat": "JWT", "description": "Signed-in owner's Supabase access_token; only for key management. An integration API key cannot manage keys."},
    }
    seen = set()
    for route in api_v1.router.routes:
        for method in route.methods:
            identity = f"{method} {route.path}"
            annotation = ENDPOINTS[identity]
            seen.add(identity)
            operation = spec["paths"][route.path][method.lower()]
            dependency = route.dependant.dependencies[0].call
            management = dependency is get_current_user
            scope = None if management else inspect.getclosurevars(dependency).nonlocals["required_scope"]
            bulk = False if management else inspect.getclosurevars(dependency).nonlocals["bulk"]
            operation.update({"summary": annotation["summary"], "description": annotation["description"], "tags": [annotation["tag"]],
                              "security": [{"UserSession" if management else "IntegrationKey": []}],
                              "x-required-scope": scope, "x-rate-bucket": None if management else "bulk" if bulk else "standard",
                              "x-path-values": annotation.get("pathValues", {}), "x-query-example": annotation.get("query", {})})
            success = str(route.status_code or 200)
            response = {"description": "Success", "content": {"application/json": {"schema": ref(annotation["response"]), "example": annotation["example"]}}}
            if route.path == "/api/v1/keys":
                response["headers"] = {"Cache-Control": {"schema": {"type": "string"}, "example": "no-store"}}
            operation["responses"] = {success: response, "default": {"description": "Error; see the error-code reference. User-session and gateway failures may have a string detail or non-JSON body.", "content": {"application/json": {"schema": ref("ErrorResponse")}}}}
            if "request" in annotation:
                operation["requestBody"]["content"]["application/json"]["example"] = annotation["request"]
            operation["x-extra-examples"] = annotation.get("extraExamples", {})
            for param in operation.get("parameters", []):
                param["description"] = TEXT.get(param["name"], {"page": "One-based page number.", "page_size": "Maximum records in a page, from 1 to 100.", "item_id": "Item UUID from a create response or inventory read.", "key_id": "Key metadata UUID, not the raw secret or key prefix."}.get(param["name"], ""))
    assert seen == set(ENDPOINTS), "Remove annotations for deleted endpoints."
    schemas = spec["components"]["schemas"]
    for model in ["APIItemCreate", "APIItemPatch", "APIBulkItem"]:
        for name, schema in schemas[model]["properties"].items():
            schema["description"] = TEXT[name]
    schemas["APIItemPatch"]["description"] = "All fields may be omitted, but the body must contain at least one. Explicit null is rejected for name, category, quantity, and location."
    # Pydantic's after-validators enforce constraints absent from its JSON schema.
    for name in ["name", "category", "quantity", "location"]:
        schema = schemas["APIItemPatch"]["properties"][name]
        concrete = next(option for option in schema.pop("anyOf") if option.get("type") != "null")
        schema.update(concrete)
        schema.pop("default", None)
    schemas["APIItemPatch"]["minProperties"] = 1
    for name in ["source_system", "external_id"]:
        schemas["APIBulkItem"]["properties"][name]["description"] += " Required for bulk sync; surrounding whitespace is trimmed and blank values are rejected."
    key_descriptions = {"name": "Integration label, 1–100 characters before trimming; must not be blank.", "workspace_id": "Owned Team UUID for a workspace key. Omit or send null to create an organization key covering the issuing account's owned Teams. Use workspace scopes with a Team UUID and organization scopes without one.", "scopes": "1–8 entries. Workspace: items:read, items:write, import:write, workspace:read. Organization: org:read, org:write. Types cannot be mixed; whitespace is trimmed and duplicates removed.", "expires_at": "Future ISO 8601 datetime; omit or null for no expiry. Use Z or an explicit offset; timezone-free input is treated as UTC."}
    for name, schema in schemas["CreateKeyRequest"]["properties"].items():
        schema["description"] = key_descriptions[name]
    query_descriptions = {"resource": "Only items is supported.", "workspace_id": TEXT["workspace_id"], "filters": "Up to 10 ANDed filters; empty array matches all visible rows.", "aggregate": "count = item records; sum_quantity = stored unit total across all matches. Omit/null to return an item page.", "page": "One-based page; maximum 1000000. Validated even for aggregates.", "page_size": "1–100 records; default 50. Does not bound aggregate totals."}
    for name, schema in schemas["InventoryQuery"]["properties"].items():
        schema["description"] = query_descriptions[name]
    schemas["APIBulkRequest"]["properties"]["items"]["description"] = "1–500 records with stable external identities. A configured server cap can be lower."
    filters = schemas["InventoryFilter"]
    filters["properties"]["field"]["description"] = "One of the listed item fields. Text and quantity have different operator/value rules."
    filters["properties"]["op"]["description"] = "Text: eq or neq only. Quantity: eq, neq, gt, gte, lt, lte. Defaults to eq."
    filters["properties"]["value"]["description"] = "Text: case-sensitive string of at most 200 characters. Quantity: JSON integer 0–100000; no strings, booleans, decimals, or null."
    filters["allOf"] = [{"if": {"properties": {"field": {"const": "quantity"}}}, "then": {"properties": {"value": {"type": "integer", "minimum": 0, "maximum": 100000}}}, "else": {"properties": {"op": {"enum": ["eq", "neq"]}, "value": {"type": "string", "maxLength": 200}}}}]
    return spec


def serialized_spec():
    return json.dumps(build_spec(), indent=2, ensure_ascii=False) + "\n"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    sys.path.insert(0, str(ROOT / "backend"))
    os.environ.update({"ENV": "development", "SUPABASE_URL": "https://placeholder.supabase.co", "SUPABASE_ANON_KEY": "placeholder", "SUPABASE_SERVICE_ROLE_KEY": "placeholder", "SUPABASE_JWKS_URL": "https://placeholder.supabase.co/jwks", "OPENAI_API_KEY": "placeholder"})
    expected = serialized_spec()
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text() != expected:
            raise SystemExit("API reference is stale. Run python scripts/api_reference.py and review the changes.")
        print("API reference matches the current backend contract.")
    else:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_text(expected)
        print(f"Wrote {OUTPUT.relative_to(ROOT)}")
