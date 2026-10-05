# Active work

Update this file when work starts, changes owner, becomes blocked, or lands. Do not
list ideas as active work.

## Verified active work

The user explicitly holds Apple submission until they give a new instruction.
Mobile appearance and text-size work is isolated from the held screenshot lane
and the separate native lifecycle work. FIND remains unchanged.

The user asked to wait on October 4 for their release assets. Original mark,
icon and outlined-wordmark SVGs plus a 1024px RGBA icon PNG have now arrived
in their Downloads directory and were inspected read-only. Six iPhone PNGs have
also arrived: all 1320x2868 without alpha. Do not upload as-is: their depicted
text navigation/More and unimplemented drawer-location diagram do not match
build 46. Corrected real-app artwork or a user-approved revision is needed under
Apple's accurate-metadata rules; no automatic app redesign is authorized.
Use the provided original logo assets rather than recreating them. None are installed yet.
The FIND transport change was explicitly withdrawn and remains out of scope.

| Work | Area | State | Dependencies and handoff |
|---|---|---|---|
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
