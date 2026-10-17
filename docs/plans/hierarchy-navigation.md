# Organization and workspace navigation repair

October 16, 2026. Lane feat/hierarchy-navigation-20261016, based on dec9cf9.
User authorized replacing the flow before an inventory opens on mobile and web.
The working inventory dashboard, Spaces, capture, search and item screens are
preserved. No organization or workspace was merged by name: duplicate names may
represent different resources with different roles.

## Findings and changes

- Mobile hid inventory creation after the first collection. New inventory is now
  visible for every authorized workspace, regardless of its inventory count.
  Successful creation refreshes the directory without unexpectedly entering an
  empty dashboard. Existing backend creation already supports multiple inventories.
- Organizations were dim switcher headings, including empty headings without a
  destination card. They are now explicit tappable cards with a badge, role and
  chevron. Their workspaces appear immediately below, once per actual parent ID.
- Organization pages separate Workspaces and People. Authorized creation/invitation
  actions are visible in their own section; empty states indicate the next action.
- Workspace home prioritizes its inventory directory, with visible create and
  separate per-inventory management actions. Tasks, Files, People, Activity and
  Workspace settings form a separate group. Organization and switch controls retain
  the selected place; new standalone workspaces select the returned saved ID.
- Separate semantic targets expose inventory opening and its management menu.
  Directory-only button themes avoid inheriting the working app's glass decoration.
- Web workspace URLs default to Inventories; Overview remains an explicit optional
  view. Cards, search, spacing, buttons and Inter typography are scoped to the
  directory routes, including their shell. Working inventory routes keep their theme.
- Both clients expose rename and typed-name deletion menus outside the dashboard.
  No previous inventory DELETE API existed. New authenticated DELETE /inventories/{id}
  calls one backend-only operation and reports only a confirmed exact receipt.

## Safe deletion and migration 049

Only owners/admins with current inventory access can delete. Creation/rename rights
alone do not imply deletion rights. The operation requires the exact current name,
locks the inventory and current membership/grant rows, inspects all content foreign
keys, and rejects nonempty inventories before any cascade. Items, Spaces, documents,
chats, reviews, aliases and other linked saved content prevent deletion. Permission/
invitation metadata may cascade; content-free memory receipts retain their history.
The audit survives and a remaining inventory becomes the default when necessary.
Missing/stale/revoked/unknown outcomes are actionable and never called success.

Migration 049 adds the service-only function; it does not itself delete any records
or change existing permissions. Direct client RPC execution is revoked. Keep the
function on runtime rollback; the previous runtime simply does not expose DELETE.
Tanya explicitly approved production application. Migration 049 is now applied
and the reviewed API is live. Runtime rollback keeps this service-only function.

## Verification

- Full backend: 780 passed, 72 dependency warnings, six subtests.
- Full web: 305 passed, 42 suites. TypeScript and changed production-file ESLint pass.
- Full Flutter: 448 passed. Static analysis clean. Subsequent directory-only visual
  and accessibility refinements have a final focused 33-test passing run.
- Composed disposable Postgres fixture passes all existing policies/migrations,
  migration 049 owner/outsider/name/content/audit/replay cases and a future content
  foreign-key protection case. No production data used for fixtures. Locks are
  implemented for concurrent writes; no load/concurrency benchmark is claimed.
- Ordinary production-configured server webpack build passes with real fonts.
  Release web-hierarchy-20261016 is live; source outside six reviewed
  web files is preserved. No synthetic font/auth fixture output is deployed.
- iPhone 16e simulator visual review uses isolated tool/place_preview.dart data:
  switcher, organization tabs/creation, workspace inventory/menu and delete/cancel.
  Screenshots in design/hierarchy-navigation/out are synthetic UI evidence, not
  proof of authenticated live writes. An initial native attempt and one focused
  test attempt ran out of disk; only regenerable caches/build outputs were cleared.
  Signed prior releases and user data remain preserved.

## Files

Backend: inventory_workspaces.py; migration 049_empty_inventory_delete.sql;
test_inventory_delete.py; SQL api_key_rls.sql and inventory_delete.sql.
Web: organization-directory.tsx; workspace-directory.tsx;
inventory-management-actions.tsx; directory-design.module.css;
lib/context-navigation.ts; app/workspaces/[workspaceId]/page.tsx;
inventory-navigation.test.tsx; workspace-profile.test.tsx;
inventory-management-actions.test.tsx.
Mobile: workspaces/workspace_home.dart, hierarchy_page.dart, inventory_actions.dart,
place_ui.dart; pubspec.yaml (1.0.8+71); workspace_home_test.dart,
organization_place_flow_test.dart, hierarchy_page_test.dart,
onboarding_launch_test.dart, inventory_directory_actions_test.dart;
tool/place_preview.dart (isolated entry only). Shared context/docs and screenshots.

## Manual acceptance after publication

1. Owner: open an organization, create a workspace, and create two inventories.
   Both remain visible in the selected workspace; tap either to open the unchanged
   inventory dashboard. Return, switch parent, and confirm no stale cards appear.
2. Open the inventory dots menu, rename, refresh web/mobile, and verify the name.
   Delete a disposable empty inventory with exact confirmation; it disappears from
   both clients after refresh. A wrong name or a saved Space/item must block it.
3. Viewer/member: verify no unauthorized creation/deletion action appears and a
   direct DELETE is denied. Restricted inventories still lead to access review.
4. Organization People: inspect roles, invitations/consent, and workspace assignment.
   Revoked membership must remove access on refresh. No test invitations are sent.
5. Offline/slow requests: verify Retry, no fake save/delete success, and account/
   workspace-switch isolation. Restart retains the last accessible workspace.
6. On iPhone check largest text, VoiceOver, keyboard and navigation. Verify that
   existing dashboard, Spaces, Capture and FIND behavior remain unchanged.

Authenticated production writes, real two-account synchronization and physical
TestFlight acceptance remain unverified until performed with disposable accounts.

## Production activation

Tanya approved migration 049 and publication. Fresh private runtime/database
backups are in /home/ubuntu/findez-hierarchy-release-20261016. The live snapshot
restored in an isolated container and migration 049 passed before application.
Only inventory_workspaces.py and the new migration were installed in the dirty
production checkout. No customer records were changed for QA. Local/public
health and database health return 200; missing/invalid sessions on DELETE return
401. Database metadata confirms anon/authenticated cannot execute deletion and
service_role can. The operation itself only runs on an explicitly confirmed
user request, not as part of migration or release verification.

Web runs web-hierarchy-20261016 after the normal production build. Public pages
and signed-out directory protection pass. An existing authenticated Safari
session, refreshed after activation, shows the real workspace inventory list,
New inventory button and independent Rename/Delete menu. This read-only check
does not establish successful live creation/deletion or cross-client sync.
Prior web override/runtime backups remain available for rollback.

Apple acknowledged signed production TestFlight 1.0.8 (71), runtime 9bec964,
delivery f40d86ad-2880-424d-8aa7-c5e2fb2d8e9b. Processing and tester
availability are pending and were not polled. No tests/CI were repeated after
push or signing. Public App Store submission was unchanged.

PR: https://github.com/tanyasmritivc/main-inventory-app/pull/90. Branch:
feat/hierarchy-navigation-20261016. Runtime commit: 9bec964. The following
documentation receipt does not change the uploaded binary.

## Workspace deletion follow-up

User reported that workspace removal was still unavailable. Existing owner-only
DELETE /teams/{id} is reused, with its current transaction retaining physical
inventories as Personal and removing collaboration/tasks/workspace files. No
backend/schema changes for this part. Mobile home Workspace menu and Workspace
settings expose the action; web workspace headers/cards and settings expose it.
Typed-name confirmation, real success receipt, busy/cancel/error and account
unmount guards are tested. Successful mobile removal resets saved place to
Personal; web returns to the workspace directory. Web release
web-workspace-delete-20261016 is live after real production build, route/auth
checks and 309 web tests. Twelve focused mobile tests pass; complete suite had
a synthetic map typing/owner-fixture issue corrected by that focused run.
Final full regression and beta72 are pending the additional inventory purge and
account deletion reports. No real deletion was attempted for verification.
