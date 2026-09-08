# FindEZ integration API

Implementation is backend-only and mounted at `/api/v1`. Existing session routes retain
 their paths and authentication. No spaces table is created or queried: API spaces are
 distinct `(workspace_id, items.location)` values.

## Deployment

1. Back up the target database and review/apply `032_api_keys.sql` as the database
   administrator before deploying the backend. It is a one-time transactional migration;
   an existing `findez_api` role or conflicting tenant tables deliberately causes failure
   instead of silently trusting existing privileges.
2. Set a strong password for `findez_api` through secure database administration, permit
   the backend host in PostgreSQL connection rules, and set `API_KEYS_DATABASE_URL` to
   that login's DSN. Use direct PostgreSQL or session pooling and TLS (`sslmode=verify-full`)
   for remote connections. Never use the postgres owner or Supabase service-role login.
   The backend rejects superusers, BYPASSRLS, inherited roles, table owners and role memberships.
3. Set `API_KEYS_ENVIRONMENT=live` in production. A separate test deployment/database uses
   `test`; the environment prefix does not create a sandbox inside a shared database.
4. Install `backend/requirements.txt` and restart the backend. An unset integration DSN
   returns a stable 503 only for integration routes; legacy routes keep working.
5. Provision organizations, memberships and workspaces through trusted database
   administration. Add the normal Supabase user's UUID to `organization_memberships`
   with role `admin` so that session can manage keys. These tables have RLS enabled and
   no direct client grants. Workspace memberships are reserved for explicit onboarding;
   API keys themselves carry the workspace delegation and organization admins manage it.

The existing schema has user/team ownership, not organizations/workspaces. The migration
adds separate tenant tables and nullable `items.workspace_id`, `source_system`, and
`external_id`. Existing items remain unassigned and invisible to API keys until an
administrator explicitly maps them to a workspace. Do not infer company membership from
matching location names. Existing session ownership policies remain unchanged; the API
creator's `user_id` is retained on new items for compatibility. Moving existing data or
integrating the new workspaces into mobile/team workflows is not automatic.

## Authentication and isolation

Keys contain 24 random bytes encoded as 32 URL-safe characters after `findez_live_sk_`
or `findez_test_sk_`. Only an Argon2id hash of the full key and its first 20 characters
are stored. Creation is the only response containing the raw key. Do not log that
response or Authorization headers at the proxy/APM layer.

`authenticate_api_key` looks up all prefix candidates and verifies hashes off the event
loop, rejects environment mismatches, expiry and revocation. `require_api_scope` checks
endpoint permissions and opens a transaction with `request.jwt.claims` set locally.
Database policies resolve the organization/workspace from the stored key and recheck
its status and scopes. Restrictive policies AND with legacy permissive policies, so
an identical legacy owner UUID cannot widen API tenant access. Claims reset after commit
or rollback. Item reads/writes use the restricted connection, never Supabase service-role
queries or a tenant filter as the security boundary.

Only narrow SECURITY DEFINER functions read key hashes, manage keys, and update usage.
They use fixed search paths, qualified tables, and have PUBLIC/anon/authenticated execution
revoked. `api_private` is not a PostgREST-exposed schema. There is no SQL execution route.
The dedicated database credential is a trusted backend credential and must not be shared
with API consumers: the server sets claims after verifying their bearer secret.

## Requests

Key management requires `Authorization: Bearer <normal-session-JWT>`. API keys cannot
manage keys. If the user administers multiple organizations, send `X-FindEZ-Org-ID`.

- `POST /api/v1/keys`: `{ "name": "ERP", "workspace_id": "<uuid>", "scopes": ["items:read"], "expires_at": null }`.
  For an organization key set workspace_id to null and use org scopes. Returns 201 with `key` once.
- `GET /api/v1/keys`: metadata under `data`; includes revoked keys, never hashes/raw keys.
- `DELETE /api/v1/keys/{id}`: sets revoked_at; repeat calls return 204, never delete the audit row.

Data requests use `Authorization: Bearer findez_live_sk_...`:

| Endpoint | Workspace scope | Global scope |
|---|---|---|
| GET /api/v1/items | items:read | org:read |
| POST /api/v1/items | items:write | org:write |
| PATCH /api/v1/items/{id} | items:write | org:write |
| POST /api/v1/items/bulk | import:write | org:write |
| GET /api/v1/spaces | workspace:read | org:read |
| GET /api/v1/workspaces/summary | workspace:read | org:read |

Read and write are independent: org:write does not grant org:read, and items:write
does not grant import:write. Items support UUID cursor pagination (`limit` 1–200,
default 50; pass the response's `next_cursor` as `after`). Optional `workspace_id`
filters items/spaces within the RLS-visible set. Summaries include empty workspaces,
item_count (rows), total_parts (sum of quantity), and space_count (distinct locations).

Create requires name, category, nonnegative integer quantity and location; accepts
notes, barcode and paired source_system/external_id. Workspace keys default writes to
their own workspace; global keys require workspace_id per item. PATCH only updates
name/category/quantity/location/notes/barcode, never tenant or ownership columns.
Bulk accepts `{ "items": [...] }`, 1–500 items, each with source_system/external_id;
it upserts on `(workspace_id, source_system, external_id)` in one atomic transaction.
Repeated identities within a batch apply in order, with the last occurrence winning.

Limits are atomic per-key fixed UTC minute windows, shared by backend workers: 120
requests/minute, including at most 10 bulk calls. A limit returns 429 with Retry-After.
last_used_at writes are throttled to once per five minutes. Prefix verification uses
at most four concurrent Argon2 operations per worker; retain edge/IP abuse limits to
protect unauthenticated traffic and session key creation. Request bodies are capped at 1 MiB.

Errors have `{ "error": { "code", "message", "correlation_id" } }`, matching
`X-Correlation-ID`. Codes include invalid_api_key (401), insufficient_scope (403),
rate_limited (429), invalid_request (422), conflict (409), and internal_error (500).
Internal logs include correlation ID, exception class and SQLSTATE, omitting SQL values,
request bodies, secrets and raw database error details. All integration responses use no-store.

## Verification

Use a disposable PostgreSQL 17 cluster only. The suite creates and drops unique test
databases and provisions cluster roles. It never connects to production automatically.

```sh
pip install -r backend/requirements.txt pytest pytest-asyncio
API_TEST_ADMIN_DSN=postgresql://user@127.0.0.1:55439/postgres \
PYTHONPATH=backend pytest backend/tests/api_keys -q
```

The tests exercise real PostgreSQL RLS and HTTP routes, including deliberate unfiltered
reads, legacy owner overlap, read-only write denial, pool claim reset, cross-org writes,
bulk rollback/upsert, key secrecy, scope checks, prefix collisions, expiry, revocation,
pagination, global access, rate limits, and rejection of privileged connections. Session
JWT verification is mocked; the existing verifier is reused unchanged in production.

Validation on 2026-09-08: seven integration tests passed against PostgreSQL 17.
The existing suite had 118 passes and two `TestRouteRawQueryMerge` failures; the same
failures were reproduced by running the full suite on unchanged HEAD. The search test
module passes individually, indicating existing test-order interference. Full application
route mounting, health, and unauthenticated integration error smoke checks passed.
