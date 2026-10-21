# Chat polish and item management — build103 prepared

## User-visible changes

- Native notification authorization on the first active frame, only when iOS has
  not recorded a decision. Existing denial/approval remains respected.
- True black dark pages and neutral gray panels; compact glass composer, regular
  placeholder typography and anchored attachment menu. Chat header has its own
  layout space, fixing content clipping and rectangular blur over messages.
- Navigation focus slides with a finite subtle pulse; reduced motion disables it.
- Former Small becomes Default (.9), with a new .8 Small and unchanged larger
  options. Legacy Small remains the same physical size; OS scaling still applies.
- Idle placeholder cycles short prompt ideas, stopping for focus/drafts/voice,
  inactive lifecycle, offscreen tabs and reduced motion.
- Avatar exposes preferences directly. Spaces/More headings move to the top and
  organization selection remains on Ask only, in its established position.
- Space Projects banner becomes equally sized Review images / Low quantity
  actions. Review is scoped to that Space; low quantity toggles its item filter.
  Projects remain reachable through existing overflow and More navigation.
- Streaming presents incoming chunks promptly with existing fades; photo matching
  runs concurrently with identification. Item/Space links are derived from fresh
  authorized results and reauthorized when opened, never arbitrary model URLs.

## Chat management and safety

Chat can propose saved item details/quantities, moves to an exact existing Space,
unit price plus ISO currency, expiry dates and explicit reorder thresholds and
quantities. Prices allow four decimals; missing or ambiguous values are requested.
Every change shows exact details and requires confirmation. Only server-owned
private conversation cards can execute; confirmations lock authority and item
rows, recheck full snapshots and reject expired/stale/cross-world proposals.
Receipts replay without repeating writes, and history/audit records are retained.

Automatic reordering means approval requests, as explicitly chosen by the user.
One open request exists per item. A new low-stock cycle creates a request; approval
never purchases or changes quantity. A separately confirmed Received action adds
stock exactly once. Dismissal does not immediately recreate the same request.
Moves preserve item IDs, photos, linked documents/history/checkout/review records
and relocate requests, clearing obsolete bin assignments. Active project
allocations must be released before a move. Legacy unknown quantities stay unknown
when unrelated details change. No external supplier/purchasing integration exists.
Older mobile clients omit supports_item_management and receive only compatible
tools, with update guidance for advanced requests.

## Verification and release boundaries

741 Flutter tests pass (one opt-in check skipped in the full run; production configuration passed separately),
analysis is clean. Backend:1236 tests and10 subtests pass. SQL fixtures exercise
migration replay, stale and unauthorized cards, movement, rule cycles, receipt
replay and stock accounting. A fresh isolated restore verified90 original tables
and all original values after applying074 twice; private image storage stayed
private. No founder-account or customer QA writes were made.

Synthetic configured-production-model probe: first text1.02s, total1.38s,
18chunks and a verified item link. This is one controlled text probe, not a
promise that photo/model/network latency disappears. All20 native iOS checks pass;13 previews are preserved and reviewed. Checks
cover both themes, header/composer clearance, attachment popup, avatar settings,
keyboard and large text. Physical device appearance/APNs/performance acceptance
remains pending; iPhone Mirroring reported the phone was in use.

Migration074 adds optional tracking columns, a service-only reorder-request table,
a stock-change trigger and reviewed-action RPCs. Existing customer fields are not
rewritten. Production has NOT been migrated/deployed for this lane. Explicit
approval is required by AGENTS.md before074. Deployment must take a fresh backup,
verify runtime/schema drift, apply074 transactionally, then overlay only the three
runtime files with rollback and health/anonymous-access checks. No blind VM pull.

Build103 signed archive, production configuration, privacy/platform checks and
Apple validation must complete before upload. TestFlight upload is authorized by
standing instruction; stop at Apple's delivery acknowledgment, without polling
processing. Public submission is outside this task.

## Final release candidate evidence — October21

All five CI gates pass for PR151 (run39560259836), PR152
(run39560323927) and PR153 (run39560615850), including PostgreSQL, backend,
Flutter, web and connectors; Vercel previews pass. Runtime sources are14285ce
(mobile) andba8a2ce (API), with notification parent6aae4a6.

Signed1.1.0(103) archive/export and strict signing pass;32 archive plus32 exported
iOS executables,24 privacy manifests and production configuration are verified.
Apple validation passes. IPA SHA256:
`f06263705d9976bdd4162ab792a5310430f2a1c10bdf77a27362324491483cb1`.
Artifacts and13 native previews are preserved in
`Documents/FindEZ/AppStore/1.1.0-build103`.20 native cases pass.

Guarded deployment preflight passes for exactly three runtime files. The fresh
backup/replay rehearsal verifies90 original tables with original values unchanged.
Migration074 remains unapplied and the API remains unchanged. The prepared helper
`/tmp/findez-management-publish.py --apply-074` on the VM may run only after explicit
production migration approval. After activation, upload the already validated103
IPA; stop at Apple acknowledgment. No public App Store submission.
