# Chat item actions (delivered, 2026-10-18)

User requested item creation and deletion through Chat after streaming/focus delivery.
Keep all prose model-written. Use model-selected, structured proposals with an
explicit review/confirmation card; no item write occurs during model inference.
Cards show exact names, quantities and destination Spaces or the frozen deletion
selection. Editors/Owners/Admins may confirm; Viewers and restricted users may not.

Store proposals in the existing private assistant message answer_context. A new
service-only SQL transaction (057, approved/applied) locks current inventory
authority and that message, verifies the actor, current role, frozen payload and
record snapshots, then commits item writes and an idempotent receipt together.
Retry never duplicates an addition or expands a deletion to new matching records.
A stale selection must be reviewed again. No inventory/Space/organization deletion.

Support text and photo instructions. Photo proposals use only server-retained
observations and photo references, retain crop + original in the item gallery,
and preserve private teammate access. Bulk attachment to existing items remains
a separate unsupported operation, not an excuse to create duplicate entries.

Required checks: role/scope/revocation and ownership; no writes before confirmation;
replayed confirmation, concurrent confirmation, stale/deleted/foreign item; limits;
partial failure rollback; private image references; model outages before/after a
receipt; streaming/fades, history, cancellation and both themes. Use disposable
fixtures and a network-isolated restored database. No customer QA writes.
Production database activation needs separate explicit approval under AGENTS.md.

Validation completed before publication:
- 1,032 Python tests plus 10 subtests; new proposal, receipt, actor, cache,
  capability, history-write and model-outage coverage.
- Composed disposable SQL replay, explicit Viewer/No access and stale/expired
  selection checks; skipped item/audit/message/original-photo writes roll back.
  Two real connections prove double-confirmation creates one item/audit and
  concurrent revocation blocks confirmation.
- Fresh network-isolated production restore: all original values across 87
  tables unchanged after replay; private bucket and service-only RPC retained.
- Configured production model, synthetic mocked data only: selected both proposal
  tools, produced model-written replies, and performed zero item writes.
- 361 branch web tests/types/lint. Preserved production-configured web compilation
  and types pass; Chat, streaming and inventory tests pass. Its full suite has
  18 unrelated failures across five existing signup/API-key/landing/legal/account
  deletion fixtures (including absent sibling fixture source); those runtime
  files are hash-preserved. No unrelated product code or expectations changed.

Compatibility: only clients declaring supports_item_actions receive proposal
features. Older clients retain existing model-written Capture/editor guidance.
A new review card is delivered only after its exact private message payload is
verified durable, including reconciliation of a lost insert response. Chat item
reads bypass earlier process caches. Cancellation and completed receipts remove
unneeded photo references; exact pending photo grants never authorize another actor.

Current status: the user approved "Apply 057 and publish build 91." Migration 057
is applied; API `65c90d4`/web `bee5088` are live with health/database 200 and invalid
Chat/anonymous-photo 401. Apple acknowledged signed production 1.0.8 (91), source
79b9abe, delivery c6cab1f6-1254-4395-87f7-9e449ad60d18. Final combined web 365/Flutter 651 tests,
analysis/types/lint and all five CI gates pass on each final source. The separate
compiled release-config gate passes. Existing 90 release artifacts are preserved.
Physical-device acceptance and TestFlight processing/availability remain unverified
and were not polled. Runtime-only rollback remains possible; do not remove the
transaction/privacy functions after receipts have been created. Backup/manifests/
receipts: /home/ubuntu/findez-chat-actions-release-20261018.

Legacy invalid quantities remain explicitly unknown on deletion cards, rather than blocking their review or turning them into zero. The disposable fixture confirms exact deletion of such a record.
