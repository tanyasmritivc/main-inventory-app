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
