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


Follow-up requests in this release: item photos open a full-screen authenticated
viewer with contain sizing, pinch zoom/pan, Reset, photo navigation and Close.
Both themes pass real gesture tests and inline-field render inspection.

Session restoration: no inactivity timeout is configured in the auth service;
access tokens expire after one hour and should refresh. Supabase Flutter is now
pinned to 2.16.0 (GoTrue 2.26.0), which includes stale startup recovery and refresh
race fixes missing from 2.12.1/2.19.0. Auth stream network errors retain the saved
session and show a bounded Retry path. Four SDK regression tests cover persisted
expiry, stale token reuse, concurrent account change and genuine revocation; the
startup widget test covers offline Retry without showing sign-in. The precise
cause of the user's historical logout is not proven; device acceptance remains.
The new SDK uses the renamed publishableKey argument with the same existing anon
key; no provider, account or server session policy is changed.

Final mobile validation: 661 tests passed in the full run; one file was edited
while the run was collecting it and had a test-only constructor error. After
correction all eight tests in that file pass (669 total), and analysis is clean.
CI will run the complete final source. Web and API review PRs are 136 and 135.
Staged real web build passes. Two staged Chat fixture failures also reproduce
against unchanged live code; no Chat behavior was changed to hide them.
