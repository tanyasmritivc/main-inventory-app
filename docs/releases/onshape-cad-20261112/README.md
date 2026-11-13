# Onshape CAD Intelligence implementation candidate

Branch: `feat/onshape-cad-intelligence-20261112`.

Built the read-only Onshape OAuth connector, revision-pinned flattened BOM
adapter, automatic launch route, inventory selection, shared Fusion/CSV results,
shortages export, editable saved matches/rejections/reset, and CSV Name-column
preference. Direct action uses Onshape's documented Assembly context-menu action
and opens FindEZ in a new window. No CAD geometry, stock, mobile, or vendor-price
changes. No app publication, production migration, credential setup, or tester
messages have occurred.

See `integrations/findez-onshape/README.md` and `registration.json` for exact
operator and tester steps. The remaining activation gates are Onshape registration,
server-only credentials/key configuration, production approval of migration 086,
callback log redaction, deployment, and real-account/assembly acceptance.
Vendor catalogs remain a later phase; feed URLs and reuse/crawl permissions were
not verified, so no crawler was started.

## Validation

- Full backend: 1,247 passed, 206 existing deprecation warnings.
- Full web: 686 passed across 91 suites; no failures/skips.
- Focused CAD web: 30 passed. Focused Onshape backend: 26 passed.
- Changed-file ESLint: zero errors/warnings.
- Production Next.js build: passed with live public build settings. Initial local
  attempts needed font network access and the missing public build environment;
  both were resolved without changing repository configuration.
- Disposable PostgreSQL 17: candidate migration and its scoped permissions,
  wrong inventory/item rejection, viewer denial, updates/reset, refresh lease,
  actor-bound state replay, disconnect race and account-deletion checks passed.
- `git diff --check`: passed.

Synthetic schema/BOM tests do not prove live Onshape payload compatibility,
App Store installation, OAuth consent, or a robotics team's actual assembly.
Those are explicitly required before tester distribution.

## Baseline recovery

This checkout lacked the deployed CAD backend. Recovered CAD service and route
files from the existing Fusion worktree and verified their SHA-256 hashes against
the production server before edits. Restored its unchanged spreadsheet reader and
Fusion adapter/test baseline. One old import test still expected a vendor part
number to become purchase_source; aligned it with the verified live behavior,
which preserves that value in import_data instead. No production files were
modified during this recovery.

## Database compatibility

Read-only inspection of production confirmed `app_inventories.inventory_id` and
its actor-role function. Migration 086 references existing inventory/item/Auth
identities, adds three service-only tables and four service-only RPCs, and has no
ALTER on existing inventory/Space tables. There are no client RLS policies granting
credential access. FastAPI scopes reads and PostgreSQL rechecks save permissions.
Rollback before activation is simply leaving the candidate unapplied. After
activation, first disable CAD connection settings and restore the previous code;
do not delete credential/correction tables blindly.
