## October 21 — Workspace writes, capture imports and 30-day notifications

Lane: fix/api-workspace-capture-notifications-20261021. Production logs identify
AccessQuery.headers delegation as the task/part-request/checklist write failure.
An explicit forwarding property preserves authenticated write headers. Synthetic
create/update tests cover all three board kinds and notification dispatch.

World-scoped spreadsheet and barcode routes create private chat drafts without a
required destination. Imports preserve original columns, accept up to 10,000 rows,
and save in resumable 200-item batches with stable IDs. Revision/status/checkpoint
CAS filters avoid oversized URLs. Unknown barcodes retain Review uncertainty.
Notification feed and unread badge cover 30 days; verified recipients can still see
accepted/expired invitations without invitation codes. Streaming acknowledges a
validated request before model generation.

Validation: 1,273 Python tests plus 10 subtests passed. Staged production-model
probe with synthetic data passed; API imports and APNs credential signing passed.
No notifications sent and no customer QA writes. No schema changes. Candidate
preserves the existing deployed invitation retry hooks from 305e3e0. Activation
is pending guarded file replacement, health/access checks and rollback backup.
Physical push receipt remains unverified.

Mobile delivery is a separate PR/build105. Backend activation must preserve all
unrelated live Python sources and previously deployed invitation hooks. Public
App Store submission and database changes are outside this runtime-only release.

## October 21 — Runtime activation receipt

API1f31f97 / PR157 activated at2026-10-22T00:44:17Z. All five CI gates passed.
Nine guarded runtime replacements;96 unrelated Python sources preserved.
Health and database health200; anonymous private access401. No migration and no
customer QA writes. Rollback files and activation receipt remain in the private
server candidate directory. APNs signing is verified; physical delivery remains
unverified. Mobile105 is separately packaged in PR158.

