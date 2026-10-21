# Chat polish and item management — build103 delivered

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

741 Flutter tests pass (one opt-in production-config check separately required),
analysis is clean. Backend:1236 tests and10 subtests pass. SQL fixtures exercise
migration replay, stale and unauthorized cards, movement, rule cycles, receipt
replay and stock accounting. A fresh isolated restore verified90 original tables
and all original values after applying074 twice; private image storage stayed
private. No founder-account or customer QA writes were made.

Synthetic configured-production-model probe: first text1.02s, total1.38s,
18chunks and a verified item link. This is one controlled text probe, not a
promise that photo/model/network latency disappears. Native iOS screenshot checks
cover both themes, header/composer clearance, attachment popup, avatar settings,
keyboard and large text. Physical device appearance/APNs/performance acceptance
remains pending; iPhone Mirroring reported the phone was in use.

Migration074 adds optional tracking columns, a service-only reorder-request table,
a stock-change trigger and reviewed-action RPCs. Existing customer fields are not
rewritten. At candidate review, production had not been migrated/deployed. Explicit
approval was required by AGENTS.md before074; it was subsequently received. Deployment must take a fresh backup,
verify runtime/schema drift, apply074 transactionally, then overlay only the three
runtime files with rollback and health/anonymous-access checks. No blind VM pull.

Build103 signed archive, production configuration, privacy/platform checks and
Apple validation must complete before upload. TestFlight upload is authorized by
standing instruction; stop at Apple's delivery acknowledgment, without polling
processing. Public submission is outside this task.

## Release candidate evidence — before approval on October21

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
At candidate review, migration074 was unapplied and the API unchanged. The prepared helper
`/tmp/findez-management-publish.py --apply-074` on the VM may run only after explicit
production migration approval. After activation, upload the already validated103
IPA; stop at Apple acknowledgment. No public App Store submission.

## October21 — Build103 uploaded; approved074 and API live

The user explicitly approved production074. The guarded activation applied it
transactionally after a fresh backup and published APIba8a2ce. Three runtime files
changed;101 unrelated Python files and existing database functions were preserved.
Health/database return200; anonymous World/private-photo access returns401. No
customer QA writes. Activation:2026-10-21T07:23:34Z.

Apple validated and acknowledged1.1.0(103), delivery`b5928b86-5154-4874-b1b7-db123c0e2220`.
Mobile source14285ce, notification parent6aae4a6; PR151/152/153 all pass five CI
gates.741 Flutter tests, enabled production-config check,20 native iOS cases,
1236 backend tests plus10subtests, and isolatedSQL/data-preservation rehearsal pass.
32+32 device executables,24 privacy manifests and signatures verified;13 previews
and signed artifacts preserved in Documents/FindEZ/AppStore/1.1.0-build103.
Processing/tester availability was not polled. Physical-device acceptance remains
pending. No public App Store submission. See docs/plans/chat-polish-item-management-20261021.md.

The final activation receipt is `api-activation.json`; Apple acknowledgment is
`apple-upload.json` in the preserved build103 directory. Production backup remains
on the server under `/home/ubuntu/findez-item-management-release-20261021/before-20261021T072331Z`.
No supplier purchase connection exists: reorder approvals never place purchases.
