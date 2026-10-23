# Organization leave and explicit removal choices — October 19, 2026

## Requested scope

Add Leave organization; let Owners/Admins remove members while protecting the
organization Owner. Replace empty-first deletion with explicit keep/move or
cascade-delete choices on web and mobile. Remove only the repeated headings
inside expanded web item rows. Dashboard and unrelated product flows stay intact.
The user explicitly excludes their founder account from testing. All lifecycle
QA uses generated example.invalid identities in isolated databases.

## Behavior

- Organization members/Admins can leave with a named confirmation. The designated
  organization Owner must transfer ownership first. Owned workspaces must also
  have a successor before voluntarily leaving; content is never silently erased.
- Owner/Admin member removal revokes organization, workspace, inventory and legacy
  Space assignments together. If a removed member owns an organization workspace,
  its ownership moves to the designated organization Owner; shared content stays.
  Admins cannot remove the organization Owner. Workspace Admins can remove peer
  Admins but cannot remove the workspace Owner or promote themselves to Owner.
- Organization deletion remains Owner-only. Keep moves its workspaces outside the
  organization and preserves direct workspace memberships; Delete removes its
  descendants. No manual empty-workspace prerequisite.
- Workspace Owner/Admin can keep inventories in each existing owner's Personal
  area, or delete all contents. Workspace tasks, files and memberships disappear
  with the workspace; inventory sharing is revoked when moving to Personal.
- Inventory Owner/Admin can move the whole inventory to an authorized workspace
  with the same existing owner, or to the existing owner's Personal area. IDs,
  items, Spaces, photos and original ownership stay intact. Old custom grants,
  invitations and legacy shares are removed; destination permissions apply.
  Delete uses the existing atomic content deletion and durable file cleanup.
- Space Owner/Admin can move items/bins/pending reviews to another Space in the
  same inventory when one exists, or delete the Space and its contents together.
- Neither action is preselected. Preview shows counts; typed current name and an
  explicit choice are required. Backend rechecks current authority and destination.
  Cancel performs no write; bad receipts/errors keep the confirmation open.
- Expanded web rows retain their existing fields and inline editing, with no
  repeated item headings. Standalone item details retain their heading.

## Validation

Python: 1,144 tests plus 10 subtests pass. Web: 474 tests / 59 suites pass, clean
TypeScript and scoped ESLint. Mobile: 693 tests pass with coverage; the one compiled-config gate is separately
enabled and passes; analysis is clean. Both-theme small-phone tests with 2x text and
keyboard found a dialog reachability issue; scrolling now includes the title,
and all 23 focused confirmation cases pass.

A complete HTTP-to-real-PostgreSQL journey passed 15 requests using four generated
identities: preview/cancel, stale name, Viewer denial, protected Owner, Space move,
retry, voluntary leave, member removal, permission change after preview, workspace
preservation, content deletion and replay. Authentication is overridden for these
synthetic identities and storage is mocked because no real objects are created.
This is not a physical-device or live identity-provider test.

Disposable SQL covers migration replay, every resource's keep/delete semantics,
ID/content preservation, membership revocation, Admin protections, destination
validation and service-only execution. A fresh private production restore applied
069/070 twice: all original values in 90 tables unchanged; item images remain
private. No customer QA writes. The staged actual web runtime builds using webpack,
preserving unrelated live overlays. No production migration has been applied.

Reproduce the HTTP journey only against the prepared disposable fixture:
`FINDEZ_DISPOSABLE_SQL_TESTS=1 FINDEZ_SQL_TEST_CONTAINER=findez-leave-test-20261020
python backend/tests/sql/resource_removal_journey.py` (single command). Optional
`FINDEZ_SQL_TEST_HOST=findez` uses the isolated container on the test host.

## Release boundary

069/070 require explicit production approval under AGENTS.md. Build 97 is the
matching client. Do not publish dependent runtime/client code before migrations.
Stage/restore/build evidence: `/home/ubuntu/findez-org-leave-20261020`.
Native artifacts: `Documents/FindEZ/AppStore/1.0.9-build97`.
Production deployment, TestFlight acknowledgment, availability and device
acceptance must be reported separately; public App Store submission is not included.

## Final candidate receipt

All five CI gates pass in API run 39369751891, web run 39369763939 and mobile run
39369776231. Runtime commits: API 5a86c39, web 61f742e, mobile 397490d. Draft PRs
138/139/140 are stacked on the prior released lanes. The full fresh SQL suite
also passes. The temporary test containers were removed after saving evidence.

Signed production 1.0.9 (97) is Apple-validated, with 31 archive and 31 exported
iOS executables verified, strict signing, 24 privacy manifests and the production
HTTPS/anonymous configuration checked. Archive and IPA are preserved. IPA SHA256:
`80a237b2e0c742c9992758b64ce5b3940209234ba8114b006dea87b6b6203e89`.

Release preflight confirms exactly two API runtime files and ten web files change;
unrelated live runtime, environment, dependencies and configuration are preserved.
Activation script defaults to read-only preflight. Migrations 069/070 remain
pending explicit approval, runtime is not activated, and build 97 is not uploaded.
No founder-account testing or customer test writes were performed.

## Approved activation and Apple upload

User requested “build on testflight” after the combined migration/publication
approval request. Migrations 069/070 applied together atomically after a fresh
private backup. The matching two-file API overlay and ten-file web release are
live; API/database/web health passes and unauthenticated resource/private-photo
access returns 401. No customer QA writes or existing-content rewrite.

Apple acknowledged production 1.0.9 (97), delivery `f7f277d6-3bda-4182-a4cd-1d27c3dc21d4`.
The signed IPA/archive and acknowledgment are preserved in
`Documents/FindEZ/AppStore/1.0.9-build97`. TestFlight processing and tester
availability have not been polled; physical-device acceptance remains pending.
Public App Store submission was not performed. This receipt supersedes earlier
candidate/pending notes above. The founder account was not used for testing.
