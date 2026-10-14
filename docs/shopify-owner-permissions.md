# Owner-controlled Shopify access and reviewed edits

October 13, 2026. Development source increment on `feat/shopify-owner-permissions`,
based on `ef9489e` (PR #63). The user replaces permanently read-only access with
owner-selected, adjustable read/edit permissions and selects stock plus product
details for the first supported edits. No production migration/deployment,
merchant installation or actual Shopify grant/write has been performed.

## Owner experience

Connect read-only first. Team > People > Shopify > Connection permissions lets
the Team owner independently allow product details and stock adjustments, and
limit editing to the owner or delegate it to existing Team mentors/members.
Viewers remain read-only. Existing Team membership and role management controls
who can read the connected Team's records and lets the owner change that later.
No Shopify staff identity or permission is inferred from a FindEZ Team role.
The owner explicitly delegates actions using the app's offline store grant.

The owner can change settings later. Increasing edit access requires the needed
Shopify grant; changing a checkbox alone does not create it. Owner policy is
revisioned, so concurrent stale saves fail visibly. Pending edit reviews carry
that revision and are invalid after a policy change. A downgrade immediately
blocks future FindEZ dispatches. An already dispatched external request cannot
be recalled; its recorded outcome belongs to the policy under which it started.

The UI distinguishes saved FindEZ restrictions from actual Shopify grants.
It attempts optional-scope revocation and queries the returned grants. A network
failure, refused revocation or retained scope is shown as unconfirmed external
revocation, with retry and Shopify review. It never claims that Shopify removed a
grant solely because the local owner policy was saved.

## Supported edits

- Product details: title, vendor, product type and tags, through fixed
  `productUpdate`. An edit applies to the Shopify product and all of its variants;
  the UI says so before review. No publication/status, media, price, SKU, barcode,
  deletion or arbitrary metafield mutation is exposed in this increment.
- Stock: an explicit nonzero integer adjustment of Shopify `available` stock at an
  imported active stock location, through fixed `inventoryAdjustQuantities` and
  its required `@idempotent` directive. A recorded physical count does not become
  Shopify's available/on-hand quantity. The UI shows the live quantity at review,
  the requested delta and that concurrent commerce activity can change the total.

Both require a fresh review, an explicit Apply in Shopify confirmation, current
membership/owner policy, an actual live grant and a server-owned prepared operation.
Mutation targets come from the selected connection's imported stable variant IDs.
There is no client-supplied arbitrary GraphQL/SQL, generic mutation proxy or LLM
write tool. FIND, personal Ask and physical confirmation remain separate.

## Architecture and data integrity

Migration 044 adds independent owner edit flags, allowed editor roles, permission
revision and a bounded connection IO lease. Base reads remain products/inventory.
OAuth states bind the requested scopes and permission revision to the existing
owner/Team/browser/store flow; callbacks validate the returned capability set,
including implied read scopes, and reject stale policy revisions or unsupported
customer/order scopes. Refresh uses the actual known grant instead of assuming
every connection is read-only. New grants still require merchant approval.

The API uses fixed GraphQL 2026-10 operations. Each action queries actual scopes,
validates current targets and persists an immutable intent and live snapshot in
`shopify_operations`. IO leases serialize refresh and mutation dispatch against
worker pages/reconnection. They are not exposed through client table reads.
Service-only SQL RPCs independently check current roles, edit flags, scopes,
installation generation, review expiry and permission revision before dispatch.
Credential storage retains existing AES-GCM binding and server-only handling.

Product details are re-read immediately before dispatch. A changed `updatedAt`
rejects the old review. Shopify's product mutation has no atomic version condition
here, so an external change can still race between preflight and mutation. Only
explicit requested fields are sent; do not describe this as a transactional CAS
across FindEZ and Shopify. Confirm real-store behavior before extending fields.

Stock adjustments use the persisted operation UUID as Shopify's idempotency key.
Neither mutation is automatically replayed after dispatch. A duplicate completed
request returns the saved receipt; a sending/unknown operation cannot be resent.
Only verified mutation results with no user errors produce success. Partial,
missing or timed-out responses remain unknown. An unsuccessful local receipt
save after an external response requires checking Shopify, not a success claim.

Unknown writes pause new edits until the owner checks actual Shopify history and
explicitly acknowledges that check. The acknowledgment permits a new review but
leaves the previous outcome unknown. History includes the last 20 actions plus a
bounded unresolved list so an older uncertain action cannot be hidden by prepared
reviews. Operations retain actor, intent, evidence, permission revision and outcome;
the existing audit records prepare/dispatch/result/permission/recovery events.
Raw operation rows and mutating RPCs are denied to clients and API keys.

## Isolated setup and acceptance

Apply migration 044 after 042/043 on the separate test database before enabling
this source. `SHOPIFY_WRITES_ENABLED` defaults false. Opt in only in the isolated
development installation with owner-approved app scopes and test records.
`shopify.app.toml.example` declares base read scopes and optional product/inventory
writes. Verify its installation/distribution configuration with Shopify CLI and
the real app. A development app/store are now registered, but the initial app
version declares reads only and no live grant lifecycle is verified.

Current primary references:

- [Scope management](https://shopify.dev/docs/apps/build/authentication-authorization/manage-access-scopes):
  standalone authorization-code apps request new grants with an updated authorization
  URL; optional revocation requires supported dynamically granted optional scopes.
  Do not silently replace the pilot's authentication flow with an embedded app flow.
- [Product update](https://shopify.dev/docs/api/admin-graphql/2026-10/mutations/productUpdate).
- [Inventory adjustment](https://shopify.dev/docs/api/admin-graphql/2026-10/mutations/inventoryAdjustQuantities)
  and [required idempotency](https://shopify.dev/changelog/posts/making-idempotency-mandatory-for-inventory-adjustments-and-refund-mutations).

Before merchant acceptance, test actual read-only install, granting either/both
edit scopes, declining approval, required versus optional scope behavior, reducing
permissions/revocation, reconnecting and token refresh. Observe real callback and
scope-update webhooks; mocks do not validate grants. Test all four product fields,
product-wide versus variant behavior, tracked/untracked/inactive/multiple stock
locations and negative/positive adjustments. Verify actual receipts in Shopify,
duplicates, timeouts, stale product reviews, role/account changes and concurrent
permission changes. Pause new edits on uncertain outcomes and check owner-only
recovery without fabricated success. Verify deletion/uninstall/retention and backups.

Keep writes disabled until these real-store gates pass. Runtime rollback disables
new edits while preserving history and continuing read-only sync; saved write
preferences/grants remain distinct and must be reviewed rather than implied revoked.
Disconnect still purges imported commerce data and credentials while independent
FindEZ physical memories remain. Operations cascade on connection redaction;
their private contents require explicit retention/policy review before rollout.
This source work does not authorize a production migration or deployment.
