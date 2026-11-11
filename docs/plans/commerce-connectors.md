# Amazon and Shopify integration lane

Status: backend, merchant web UI and private schema deployed with explicit user
authorization November 10, 2026. Commerce remains disabled pending the public
callback header correction and provider credentials/configuration. Shopify dev
resources exist; no live connection, browser extension, mobile UI or provider
approval is claimed. Amazon registration is pending. Release and remaining work:
`commerce-production-rollout.md` and `commerce-edge-proxy.md`.

## Shopify setup receipt - November 10, 2026

The user completed signup and Partner organization onboarding in Safari.
Organization: AI Robots INC (`246688821`), API contact `info@findez.ai`.

- Dev store: FindEZ Integration Test, created with generated sample data and
  free Basic-plan testing features. Admin:
  https://admin.shopify.com/store/findez-integration-test-hdjbsg6g
- App: FindEZ Connect (`446104666113`). Dashboard:
  https://dev.shopify.com/dashboard/246688821/apps/446104666113
- Active configuration version: `commerce-dev-1` (`1203132465153`). This means
  Shopify app configuration was saved; it is not a FindEZ production deployment.
- App URL: `https://www.findez.ai/home`; embedded mode off.
- Allowed callback: `https://www.findez.ai/connect/shopify/callback`.
- Read-only scopes: `read_products,read_inventory,read_orders`.
- Legacy installation flow enabled to match the implemented explicit
  authorization-code flow. Webhooks API version: `2026-10`.
- Client credentials exist in Shopify Settings. The secret was not revealed,
  copied, committed, or configured on a FindEZ server.

No app installation or store synchronization has occurred. Distribution is not
selected and privacy/uninstall subscriptions are not registered. The implemented
callback pages are deployed, but Caddy overrides their referrer policy. Complete
the edge correction, provider credentials, backend activation and
test-store authorization before treating this as an operational connection.
All five CI jobs passed in run `42955103759` for backend commit `496c3cd1`.

Branch: `feat/commerce-connectors`, based on backend `17632a92024a986cb08dcfb795ba518fd9897ee9`
(`fix/barcode-camera-lookup-217`). The mobile Android checkout carries different
backend history; do not use it as the backend integration base.

## Scope and coordination

This lane owns `backend/app/services/commerce/`, `backend/app/api/routes/commerce.py`,
the commerce migration/tests, and the small router registration. The user also
assigned the merchant Connections screen and OAuth callback pages to this terminal.
It does not own CAD, canonical inventory identity, chat orchestration, or Flutter.

Existing `items`, stock, Project Kits, reservations, imports, and FIND extraction
remain authoritative for their current responsibilities. No commerce operation
creates stock, changes quantities, reserves components, purchases goods, or sends
messages. There is no automatic order-to-owned transition.

Implemented:

- Shopify merchant OAuth with exact shop validation, signed callbacks, single-use
  actor/inventory-bound state, expiring offline tokens and server-side rotation.
- Shopify GraphQL Admin API `2026-10`: all product variants, aggregate tracked
  inventory, and recent order lines including current quantities and cancellation/
  fulfillment status. Deleted variants remain readable in historical order lines.
- Amazon seller OAuth/LWA refresh, Orders `2026-01-01` with line items, and FBA
  Inventory summaries. This is seller sales/stock, not personal purchase history.
- Amazon consumer CSV preview and explicit hash-confirmed import. This is a
  documented FindEZ template, not a promise to parse every Amazon export format.
- Actor-private source reads, disconnect, purge, complete pagination, atomic
  snapshot commits, idempotent source keys, and durable sync/rotation claims.
- Signed Shopify uninstall and mandatory privacy webhook processing, duplicate
  suppression, private data-request exports, and hashed order suppression so a
  later sync cannot restore redacted order lines.

Not implemented: Shopify buyer OAuth/storefront carts, Amazon consumer-account
OAuth/carts, receipt email access, a browser extension, automatic scheduling,
catalog identity matching, provider write-back, merchant financial analytics,
Amazon merchant-fulfilled stock/listings, or provider return-event history.

## Merchant web client

Inventory navigation now includes Connections at
`/inventory/connect?inventory=INVENTORY_UUID`. Existing server authentication and
InventoryBoundary verify the selected inventory. Editing access is required.
The screen supports Shopify merchant and Amazon seller authorization, explicit
catalog/stock and last-30-day order sync, paginated source records, disconnect with
retained history, and separately confirmed deletion of imported records. Readiness
comes from `/commerce/capabilities`; unavailable providers cannot be connected.
Amazon consumer CSV remains an API feature without an upload screen in this step.

Standalone `/connect/shopify/callback` and `/connect/amazon/callback` pages remove
the query before asynchronous auth work, reject duplicate query keys, preserve all
once-decoded signed fields, and require the initiating FindEZ account. Pending
connection identity/state expires after ten minutes in per-tab sessionStorage;
codes and tokens are never stored there. Redirect host/path and callback origin
are checked before leaving FindEZ. The configured callback must use the same web
origin as the initiating page. Strict Mode reuses one completion promise; failed
exchanges are not replayed. Refresh Connections to resolve uncertain completion.
Callback responses use no-referrer and no-store headers; they do not redirect
unauthenticated callback queries into sign-in URLs or render provider parameters.

The client uses account-bound API requests, with stale account/inventory results
discarded. Source stock, sales and purchases remain visibly distinct from verified
physical inventory. No client operation calls item mutation routes.

Validation: 28 focused OAuth/UI tests, all 353 web tests in 47 suites, TypeScript,
changed-file ESLint, and the repository compile-only webpack check pass. The
compiled route manifest confirms no-referrer/no-store on both callbacks. The
sandbox denied binding a localhost server (EPERM), so HTTP smoke testing is not
claimed. The compile check uses synthetic
auth settings/substituted fonts and its output must not be deployed. Rendered
light/dark fixtures contain fictional data, not successful provider authorization.
Desktop and 390px fixture layouts were inspected in Safari. Generate fixtures
from frontend:

```bash
FINDEZ_COMMERCE_PREVIEW=/private/tmp/findez-commerce-preview npx jest --runInBand commerce-client.test.tsx
```

## Client API contract

All routes below require the existing FindEZ user bearer JWT, except the signed
Shopify webhook. Commerce routes are mounted once at the application root, not
under legacy scoped routers or the public API-key surface.

| Method/path | Purpose |
| --- | --- |
| GET `/commerce/capabilities` | Provider configuration readiness; unsupported buyer/cart features are explicit |
| GET `/commerce/connections?inventory_id=UUID` | Connecting actor's connections in an authorized inventory |
| POST `/commerce/connections` | Create an import destination or begin provider OAuth |
| POST `/commerce/connections/UUID/complete` | Complete OAuth with the same signed-in FindEZ actor |
| POST `/commerce/connections/UUID/sync` | Explicit bounded provider sync |
| GET `/commerce/connections/UUID/records?offset=0&limit=100` | Source evidence with observation times and pagination |
| POST `/commerce/connections/UUID/purchase-file` | CSV preview, or reupload with `confirmed_sha256` to commit |
| DELETE `/commerce/connections/UUID?purge=false` | Remove credentials; retain disconnected evidence by default |
| DELETE `/commerce/connections/UUID?purge=true` | Remove connection and its source records/exports |
| GET `/commerce/connections/UUID/privacy-exports` | Export responses for the merchant to deliver manually |
| POST `/commerce/webhooks/shopify` | Raw-body HMAC authenticated lifecycle/privacy callback |

Create Shopify:

```json
{"inventory_id":"INVENTORY_UUID","provider":"shopify","external_account":"example.myshopify.com"}
```

Create Amazon seller (seller ID is a public account identifier, not a password):

```json
{"inventory_id":"INVENTORY_UUID","provider":"amazon_seller","external_account":"SELLER_ID","region":"na","marketplace":"ATVPDKIKX0DER"}
```

Create consumer import: `{"inventory_id":"INVENTORY_UUID","provider":"amazon_consumer"}`.
The server derives its account key; callers cannot import into somebody else's account.

OAuth start returns `connection`, `authorization_url`, and `expires_in=600`.
Save the connection ID in actor-bound client session state and navigate to the
authorization URL. Configure a frontend HTTPS callback page to collect provider
query parameters and POST `{"parameters":{...}}` to `/complete` with the FindEZ
JWT. The frontend callback pages are implemented in this branch. Reject duplicate
query keys, decode once, forward all Shopify
parameters unchanged for HMAC validation, and strip the authorization code from
browser history immediately. Do not store it in analytics or browser logs.
If the FindEZ account changed, cancel the flow instead of attaching credentials.
There is deliberately no unauthenticated state-only completion endpoint.

Shopify supplies `shop`, `state`, `code`, `timestamp`, `hmac`, and potentially other
signed fields. Amazon supplies `state`, `selling_partner_id`, `spapi_oauth_code`.
The expected seller ID is checked against the requested account. Failed exchanges
consume the state; disconnect and begin a new flow. A lost successful response can
be resolved by listing the connection state, without exchanging the code again.

Sync body: `{"resource":"orders","since":"2026-11-01T00:00:00Z"}`.
Shopify also accepts `catalog` (variants plus aggregate stock); Amazon accepts
`stock` (FBA only). The default order window is the last 30 days; this candidate
allows at most 59 days and requests no `read_all_orders` privilege. Order sync is
upsert-by-source, not full-history replacement. It returns its requested coverage.
Shopify order access remains subject to its protected-customer-data requirements,
even though FindEZ does not request names, addresses or emails.

Limits: 100 provider calls, 10,000 normalized records, 75-second call-start budget,
15-second request timeout, 8 MB decoded response. A truncated or failed fetch
never replaces the previous snapshot. FBA pagination is paced at its default two requests per second. Amazon Orders
uses at most its 20-page default burst; larger windows require future queued
continuation. No automatic HTTP retries; the caller can
retry after rate limits. Sync/refresh claims expire after 120 seconds, and stale
workers cannot commit. Large accounts may need future queued/bulk ingestion.

## Source contract for the unified FIND lane

`SourceRecord` is defined in `backend/app/services/commerce/models.py`.
Identity is `(connection_id, kind, external_id)`, not SKU alone. Provider/account,
inventory boundary, granted scopes and status come from the connection. Each
record retains `observed_at` plus provider timestamps where available.

- `catalog_variant`: product identity evidence, not owned stock.
- `merchant_stock`: provider-reported business stock; `available_quantity` differs
  from `quantity` (for example, FBA fulfillable versus total). Shopify untracked
  variants have unknown available quantity, not a fabricated zero.
- `sale_line`: goods sold by the connected merchant. Never interpret as purchases
  by the FindEZ account holder. `current_quantity` is the provider's current line
  quantity; it is not a confirmed delivered or returned quantity.
- `purchase_line`: consumer claims imported from a file. A `delivered` label is
  user-provided evidence, not physical verification.

Every record has `physically_verified=false`; no model-generated confidence or
ownership claim is introduced. Source text is untrusted data, never instructions
for Assist. Never add quantities across sales, purchases, stock and physical scans.
Reconciliation belongs to the unified inventory lane and must be reviewed.
Disconnected records are historical evidence; do not treat them as live availability.
Order coverage and observation timestamps must remain visible in answers.

Connections and records are initially visible only to their connecting actor,
with inventory edit access rechecked. Membership alone does not expose a teammate's
merchant data. Expanding this to shared merchant administration requires a separate
permission contract. A store/seller has one active connection across the app;
disconnect before moving it to another inventory. This prevents Shopify token
rotation in one connection silently breaking another.

## Amazon consumer CSV

```csv
order_id,line_id,title,quantity,ordered_at,asin,status
example-order,example-line,NEMA 17 motor,2,2026-11-01T00:00:00Z,B000000001,purchased
```

First five columns are required; `asin` and `status` are optional. Status is one of
`purchased`, `shipped`, `delivered`, `cancelled`, `returned`, `unknown`.
Dates require timezone, quantities are nonnegative integers, and order/line pairs
must be unique. Preserve the same source identifiers across updates. Maximum
2 MB/5,000 rows; unexpected columns are rejected to avoid accidentally retaining
addresses or payment data. Preview sends normalized records and SHA256; confirm
reuploads the same bytes and includes that hash. No data is stored during preview.
Repeated confirmed files update the same source keys, never physical stock.

## Setup and activation

Use `backend/commerce.env.example` for names only. Supply credentials via the
server's environment or protected backend `.env`, never mobile/web builds.
The AES-256-GCM key is a base64 encoding of 32 random bytes, distinct from the
Supabase JWT/service keys. Ciphertext is authenticated to the connection ID.
Keep the key across restarts. Key rotation currently requires a controlled
decrypt/re-encrypt migration or reconnecting affected accounts; no silent fallback.

Shopify: create a development store and app, register the client callback, configure
`read_products,read_inventory,read_orders`, and install on the test store.
Subscribe API version `2026-10` to `app/uninstalled` and compliance topics
`customers/data_request`, `customers/redact`, `shop/redact`, all pointing at
`https://findez.openstack.ftctools.com/commerce/webhooks/shopify` after backend activation.
The receiver verifies the raw body, payload shop and event timestamp. A data
request prepares a private export; the merchant/operator must deliver it through
their established privacy-request process. This code does not email a requester.
Monitor these requests before enabling any public installation.

Amazon: register an SP-API developer application and LWA credentials, configure
the callback, request the appropriate Orders/FBA Inventory roles, and authorize
an owned test seller. Draft consent uses `version=beta`; set `AMAZON_DRAFT=false`
only once the app is eligible for live authorization. No consumer Amazon passwords
or personal account APIs are used. Additional marketplaces require an explicit
reviewed entry in `REGIONS` rather than arbitrary API endpoints.

Apply `20261110_commerce_connectors.sql` only after reconciling the real schema and
the parallel foundation lane. It depends on `auth.users`, `app_inventories` and
`findez_inventory_role`, all already used by existing connector code. The timestamp
filename avoids competing for a sequential migration number. Production database
changes still require the repository's explicit authorization gate.

Keep `FINDEZ_COMMERCE_ENABLED=false` until migration, client callback, credentials,
test-account acceptance and provider configuration are complete. Preserve signed
webhook handling while pausing new connections. Disconnect removes local tokens;
users should also revoke/uninstall access in the provider account. No claim of
provider-side revocation is made for local disconnect.

## Verification

Run `.venv/bin/python -m pytest -q` from the repository root. Commerce fixtures
use `httpx.MockTransport`, not live credentials. Run `backend/tests/sql/commerce.sql`
against an empty disposable PostgreSQL database; it applies the migration twice
and checks service-only grants, actor isolation, replay, lease replacement,
revocation, atomic writes, disconnect races and privacy handling. CI includes it.
Validation on this candidate: 1,671 backend/API-doc tests and 10 subtests passed;
46 dedicated commerce tests passed. The disposable PostgreSQL suite passed all
29 assertions, including migration replay and privacy suppression. An initial
SQL alias ambiguity was fixed before the passing run. No live acceptance claimed.

Local Python 3.14 cannot install the repository's pinned Pydantic core; use 3.12.

Before activation, perform real test-store/seller OAuth, token rotation, denied
consent/scopes, multi-page sync, uninstall, privacy callbacks, reconnect, provider
rate limits, and client account-switch tests. Mocks do not certify live acceptance.

## Official references checked November 10, 2026

- https://shopify.dev/docs/apps/build/authentication-authorization/authenticate-standalone-apps
- https://shopify.dev/docs/apps/build/authentication-authorization/access-tokens
- https://shopify.dev/docs/api/admin-graphql/2026-10/queries/productVariants
- https://shopify.dev/docs/api/admin-graphql/2026-10/queries/orders
- https://shopify.dev/docs/apps/build/compliance/privacy-law-compliance
- https://shopify.dev/docs/apps/build/webhooks/verify-deliveries
- https://developer-docs.amazon.com/sp-api/docs/website-authorization-workflow
- https://developer-docs.amazon.com/sp-api/docs/orders-api-migration-guide
- https://github.com/amzn/selling-partner-api-models/blob/main/models/orders-api-model/orders_2026-01-01.json
- https://developer-docs.amazon.com/sp-api/reference/getinventorysummaries
