# Fusion CAD comparison prototype

Date: 2026-11-10. Branch: `feat/fusion-cad-prototype`, based on the Phase 0
documentation commit `0eeac588`. Status: the read-only preview is deployed;
see [the production receipt](PRODUCTION_RELEASE.md) for the current live overlay,
verification and rollback. This is an initial vertical slice, not the complete roadmap.

The user declined to provide a private assembly or target inventory. Respect that
decision: automated and visual checks use synthetic designs/stock only. No
customer inventory queries or private CAD documents were used for this prototype.
The later "logged in" message belonged to another chat and did not authorize
accessing an account. Native Fusion was not available in the inspected app list.

## Delivered behavior

- Installable Python Fusion add-in with a Design/Utilities export command. Export
  is local and opt-in; no network client, credential input or geometry upload.
- Recursive contextual occurrence traversal with file/version/configuration-scoped
  definitions, suppression/visibility handling, explicit procurement policies,
  dirty revision labels and incomplete-reference warnings.
- Versioned, bounded snapshot validation. The backend derives requirements from
  occurrences rather than accepting client-supplied requirement totals.
- Stateless `POST /inventories/{inventory_id}/cad/compare`, using the existing
  Supabase user JWT and `_inventory` authorization before and after fresh reads.
  Every stock/reservation/checkout query has an explicit inventory filter.
  Inventory-wide comparison refuses a mismatched actor/inventory or Space-chat
  context. Viewer roles can compare without gaining mutation permissions.
- Exact barcode or manufacturer/part-number matching with conflict rejection;
  default part numbers/name-only candidates require review. Recorded stock is
  reduced by existing reservations and active checkouts. One unit cannot be
  assigned to multiple requirements. No AI call or database mutation occurs.
- `/cad` web page with normal sign-in, inventory context, explicit upload consent,
  evidence, incomplete-state warnings, coverage/shortage summaries, filters,
  100-row display pagination and spreadsheet-safe CSV export.
- Sidebar entry, protected-route and theme registrations; deterministic download
  at `frontend/public/downloads/findez-fusion-preview.zip`.

The CAD page verifies the server session before rendering the client inventory
boundary. This prevents the anonymous inventory-loading state from hiding the
sign-in redirect. It reuses the existing boundary and shell without altering the
authentication or navigation behavior of other product pages.

Source and installation guide: `integrations/findez-fusion/README.md`.
Package generator: `python scripts/package_fusion.py`.

## Verified locally

- Backend full suite: **1,667 passed**, including **42 CAD tests**.
- Web full suite: **334 passed** across 48 suites.
- Changed CAD web files pass ESLint. Release-mode Next.js webpack build and its
  TypeScript check pass with placeholder service configuration.
- Headless Chrome, isolated synthetic component harness: light/dark at 1280 and
  390 px; no page-level horizontal overflow or runtime errors; no upload before
  explicit Compare; result/evidence rendering; correct shortage CSV download.
  The result table intentionally scrolls horizontally at narrow widths and has
  a labeled keyboard-focusable scroll region.
- Real local `/cad` anonymous navigation redirects to sign-in while retaining
  the inventory destination. ZIP endpoint returns the package successfully.
- Native Python syntax and manifest parse; package bytes match the four reviewed
  source files. The package parity assertion runs in the backend test suite.
- Synthetic adapter/validator/comparison benchmarks for 100, 1,000 and 10,000
  repeated occurrences produced exact counts and a one-unit shortage. Observed
  pure-Python times were approximately 0.002s, 0.004s and 0.033s on this computer.
  These exclude Fusion API calls, network and database access; they are not
  product latency claims.

Visual QA found and corrected dark-theme text tokens. Browser QA found and
corrected the CAD route's redirect placement. The temporary synthetic QA route
and in-memory session stub were deleted before delivery; neither ships in the
application. No real credentials were used. Screenshots were visually inspected.

Initial build failed because sandbox DNS blocked existing Google Fonts fetches;
the permitted network build succeeded. After the temporary QA route was removed,
stale generated development types were moved outside the worktree before the
final production build. No application type checking was disabled.

## Deliberate limits and next gates

- Native Fusion install/command behavior, configurations, suppression, external
  references and counts still require private Windows/macOS host acceptance.
  Synthetic protocol fakes do not prove Autodesk runtime behavior. The included
  guide lets the user validate privately without sharing the design with us.
- No desktop-to-FindEZ automatic login or direct panel upload yet. Export/import
  is the working preview bridge; browser sign-in remains the existing auth flow.
- No persistent CAD projects, snapshots/history, allocations, consumption,
  alternatives, geometry, Onshape or Assist tools are activated.
- The prototype uses a bounded subset of the proposed schema: component identity,
  hierarchy, source state and whole occurrence units. Detailed dimensions/material
  specifications and unit conversion remain future work. Do not claim engineering
  compatibility from this identity comparison.
- Source documents are client exports, not provider-attested records. Responses
  include a canonical snapshot hash, source-verification label and inventory
  fingerprint for traceability, but these do not authenticate a CAD design.
- Stock reads span multiple requests. Results explicitly report nontransactional
  preview consistency and unverified recorded quantities. Recheck before use;
  never treat this preview as a reservation or physical verification.
- At most 5 MiB JSON, 20,000 occurrences, 5,000 definitions, depth 64 and 50,000
  records per stock table. More than 100 candidate stock records for one line
  produces an explicit review warning, not truncated automatic coverage.
- Future rollouts must reconcile current production source overlays rather than
  deploy this older branch wholesale. The subsequent user-authorized preview
  rollout is documented in `PRODUCTION_RELEASE.md`; no production SQL, mobile
  binary, CAD account registration or private-data migration was needed.

The full implementation plan and unapplied schema remain in the Phase 0 document.
Stock writes still require the shared all-writer locking and transactional tests
specified there. Do not enable them merely because the comparison tests pass.
