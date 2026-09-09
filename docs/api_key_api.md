# FindEZ API-key integration guide

The integration API is served from `https://api.findez.ai/api/v1`.

## Tenant model

- A FindEZ team is an API workspace (`workspace_id` is the team's UUID).
- The team owner's account is the organization boundary. An organization key can access every team owned by that account.
- A physical space is a distinct `location` string on an item. The API does not use a spaces table.

## Create a key

Key management requires a normal Supabase user access token. An API key cannot create another key.

First list the signed-in user's teams to obtain a workspace UUID:

```bash
curl https://api.findez.ai/teams \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN"
```

Create a workspace key:

```bash
curl -X POST https://api.findez.ai/api/v1/keys \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Warehouse sync",
    "workspace_id": "TEAM_UUID",
    "scopes": ["items:read", "items:write", "import:write", "workspace:read"]
  }'
```

Create an organization-wide read key by setting `workspace_id` to `null` and using an organization scope:

```json
{
  "name": "Reporting",
  "workspace_id": null,
  "scopes": ["org:read"]
}
```

The creation response contains `key` exactly once. Store it in a secrets manager; FindEZ stores only its Argon2 hash and cannot retrieve the raw value later.

## Use a key

```bash
export FINDEZ_API_KEY="findez_live_sk_REPLACE_WITH_THE_RETURNED_KEY"

curl "https://api.findez.ai/api/v1/items?page=1&page_size=50" \
  -H "Authorization: Bearer $FINDEZ_API_KEY"
```

Create an item with a workspace key:

```bash
curl -X POST https://api.findez.ai/api/v1/items \
  -H "Authorization: Bearer $FINDEZ_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "PN-F280",
    "category": "Hardware",
    "quantity": 1,
    "location": "Shelf B",
    "part_number": "PN-F280"
  }'
```

Organization write keys must include `workspace_id` in each item. Workspace keys may omit it because their workspace is fixed by the key.

Bulk upsert matches `(workspace_id, source_system, external_id)`:

```bash
curl -X POST https://api.findez.ai/api/v1/items/bulk \
  -H "Authorization: Bearer $FINDEZ_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"items":[{
    "name":"PN-F280",
    "category":"Hardware",
    "quantity":4,
    "location":"Shelf B",
    "source_system":"erp",
    "external_id":"part-280"
  }]}'
```

Submitting the same external identity again updates the existing row instead of creating a duplicate.

Other operations:

```text
PATCH  /api/v1/items/{item_id}
GET    /api/v1/spaces
GET    /api/v1/workspaces/summary
GET    /api/v1/keys
DELETE /api/v1/keys/{key_id}
```

`GET /api/v1/spaces` returns distinct item `location` values with counts.

## Scopes

Workspace keys:

- `items:read`
- `items:write`
- `import:write`
- `workspace:read`

Organization keys:

- `org:read` implies item and workspace reads across owned workspaces.
- `org:write` implies item writes and bulk imports across owned workspaces.

Read and write are deliberately independent. A write-only key cannot call read endpoints.

## Limits and errors

- Standard endpoints: 120 requests per minute per key by default.
- Bulk endpoint: 10 requests per minute per key and at most 500 items per request by default.
- Limits are configurable by server environment variables.
- Errors contain a stable `detail.code`, a safe message, and a correlation ID. Raw SQL errors and stack traces are never returned.
- Keys are revoked, never deleted. Expired and revoked keys return HTTP 401; missing scopes return HTTP 403.

There is intentionally no raw SQL execution endpoint.
