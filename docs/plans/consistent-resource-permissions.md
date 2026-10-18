# Consistent resource permissions and private photographs

Activated October 18, 2026 after the user's explicit approval to apply 054/055
and publish. Backend, web, private storage and gateway rules are live. Mobile
build 85 contains the legacy-photo and standalone Account follow-ups; its final
Apple delivery receipt is recorded in the shared agent state.

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
- The standalone mobile account destination uses an opaque, safe-area-aware
  Scaffold/AppBar and the existing compact Profile hub. Profile editing and
  Settings open separately, preserving back navigation and account binding. The
  legacy transparent combined body is no longer pushed over the caller's page.

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
  Role/profile/ownership checks include Light and Dark. The latest 25 focused
  cases cover profile opacity, safe-area geometry, back navigation, actual
  private Image widgets, legacy URLs and Review. Synthetic captures exercise
  both themes; some test-font rendering remains synthetic. This is not simulator
  or physical-device acceptance of this release.
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
- Kong 3.9.3 and 7 isolated HTTP privacy tests pass, including old signed, public,
  render, encoded-bucket and bucket-root paths. The probe now exercises the real
  self-hosted entrypoint and environment on an internal Docker network, without
  publishing ports or exposing configuration. The first template serialization
  missed entrypoint substitution and briefly prevented gateway startup; the
  original template was restored, then a fragment-only insertion was verified
  and activated. Preserve all original template bytes outside the added service.
  Private receipts remain in /home/ubuntu/findez-permission-release-20261018.
- A real existing-photo compatibility issue was corrected: stored locators use
  //storage after the hostname. SQL, web and mobile accept these trusted-origin
  locators; both immutable-parser expression indexes were rebuilt. All 16 existing
  photos are recognized, with 28 authorized member/photo pairs and 0 lookup
  failures. An authorized backend RPC plus the actual Storage SDK downloads and
  validates image bytes. No stored locator, image or customer record was rewritten.
- Live health/database/auth routes pass; anonymous app photo requests return 401,
  and all 16 actual old public links plus old signed/render paths return 404.
  The item-images bucket is private. No customer invitation or membership writes
  were used for QA. Automatic CI is green on API b0c04e3 (39115338261), web eccccc1
  (39115340558), and mobile 9cec0bc (39115340763).

## Activation and compatibility

The user approved "Apply 054/055 and publish the fixes." Both migrations were
applied in one outer transaction after a fresh private backup. Only reviewed
backend files were overlaid; 79 unrelated Python files and 242 unrelated web
source files were preserved. Backend runtime is 1c2280c; schema/tool follow-up is
b0c04e3. Final web eccccc1 runs from
/home/ubuntu/findez-web-releases/permissions-url-compat-20261018/frontend.
The double-slash parser correction was applied transactionally after a separate
fresh backup, together with REINDEX of permission_item_image_path and
permission_event_image_path. Migration 055 includes the correction for replay.
The final gateway source SHA-256 is
0c5b76c0d535b81f20d22b23d7ae5b65d4e0f1146222e8e1b2bd118fcd5c26d1.
Backups, manifests and activation/compatibility/live/storage receipts are private
under /home/ubuntu/findez-permission-release-20261018. Do not rerun activation
scripts or alter real invitations merely for smoke tests.

The matching signed mobile build is 1.0.8 (85), runtime 9cec0bc, production main
target and normal production configuration. Build 84 was uploaded and acknowledged
but is superseded: it did not parse the real //storage locators and used the
transparent legacy profile body directly. Old mobile versions request public
Storage links and need build 85 to display private photos and crops. Stop Apple
work at upload acknowledgment, without processing/group polling.
Public App Store submission remains held. Device acceptance, actual customer
cross-client role changes and native camera/auth/push remain manual checks;
automated fixtures must not be described as those checks.

API lane: fix/api-workspace-editor-20261017 (base 8c0c0f7).
Web lane: fix/web-workspace-editor-20261017 (base 406e36b).
Mobile lane: fix/mobile-workspace-editor-profile-20261017 (base e9c3e27).

## Final Apple delivery

Apple acknowledged production 1.0.8 (85), runtime 9cec0bc, delivery
6a197534-7e09-453d-a1fa-efe1bf9adeec. IPA and compressed archive are preserved privately under
Documents/FindEZ/AppStore/1.0.8-build85. All 31 archive and export executables verify
as iOS device code; strict signatures, production defines/main target and Apple
validation pass. No processing/group/tester polling followed acknowledgment.
Processing, tester availability and physical-device acceptance remain unverified.
Beta84 is superseded. Public App Store submission remains held.
