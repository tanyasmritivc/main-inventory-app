# Mobile hierarchy parity

Implementation lane: `feat/mobile-inventory-context-20261016`.
Audit baseline: `897def7f64cd26c21cea680a0f9a6150a751de5c`, clean tracked tree,
`/Users/tanyasmritivictorcharles/dev/findez-mobile-color-accents`.
No backend, web, database, dependencies, signing or production changes.

## Verified relationships and authorization

The source of truth is the current web implementation and existing backend
contracts, not a newly invented mobile hierarchy:

- `app_organizations` has `app_organization_members` (owner/admin/member).
- `teams.organization_id` is optional. Existing Teams are workspaces;
  `team_memberships` is their collaboration boundary. Backend workspace roles
  owner/mentor/member/viewer display as Owner/Admin/Editor/Viewer.
- `app_inventories.team_id` associates a collection with a workspace. A null
  `team_id` is a personal collection belonging to `owner_user_id`.
- `app_inventory_members` supplies admin/editor/viewer/none overrides. Inventory
  access modes are legacy/workspace/restricted. Only backend-returned effective
  roles and capabilities control mobile presentation; the server reauthorizes
  each operation. Organization membership grants no automatic workspace access.
- `spaces.inventory_id` defines inventory-local locations. A workspace's separate
  `app_physical_locations` hierarchy uses `team_id` and `parent_id`; an explicit
  `spaces.physical_location_id` attachment connects them. Space access does not
  imply permission to every inventory in the same room.
- Directory visibility is independent of content access. Restricted visible
  entries expose approved metadata only, with an explicit viewer access request.
- New organization/workspace/inventory grants use `app_access_invitations` and
  explicit recipient acceptance. Independent workspaces retain the web's older
  email/shared-code Join flow; that code is shareable rather than recipient-bound.

Evidence: `backend/supabase/schema-baseline-2026-08-10.sql`, migrations
`043_workspace_inventories.sql` through `047_empty_organization_delete.sql`;
`backend/app/api/routes/{inventory_workspaces,collaboration,workspace_directory,access_invitations,teams}.py`;
`backend/app/services/{inventory_scope,resource_access,access_invitations}.py`.
New collaboration tables are service-only with RLS enabled. Restrictive inventory
policies, write triggers and parent checks augment existing policies. The mobile
implementation makes JWT-authenticated FastAPI requests, with no direct hierarchy
table writes, service credentials, RLS changes or new endpoints. These are source
and local-test conclusions, not a fresh certification of production security.

## Audit and parity matrix

| Capability | Existing web | Mobile before | Mobile implemented | Existing backend |
|---|---|---|---|---|
| Organizations | Directory, assigned workspaces, people | Missing | List/switch, create, owner rename, exact-name empty deletion, people/invitations, attach owned independent workspace | `/organizations`, `/organizations/{id}` and child routes |
| Workspaces | Organization or independent projects | Teams/Team Spaces only | Organization projects and assigned-workspace shortcuts, create/rename, permitted delete/leave, tasks/files, people/roles, locations, filtered audit | `/inventory-workspaces`, `/teams`, `/inventory-workspaces/{id}/overview` |
| Inventories | Independent directory and active context | No collection selector | Directory, paginated loading, restricted entry/request/cancel/manager decision, create/rename, access policy, directory settings, selected inventory | `/inventory-workspaces/{id}/directory`, `/inventories/{id}`, `/inventory-directory`, access-request routes |
| Physical locations | Workspace hierarchy and explicit inventory attachments | Team Space and personal location lists | Hierarchical paths, create with parent, attach to inventory; existing inventory Space CRUD; explicit same-workspace Space moves | Workspace `/locations`, inventory `/locations`, scoped `/spaces`, `/inventories/{id}/spaces/{space}/move` |
| Members | Organization, workspace and inventory roles | Legacy Team/Shared Space roles | Read effective/inherited roles, permitted assign/change/remove, pending invitations/cancellation, recipient review by inbox/link/code | Collaboration and access-invitation APIs |
| Items and editing | Inventory-scoped reads/writes | Mainly account/Team Space scope | Immutable selected client scopes reads, manual create/edit/delete, photos and location choices; viewer details remain readable, writes/swipes disabled | Existing `/inventories/{id}/...` boundary |
| Capture and imports | Selected collection | Account scope or Team Space | Photo/barcode/review/import/BOM/kit requests use selected inventory; share imports require a destination picker; no arbitrary organization/Space selection | Existing scoped capture/import/review APIs |
| Ask and documents | Inventory context, private conversations | Legacy account context | Both SSE paths, history, document/note routes scoped; viewer notes read-only | Scoped AI/conversation/document APIs |
| Personal and Shared Spaces | Personal collections plus legacy shares | Implemented | Personal entry retained, account-bound restoration, Shared with me and explicit legacy Join supported | Existing personal/shared contracts |
| Synchronization and resilience | Refresh and authoritative API responses | Screen-level refresh | Refresh after mutations, pull/toolbar refresh, resume grant recheck, offline/denied/error/retry/empty states, generation fences, separated caches | Same authenticated backend as web; no offline write queue or realtime claim |
| Archive/delete inventory or edit/delete shared hierarchy nodes | No corresponding current API | Not present | Not invented; only existing permitted operations exposed | No new endpoint/table |

Web references: `frontend/src/components/site/{organization-directory,workspace-directory,workspace-overview,collaboration-panel,inventory-access-request,access-invitation-client}.tsx`,
`frontend/src/lib/{inventory-selection,workspace-directory,account-request}.ts`,
`frontend/src/app/organizations/`, `frontend/src/app/workspaces/`, and the scoped
application routes under `frontend/src/app/(workspace)/`.
Web state uses account-bound requests, URL-selected inventory and explicit
navigation. Flutter uses its existing StatefulWidget/ChangeNotifier patterns,
Dio API client and Supabase Auth instead of adding a second state framework.

## Implementation behavior

The auth gate opens Your world unless the same account has a previously selected
inventory. Only a fresh successful `/inventories/{id}` response can restore it.
The picker supports Personal, organizations and explicitly assigned workspaces.
Opening an inventory creates an immutable client with a captured account,
inventory, workspace and effective capabilities. Home/Capture/Ask/Find remain the
four mobile destinations. The old Teams segment is absent from this environment.
The header shows the working context and offers switching and inventory settings.

Switching retires the old client and Navigator, clears its screens/drafts/caches,
and rejects late HTTP and SSE results. Already accepted server requests cannot be
undone by switching; they keep their original URL/token and are never retargeted.
The last selected inventory ID is persisted per account, not accepted as an access
grant. No first-organization/first-inventory fallback is used. Camera/picker resume
rechecks access without discarding a draft when the grant is unchanged. Transient
connection/server failures show a retryable notice and preserve drafts; explicit
denial/unavailability retires the inventory routes. Every action still requires
current server authorization.

The inventory cache is partitioned by account/inventory. Capture confirmation and
barcode matching use that partition. Local restock preferences retain existing
account/item-ID semantics; this does not add cross-device restock synchronization.
Workspace tasks no longer fall back to another Team if an explicit requested
workspace disappears. Invitations and notifications remain account-level.

## Changed application files

New:

- `mobile/lib/core/inventory_context.dart`: authorized context model, display roles and location paths.
- `mobile/lib/core/inventory_session.dart`: selection, restoration, retry, grant revalidation and lifetime fencing.
- `mobile/lib/features/workspaces/inventory_context_host.dart`: chooser/scoped shell lifecycle and import destination selection.
- `mobile/lib/features/workspaces/hierarchy_page.dart`: organization/workspace/inventory directories, settings, memberships, physical locations and access requests.
- `mobile/lib/features/workspaces/invitation_page.dart`: read-only preview and explicit Accept/Decline.
- `mobile/test/inventory_context_test.dart`: authenticated transport, scope, race, parent, cache, offline and revalidation regressions.
- `mobile/test/hierarchy_page_test.dart`: directories, permissions, consent, requests, create/refresh, import chooser, phone layout and accessibility.
- `mobile/test/support/hierarchy_fixture.dart`: synthetic authenticated HTTP fixture only; not application mock data.

Updated:

- `mobile/lib/main.dart`: auth entry and incoming spreadsheet destination selection.
- `mobile/lib/core/api_client.dart`: account-bound clones, scoped Dio/SSE routes, current-context checks and viewer guards.
- `mobile/lib/core/api_error.dart`: distinguish permission denial from plan limits and show safe context/validation errors.
- `mobile/lib/core/inventory_cache.dart`: collection-specific caches.
- `mobile/lib/core/invitation.dart`: access-invitation link/code handoffs alongside existing six-character codes.
- `mobile/lib/features/shell/main_shell.dart`: context header, switch/settings, selected views, viewer Capture state, resume refresh.
- `mobile/lib/features/home/{home_page,home_overview}.dart`: selected cache and contextual overview heading.
- `mobile/lib/features/inventory/inventory_page.dart`: selected Space/item actions, read-only details, hidden/disallowed writes, permission errors, scoped sharing boundaries.
- `mobile/lib/features/inventory/item_detail_sheet.dart`: enforce effective read-only presentation and selected cache updates.
- `mobile/lib/features/documents/{documents_page,notes_editor_page}.dart`: viewer document/note presentation and write guards.
- `mobile/lib/features/scan/{scan_page,confirm_scan_sheet,space_barcode_flow,upload_photo_flow}.dart`: selected duplicate-match cache and captured request context.
- `mobile/lib/features/shopping/shopping_list_page.dart`: selected item cache updates.
- `mobile/lib/features/notifications/notifications_page.dart`: invitation review and refresh.
- `mobile/lib/features/sharing/invitation_host.dart`: cold/warm access links, preserved sign-in handoff and current chooser after joining.
- `mobile/lib/features/teams/team_board_page.dart`: explicit-workspace failure instead of first-Team fallback; task terminology.
- `mobile/lib/features/showcase/tutorial_controller.dart`: context-switcher tour target/copy.
- `mobile/test/{onboarding_launch,tutorial_overlay}_test.dart`: chooser entry, validated restoration and updated tour.
- `.agents/{ACTIVE_WORK,CURRENT_STATE,DECISIONS}.md`, `TESTING.md` and this document: scope, verification and release limits.

## Verification and remaining release gate

Final local results on October 16:

| Check | Actual result | What it proves |
|---|---|---|
| `flutter analyze --no-pub` | No issues, 2.8s | Dart static analysis for the whole mobile app |
| Full sequential Flutter suite | 409 passed, 1m46s | Existing regressions plus client, session and widget tests; not native end-to-end |
| Optional phone render check | 1 passed; four 390px light/dark renders inspected | Directory/workspace layout with synthetic records; large text also covered by widget tests |
| Targeted backend suites listed below | 75 passed, 5.09s; 69 deprecation warnings | Existing inventory boundaries, permissions, consent, directory and creator actions with external I/O stubbed |
| Web suites listed below | 59 passed across seven suites, 5.606s | Existing web transport/navigation/access compatibility; web source unchanged |

Widget and HTTP-adapter tests use synthetic records. Backend route tests stub external
I/O. They verify transport and authorization behavior locally; they do not prove
camera hardware, email delivery, Apple universal-link dispatch, FIND recognition
or a signed-in two-client production round trip. Phone renders use test fixtures
and the local system font. No native binary or TestFlight build is published.

Run Flutter checks sequentially on this machine: the available disk was below
0.5 GiB and simultaneous Flutter compilation briefly exhausted temporary space.
A native build needs additional free disk space. No unrelated files were deleted.

Commands from the repository:

```sh
cd mobile
flutter analyze --no-pub
flutter test --no-pub --concurrency=1 --reporter expanded
flutter test --no-pub --concurrency=1 --dart-define=FINDEZ_VISUAL_QA=true test/hierarchy_page_test.dart --name 'phone hierarchy visual acceptance'
```

The optional visual test uses `/System/Library/Fonts/SFNS.ttf` on macOS and writes
`/private/tmp/findez-hierarchy-{light,dark}-{organizations,workspace}.png`.
It is gated off in the normal cross-platform suite.

Backend, using an installed development virtual environment:

```sh
cd backend
python -m pytest -q tests/test_inventory_journeys.py tests/test_inventory_scope.py tests/test_collaboration_access.py tests/test_workspace_directory.py tests/test_access_invitation_consent.py tests/test_creator_rename.py tests/test_organization_delete.py
```

Web compatibility (source unchanged):

```sh
cd frontend
npm test -- --runInBand inventory-transport inventory-navigation workspace-boundaries workspace-directory-access collaboration-access access-invitation-consent organization-actions
```

## Manual device/simulator acceptance

Use disposable test accounts/data on a test backend with the same migrations as
web. Build this branch with the existing mobile configuration:
`flutter run --no-pub --dart-define-from-file=/path/to/mobile-test-defines.json`.
That private file supplies API_BASE_URL, SUPABASE_URL and SUPABASE_ANON_KEY only;
never put service-role/FIND/gateway keys in it.

1. Sign in as an owner with one organization, then as one with two. Confirm
   Personal and all assigned workspaces. Organization membership alone must not
   reveal an unassigned workspace's contents. Test an empty account and Retry in
   airplane mode. Sign out/in as another account; no prior content may remain.
2. Create a disposable organization/project/inventory on mobile. Refresh web and
   confirm the same IDs/names/roles. Rename on each client and refresh the other.
   Attach an owned independent workspace. Cancel deletion first; test nonempty
   organization rejection and empty exact-name deletion only on throwaway data.
3. Create two inventories in each of two workspaces. Put distinct items/Spaces
   in each. Switch repeatedly, including during a slow upload/read. Check header,
   Home, Find, Review, documents and chat history. No result/draft from the previous
   context may populate the next. Restart and verify last selection is reauthorized.
4. Capture a photo, scan a barcode, manually add/edit quantity, save a note and
   upload a document in a selected inventory/Space. Refresh web and verify every
   record's collection/location. Edit in web, pull to refresh mobile, and check the
   changed value. Share an XLSX/CSV to mobile: cancel the destination picker, then
   repeat with an explicit destination and confirm no arbitrary assignment.
5. Invite a second account to the organization, then assign workspace and
   inventory roles. Before acceptance it must have no new access. Test email link,
   12-character code and inbox; wrong account, expired/cancelled invite, Accept,
   Decline and replay. Verify legacy explicit six-character Join separately.
6. As viewer, open items/photos/documents/notes and ask questions. Item and Space
   edits, scanning saves, document writes and membership changes must be disabled
   or denied. Change/revoke roles on web while mobile is active/backgrounded;
   refresh/resume and try a stale item URL/action. The server must deny it.
7. Discover a restricted inventory: confirm only directory metadata, request viewer
   access, cancel it, then request again and approve from a manager account. No
   content/count/AI result appears before approval. Test hidden inventories and an
   outsider account attempting a known foreign inventory/item/document ID.
8. Add Workshop > Cabinet > Bin, attach it to the intended inventory, and check
   path display. Test a permitted Space move within one workspace, a linked-record
   conflict and a cross-workspace attempt. No invalid parent/attachment should save.
9. Check tasks/files use the chosen workspace. Revoke that workspace while open:
   it must fail instead of displaying another workspace. Verify Personal records
   and existing Shared with me still open normally.
10. On an iPhone and simulator, check light/dark, large text, VoiceOver, navigation
    Back/Close, camera/library resume, interrupted requests, app restart, cold/warm
    universal links and sign-in handoff. Send real test email only to test accounts.

Outstanding human verification: native binary/device acceptance, actual invitation
email delivery and authenticated web/mobile round trips on disposable data.
Production publication requires separate explicit approval. No new product or
schema decision is required for the implemented hierarchy.
