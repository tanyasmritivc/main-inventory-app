# Consistent resource permissions and private photographs

Prepared October 18, 2026. Not activated in production.

The supplied Roles and Permissions Specification is the target policy, copied to
permissions-specification.md. Workspace storage roles mentor/member retain their
existing values and display as Admin/Editor. Organization membership stays
separate from workspace membership and inventory content access.

## Implemented behavior

- Inherited inventories map Workspace Owner/Admin/Editor/Viewer to the same
  inventory role. The obsolete Viewer default cannot downgrade an Editor.
- Deliberate custom assignments, including No access, override inheritance and
  survive workspace role changes. Removing parent membership revokes access.
- Workspace Owner/Admin can administer restricted inventory metadata, access and
  deletion without seeing its contents. Explicit content grants require consent;
  stale invitation snapshots/revisions cannot replace a newer assignment.
- Inventory Editor can add, edit and delete items, save scans/imports and create/
  rename Spaces. Only content Owner/Admin can delete a Space.
- Workspace Owner alone renames/deletes a workspace, grants Workspace Admin and
  transfers ownership. Organization Owner alone renames/deletes an organization,
  grants Organization Admin and transfers ownership. Transfers require the exact
  current resource name and a current member; designated owners remain protected.
- Workspace Editor creates/edits tasks and uploads files; they delete only their
  own tasks/files. Viewer reads and can inspect photo/barcode scans without saving.
- JWT and API-key requests check current account status. SQL, backend and client
  action guards enforce current parent membership and effective inventory role.
  Clients retire stale selections/drafts and revalidate on foreground/focus/15s.
- Mobile main-page headers expose the user's own profile at the top right. The
  web shared topbar retains its account menu. Customer Dashboard content/layout
  is preserved; no Founder Dashboard is part of this work.

## Private photos

The user explicitly requested that team members see photographs normally but
knowledge of a URL alone grant nothing. First-party item images now use an
ordinary authenticated HTTP request, never a new bearer signed URL. Web images
use a same-origin session-cookie proxy; mobile uses the current JWT in a header
sent only to the configured application API. External product images remain
external and never receive the user's credentials. Account/token changes retire
mobile image requests; account-specific web URLs prevent cross-account reuse.

Migration 055 preserves object paths and stored image locators. A service-only
lookup checks current item/event, pending Review, own Ask-source or temporary
uploader-preview access. Saving consumes preview authorization; deleting the
source record revokes its image authorization. Empty-inventory/account deletion
also queues temporary photo files in the existing durable cleanup process.
Existing personal accepted Shared Space access is retained without bypassing
restricted inventory content rules. Unsafe paths and unauthorized references fail
closed. Image responses are private/no-store and contain no redirect or token URL.

The item-images bucket becomes private and direct anon/authenticated Storage
access is denied. A separate Kong expression route denies old public and signed
object/render URLs, including encoded bucket paths. Merely setting public=false
would leave previously issued signed URLs usable, so both layers are necessary.
The reviewed candidate leaves the service's authenticated Storage SDK route intact.

## Verification completed

- Full backend: 901 tests and 10 subtests pass.
- Full web: 344 tests / 46 suites pass; TypeScript passes; lint has 0 errors and
  54 existing warnings; real production webpack build passes.
- Full Flutter: 623 tests with coverage pass; static analysis has no issues.
  Role/profile/ownership checks include Light and Dark. Synthetic directory
  captures exercise both themes; this is not physical-device acceptance.
- Composed PostgreSQL fixture replays migrations 054 and 055 twice; inherited/
  custom/No access matrix, direct JWT/API-key access, suspension, parent removal,
  owner retention, ownership confirmation, stale invitations, consent, Space
  deletion, legacy sharing and private photo lifecycle checks pass.
- Two real concurrent revocations pass with positive controls: a stale Admin
  cannot change another member or rename an inventory after revocation. The
  fixture runs only in an empty disposable database, including in CI.
- Fresh private production restore, network disabled: both migrations replay;
  original record values across 86 public/auth/storage tables remain unchanged
  except intended permission metadata and the bucket visibility flag. Storage
  objects are preserved. No live customer role/invitation/data writes used for QA.
- Kong 3.9.3 expressions parser and 7 isolated HTTP privacy tests pass, including
  old signed, public, render, encoded-bucket and bucket-root paths. Live gateway
  remains unchanged. Its before/candidate hashes and private receipts are kept
  in /home/ubuntu/findez-permission-release-20261018.

## Activation and compatibility

Migration 054 and 055 and the gateway activation require the explicit reviewed
production-database authorization in AGENTS.md. They have not been applied.
Prepare a fresh backup, verify reviewed source hashes, apply migrations in order,
then publish only changed backend files and an isolated web release; preserve the
VM's unrelated dirty source. Verify unauthenticated image requests return 401,
old Storage links return 404, and existing health/auth routes remain available.
No real invitation or permission changes are allowed merely for smoke testing.

The matching signed mobile build is 1.0.8 (84), production main target and normal
production configuration. Old mobile versions request public Storage links and
will need this update to display private photos. Coordinate privacy activation
with that compatibility requirement. TestFlight upload is already authorized;
stop Apple work at upload acknowledgment, without processing/group polling.
Public App Store submission remains held. Device acceptance, actual customer
cross-client role changes and native camera/auth/push remain manual checks;
automated fixtures must not be described as those checks.

API lane: fix/api-workspace-editor-20261017 (base 8c0c0f7).
Web lane: fix/web-workspace-editor-20261017 (base 406e36b).
Mobile lane: fix/mobile-workspace-editor-profile-20261017 (base e9c3e27).
