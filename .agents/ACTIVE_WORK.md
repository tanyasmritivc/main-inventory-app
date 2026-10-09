# Active work

## Landing copy and returning-user navigation (October 8)

In progress on `fix/landing-dashboard-link` in
`/Users/tanyasmritivictorcharles/dev/findez-web-navigation`, based on `f36ca25`.
The user now explicitly authorizes removing the hero's chatbot/database paragraph
and replacing top signup/sign-in actions with Dashboard for signed-in visitors.
The landing uses server-verified initial identity and marketing navigation follows
browser sign-in/out events. Preserve the deployed interior, animation, public API,
backend, mobile and production data. Validate and deploy through existing self
hosting in an isolated release; preserve the original dirty VM checkout.

## Web navigation and hover sidebar (October 8)

Completed and deployed on `fix/web-navigation-hover` in
`/Users/tanyasmritivictorcharles/dev/findez-web-navigation`, based on `5473694`.
Runtime `0cc9f44` uses a persistent workspace layout, per-page authentication,
content skeletons and smooth hover expansion/collapse over a stationary page.
181 web tests, TypeScript, lint, local/server builds and all five runtime CI jobs
pass. Safari read-only checks cover all 18 sidebar destinations, live data,
mouse/focus behavior and public docs theme cleanup. Self-hosted release:
`/home/ubuntu/findez-web-releases/web-navigation-hover-20261008/frontend`.
Original dirty checkout, backend, landing, API/docs and existing collection
heading colors are preserved. Draft PR #48 is stacked on the web rebuild.

## Web mobile-parity rebuild (October 6)

User-authorized authenticated web rebuild on `web/mobile-parity-rebuild` in
`/private/tmp/findez-web-rebuild`, based on submitted mobile build-58 record
`1e36998`. Mobile defines feature semantics; supplied desktop prototype guides
layout only. Preserve marketing, production data, public API contracts and docs.
Scope: desktop navigation, Home/Spaces/Find, grounded/photo Ask, account-local
Restock, item galleries, Documents/notes, existing collaboration/utilities, and
visible loading/retry states. Implemented and deployed to the existing self-hosted
server on runtime `afea356`; systemd `findez-web` uses isolated release
`/home/ubuntu/findez-web-releases/web-mobile-parity-20261006-live/frontend`.
The dirty original VM checkout and previous builds remain recoverable. All 176
web tests with coverage, TypeScript, lint with no errors and production webpack
build pass. Native Safari verified desktop and 390px flows with fictional local
data, then actual live Home/Documents/Restock/profile reads. Profile signup
recursion is covered by a regression. Public HTTPS/static/auth checks pass;
landing content and all public API/docs/assets remain preserved. Backend,
mobile and schema are unchanged. Draft PR #47 targets `release/appstore-build58`
to keep the diff web-only; exact-head shared CI is recorded on the PR. Full live
file-write, multi-account and collaboration acceptance was not repeated.

Update this file when work starts, changes owner, becomes blocked, or lands. Do not
list ideas as active work.

## Verified active work

The user's latest October 5 instruction explicitly authorizes checking the current
mobile app and submitting it to Apple. This supersedes the earlier screenshot
preparation hold. FindEZ AI 1.0.7 (58) was submitted at 2026-10-06 06:06:37 UTC
(October 5, 11:06 PM PDT). Apple reports WAITING_FOR_REVIEW for both the version
and submission `2b777948-f7bd-46b3-bf43-9a2e60074361`. Manual release is preserved.

All six supplied iPhone PNGs and six supplied iPad PNGs are uploaded in order,
COMPLETE, and checksum-identical to the ZIP originals. Listing description,
subtitle, promotional text, keywords, release notes and reviewer instructions
follow the supplied physical-memory vision and contain no em dashes. Future
roadmap features are not advertised as implemented. Reviewer login, eight live
read endpoints, six consistent sample-inventory reads, website/privacy URLs and
all five exact-runtime CI jobs pass. Simulator Home/Spaces were observed; a full
physical-device acceptance pass was not repeated. Public version 1.0.6 (17)
remains available while Apple reviews the update. Runtime, backend, database,
billing, original logo assets, native lifecycle and FIND transport are unchanged.

| Work | Area | State | Dependencies and handoff |
|---|---|---|---|
| App Store submission build 58 | Apple listing, screenshots and release records | Submitted; WAITING_FOR_REVIEW on `release/appstore-build58`. Version 1.0.7 selects eligible build 58, runtime `9657aed`. Submission `2b777948-f7bd-46b3-bf43-9a2e60074361`, manual release. | Twelve original screenshots and vision-grounded copy are verified. `appstore/submission.json` records checks and durable artwork location. Apple approval and a later manual publication remain pending. Full physical acceptance was not repeated in this submission pass. No runtime or production implementation change. |
| Mobile accent consistency | `mobile/` shared brand accents, monochrome Teams list and Team file icons | Released build `1.0.7 (58)` on runtime `9657aed`, `fix/mobile-accent-consistency` in `/private/tmp/findez-accent-consistency`, Draft PR #46 stacked on PR #45 (`64c4e47`). Clean analysis/all 296 mobile tests with coverage, actual-shell Light/Dark palette/navigation previews, all five exact-source CI jobs (`37412454402`), signed export/config/logo/signature and Apple validation pass. Upload accepted with no errors at 21:16:01 PDT October 5 (delivery `b9a53267-2cea-4d13-903f-a885f9e62351`); COMPLETE/VALID/APP_STORE_ELIGIBLE, nonexpired and both internal groups verified at 21:20:52 PDT. | User rejected build 57's orange list and requested this page black/white. Create/Join/Team/file icons, selected Teams segment and bottom-nav highlight while Teams is active are neutral. Other main screens keep restrained brand accents. Artifacts/manifest: `/private/tmp/findez-build58-native` and `/private/tmp/findez-build58-verification.json`. Builds 56/57 remain VALID in both internal groups with verified artifacts preserved; 55 was not uploaded. Physical acceptance follows the user's TestFlight choice; public App Store remains held. No backend/web/schema/billing/FIND/native lifecycle change. |
| Restock planner replacement | `mobile/` purchase planning, inventory/Home/Space summaries and arrival stock confirmation | Implemented as candidate `1.0.7 (54)` on `feat/mobile-restock-planner` in `/private/tmp/findez-restock-planner`, based on released build-53 record `3a08fd1`; clean analysis and all 292 mobile tests/coverage pass. All five exact-source CI jobs (`37406983954`), signed archive/export/configuration/logo/signature and Apple validation pass on runtime `98f019e` (Draft PR #45). Uploaded at 20:09:15 PDT October 5; Apple processing is COMPLETE/VALID/APP_STORE_ELIGIBLE and both internal groups are verified. User supplied the build-54 planner screenshot and requested less copy; compact presentation and amber To buy/blue On order feedback are implemented for build 55 in this same lane. All 296 tests with coverage and clean analysis pass, including 22 restock regressions; all five exact-source CI jobs (`37408858103`), signed/config/logo/signature checks and Apple validation pass on `5d24797`. Build 55 is preserved but not uploaded after the user requested app-wide brand consistency; stacked brand PR #46 includes these changes in released build 56. | Explicit To buy, On order and Record arrival, editable quantities, per-item opt-out, inventory chooser and consistent counts replace disconnected checkmarks. Old thresholds/ordered selections migrate with account isolation; confirmed absolute stock saves retain safe lost-response retries. Planning remains account/device-local; real stock uses existing authenticated APIs. New logo/typography and unrelated flows are retained. No backend/web/schema/billing/FIND/native lifecycle change. User chose TestFlight verification; public App Store remains held. |
| App-wide typography consistency | `mobile/` shared typography, all screens/forms and regressions | Uploaded as `1.0.7 (53)` at 19:00:26 PDT October 5; all 274 mobile tests/coverage and analysis pass on `fix/mobile-home-bold-text` in `/private/tmp/findez-home-bold-text`, based on release `e123c22` | User confirmed iPhone Bold Text is enabled and supplied Cal AI as a typography reference. The user approved build 52 Home on the phone, then requested the same policy across the whole app. Build 52 was validated/installed and user-approved on Home but not uploaded; The complete app-wide replacement beta 53 is uploaded and draft PR #44 reflects that scope. Exact-source `afc39ac` has all five CI jobs passing (`37398740825`); signed archive/export, production-config/logo, strict signature and Apple validation pass. Native install completed, but launch/visual checks are unverified after the user chose TestFlight verification. Apple accepted delivery `67e8af04-e91a-4157-aa8d-e758c3222d3b` with no errors; `VALID`/`APP_STORE_ELIGIBLE` and both existing internal TestFlight groups are verified. Artifacts/manifest are preserved under `/private/tmp/findez-build53-native` and `/private/tmp/findez-build53-verification.json`. Apply supporting text Medium and headings/counts to Semibold without disabling OS text scaling or changing global accessibility preferences. Preserve logo, routes, API/schema/backend/web/FIND and native lifecycle. |
| Current TestFlight beta build 51 | `mobile/` release metadata and Apple beta upload | Uploaded on `release/testflight-current` in `/private/tmp/findez-testflight-current`, runtime/release commit `15b6374`, based on latest mobile head `671e304` | Includes branding, appearance, Space icons, onboarding, November pilot copy and the cold Home-to-Space fix. Analysis/265 tests, signed archive/export/configuration, supplied-logo verification, Apple validation/upload and native install/process launch pass. Apple processing is `VALID`/`APP_STORE_ELIGIBLE`, with both existing internal groups verified. No backend/schema/FIND, billing implementation or public App Store submission is part of this beta release; full physical acceptance remains open. |
| Cold Home-to-Space launch fix | `mobile/` inventory loading/navigation | PR #42 runtime `ab506f2` on `fix/mobile-home-space-cold-load` in `/private/tmp/findez-home-space-fix`, based on `2758498`. Actual-shell regression failed before the fix; confirmed reads, retry, true empty data and duplicate/disposal guards now pass. All 265 mobile tests/coverage, analysis and five CI jobs pass (`37385102041`). | Source-only; no new native install/device claim or Apple upload/submission. Exact Space IDs, filters, drafts and routes retained. Separate backend PR #43 deployed private documents with disposable access/revoke checks; item-photo privacy and legal publication remain pending. Preserve FIND and native lifecycle work. |
| Free-pilot date correction | Backend notice, dormant web copy and mobile pilot card | Implemented on `fix/free-pilot-november1` in `/private/tmp/findez-pilot-november`, based on onboarding head `19da889`. November 1, 2026 is the final advertised free-pilot day; following-day copy says November 2. Live backend notice and dormant web source copy selectively deployed with rollback copies. All 350 backend, 134 web and 260 mobile tests, Flutter analysis, TypeScript, web builds and connector/bundle checks pass. | Keep `PILOT_MODE`, public-pilot visibility, limits, Stripe guards, optional end-date configuration and manual activation unchanged. The existing `/pricing` redirect and web artifact are preserved. Mobile API/fallback/cache and 320pt Light/Dark card wrapping are tested through 3.4x; mobile fallback/layout remain source-only for the next approved binary. Dirty production work/FIND are preserved; Apple upload/submission remains held. |
| Physical-memory first-launch onboarding | `mobile/` onboarding presentation and launch gate | Implemented as local `1.0.7 (50)` on `feat/mobile-physical-memory-onboarding` in `/private/tmp/findez-appearance`, based on icon-picker PR #38 (`bea71f5`). PR #39, runtime `f6782d3`, passes all 246 mobile tests/coverage, clean analysis and all five CI gates (run `37265597966`, repeated on docs head `ff15a5d` in `37265970841`). Four concise branded screens, interactive local graphics and reduced-motion transitions; final native simulator build also passes. | Fresh signed-out installation shows onboarding before Auth; returning sessions, completion, invitation inbox and replay/legacy signup state are preserved. No sample inventory/Space writes, permissions, backend/web/schema/FIND or native lifecycle changes. Dark/Light/Larger and sample controls verified. Native signed-out flag-reset cold launch -> four-step completion -> Auth -> restart/Auth verified without erasing app data; original confirmed completion restored. Simulator retains Dark/Default and is left on sign-in. Physical touch/VoiceOver/fresh auth remain deferred. Apple uploads/submission remain held. |
| Personal Space icon picker | `mobile/` Space presentation/preferences | Implemented as local `1.0.7 (49)` on `feat/mobile-space-icon-picker` in `/private/tmp/findez-appearance`, stacked on brand PR #37 (`1d49e27`). Searchable 24-icon picker from the leading icons in personal/owned, joined/shared and Team Space lists. Account/stable-ID device-local choices, Automatic reset and explicit Save/Cancel; all 226 mobile tests/coverage, analysis and native simulator build pass. | Simulator verifies search, Cancel, confirmed card update, restart persistence and both themes/Larger text. Personal preference only, not synced or shared to other members. Permissions, API/schema/backend/web/FIND, nav and native lifecycle remain unchanged. Physical touch/accessibility acceptance deferred; no phone install or Apple upload/submission. |
| Mobile brand theme and duplicate sheet handles | `mobile/` presentation and assets | Implemented as local `1.0.7 (48)` on `feat/mobile-brand-theme` in `/private/tmp/findez-appearance`, stacked on appearance PR #36 (`def3d3c`). Supplied outlined SVGs/native icon, exact light tokens/readable dark roles, neutral legacy UI and single editor grabber. All 203 mobile tests/coverage, analysis and native simulator build pass. Simulator confirms Light/Dark/System, larger text, restart persistence and single handles. | Simulator only; no phone install or Apple upload/submission. Preserve five-icon nav, routes, drafts, API/schema/backend/web/FIND and separate native lifecycle work. Physical appearance/QR/photo/swipe gates remain. Cold Home-to-Space showed an empty list while Find-to-Space was populated; unchanged routing must be checked in a separate release lane. |
| Mobile appearance and text size | `mobile/` presentation/preferences only | Implemented as local `1.0.7 (47)` on `feat/mobile-appearance-accessibility` in `/private/tmp/findez-appearance`, stacked on `df7e1d1` / PR #35. All 190 mobile tests/coverage and analysis pass. Persisted Light/Dark/System and four OS-composed text sizes; adaptive screens and contrast/layout/save-failure regressions. Simulator verifies live appearance changes, restart persistence, large text and existing navigation/item-info presentation. | User chose simulator-only verification: no phone install or Apple upload/submission. Physical photo/QR/accessibility/swipe acceptance remains deferred; CUA mouse drags did not dismiss the simulator panel, while automated swipe regressions pass. No backend/web/schema/FIND or native lifecycle changes. Preserve icons-only navigation, data and routes. |
| Release backend cache correction | `backend/` Space cache and release records | Isolated `fix/release-cache-find-transport` in `/private/tmp/findez-ask-reference`, based on `2376d0f`. Cache-only PR #35, runtime `6027a87`, passes all five CI gates (run `37240403382`), six new regressions and all 349 backend/API-doc tests. Exact `spaces_repo.py` selectively deployed with rollback copy; health/database, live QA and build-46 simulator rename/count pass. Post-deploy API access/revocation also passes. | User explicitly withdrew the FIND transport change on 2026-10-04. No FIND runtime/configuration/proxy change was made. Preserve the existing HTTP route and allowance unless newly authorized; its unencrypted hop remains a documented risk. Keep mobile/API shapes/schema/real data unchanged. |
| App Store build-46 submission | App Store Connect and release records | Held on 2026-10-04 on release records based on PR #34. Draft selects valid/eligible 46, manual/unsubmitted; privacy URL and dedicated verified review login saved. Five test-only items seeded; API access/revocation and six simulator tab cycles pass. Initial rename failure was corrected and selectively deployed in the approved backend lane; immediate live/API and simulator counts now pass. | Updated screenshots, physical multi-account/offline/photo/profile/Documents, filtered rename and real invitation acceptance remain outstanding. Mirroring reports iPhone in use. Preserve public build 17, pricing, real data/memberships, Team-only AASA and separate lifecycle work. Do not fabricate privacy/legal answers or mark API/simulator results as physical passes. User excluded FIND transport changes; leave that connection unchanged and retain the known risk. |
| Swipe-down item detail dismissal | `mobile/` inventory sheet and regression tests | Released as `1.0.7 (46)` on PR #34, `fix/item-detail-swipe-dismiss`, stacked on approved navbar PR #33 in `/private/tmp/findez-ask-reference`. Build 45 was held and not uploaded after uneven-exit feedback. Corrected runtime `78404fa` passes all 135 mobile tests/coverage, clean analysis and all five CI gates (run `37033574121`). Exact signed 46 installed/launched; user-confirmed smooth Parts Room exit. Apple validation/upload passed; `VALID`, `APP_STORE_ELIGIBLE` and both internal TestFlight groups are verified. | Shared item-info panel in personal, shared/joined and Team Spaces, not Edit item. Coordinate top-of-content dragging with scrolling, keep dismissal latched during route exit, and preserve the layout and Close fallback. Guard unsaved notes and pending writes before dismissal. No backend, web, API/schema, branding or native lifecycle changes. Public App Store remains unchanged; the later draft selection and submission hold are recorded in the release row above. |
| Icon-only mobile navigation | `mobile/` shell navigation and tests | PR #33 on `fix/icon-only-mobile-nav`, based on released build 42. Build 43 was not uploaded; the user rejected its tall appearance. Compact build 44 passes 117 mobile tests/coverage, visual capture, clean analysis and all five CI gates on runtime `42f977c`. Exact signed 44 installed/launched and the user approved its appearance. Apple validation/upload passed; `VALID`, `APP_STORE_ELIGIBLE` and both internal TestFlight groups are verified. | Use a 56pt visible bar, circular selected highlight and safe-area spacing outside the pill. Preserve icons/order, accessible names, avatar, routes and tutorial targets. Builds 42-45 are recoverable from verified private server backups; 42 stays in TestFlight. The App Store draft has since advanced to 46 as recorded above. Branding, page content, backend/web and native lifecycle files are out of scope. |
| Space and Team invitation links | `backend/`, `mobile/`, invitation web pages | Implemented/pushed on `feat/workspace-invite-links` (PR #32, runtime source `0b4c207`); reviewed backend/web deployed and healthy. Final `1.0.7 (42)` is `VALID`, `APP_STORE_ELIGIBLE`, and assigned to both internal TestFlight groups. | 343 backend/133 web/114 mobile tests, MCP/bundle checks, analysis/typecheck, production web compilation and all five CI gates pass. Exact signed build 42 installed/launched; the user confirmed its cold Team and real Safari Space prompts, with no real membership changed. App Store 1.0.7 draft has since advanced to 46, still manual/unsubmitted. Fresh-install continuity, real acceptance/revocation and broader physical/security gates remain before submission. Keep Team-only AASA while public build 17 is live. Preserve separate lifecycle work. |
| Flutter UIScene lifecycle migration | `mobile/ios` | Local branch `mobile/flutter-uiscene-migration`; commit `30d5a5e` plus uncommitted changes in Podfiles, Xcode project, and `AppDelegate.swift` | Owner and release status are not recorded. Inspect that worktree before editing these files. Run Flutter analysis/tests, an iOS release build, and physical launch checks before release. |
| App Store recovery and item-photo release | `mobile/` and deployed item-photo backend routes | The public `1.0.6 (17)` source was recovered, build 30 was processed in its internal groups, and item-photo build `1.0.7 (31)` finished App Store Connect processing with `VALID` status on 2026-09-29. | Verify build 31 group assignment and install it from TestFlight. On a physical iPhone, check retained FIND photos plus camera/library add and delete against production. Do not mix the Interior v2 rebuild into this lane. |
| Physical-memory home and durable review | `backend/`, `mobile/`, and matching authenticated web review/home behavior | Branch `feat/physical-memory-home-review` in `/private/tmp/findez-physical-memory`, PR #27; migration `036` and backend/web are deployed. Reference-matching Home and the requested previous rounded four-tab pill are available as build 35 in both internal TestFlight groups. Analysis, all 34 Flutter tests, five CI jobs, Apple validation/processing, and native physical install/launch passed. | Preserve the recovered App Store baseline and separate UIScene worktree. TestFlight-app install and physical capture/photo/auth/revocation checklist remain before calling this production-ready. |
| Reference-matching grounded Ask | Mobile Ask presentation and its additive public answer context | Branch `feat/ask-grounded-reference` in `/private/tmp/findez-ask-reference`, PR #28 stacked on #27. Migration `037` and the selectively deployed backend are live. Build 36 is `VALID` and in both internal TestFlight groups; Apple validation and exact archived physical install/launch passed. All 46 Flutter and 292 backend tests, analysis, and PostgreSQL ownership checks pass. | Home and the previous four-tab pill are unchanged. Hands-on TestFlight install, keyboard/voice, source navigation, ambiguous-project and account-switch acceptance remain unverified. This step does not implement the future memory graph, document retrieval, purchase intelligence, or offline system. |

## Ask photo release

- `feat/ask-fast-photo-questions`, PR #29 stacked on #28, implementation
  `6944ed3`, in `/private/tmp/findez-ask-reference`: the photo-only follow-up is
  complete and the four selected backend files are deployed with exact build-36
  backups preserved. All 327 backend/55 mobile tests, clean Flutter analysis,
  and all five CI test jobs passed. Build `1.0.7 (37)` passed Apple validation,
  native physical install/launch, and processing (`VALID`,
  `APP_STORE_ELIGIBLE`); both internal TestFlight groups are assigned.
  Text-speed work was withdrawn and is excluded. Home, Capture, web, FIND, and
  the restored pill are unchanged. Hands-on camera/library, ownership/uncertainty,
  Review, follow-up and account-switch acceptance remain unverified. Existing
  FIND public-HTTP transport remains a separate security limitation.

## Profile navigation release

- `feat/profile-nav-hub` in `/private/tmp/findez-ask-reference`, based on the
  released build 37. Mobile only: add a fifth circular Profile destination to
  the same inset rounded pill; group account details, settings and existing
  utilities there. Preserve Home, Ask attachments/speed, Capture, Find inventory,
  tutorial page indices, API contracts, backend and existing account actions.
  Implementation, all 66 Flutter tests with coverage and clean analysis are
  complete, with all five CI test jobs passing on `b4aa726` (PR #30). Build
  `1.0.7 (38)` passed Apple validation, upload, `VALID` processing, both internal
  group assignment and native install/launch. Hands-on
  account/settings/camera and TestFlight-app checks remain unverified.

## Profile and Documents polish release

- `fix/profile-documents-polish` in `/private/tmp/findez-ask-reference`, based on
  released build 38. Mobile only: replace cramped account editing with a labeled,
  scrollable form and reliable save/photo actions; use the saved avatar in the
  Profile hub and pill; restyle Documents and its local subflows to the matte
  grouped design. Preserve document API/actions, Home, Ask speed/attachments,
  Capture, Find, settings behavior, backend/web and native lifecycle files. The
  Settings screenshots are visual guidance, not authorization for pretend
  training, retention, offline or export toggles. Implementation `6a0118e` and
  all 94 mobile tests with coverage/clean analysis pass; all five CI jobs are
  green on that exact source (PR #31, stacked on #30). Final build `1.0.7 (39)`
  passed signed archive, Apple validation/upload, `VALID` processing,
  `APP_STORE_ELIGIBLE` and assignment to both internal TestFlight groups. The
  exact final signed app installed and reports build 39. Its launch checks were
  blocked by the locked iPhone; an earlier superseded build-39 binary launched,
  which does not pass the final-binary gate. User unlock was requested. Final
  launch, TestFlight-app installation and hands-on photo/document/account-switch
  acceptance remain unverified. Build-38 archive/IPA are preserved.

## Known blocked product work

| Work | Blocker |
|---|---|
| FIND geometry and training corrections | Unresolved object records, public evidence, review status, uploaded source images, and available crops persist. Masks, geometry, and training-quality correction events still do not persist after FIND job cleanup. |
| Hosted MCP access for remote clients | Current MCP transport is local stdio. A hosted Streamable HTTP service and per-user authentication are not implemented. |

## Handoffs

No task-specific handoff is registered in `.agents/HANDOFFS/`. Current release
preflight evidence and blockers are in `CURRENT_STATE.md` and the release checklist.
