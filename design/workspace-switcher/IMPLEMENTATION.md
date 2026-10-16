# Mobile workspace home and place switcher

Source lane: `feat/mobile-place-switcher-20261016`, based on mobile build 66.
Mobile only. No API, backend, schema, RLS or web behavior changes.

## Verified relationships and capability parity

| Capability | Web source of truth | Mobile implementation | Backend support / remaining work |
| --- | --- | --- | --- |
| Organizations and accepted membership | `organization-directory.tsx`, `/organizations` | Existing `HierarchyPage` management retained; grouped switcher opens organization management | Existing organization/member APIs; invitations still require recipient consent |
| Workspace parent and roles | `workspace-directory.tsx`, workspace overview | `PlaceRepository` loads authorized overviews for actual organization parents; workspace appears once | `/inventory-workspaces`, `/{id}/overview`; list alone omits parent IDs |
| Inventory directory and restricted entry | workspace directory and `inventory-boundary.tsx` | One-inventory hero, multiple-inventory list, restricted entry/access request and existing management | Existing paginated directory and `/inventories/{id}` authorization; counts hidden when absent |
| Locations, spaces, items, capture and Assist | selected inventory transport in `inventory-selection.ts` | Existing immutable `InventorySession` and scoped `ApiClient`; no arbitrary parent selection | Same authenticated inventory endpoints, server authorizes each request |
| Tasks, Files, People, Activity | workspace tools | Home links to existing screens; People has Leave and existing confirmation | Existing workspace APIs, management and invitation controls retained |
| Reopen and switch place | New mobile device preference | Account-bound `PlaceSession`, `LastPlaceStore`, authorized cold restore and stale-response protection | No new endpoint; 403/404/410 falls back to Personal; offline errors remain retryable |
| Incoming workspace context | existing invitation and notification paths | Target wins over saved place; accepted invitation uses returned workspace ID | iOS must deliver the link/notification; live APNs and published AASA workspace-path delivery remain unverified |

Physical spaces remain locations inside an inventory or explicitly attached shared
locations. Organization membership does not grant inventory contents access.
The workspace is the collaboration context; an opened inventory is a separate,
authorized working context. Inventory tools themselves were retained.

## Behavior

- Warm background, bundled official Geist 1.8.1 fonts, reference tokens and custom
  specified chevrons/check/search/close glyphs.
- Personal and workspace home, grouped scrollable place switcher, selected card,
  roles, counts only where returned, existing create and management flows.
- Pull to refresh replaces the home refresh button. Search now lists only the
  selected workspace's inventories. Tools are absent on Personal as requested.
- The organization route uses the same compact cards, section labels, role tags
  and spacing. Opening a workspace from it returns to the workspace home.
  Workspace management and inventory settings use the same page styling.
- `last_place_<userId>` stores only account/place identity. Writes are serialized,
  generation-checked and cleared on sign out. Home waits for authorized restoration.
- Revoked/deleted saved workspaces fall back to Personal with the specified notice.
  Network/server failures show Retry instead of pretending access was revoked.
- Space creation blank page fixed: inventory dialogs now use the same nearest
  Navigator as their actions. Previously showDialog used the outer root navigator,
  while Create/Cancel popped the inventory navigator. This was reproduced by an
  isolated nested-Navigator regression before applying the fix.

## Validation and limits

- `flutter test --no-pub --concurrency=1 --coverage`: **434 passed** after
  organization and workspace flow changes. The focused organization, workspace
  home and hierarchy suite passed **29 tests** after the last accessibility edit.
- `flutter analyze --no-pub`: **No issues found**.
- New tests cover per-user restore/save/sign-out, revoked access, offline Retry,
  deep-link override, late writes/reads, forged parents, directory deduplication,
  viewer/restricted entries, counts, large text and People confirmation.
- Space regression covers actual scoped API transport, Personal/shared inventory
  creation, Cancel and viewer denial. Original code fails three of these four tests;
  fixed code passes. Existing launch expectations were updated for workspace home.
- Organization flow widget tests exercise real authenticated API shapes for
  organization selection, workspace home, Tasks, Files, People, Activity, search,
  creation refresh, Retry, viewer restrictions and large text. The production
  connected simulator confirmed the FTC organization page, workspace selection,
  focused Search, real Tasks/Files responses and Space Create/Cancel without a
  blank page. No customer data was written during this review.
- iPhone 16e iOS 26.2 simulator screenshots are in `out/`, using only isolated fake
  API data via `tool/place_preview.dart`. Production entry is `lib/main.dart`.
- Selected FTC place survived terminate/relaunch using native SharedPreferences.
  Live two-account web/mobile refresh, external revocation, camera, email delivery,
  APNs delivery and physical iPhone acceptance are not established by fake-data QA.
- References are left and native renders right in the two `compare-*.png` files.
  Layout, grouping, colors and copy closely match; the bundled official font has
  small raster/glyph-width differences and some baselines differ by 1 to 3 points.
  This is not a claim of pixel-identical typography.
- Images override prose: Personal has no unselected chevron; while the sheet is
  open only the place title remains behind the scrim, without the search/hero.
- Exact muted reference colors do not all meet 4.5:1 at normal contrast. High
  contrast mode darkens muted labels. Main controls retain semantic labels and
  44-point targets; rows grow under large text. Normal token contrast versus
  exact reference appearance remains a design tradeoff.

## Real-device acceptance

1. Sign in with a disposable single-workspace account, then a multi-organization
   account. Check organization grouping, roles and no duplicate workspaces.
2. Select a workspace, open an inventory and switch during slow requests. Confirm
   old data, drafts and responses cannot appear in the new inventory.
3. Force quit on FTC and reopen. Confirm FTC home appears without Personal flashing.
   Revoke access from web, reopen and confirm Personal plus the notice. Offline
   instead must show Retry and preserve the saved target.
4. Open Find, tap New Space, create a disposable space and use Back. Confirm the
   space persists on both web and mobile refresh. Cancel must not blank the page.
   A viewer must not see creation or be able to mutate records.
5. Create/capture/edit an item in that space and compare web/mobile after refresh.
   Confirm documents and Ask use only the selected inventory.
6. Test invitation acceptance/decline and revoked access with disposable accounts;
   follow invitation/workspace links and notification targets before and after sign in.
7. Test airplane mode, interrupted writes, Retry, large accessibility text,
   light/dark appearance, camera/library and microphone permissions on iPhone.
8. Open People, inspect roles, cancel Leave, then confirm Leave only on disposable
   membership. Ensure the home falls back safely and the owner/data are unchanged.

## Files

Core/session: `mobile/lib/core/last_place.dart`, `place_session.dart`.
Navigation: `mobile/lib/main.dart`, `features/workspaces/inventory_context_host.dart`,
`features/sharing/invitation_host.dart`, `features/shell/main_shell.dart`,
`features/workspaces/invitation_page.dart`.
UI: `features/workspaces/workspace_home.dart`, `place_ui.dart`, `hierarchy_page.dart`.
Space fix: `features/inventory/inventory_page.dart`.
Assets/config: `mobile/pubspec.yaml`, five files in `mobile/assets/fonts/`.
Tests: `last_place_test.dart`, `workspace_home_test.dart`,
`space_creation_navigation_test.dart`, `organization_place_flow_test.dart`,
`hierarchy_page_test.dart`, `onboarding_launch_test.dart`,
`support/hierarchy_fixture.dart` under `mobile/test/`.
Simulator entry: `mobile/tool/place_preview.dart`.
Design: supplied `PROMPT.md`, both `reference/` PNGs, four native screenshots and
two comparison pairs in `out/`, and this implementation record.
Project state: `.agents/ACTIVE_WORK.md`, `.agents/CURRENT_STATE.md`,
`.agents/DECISIONS.md`, `TESTING.md`.

## Delivery

Runtime `9b66023`, draft PR #87. FindEZ 1.0.8 (67) uploaded successfully after
Apple validation and exact-runtime CI run 38973815385: five jobs pass, including
430 Flutter, 565 backend and 296 web tests. Strict native/package checks cover
31 iOS device executables, both signatures, production configuration and bundled
fonts. A cached simulator native library was rejected locally, then removed by
a clean rebuild before validation/upload. Apple delivery:
`8b0f89b7-a938-47fd-804a-c525d6bb7964`. Processing and tester availability remain
pending; no wait or public App Store submission. Durable receipts and release
artifacts are outside Git in `Documents/FindEZ/AppStore/1.0.8-build67/`.

The visual fixture has intentionally limited routes and an inert inventory-open
callback. Its Tasks/Files error screen is not a production API result. Functional
acceptance must use `lib/main.dart` with the authenticated production client, not
`tool/place_preview.dart`. The signed IPA was explicitly built and verified with
`lib/main.dart` and contains neither fake API origin nor preview route markers.
