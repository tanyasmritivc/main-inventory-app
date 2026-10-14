# Commerce-linked physical memory: development milestone 1B

October 13, 2026. Implemented in source on `feat/commerce-physical-memory`, based
on read-only connector `1a49e1c` (PR #61). Disabled by default. Migration 043 is
not applied to production; no real Shopify app/store acceptance is complete.
This is an additional FindEZ capability using the shared backend, not a separate
Shopify application or replacement for native inventory and personal Ask.

## Implemented workflow

1. A Team owner connects a configured pilot store through the milestone 1A web
   flow. The worker imports catalog variants and per-location commerce snapshots.
2. A member opens the web Team Memory tab or mobile Team physical-memory page.
   Find a variant by name, SKU or exact barcode. Select the correct candidate if
   several match; duplicate SKUs are not assumed to identify a unique product.
3. An authorized editor explicitly writes the name FindEZ should remember and
   confirms an existing Team Space and optional bin. A physical count is optional;
   blank means unknown and zero is a valid observation. This is an employee
   confirmation, not proof from an image or an automatic stock adjustment.
4. Ask a supported question such as "Where is the black medium hoodie?" or
   "Show products in bin 12." The shared API retrieves accessible records and
   returns location, confirmer, time and sources. Multiple candidates require
   clarification. Missing locations remain unknown. Confirmations at least seven
   days old are called out as old records, not current physical availability.
5. Reconfirm, add a location or explicitly remove a placement with history retained.
   View up to 100 recent confirmations for a placement still accessible to the Team.

This lookup uses a bounded name/SKU/barcode/location grammar and deterministic
database retrieval. It does not provide arbitrary reasoning across documents,
fulfillment or projects. JSON and streaming responses use the same authorized
read-only path and existing answer-context rendering. It never invokes the general
agent's mutable inventory tools or copies Team data into personal conversation history.

## Mapping and persistence

| Record | Meaning and reuse |
| --- | --- |
| `shopify_variants` / `shopify_inventory_levels` | Migration-042 commerce cache with stable connection/variant IDs and sync time. Not a native physical item or observed quantity. |
| `physical_memories` | Independently authored FindEZ name owned by an existing Team. Not copied automatically by a catalog sync. |
| `physical_commerce_links` | Explicit link from a memory to a connection/variant. Unique per connected variant; removed when commerce cache is purged. |
| `physical_placements` | Existing Space/bin references, optional observed count, active/removed state, confirmer/time and revision. Multiple locations are allowed. |
| `physical_observations` | Append-only confirmation/removal events, request ID/hash, revision and location labels at confirmation time. |

Existing Teams, memberships, Spaces, bins, actor identities, authentication and
answer presentation are reused. Native `items`, their quantities, manufacturer
catalog and FIND/Review contracts are unchanged. Shopify quantity snapshots and
employee counts are shown with their different origins and times.

Disconnect/uninstall deletes imported variant links and stock cache; independently
authored names and physical confirmations remain searchable by FindEZ name.
Removed catalog variants have no current stock snapshot and are identified as
removed. Reconnecting does not silently relink detached memories: reconciliation
of previous memories is a future explicit workflow. Team deletion cascades its
memory; account deletion preserves historical events with a deleted-actor label.
Detaching/deleting a Space or bin removes access to its placement/history rather
than treating an inaccessible destination as current evidence.

## Authorization and reliability

- Authenticated Team membership is checked before every endpoint. SQL RPCs enforce
  Team, Space and bin access again. Viewer roles cannot confirm; a Team role alone
  cannot grant edit access to a Space the employee cannot edit.
- Client and integration API-key access to these tables is denied. Backend-only
  RPCs operate through the established server authorization boundary. Service-role
  UPDATE/DELETE privileges on observations are revoked; parent deletion cascades
  still support authorized retention behavior.
- Saves use a UUID request ID and payload hash. Identical retries return the actual
  saved receipt; a reused request ID with a different change is rejected. Revisions
  reject concurrent stale edits. Database locks serialize placement changes and
  fence confirmation against connection disconnection.
- A barcode confirmation must exactly match an imported alias, preserving leading
  zeros. A saved external identifier is evidence of catalog association, not an
  automated visual match. Only explicit employee confirmations become locations.
- Web/mobile bind requests and result state to account and Team, invalidate late
  responses after switches, clear private views on access denial and refresh access
  options every 30 seconds. This does not erase information already legitimately
  viewed before access was revoked. Server authorization remains the enforcement.
- Visible API/conflict/retry errors preserve the draft. A receipt with an actual
  observation ID is required before reporting a successful confirmation. No write
  operation targets Shopify; there is no generic SQL or GraphQL mutation proxy.

## Isolated setup and acceptance

Follow `docs/shopify-development.md` to create the test app/store, private
configuration, separate backend/web/database and supervised connector worker.
Apply migration 043 after 042 in that disposable environment, then opt in with
`PHYSICAL_MEMORY_ENABLED=true`. Keep the flag off on production. Native clients
discover availability from the Team API instead of carrying Shopify credentials.

Acceptance must include:

- Import actual variants, including ambiguous/missing SKUs, barcode aliases,
  tracked/untracked stock and multiple commerce locations, without inserting native
  items or changing quantities. Complete the 1A live OAuth/sync/webhook checklist.
- Confirm a variant in two existing Team Spaces/bins and retrieve both records with
  confirmer, timestamps, optional count and distinct commerce snapshots. Test blank
  count and zero independently.
- Reject cross-Team/store/Space/bin access, viewer writes and changes after access
  revocation. Switch accounts/Teams during lookup and pending save on web/mobile.
- Retry the same save after a dropped response: exactly one observation. Race two
  revisions and confirm the losing change reports a conflict without partial rows.
- Ask by name, size alias, SKU and exact barcode; ask for contents of a Space/bin.
  Ambiguous variants require selection, unknown locations remain unknown, stale
  locations are flagged and unsupported/mutation requests do not execute.
- Remove a placement and verify its history and lack of an active location. Detach
  its Space, delete its bin and revoke access; inaccessible evidence is not returned.
- Disconnect/uninstall during confirmation: no orphan external links or false save
  success. Authored physical memory survives; purged SKU/barcode/stock cache does
  not remain searchable. Reconnect does not silently attach unrelated old memories.
- Actual web Light/Dark, narrow widths and native accessibility, keyboard, offline
  retry and account lifecycle acceptance, using test records only.

Automated checks cover these data boundaries with mocked Python transports,
disposable PostgreSQL, React and Flutter tests. They do not replace real Shopify
installation or mobile device acceptance. Before a production rollout, obtain
explicit authorization, reconcile live schema/deployed source, back up, apply
dependencies before runtime and record health/acceptance and rollback evidence.

## Merchant adoption and subsequent product work

The user wants businesses to migrate their existing operational context into
FindEZ so they can understand and plan their physical operation. The first slices
provide catalog import and trusted placement, not an end-to-end migration wizard.
The following source increment adds guided adoption: show actual import progress,
separate unmapped/confirmed variants, let employees work through storage locations
and demonstrate their first successful location lookup. Reuse the existing
connection, memory and Team APIs. Never infer that import completion means physical
mapping is complete or convert commerce stock into observed counts.
See `merchant-guided-migration.md` for its implemented boundaries and test gates.

After development-store acceptance, test with merchants and measure setup effort,
time to locate/pick a product, repeat employee use and willingness to pay. Use those
results to prioritize photo evidence/catalog matching and actionable attention
lists for unconfirmed or stale locations. Later planning must distinguish unknown
physical stock, Shopify snapshots and employee observations. Document linkage,
shipments, discrepancy resolution and forecasting remain future scope.
Owner-selected product/stock write source exists separately in
`shopify-owner-permissions.md`, with actual grants/mutations still unverified.
Existing published pricing is preserved; no arbitrary new tier limits
or revenue outcomes are promised.

Shopify's current Claude connector covers commerce management through chat;
[Shopify documents its supported actions](https://help.shopify.com/en/manual/ai-powered-tools/connecting-ai-tools/shopify-connector-for-claude).
Our recommended angle is persistent, evidenced physical memory and reliable
employee workflows. This recommendation is a product hypothesis, not proof of
competitive superiority or customer willingness to pay.
