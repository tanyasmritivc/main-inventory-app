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

Validation so far: 1,106 root Python tests plus 10 subtests; 467 web tests/58 suites;
663 full Flutter tests (one separately enabled configuration test); 31 focused
final detail/task checks; clean Flutter analysis and TypeScript; changed-file ESLint
has no errors. Production-config gate passes. Full PostgreSQL fixture and migration
replay pass in a network-isolated disposable PostgreSQL 17 container. Real
permission revocation and duplicate Chat confirmation races pass. MCP tests,
committed bundle comparison and bundle smoke pass with lockfile-installed deps.

Release is not activated. Migration 062 requires explicit production approval per
AGENTS.md. Staging preserves current live source and invitation delivery idempotency.
Signed 1.0.9 (96), Apple acknowledgment, CI, staging production build, and physical
device acceptance remain pending. No public App Store submission is authorized.
