# Mobile organization scope

Branch: fix/mobile-organization-scope-20261017. Base: 24bbcac. Mobile only.

The organization pill appears in the directory and the inventory context header.
Its dropdown lists organizations and the separate Personal scope, plus creation.
The workspace picker contains only children of that selection. People, Tasks and
Files are visible workspace controls; settings, activity and deletion are secondary.
Creation uses /organizations/{id}/workspaces in an organization, with existing
standalone /teams only in Personal. Existing records are never reparented.

PlaceSession stores the selected organization with the account-bound last place,
including empty organizations. Generation guards retire stale reads/preferences.
Child overviews validate actual organization IDs before displaying inventories.
On explicit onboarding/link/notification navigation, the validated parent sets the
scope. Normal inventory opening cannot escape it. A dashboard organization change
retires the old inventory client, nested routes, streams and drafts via the existing
InventorySession. Revoked/failed organization reads show Retry and the organization
selector, without exposing another scope. Deleting a workspace refreshes its org.

Personal resolves workspace parents without loading other organizations' inventory
directories. This is client navigation containment; existing backend authorization
continues to enforce access. No API, schema, auth, GPU, web, customer records or
dashboard content changes. The context header alone gains the requested selector.

All 588 Flutter coverage tests pass. This includes both appearance modes for
workspace and organization flows, 3.2x text, owner/viewer controls, creation/error
and deletion fallback. Palette contrast checks pass at 4.5:1 for body/supporting
text and 7:1 for primary text; high-contrast variants are included. Existing
onboarding/auth tests cover the actual inventory shell, scope exit and its enlarged
header. Static analysis is clean. The final 15 boundary/auth cases pass after adding
a fresh scoped directory read on dashboard return and a reparenting guard.
The release receipt follows below.

Native iPhone 16e review verifies two organizations with same-named workspaces,
filtered child menus and inventories, visible People/Tasks/Files, and light/dark
directory/dropdown/collaboration/search/management/confirmation presentation.
Deletion dialogs were canceled. The original light simulator appearance is
restored. Screenshots are in design/mobile-organization-scope/out. A shared
forced-light theme and white search field discovered during review now follow
the app appearance. Default light preference and dashboard content are unchanged.
The first simulator attempts hit local disk limits; only regenerable build caches
were cleared. Final native build succeeded. An overlapping full test attempt was
interrupted; the final sequential 588-test run completed successfully.

Apple acknowledged TestFlight 1.0.8 (82), runtime 8e7ee6b, delivery
10545da8-eadf-447d-be11-de5957dfbc98. All 31 archive/export executables verify as
iOS device code, and strict archive signatures pass. All five automatic CI jobs
pass on runtime source (run 39079363353). Processing/tester availability remains
unverified; no Apple polling or post-push regression reruns. Physical acceptance
remains open. PR 98: https://github.com/tanyasmritivc/main-inventory-app/pull/98.

The clean Flutter archive wrapper hit the disk limit while writing temporary
Xcode diagnostics. Direct Xcode archive/export succeeded with the same verified
production defines, lib/main.dart target and build number, followed by the full
platform/signature gates. Only regenerable compiler/download caches and the
isolated QA app were removed. Installed dependencies, customer files, the signed-in
app and prior private releases were preserved. No source change followed checks.
Private signed IPA/archive, SHA256 and Apple receipt are preserved in the build82
release folder. No public App Store submission or production database change.
 Native preview uses synthetic fixtures in
tool/place_preview.dart, excluded from lib/main.dart. Physical TestFlight account
switching, notification handoff, permissions/revocation and capture acceptance are
not established by these fixtures. No live customer writes are used for QA.
