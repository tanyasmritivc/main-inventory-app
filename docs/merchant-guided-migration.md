# Guided merchant setup

Source lane `feat/merchant-guided-migration`, stacked on owner-permission source
`a58e84e` (draft PR #64). This is an additional Shopify feature within existing
FindEZ Teams. It does not replace personal inventory, Capture, FIND, Ask or pricing.
No Shopify development app/store exists yet; no live merchant or production
installation is claimed.

## Implemented behavior

The existing Team > People Shopify panel includes a compact stockroom setup guide
when the connector, physical-memory and merchant-guide capabilities are enabled.
Connection and sync controls still use the existing connector. The guide reports
four distinct tasks: connect, import the catalog, confirm storage, and try a saved
location lookup. Lookup readiness is not proof that an employee found or picked
an item, and no automatic finding or physical availability is claimed.

Migration 045 adds one service-only read function, not another catalog, progress
table or inventory representation. Each report checks current membership and the
connection's Team. Progress is derived from existing nondeleted Shopify variants,
physical commerce links, independent physical memories and active placements in
Spaces still linked to the Team. Deleted, moved or inaccessible bins do not become
guessed Space-only locations. Multiple placements count a variant once. Any
accessible placement at least seven days old flags that variant for rechecking.
Counts of mapped variants are not counts of physical units.

An import is complete only after a successful full sync for the current installation.
Cached records from a partial or earlier installation cannot mark a new import
complete. The guide shows partial-sync context, a bounded first-five unconfirmed
variant queue, and one actually confirmed example for a first lookup. Connection
renewal and sync-in-progress labels come from the fresh report, even when the
surrounding panel's earlier status has not refreshed yet. Stable
connection/variant IDs distinguish variants even when SKUs are repeated or absent.
An empty completed catalog differs from a catalog still awaiting import.

Selecting a queue entry opens the existing Team physical-memory lookup and
confirmation form. A cleaned, bounded catalog-derived name is suggested, omitting
Shopify's "Default Title" placeholder. The employee reviews or changes it, selects
an existing Team Space and optional bin, optionally records an observed count, and
explicitly confirms. Nothing is auto-saved. Existing native names stay unchanged.
Original revisions, retry identity, server-side authorization and independent
confirmation history remain in force. This flow never changes Shopify stock.
Owner-selected Shopify edits remain separate reviewed actions.

Viewers can see progress and retrieve a confirmed example but cannot start
confirmation. A connection requiring renewal keeps cached progress labeled and
prevents mapping. If an editor has no linked storage, the guide opens the existing
Space creation/linking flow. Reports refresh on focus and every 30 seconds while
visible, plus explicit refresh. Failed or revoked reads clear displayed records;
Team/account/store changes remount scoped state and discard late responses. The
selected lookup is also bound to the current Team and account in its parent.

## Development setup and acceptance

`MERCHANT_MIGRATION_ENABLED` defaults false, as do the existing feature flags.
Apply migrations 042 through 045 in order on the isolated test database, configure
the existing development connector and worker, then opt into Shopify, physical
memory and merchant setup there. Shopify writes need their separate flag and real
approved scopes; guided setup works without writes. Disabling the new guide leaves
the existing connection, Memory tab and stored confirmations intact.

Automated checks cover route gates/actor binding, real PostgreSQL aggregation and
isolation, incomplete imports, repeated SKUs, multiple placements, deletion,
detachment, old confirmations, viewers, revoked reads, stable ID navigation,
Team/account changes and reviewed names without automatic saves. Full backend,
web, TypeScript and changed-file lint run locally. CI also runs a production web
build, PostgreSQL 17 fixtures, AI connector tests and existing mobile checks.
Sample-only visual checks are separate from live-store acceptance.

Before enabling this for merchants:

1. Complete actual OAuth, catalog, refresh, webhook, failure, retention and owner
   permission acceptance in `shopify-development.md`, `physical-memory.md` and
   `shopify-owner-permissions.md` using a real development app/store.
2. Watch a partial import become complete; reconnect and verify an old sync cannot
   complete the new import. Test an empty catalog and deleted variants.
3. Map two variants with repeated SKUs and a variant in multiple bins. Verify the
   next queue and totals reflect saved confirmations after returning to the guide.
   Verify missing bin, detached Space and stale confirmation behavior.
4. Retrieve the confirmed location from another authorized employee account;
   preserve source, confirmation time, optional physical count and distinct Shopify
   quantities. Test viewers, access revocation and late responses on Team/account
   changes. Check Light/Dark, narrow layouts and keyboard use with real records.
5. Test a small merchant pilot: measure setup effort, finding/picking time before
   and after, repeat employee use and willingness to pay. The source guide does
   not collect these business metrics or assume commercial success.

Explicit authorization, live schema/source reconciliation, backups and dependency
migrations remain required for production deployment. No production schema or
runtime is changed by this lane.

## Next task and limits

The next useful step is configuring the isolated Shopify development app/store
and completing the real end-to-end acceptance above, before adding more features.
One server-configured pilot store is still the connector's scope; public app
distribution, bulk enterprise adoption and costs require separate decisions.
The aggregate report scans current catalog/mapping data; measure query cost and
polling load at the intended merchant scale before expanding beyond the pilot.

Automatic photo-to-catalog matching, richer evidence, shipment workflows,
discrepancy investigation, operational planning and forecasting remain unbuilt.
The guide is a first adoption flow for catalog and storage context, not an
end-to-end business migration wizard. Use pilot evidence to choose the next
increment; preserve the physical-memory angle and existing published pricing.
