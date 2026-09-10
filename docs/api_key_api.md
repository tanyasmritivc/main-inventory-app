# FindEZ API-key integration guide

The integration API is served from `https://api.findez.ai/api/v1`.

## Tenant model

- A FindEZ team is an API workspace (`workspace_id` is the team's UUID).
- The team owner's account is the organization boundary. An organization key can access every team owned by that account.
- API location listings are distinct `location` strings on items. The application stores actual Spaces and Team Space associations; the API preserves those associations so imported inventory appears in the app.

## Web setup

Open **Settings → API keys** (`/settings/api-keys`). Choose a team you own (or all teams you own), select permissions and expiration, and create the key. Read access is selected by default. Copy the key before dismissing it; it cannot be recovered later.

**Test connection** authenticates the new credential and, for read keys, runs an inventory count through the actual query endpoint. Write-only keys can verify authentication without creating a test item. The saved list shows the prefix, permissions, expiration, last use, and a separate Revoke action per key. The raw value is never saved in browser storage or returned by the list endpoint.

Individuals currently need a Team with linked Spaces to use the API. Personal inventory outside Teams is not exposed. Only owners can issue integration keys; membership alone is insufficient. Organization access means all teams owned by the same account, not an independent company/organization record.

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

For a first read-only connection, keep the default read permissions in the web
form. In Terminal (macOS zsh or bash), run this command **on its own**, paste the
copied key, and press Return. Input is hidden and the key is not entered as a
command in shell history:

```bash
read -rs FINDEZ_API_KEY
```

Then retrieve the first page of your team's inventory:

```bash
curl "https://api.findez.ai/api/v1/items?page=1&page_size=50" \
  -H "Authorization: Bearer $FINDEZ_API_KEY"
```

The response contains `items` (including each item's name, quantity, and location)
and `total`. Increase `page` to retrieve more records. An empty result can mean no
inventory is in Spaces linked to the selected team; it does not include unlinked
personal Spaces.

To ask "How many units of this part do we have?", replace `5202` with the **exact
stored part number** and run:

```bash
curl https://api.findez.ai/api/v1/query \
  -H "Authorization: Bearer $FINDEZ_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"resource":"items","filters":[{"field":"part_number","op":"eq","value":"5202"}],"aggregate":"sum_quantity"}'
```

For example, three matching inventory records with quantities 4, 2, and 2 return
`{"resource":"items","aggregate":"sum_quantity","value":8}`. This is the stored
quantity total, not a calculation of unreserved stock or build compatibility.

When finished, run `unset FINDEZ_API_KEY`. For ongoing integrations, store the key
in that tool's private credential/secret settings, not in a public website, source
code, spreadsheet cell, or chat message. Use a separate key for each integration so
one can be revoked without stopping the others. A leaked key should be revoked in
Settings and replaced.

Read-only keys can power reports and external inventory lookups. Enable item-write
or bulk-import permissions only for an integration that needs to change inventory.
The key authorizes requests; it does not schedule spreadsheet refreshes, send
low-stock emails, or connect an AI assistant by itself. Those tools still need to
be configured to call this API.

## Write and sync inventory

Create an item with a workspace key:

`location` must exactly match one existing Space linked to the selected team. Create or attach the Space in FindEZ first. An unknown or ambiguous location returns 400. The write preserves the Space owner's account and associates the new item with that Space.

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
GET    /api/v1/keys/workspaces
DELETE /api/v1/keys/{key_id}
GET    /api/v1/whoami
POST   /api/v1/query
```

`GET /api/v1/spaces` returns distinct item `location` values with counts.

## Structured inventory queries

Send an API key with `items:read` or `org:read`:

```bash
curl -X POST https://api.findez.ai/api/v1/query \
  -H "Authorization: Bearer $FINDEZ_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"resource":"items","filters":[{"field":"location","op":"eq","value":"Shelf B"}],"aggregate":"count"}'
```

`count` counts item records. `sum_quantity` totals units across all matching records, including rows beyond the first page. Omit `aggregate` for a paginated item list with `page`, `page_size`, and `total`. Default page size is 50; maximum is 100.

Filters are ANDed, with at most 10 per query. Allowed text fields: `name`, `category`, `location`, `brand`, `part_number`, `barcode`, `source_system`, and `external_id`. Text supports exact `eq` and `neq` (case-sensitive). `quantity` also supports `gt`, `gte`, `lt`, and `lte`, with integer values from 0 to 100000. SQL, joins, arbitrary projections, unknown resources/fields/operators, and extra JSON properties are rejected. Values are bound parameters in PostgreSQL; the caller cannot supply SQL.

Workspace keys cannot override their workspace. Organization keys may add `workspace_id` to narrow a query or `GET /items`; PostgreSQL still restricts results to currently owned teams. Attaching/moving/detaching a Team Space and new app item writes keep API workspace membership current. Detachment preserves inventory and removes the old team's access. Keys also lose access if the team changes owner or is deleted.

This HTTP API can be called by integrations or AI tools configured to use it. Creating a key does not itself install a ChatGPT/Claude connector, MCP server, or Zapier integration.

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

## Deployment and verification

Apply migration `034_api_inventory_queries.sql` after `032` and `033`, then deploy the backend before the web page. It updates access checks, adds Team Space synchronization triggers, reconciles workspace membership for existing linked items, and installs the bounded query RPC. It does not delete inventory or change its owners.

The PostgreSQL fixture in `backend/tests/sql/api_key_rls.sql` runs against an **empty disposable database only** and tests real RLS, read-only rejection, write-only updates/upserts, cross-tenant isolation, query injection, aggregation, and detach/transfer/revocation behavior. CI runs it in PostgreSQL 17. The Python HTTP lifecycle and web component suites run through the existing test commands.
