# Read-only Shopify development connector

October 12, 2026. Source milestone 1A implemented; disabled by default. No Shopify
app or development store currently exists for this project (user confirmed).
No merchant is connected, no live Shopify request is verified, migration 042 is
not applied to production, and nothing in this lane is deployed. This is a
development/custom-store pilot, not a public App Store installation implementation.
The prior discovery report remains the product/architecture reference.

## What this increment does

- A selected FindEZ Team owner initiates authorization for one server-configured
  pilot store, explicitly sharing read-only catalog access with Team members.
  The browser nonce cookie, hashed single-use state, Team/actor/store binding,
  callback HMAC and generation checks prevent account/store swaps and replay.
- Access/refresh tokens use AES-256-GCM encryption bound to the connection and
  installation generation. A key ID supports rotation; credentials are backend-only.
  Expiring offline tokens use response lifetimes and serialized refresh/acquisition.
- Pinned GraphQL `2026-10` reads variants, options, case-sensitive SKUs, all up-to-20
  barcode aliases, a representative catalog image, inventory-item identifiers and
  paginated per-location stock states. Imported images are not physical evidence.
- PostgreSQL stores separate commerce cache rows and a leased, restart-safe job
  cursor. Pages commit atomically with cursors. Errors/partial GraphQL responses
  cannot declare a completed sync. Transient retries retain progress; eight failed
  attempts stop the job visibly. An owner retry starts a fresh catalog pass after
  exhaustion, so deleted records cannot trap an old cursor forever.
- Verified raw-body webhooks persist deduplicated delivery receipts and dirty flags
  before acknowledgment. Destructive callbacks also bind the signed payload's
  Shop identity/domain; headers alone cannot authorize another store's erasure.
  The worker fetches canonical records, not webhook payload
  fragments. Idle connected stores queue reconciliation once their last successful
  sync is 15 minutes old. Location names/changes are reconciled without requesting extra location
  webhook scopes. Returned GraphQL cost budgets delay durable work.
- Team > People contains a restrained optional panel: actual connection state,
  last attempt versus last complete sync, paginated catalog preview, owner Sync,
  Reconnect and confirmed Disconnect. Disabled installations add no panel. Member
  reads, server-side owner management and account/Team switches are enforced.
- Disconnect/uninstall immediately erase tokens, jobs, states, stock snapshots and
  imported variants. Late workers/callbacks are fenced out. Stale uninstall events
  cannot revoke a newer installation; uninstall during pending OAuth invalidates it.
  `shop/redact` erases the connection and associated receipts/audit, too.

Existing items, quantities, Spaces, bins, FIND, ASK, mobile, pricing and billing
remain unchanged. This increment never creates physical inventory records and
never performs a Shopify inventory/product/order mutation. Product removals
tombstone commerce rows after a completed pass. The subsequent location-confirmation
and Team-aware ASK slice is still unimplemented.

## Prepare an isolated development installation

1. Create a Shopify development app/store through the Dev Dashboard, choosing a
   standalone development/custom-store pilot rather than public distribution.
   Distribution selection can be irreversible; this work has not selected it.
   Use [Shopify's distribution guidance](https://shopify.dev/docs/apps/launch/distribution).
2. Use a separate FindEZ backend, frontend and Supabase database with test users
   and a test Team. Apply the existing schema/baseline and prior migrations, then
   `backend/supabase/migrations/042_shopify_catalog.sql`. Numbered migrations alone
   do not reconstruct the production baseline. Never point test fixtures at production.
3. Configure HTTPS frontend/API hosts on the same site, for example
   `www.dev.example.com` and `api.dev.example.com`. This is required for the secure
   SameSite=Lax browser nonce cookie. Add the exact frontend origin to backend CORS.
   The web API base must point at this test backend; changing `NEXT_PUBLIC_*` requires
   rebuilding. Do not mix the test app with a production frontend/database.
4. Use `integrations/shopify/shopify.app.toml.example` as the app configuration
   starting point. Replace the nonsecret client ID and all example origins. Register
   the exact callback and webhook URLs. Configure only `read_inventory,read_products`.
   The token adapter refuses missing or additional customer/order/write scopes.
   Subscribe through app configuration; this adapter has no arbitrary GraphQL
   mutation/proxy endpoint. Verify the template with Shopify CLI once an app exists.
   [Subscriptions](https://shopify.dev/docs/apps/build/webhooks/get-started),
   [Standalone authorization](https://shopify.dev/docs/apps/build/authentication-authorization/authenticate-standalone-apps).
5. Store these settings privately in the test backend's environment, not in git,
   screenshots, frontend configuration, chat or logs:

   | Setting | Purpose |
   | --- | --- |
   | `SHOPIFY_ENABLED=true` | Explicit opt-in after migration/configuration |
   | `SHOPIFY_CLIENT_ID` / `SHOPIFY_CLIENT_SECRET` | Development app credentials |
   | `SHOPIFY_PILOT_SHOP` | Exact lowercase canonical `*.myshopify.com` domain; no URL |
   | `SHOPIFY_REDIRECT_URI` | Exact HTTPS API `/integrations/shopify/callback` URL |
   | `SHOPIFY_TOKEN_KEYS` | JSON object mapping key IDs to base64url-encoded random 32-byte encryption keys |
   | `SHOPIFY_ACTIVE_KEY_ID=v1` | Key ID for new ciphertext; retain old keys until re-encrypted |
   | `FRONTEND_URL` | HTTPS frontend used for the fixed callback return |

   Use a cryptographically random vault key independent of Shopify/Supabase keys.
   Keep it in the existing private environment/secret store. Do not reuse test
   fixture keys. On rotation, retain old IDs, change the active ID and explicitly
   renew/reconnect stores; new token writes use the active key. Old keys cannot be
   removed until all stored credentials have been rewritten under a retained key.
6. Disable callback query-string logging at every reverse proxy and access-log
   collector. The handler scrubs its request scope before Uvicorn logs the response;
   upstream proxies see the incoming OAuth code/state and require separate config.
7. Install backend requirements, start the test API and supervise a separate worker
   with the same private environment. From `backend/`:

   ```bash
   python -m scripts.shopify_worker
   ```

   It exits on incomplete/disabled configuration. Several workers are supported by
   per-store DB leases. Monitor the worker process, queue ages, retry-exhausted and
   reconnect-required connections. A stopped worker produces no fake sync success;
   the UI shows queued work and the existing last-success time.
8. Sign in to the test web app as the test Team owner. Open Team > People, Connect,
   review member delegation, authorize Shopify, and verify the actual returned Team
   status and catalog. The connection is bound to one Team; transferring a store
   between Teams needs an explicit future ownership-transfer workflow, not a silent
   reassignment. This is pilot configuration, not a commercial store entitlement.

Current fields and token contracts were checked against primary Shopify docs;
authenticated development-store query/scopes/installation acceptance is still
required. [Variants](https://shopify.dev/docs/api/admin-graphql/2026-10/objects/ProductVariant),
[Inventory](https://shopify.dev/docs/api/admin-graphql/2026-10/objects/InventoryLevel),
[Token lifecycle](https://shopify.dev/docs/apps/build/authentication-authorization/access-tokens).

## Retention and recovery

The imported cache is retained only while connected or awaiting reauthorization.
Disconnect/uninstall purge it immediately, with no changes to independently authored
native physical items. A minimal Team/store binding remains for safe reconnect and
to prevent another Team claiming it; `shop/redact` or Team deletion removes it.
Operational receipts and actor/action audit entries expire after 30 days when the
worker runs. OAuth states expire in 10 minutes and are pruned by the worker. Full
webhook/customer payloads are never stored. This release requests no customer/order
data, so customer compliance deliveries acknowledge no stored customer records;
adding such data requires a new export/deletion implementation first.

Backups must honor the same deletion policy before any merchant launch; no backup
retention integration or public policy rollout has been implemented. Public app
distribution/billing and policy review remain separate gates. Uninstall redaction
is destructive to derived commerce cache even if a store has subsequently reconnected,
favoring erasure over keeping uncertain data. No independently authored physical
memory is erased by Shopify callbacks.

On network/throttle errors, pages retry with bounded exponential backoff and jitter.
On revoked/expired authorization, Reconnect is required. The last successful sync
remains distinct from failed attempts. Do not restart authorization while a worker
holds its lease; wait for the bounded request to finish. After a failed callback,
the consumed authorization has a two-minute serialization window before retry.
Shopify token requests have a 20-second HTTP timeout and leases are 120 seconds.

To disable new connections/sync, set `SHOPIFY_ENABLED=false` and stop the worker.
Keep the webhook secret/API receiver available for uninstall/compliance deliveries.
The authenticated disconnect endpoint remains available with the flag off; the
disabled UI is hidden. Do not drop tables or roll back existing physical inventory.

## Verification and remaining acceptance

Hermetic Python tests cover OAuth HMAC/state/browser binding, scope and expiry
validation, encryption/rotation/tenant binding, hostile hosts, fixed read queries,
GraphQL partial failures/version fall-forward/throttling, owner/member boundaries,
webhook signatures and one-page worker checkpoints/refresh. Web tests cover disabled
UI, member preview, stock labels, unknown counts, pagination, duplicate actions,
failed writes, confirmed disconnect, unsafe redirects/images and late scope responses.
The existing PostgreSQL CI fixture includes `shopify_catalog.sql`: real RLS denies
credentials/client writes/API keys and revoked members; leases/state/generation,
retry, deduplication, tombstones, redaction and unchanged native items are exercised.

Before enabling any merchant pilot, record actual development-store acceptance:

- OAuth install/reinstall/cancel in the real browser, including secure cookies and
  reverse-proxy logs free of query codes/tokens; exact returned scopes/version.
- More than one variant page, multiple barcodes, duplicate/missing/case-sensitive
  SKUs, representative images, tracked and untracked items and multiple inventory
  locations/pages. Verify query costs on the development store.
- Refresh a real expired access token, terminate/restart the worker mid-import,
  rename/delete catalog records, and verify reconciliation and last-success status.
- Real webhook retries/duplicates/out-of-order deliveries and acknowledgment timing;
  uninstall/reinstall during work, disconnect, shop redaction and backup handling.
- Another owner/Team cannot connect/read the store; member access revoked during
  preview disappears, with no physical item or stock count changes.

Automated mocks and disposable SQL do not satisfy these live-store checks. Public
distribution, connected-store ASK, location observations, photo matching, external
writes, new tiers and pricing changes are outside this increment.
