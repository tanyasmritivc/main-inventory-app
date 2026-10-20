# Organization administration and item detail update

User-approved policy: organization Owners/Admins automatically access all child
resources, including restricted inventories. Organization deletion remains Owner
only. Ordinary workspace/inventory Viewers remain read-only; other effective
roles can edit items and rename accessible workspaces/inventories. No automatic
access to Personal or unrelated organizations. Ownership transfer still requires
explicit confirmation and retains a designated owner.

Mobile item rows open full information. Live fields edit inline; shared edits use
the shared endpoint, and pending writes are serialized. Imported source fields
remain an original snapshot, separate from current stock. Web expanded Space rows
now use the full detail view, preserving exact source column names, duplicates,
empty values and structured values. Vendor/supplier part identifiers are no longer
mislabelled as purchasing destinations; original values remain in imported details.

Tasks record assigned_by on actual assignment/reassignment; unrelated edits retain
it. Historical unknown attribution is labelled not recorded. Invitations show the
sender's current display name and saved photo. Old workspace codes without an issuer
record identify the Workspace owner rather than inventing a historical inviter.

Validation: 1,106 root Python tests plus 10 subtests; 467 web tests/58 suites;
final mobile CI passes, including session-restoration regressions and the single
inline description form for part-number items. Clean Flutter analysis/TypeScript,
light/dark inline renders, full-photo pinch/pan/reset/navigation, failed-write draft
preservation, and private-photo checks pass. Full PostgreSQL fixtures, migration
replay, permission-revocation/catalog races and duplicate Chat confirmation pass.
MCP tests, bundle comparison and smoke pass with lockfile-installed dependencies.

Final implementation CI is green for API a85e6ae (39362236523), web 370776a
(39360688924), and mobile efd7209 (39362121554). The staged runtime preserves
all unrelated live changes, including idempotent invitation delivery. Real Next.js
production build and nine route checks pass. The merged backend passes 1,064 tests
plus 10 subtests; two existing Chat fixtures also fail against unchanged live code.
Those unrelated behaviors were preserved.

A fresh network-isolated PostgreSQL 17 restore passed migration 068 twice. All
original values across 90 tables stayed unchanged; item-images remained private.
Prepared activation includes fresh backup, exact source hashes, bounded SQL locks,
health checks, and runtime rollback. Read-only deployment preflight passes.

Mobile 1.0.9 (96) from efd7209 is signed and preserved. All 31 archive and 31 export
device executables, strict signing, 24 privacy manifests and production HTTPS
configuration pass. IPA SHA256:
21e61075342402a3f7a8a47b9511f9924e48238fa7dd1ffca61649abf9b9a6a3.
Apple validation passed; upload and physical-device acceptance are pending.

Session restoration: production has no configured inactivity/timebox expiry. The
one-hour access token should refresh. The SDK update fixes stale/concurrent token
recovery; transient network failure retains the saved session and presents Retry.
Genuine revoked sessions still sign out. Historical logout causality is unconfirmed.

Release is not activated. Migration 068 requires explicit production approval per
AGENTS.md. No public App Store submission is authorized. Private staging/receipts:
/home/ubuntu/findez-organization-update-20261020. Local signed artifacts:
Documents/FindEZ/AppStore/1.0.9-build96. An earlier signed candidate is preserved in
initial-validated-candidate and must not be uploaded.
