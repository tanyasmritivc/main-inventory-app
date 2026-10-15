# Current state

## October 15 centered Ask page published

PR #76 website runtime `80ba01b557dc38e5f24dc8d0472c39be2c56bb28` is live.
Ask uses a centered empty state and composer with a faint static sage/lavender
gradient in both themes. History opens in a bounded dialog; user prompts sit in
right-aligned neutral bubbles, and FindEZ replies remain on the left. Existing
photo, streaming, draft, source and inventory behavior is preserved.

All 238 web tests, TypeScript and all five CI jobs pass (38822672148). Changed-file
lint has zero errors and three existing warnings. Actual-component Safari
previews verify desktop centering, 390px light/dark prompt bubbles and 390x500
history dialogs. Live public/authentication checks pass; a signed-in visual
recheck was unavailable because the existing Safari session had expired.

Build `yM8utqb1HXdG80bVkcZYW` runs from
`/home/ubuntu/findez-web-releases/web-ask-centered-20261015-r2/frontend`.
11 public routes, 20 authentication guards and three CSS assets pass, preserving
production configuration and 1,304 prior immutable assets. Backend/database are
unchanged. Receipts: `Documents/FindEZ/Releases/ask-centered-2026-10-15/final`.
Rollback: `/home/ubuntu/findez-ask-centered-20261015-r2/previous-web-rebuild.conf`.

## October 15 workspace hierarchy published

PR #75 is live: Workspace (Personal or Team), then Inventory, then dashboard.
Physical Spaces belong to inventories. Home, capture/import, Find, Assist/history,
documents, Review, activity, lending, kits and purchase plans retain inventory
context. Account settings and billing remain global. Existing mobile/API routes
remain compatible; the new chooser is website-only.

Website runtime `eb67ce1120128a14ffcd369458cd268187dd62d0`, build
`PTR7zEZHl_uHR-Ay09uw3`, runs from
`/home/ubuntu/findez-web-releases/web-workspace-inventories-20261015-r2/frontend`.
Backend runtime `eb3eee0c0232c7433b25f05541737cc766b134cb` and migration 043
are live. All original values across 21 tables were preserved inside the locked
migration transaction. Historical records with removed account owners keep their
owner IDs; the NOT VALID owner foreign key enforces new writes without rewriting
those records. Documents remain private. No customer records were created for QA.

511 backend/API-doc tests, 237 web tests, TypeScript, PostgreSQL isolation and
record-preservation checks pass. All five CI jobs pass for final runtime in run
38702261152. Desktop/narrow and light/dark previews pass. Signed-in live Safari
verifies Personal and Team dashboards, refresh, scoped capture destinations,
private documents, separate Assist history, selected-Team administration and the
corrected Space toolbar. 11 public routes, 20 protected routes and three CSS
assets pass; 1,241 prior assets and production configuration are retained.

Receipts: `Documents/FindEZ/Releases/workspace-inventories-2026-10-15`.
Remote base record: `/home/ubuntu/findez-workspace-inventories-20261015`;
backend backup: `backend-backup-r2` beneath that record. Final web rollback:
`/home/ubuntu/findez-workspace-inventories-20261015-r2/previous-web-rebuild.conf`.
Runtime rollback retains the additive database schema. Payments remain disabled.

## October 14 original imported fields published

PR #74 runtime `bd1c8a1` preserves ordered original Excel/CSV/JSON source fields
and maps each sheet independently, preventing distinct source rows from merging.
Web and mobile source show Imported details with exact named headers, duplicate
and unnamed positions, nested JSON and empty/zero/false values. Read-only
verification retains all source values in 295 rows across the supplied workbook.
459 backend/API-doc tests, 225 web tests, TypeScript, changed-file lint and Flutter
analysis pass; all five exact-source CI jobs pass (38686833571), including full
mobile tests and PostgreSQL migration checks. Local mobile tests initially ran
out of disk; generated-cache cleanup was completed and a rerun was interrupted.
Migration 042 and three hash-guarded backend files are live, preserving existing
items and unrelated source. The isolated website build `dY0WQXameBIfVROypzxBZ`
at `web-import-columns-20261014/frontend` passes 11 public routes, 17 auth guards
and three CSS checks, preserving configuration and 1,122 prior assets. Receipts
and rollback are in `Documents/FindEZ/Releases/import-columns-2026-10-14` and
`/home/ubuntu/findez-import-columns-20261014`. Existing items were not reimported;
previously discarded fields cannot be recovered automatically. Mobile support is
committed and CI-verified but is not in the existing TestFlight build 65.

## October 14 Settings and navigation correction published

PR #73 runtime `7b44165` is live. Settings Plans/legal links use full-width text
rows, Developer icons stay with labels, and Appearance stays compact. The top
page-navigation dialog resets the independent utility translate, fits short
viewports, keeps its input visible above scrolling results, removes repetitive
section captions and returns keyboard focus on close. 224 web tests, TypeScript,
changed-file lint, production build and all five CI jobs pass (38685597933).
Safari verifies both themes and desktop/390px layouts. Live build
`D-x-qQyJQDdszMNcrtfXh` at `web-settings-navigation-20261014/frontend` passes
11 public routes, 17 auth guards and three CSS asset checks, retaining 1,064 old
assets and production configuration. Backend is unchanged. Receipts and rollback
are in `Documents/FindEZ/Releases/settings-navigation-2026-10-14` and
`/home/ubuntu/findez-settings-navigation-20261014`.

## October 14 website clarity published

PR #72, runtime `65226c5a49557a62298b8b9eb499c72a4b8d32f0`, is live on
the existing self-hosted website. The user selected open layouts with quiet
dividers: remove the repeated toolbar title, first FindEZ navigation caption,
duplicate Collections/Space headings, repeated Team tab headings and extra
Project kits Space prompts. Recent items and Spaces use open rows; filters and
secondary actions are lighter, inputs have consistent spacing, Labels tabs are
separated and Review photos no longer fill the page. Contracted/expanded sidebar
states work, with the user's original pinned preference restored after checking.

223 web tests, TypeScript and the production webpack build with actual production
configuration pass. Existing lint warnings remain; all five exact-runtime CI
jobs pass in run `38683070099`. Actual-component fixtures cover light/dark and
narrow layouts; signed-in Safari checks cover the screenshot routes and loaded
inventory. Public release checks cover 11 public routes, 17 protected route
guards and three workspace CSS files. Build ID is `bSG_l1U3Nn-HPx_vC7FHX` at
`/home/ubuntu/findez-web-releases/web-clarity-20261014-r3/frontend`.

The service switch preserves its production environment, unrelated dirty checkout
and 1,006 previous immutable assets. Rollback drop-in is
`/home/ubuntu/findez-web-clarity-20261014-r3/previous-web-rebuild.conf`; the first
release record also retains the original October 12 rollback. Receipts and hashes
are in `Documents/FindEZ/Releases/web-clarity-2026-10-14`, with final delivery in
`published`. Backend process/start time are unchanged; no database changes or
customer inventory writes were made. Pending web branding, pricing and capture
client preparation are included. Pricing remains planned, paid purchasing is
disabled, Shopify remains disabled and newer backend capture receipt/identity
semantics remain a separate deployment. Mobile/TestFlight state below is unchanged.

## October 14 guided tour limited to first installation

Lane `fix/first-install-tour` adds an installation-scoped, durable claim before
any automatic tour display. Existing authenticated/legacy installations migrate
to consumed state. Interrupted starts, backgrounding, sign-in flags and account
changes cannot restart it; opening personal/shared Spaces no longer launches a
second tour. Selected navigation destinations retain spotlight keys so the first
step correctly highlights Home. Setup answers and first-Space creation remain
independent. All 375 mobile tests with coverage pass and Flutter analysis is clean.
TestFlight 1.0.8 (65), runtime `8fbfacd84b1773f9332f55df6be1cc1049c550fb`, is
uploaded, VALID and IN_BETA_TESTING for both existing internal groups. All five
exact-runtime CI jobs pass. The signed app/ShareExtension versions match, all 31
native executables target iOS, production configuration/brand assets are verified,
and Apple validation passes. Simulator upgrade, Space entry and cold restart stay
quiet with the existing session/data retained. IPA, archive, checksums and receipts
are in `Documents/FindEZ/AppStore/1.0.8-build65`.

Vinod's existing private group contains build 65 and only the intended tester, but
external review submission returns Apple's 422
`ENTITY_UNPROCESSABLE.ANOTHER_BUILD_IN_REVIEW`: build 64 is WAITING_FOR_REVIEW.
Build 65 remains READY_FOR_BETA_SUBMISSION, so Vinod cannot install it yet. Retry
the saved private beta helper's `prepare`, then `status`, after build 64's review
finishes. Do not claim 65 is awaiting its own review or already available externally.
Public 1.0.7/build 59 and unselected draft 1.0.8 are verified unchanged. Shopify
stays disabled, no production backend/web deployment occurred, and physical phone
acceptance remains pending.

## October 14 launch reliability candidate and planned pricing UI

Lane `fix/launch-find-reliability` preserves individual captured objects instead
of aggregating names. Owner-bound retry identities, database read-back receipts
and indexed outcomes prevent duplicate retry quantities and silent batch loss.
Both clients keep unconfirmed drafts. Web capture/review requests bind to the
initiating token and ignore late results across accounts. Mobile stops disposed
multi-step saves. Photo ASK exposes identifier/name evidence, unknown quantities
stay unknown and result locations are labelled recorded, without fabricated
physical confirmations. The user defers image-similarity work because FIND source
is unavailable; the live API inspection exposes no such endpoint.

The public `/pricing` page and mobile Settings -> Plans now compare the requested
five tiers with monthly/yearly prices. They are explicitly planned, with paid
controls unavailable and current entitlements unchanged. No live payment link is
invented. Stripe subscription checkout, StoreKit purchase/restore/verification,
new tier enforcement and commercial configuration remain unfinished. Legacy
robotics pricing UI is replaced; its backend is not reactivated or repurposed.

Validation: 455 backend/API-doc tests and six subtests, 223 web tests, TypeScript,
changed-file lint (three existing Assist warnings), clean Flutter analysis and
362 mobile tests with coverage pass. The fictional-config production web build
passes with webpack caching temporarily disabled for disk space; source config
is restored. Safari renders the pricing comparison locally. The arm64 native
simulator app is rebuilt/installed and Plans is checked in Light/Dark, including
annual pricing and navigation back. Light is restored with Plans open. No
customer inventory or answers were written. No migration, production deployment, new TestFlight
binary or public submission. See
`HANDOFFS/2026-10-14-launch-readiness.md` for verified capabilities and release gates.

## October 14 app-wide neutral controls, orange bottom navigation

The user expands this lane to all mobile UI accents and confirms orange should
remain only in bottom navigation. Shared action/selection roles are neutral;
navigation has separate orange tokens. GlassFab uses a grey frosted surface
with a readable icon and quieter shadow. Primary/filled/elevated controls,
category/appearance pills, chat controls, onboarding/tour accents, Teams icons
and invite surfaces inherit neutral styles. Decorative owner badges are also
neutral. Supplied brand artwork, accepted Home counts and semantic statuses
remain. Native iPhone 16e checks cover Find, Space filters/Add menu, Teams,
chat and onboarding, with Space/Teams/onboarding checked in both themes.
The final arm64 debug build is installed; Light mode is restored and Find is
open for review. No inventory/answer saves or chat submissions were made.
Flutter analysis is clean and all 357 mobile tests with coverage pass. A final
parallel run stalled during tooling cleanup; a clean serial rerun passes in full.
Proof is in `Documents/FindEZ/Design/mobile-colors-2026-10-14` using the
`*-neutral-controls-*-native.png` filenames. No new TestFlight upload or public
submission; TestFlight remains build 64.

## October 14 neutral Capture and Find selectors installed in simulator

The user confirms the two requested controls are Scan Barcode/Auto Extract and
Spaces/Teams. Both now use neutral grey glass with primary-text labels/icons;
navigation palette and motion are retained. Existing FrostedSurface handles blur
and the solid high-contrast fallback. Analysis and all 357 mobile tests with
coverage pass. A full arm64 iOS Simulator build is installed and launched on
iPhone 16e (iOS 26.2), replacing the older installed preview. Capture, both Find
selection states and the accepted Home numbers/hints are visually verified.
Proof is in `Documents/FindEZ/Design/mobile-colors-2026-10-14`. This is a local
debug app, not another TestFlight delivery; TestFlight remains build 64.
The user finds Capture's first grey pill too heavy. A Capture-only refinement
lightens its tint and outline and keeps both labels at regular weight. Analysis
and all 357 tests pass again. The rebuilt app is installed and Capture is
visually checked in both themes, then returned to Light mode for review.
Proof: `capture-soft-grey-glass-native.png` and
`capture-soft-grey-glass-dark-native.png` in the same design folder.
Initial native builds hit disk exhaustion. Generated compiler cache and the
temporary build-64 verification extraction were cleared after the durable
release IPA/archive hashes were reverified. Release artifacts and app data are
preserved. Wait for further page instructions; no broad palette pass.

## October 14 Home-only number colours and smaller placeholder

`feat/mobile-color-accents` in `dev/findez-mobile-color-accents` is based on
`3a36026`. The user rejects coloured card fills and scopes this pass to Home.
Only decision numbers use mustard (identifying), purple (to buy), maroon
(out of stock) and forest green (lent), including zero; unknown values remain
neutral dashes. Cards and labels retain the neutral baseline. The white search
field has a 14pt regular grey hint and 17pt entered text; suggestions use 12pt
regular grey text. Other-page experiments are removed from the candidate.
Analysis and all 357 existing mobile tests with coverage pass. All four number
colours and the hint meet 4.5:1 contrast in both themes. The running iPhone 16e
debug simulator is refreshed through Flutter attach/hot restart, and Home is
visually verified with native fonts/icons. Native proof is in
`Documents/FindEZ/Design/mobile-colors-2026-10-14/home-numbers-light-native.png`.
No new binary is uploaded: TestFlight remains 64. Wait for the user's next-page
instructions; no broader palette or layout pass is authorized.

## October 14 backend fixes live; mobile 64 delivered to internal TestFlight

`fix/capture-review-save-boundary` in
`/Users/tanyasmritivictorcharles/dev/findez-capture-save-boundary` is based on
punctuation record `722b5c0`. New mobile/web Capture requests use `preview_only`;
the backend returns signed, account-bound previews without creating Review
rows. Explicit Save persists uncertainty with its original photo/evidence and
retry-safe identity. Chat photo analysis no longer writes Review at all.
All 438 backend/API documentation tests and six subtests, 212 web tests,
TypeScript, changed-file lint (existing warnings only), 357 mobile tests and
Flutter analysis and the placeholder-config production web build pass. Runtime
`19089e9` in Draft PR #68 passes all five CI gates (`38551614029`). Before
deployment, eight existing backend hashes matched the baseline and both new
helpers were absent. The exact combined ten-file backend bundle, patches and
manifest are in `Documents/FindEZ/Releases/capture-save-boundary-2026-10-14`.
The user authorizes deployment. The ten backend files are selectively deployed
with guarded hashes and backups at
`/home/ubuntu/findez-capture-fixes-20261014.1ztxtg/backup`; unrelated checkout
files are hash-verified unchanged. Service/database health pass, and missing
session/invalid integration-key requests return 401. Read-only production checks
verify reply punctuation, real preview signing, owner binding and the signed
save route without database writes or FIND/model calls. Deployment/live receipts
are beside the source bundle. No migration or historical Review deletion was
performed. New chat/photo behavior is live; updated web source is not deployed
and older Capture clients keep the old contract.

Mobile 1.0.8 (64), runtime `8001b13`, is VALID, APP_STORE_ELIGIBLE and
IN_BETA_TESTING in both existing internal groups, Testers and Internal Pilot
Findez AI, verified at 04:54 PDT October 14. All five exact-runtime CI gates
pass (`38554740296`), along with clean signed archive/export, production
configuration, supplied assets, strict app/extension signatures and all 31
native device-platform checks. Apple validation/upload and processing complete
without errors or warnings, delivery `3dc129af-4c32-48f7-a69d-d55c9e97cdef`.
Receipts, archive/IPA and the phone checklist are in
`Documents/FindEZ/AppStore/1.0.8-build64`. IPA SHA-256:
`a14d1d143abb399f37871fe8fbb16b712d3147d643572bbf0f4d0ac5bd28e393`.
Build 64 enables preview-only extraction and explicit Save with the deployed
backend. No build-64 simulator or physical-device acceptance is claimed;
repeat camera/library upload-cancel-Home, photo chat, explicit Save/retry and
account isolation on a phone. TestFlight 63 remains available with its legacy
Capture contract. Public 1.0.7 stays selected on 59; draft 1.0.8 remains
unselected with manual release. Public App Review and Shopify remain held.

The user subsequently requests build 64 for an existing external tester.
`Vinod Private Testing` contains only that tester, has no public link, and has
build 64 assigned. At 05:08 PDT October 14, beta submission is
WAITING_FOR_REVIEW/WAITING_FOR_BETA_REVIEW, with automatic notification enabled.
Apple rejects a repeat invitation as ALREADY_ACCEPTED; no new invitation was
sent and external build-64 availability is not yet claimed. Existing internal
access continues, the broader External Pilot group has not received 64, and
public App Store selection/release type remain unchanged. Targeted receipts
and the delivery helper are in the build-64 release folder.

## October 14 chat punctuation candidate

Backend-only `fix/ask-response-punctuation` is based on mobile release record
`1604e68`. A shared instruction and reply formatter remove em dash punctuation
from new text, photo, project and document chat replies before emission and
persistence, including legacy EEZY. User messages, tool data, inventory and
answer source/navigation snapshots are unchanged. Existing history is retained.
All 426 backend/API documentation tests and six subtests pass. Runtime `3b1c824`
in Draft PR #67 passes all five CI gates (`38548331842`). Preflight matched four
existing live hashes and confirmed the new helper absent. The exact
five-file bundle, patch and hash manifest are preserved in
`Documents/FindEZ/Releases/chat-punctuation-2026-10-14`. This change is live in
the combined backend deployment above; no migration or new binary is needed.
Shopify remains paused and public App Review remains held.

## October 14 build-63 internal TestFlight delivery

Build 1.0.8 (63) is VALID, APP_STORE_ELIGIBLE and IN_BETA_TESTING in both existing
internal groups, Testers and Internal Pilot Findez AI. Final runtime `8abe3cc`
on `feat/mobile-submission-polish` (PR #62) passes analysis, all 353 mobile tests
with coverage and all five CI gates in `38543470459`. Clean signed archive/export,
production configuration, supplied assets, strict app/extension signatures and
all 31 native device-platform checks pass. Apple validation/upload succeeds;
delivery `81fcc8ae-92f0-4d05-9dd0-e4a0a492e0c1` is COMPLETE without errors/warnings.
Group access and updated test notes are verified at 02:56 PDT October 14.

The beta includes Home Account access and four core tabs, stable regular/medium
weights independent of OS Bold Text, focused chat, concise import, plain setup X,
compact tour, spring navigation, supplied branding and Light default. Neutral
Appearance, inventory/scan choices and scan/QR/import/sharing/save actions use
`GlassControl`, preserving callbacks, busy/disabled states and high contrast.
The native preview caught RawChip's opaque canvas covering the glass outline;
a local transparent canvas fixes it. Light/Dark choices now render continuously.

Native build/install/launch, Home/Account routing, image-backed captures,
Light/Dark Appearance, plain-X setup and empty Ask are observed on iPhone 16e
(iOS 26.2). Automated text entry/paste could not submit a native chat prompt;
active chat/Back/stream acceptance still needs the final phone binary. Other
physical accessibility, camera/barcode, voice, provider auth, APNs, share handoff,
account isolation, full tour/import and store-artwork checks remain pending.
The simulator app is restored to Light; no inventory or setup-answer writes
were performed. No production deployment or schema change is part of this lane.

Durable archive/IPA, verifier, receipts, CI/tests, native screenshots and phone
checklist are in `Documents/FindEZ/AppStore/1.0.8-build63`. IPA SHA-256:
`d9fe4c008add1fd5f35e65fe5cc37bb58bca2596ec759cd8a1a1c62e2b8a6dea`.
The validated pre-glass candidate was never uploaded and is preserved in
`1.0.8-build63-before-glass`. Public 1.0.7 remains selected on 59; draft 1.0.8
is unselected with manual release. Public submission is held. Shopify stays
paused, preserved separately and excluded from this launch.

## October 14 launch excludes Shopify

The user pauses Shopify and keeps it for a later release. Preserve its separate
source lanes, draft PRs and development app/store. This mobile release lane
contains no Shopify client feature or backend configuration. Do not bring its
connector, linked physical-memory UI, owner edits, merchant guide or migrations
042 through 045 into the current launch. Resume Shopify only on a new user request.

## October 14 Home account control and lighter typography in source

Latest continuation moves Profile out of the pill, leaving four core destinations:
Home, Capture, Ask and Find. A small Home header control opens Account and its
existing utilities, with a Back route to the retained Home. Avatar edits and
live unread counts use the same owner-bound store/notifier; late count responses
cannot undo an inbox read. Four-tab indicator geometry preserves the existing
spring, stretch, fixed icons and reduced-motion behavior. Chat focus stays intact.

Shared typography now keeps body and inputs at 400 and caps emphasis at 500,
independent of OS Bold Text. Theme controls, AppText, editable fields and answer
styles use that policy. The old per-screen bold overrides and stored OS-weight
preference are removed. Larger Text, app text size, semantics and other
accessibility settings remain. The changed typography regression fails before
the fix; local full suite passes all 349 tests with coverage and analysis is
clean. Actual-widget Home renders are byte-identical with Bold Text on/off in
Light/Dark; Account and four-tab layouts are also checked. These changes are delivered in internal build 63. Physical acceptance remains
pending. No production or public submission change; Shopify stays excluded.

## October 14 focused chat and concise spreadsheet import in source

Latest mobile-only continuation on `feat/mobile-submission-polish` adds a minimal
spreadsheet ready view and conversation focus within the existing shell. A sent
message hides the pill; pinned Back restores the previous tab without replacing
ChatPage or losing its draft, conversation ID or streamed reply. Re-entering Ask
resumes that conversation, and New chat restores tabs and the empty prompt.
Import validation, processing, failures and actual result counts remain intact.
The original focus regression fails before the fix. Light/Dark, retained request/
draft, reset, previous-Find return, keyboard/large-text and pinned-scroll checks
are in `mobile/test/chat_focus_test.dart`. Local analysis and all 350 mobile tests
with coverage pass; the full local suite uses `--concurrency=1` after the parallel
run stalled and was stopped. Final build-63 source passes all five CI gates.
Actual-widget sample renders cover both themes, with narrow/large-text import
layouts, preserved in Documents/FindEZ/AppStore/mobile-polish-20261014.
These changes are delivered in build 63. Physical chat/import acceptance and
public review remain pending; Shopify stays paused and excluded.

## October 13 mobile pre-submission polish in source

Lane `feat/mobile-submission-polish` in `dev/findez-logo-light-default`, based on
delivered build-62 context `fdec959`, implements the user's latest mobile requests:
no questionnaire wordmark, an accessible plain small X, omission of pictureless/failed
Home thumbnails, compact frosted tour cards with a light scrim, and simple Ask
copy. One navigation pill slides and stretches up to 1.4 while the surface pulses
to 1.06 over 350 ms. Icons and touch targets stay fixed. Reduce Motion cross-fades
without scaling/stretch; high contrast uses solid surfaces.

The supplied October 13 logo ZIP replaces mobile wordmark/mark/icon assets byte
for byte, regenerates native icon sizes, and updates shared web branding. Light
is the default for missing/invalid appearance preferences; saved choices remain.
All 346 mobile tests with coverage and clean analysis pass. All 211 web tests,
TypeScript and production webpack build pass. Sample Light/Dark tour and navigation
renders pass. Exact source `7317590` passed all five CI gates in `38514764506`
(draft PR #62). The subsequent plain-X correction passes 26 onboarding tests.
The iPhone 16e iOS 26.2 native simulator build/install/launch passes; actual Light
questionnaire shows the small X with no background circle or wordmark. The initial
disk failure was recovered by user-approved removal of generated task caches.
These changes are included in internal build 63. Physical acceptance is pending;
no App Review submission or production deployment is performed.

Six iPhone and six iPad screenshots from the supplied ZIPs are COMPLETE in the
1.0.8 en-US draft, in supplied order with verified source MD5 checksums and image
dimensions. Durable assets, manifests and upload receipts are in
`Documents/FindEZ/AppStore/screenshots-20261013`. Version 1.0.8 remains
PREPARE_FOR_SUBMISSION, manual release, with no build selected. The optional
wide creative header is separate from these screenshots. Separate Shopify source
lanes remain disabled, unshipped and paused for a later release; the production
schema is unchanged.

## October 12 setup questions, guided tour and concise Auth delivered

- Runtime `346d9ae`, draft PR #59 stacked on #58, replaces promotional onboarding
  with four optional questions: use, inventory types, goal and collaboration.
  The final user reference is followed with centered FindEZ typography, full-width
  icon choices without radio circles, restrained glass and finite reduced-motion
  transitions. Auth has one heading, inventory copy and optional work-detail
  expansion; identity, provider, recovery and signup eligibility/Terms gates remain.
- Account-bound local pending answers sync after sign-in. Confirmed saves, visible
  retry, serialized edits and Profile → Setup questions are implemented. Migration
  041 stores the latest owned answers in `onboarding_responses`, separate from
  inventory/Teams, with owner reads, backend-only writes, integration-key exclusion
  and auth-account deletion cascade. Operator queries are in
  `docs/onboarding-answers.md`; no admin UI or tracking provider is added.
- Migration/API and public privacy disclosure are live. Backup/database dump,
  composed dirty-router preservation and deployment receipts are under
  `/home/ubuntu/findez-onboarding-20261012`. Active web release is
  `/home/ubuntu/findez-web-releases/web-onboarding-questions-20261012/frontend`;
  unrelated source/config and 813 prior static assets are retained. Public Privacy
  has the October 12 date; unchanged Terms retain October 11. Dedicated review
  account save/read/idempotency and owner-override rejection pass; only its newly
  created QA answer row was removed, restoring its initial state.
- The actual six-step spotlight tour uses concise target-specific instructions,
  opaque theme cards, adaptive measured layout and real Next/Back/Skip controls.
  All 338 mobile tests with coverage and clean analysis pass. Native iPhone 16e
  iOS 26.2 questionnaire completion, selected/multiple-choice accessibility and
  Light/Dark/Auth screenshots pass. All five exact-source CI jobs pass in
  `38346877463`, including 419 backend, 211 web and PostgreSQL isolation checks.
- Clean signed 1.0.8 (62) archive/export, production configuration (actual
  `PREVIEW_ONBOARDING` disabled), strict app/extension signatures, all 31 native
  device executables and Apple validation pass. Upload
  `3ab7200b-5045-499f-accb-2d5f4f7b6f2c` is COMPLETE without errors/warnings;
  build 62 is VALID, APP_STORE_ELIGIBLE and IN_BETA_TESTING. Both existing internal
  groups and saved test notes are verified at 21:49 PDT October 12. Durable IPA,
  archive, receipts, verifier, screenshots and phone checklist are in
  `Documents/FindEZ/AppStore/1.0.8-build62`. IPA SHA-256:
  `ed2721cb8a610a9604e1fb5e9e5bc28264d4ff08ad81fb42628867ec2f259017`.
  Released 1.0.7 (59), manual/unselected 1.0.8 and requested name/subtitle are
  verified unchanged. Physical phone acceptance remains deferred; public App Store
  submission remains held. The build-61 introduction below is historical and
  superseded; the simulator is left on the clean Dark sign-in preview.

## October 12 general inventory categories and walkthrough

- Category source `2384bbd`, draft PR #57 stacked on #56, passes all five CI jobs
  in `38312460669`. 398 backend tests, 211 web tests, TypeScript/changed-file
  ESLint, 319 mobile tests with coverage, clean analysis and disposable PostgreSQL
  category/permission checks pass. Migration 040 is live, preserving all five
  Teams and the existing plan constraint. Five selected backend files are deployed;
  the live Team document access guards are retained in the composed workspace file.
  Backup, migration and verified hashes are in
  `/home/ubuntu/findez-categories-20261012`. API/database health and unauthenticated
  Team-create 401 pass; no real Team or inventory is created for QA.
- Web categories and truthful Space-delete confirmation are live from
  `/home/ubuntu/findez-web-releases/web-inventory-categories-20261012/frontend`.
  Server 211 tests and production webpack build pass. Candidate/public checks
  verify 17 actual authenticated pages, six redirects, public legal documents,
  16 current static assets, exact integration downloads, production origins and
  category bundle markers. All other live source/config is preserved, including
  three unrelated styling files; 758 previous static files remain available.
  Restore `previous-web-rebuild.conf` from that release and restart only the web
  service for rollback.
- GitHub About, README, mobile setup, current product context, learning guide,
  legacy EEZY prompt and customer Team copy describe homes, businesses, labs,
  teams and industry. Editable App Store 1.0.8 has the exact requested name,
  subtitle and broader description; no public review submission or build selection
  is made. Categories are descriptive and do not change plans/access.
- `fix/onboarding-light-dark`, based on `2384bbd`, simplifies the four local
  onboarding examples, shortens copy, removes diagram clutter and uses explicit
  Light/Dark contrast and general inventory examples. All 319 mobile tests and
  clean analysis pass; rendered pages in both themes and 320pt layouts through
  3.4x text are checked. Native iPhone 16e iOS 26.2 compilation and walkthrough
  interactions pass in Light/Dark, including completion and persisted restart.
  All five CI jobs pass on runtime `86669ee` in `38314482069`. Apple validation
  rejects its first 1.0.8+61 export because `objective_c.framework` contains
  simulator slices (90087/91169). The failed signed package and receipts are
  preserved in `Documents/FindEZ/AppStore/1.0.8-build61-validation-rejected`.
  The clean replacement on runtime `5acd4c7` passes all five CI jobs in
  `38336413029`, strict app/extension signatures, production configuration and
  device-platform checks for all 31 Mach-O executables. Apple validation/upload
  pass without errors; delivery `f6a6c33f-7c34-4091-8df7-1c4ebf35e274` is accepted
  at 19:27 PDT October 12. Apple processing is COMPLETE without errors/warnings;
  build 61 is VALID, APP_STORE_ELIGIBLE, nonexpired and IN_BETA_TESTING. Both
  existing internal groups are verified at 19:31 PDT and test notes are saved.
  The clean archive, IPA, checksums, receipts, verifier
  and phone checklist are preserved in `Documents/FindEZ/AppStore/1.0.8-build61`.
  IPA SHA-256 is `527205291de7a52f6c1fff593a7f15acaffa7abc11e9eb830916e6b33c2c22c3`.
  Physical acceptance remains deferred. Released 1.0.7 (59) and manual/unselected
  1.0.8 draft states are verified unchanged after delivery; requested name/subtitle
  remain saved. The historical gateway proposal now explicitly defers to the
  deployed architecture and covers homes, businesses, labs, teams and industry.

## October 12 Space deletion and review lifecycle candidate

- `fix/deleted-space-review-refresh`, based on delivered build 60, adds migration
  039: pending identifications gain an owned stable Space link, cascade when the
  Space is deleted, and retain that link across rename/location edits. Existing
  matching owned records are bound; unassigned records and other users remain
  separate. Full PostgreSQL 17 permissions/documentation suite plus lifecycle,
  foreign-owner and failed-transaction regressions pass in a disposable container.
- Mobile confirms the delete response, invalidates old Find/cache reads, removes
  the deleted Space locally and refreshes Home. A failed review refresh shows an
  unknown count instead of retaining a known-obsolete value. All 317 mobile
  tests with coverage and clean analysis pass, including actual-shell Light/Dark,
  failed deletion/refresh and delayed warmup cases. Web confirmation copy now
  describes the existing destructive behavior accurately. All five exact-runtime
  CI jobs pass on `e3bb2f6` in `38310437658` (draft PR #56). Migration 039 is live;
  its cascade FK and both triggers are verified, all 83 pending records remain,
  and six owned matching records are bound. Database health passes. The private
  pre-migration backup and exact applied SQL are in
  `/home/ubuntu/findez-space-review-20261012`. No new native binary is yet delivered;
  web confirmation copy will deploy with the broader category lane.
- Read-only production schema confirms missing review-Space linkage and zero
  ambiguous names. The user's privately identified account still has Robot Room
  and six pending records, so these are not automatically purged as orphans.
  Migration backfill will associate them with that Space; the next confirmed
  deletion removes them. No real user Space or inventory is deleted for QA.

## October 12 TestFlight delivery and public release status

- The user authorized upload and internal TestFlight delivery. Apple reports
  App Store 1.0.7 selected build 59 as `READY_FOR_SALE`, release type `MANUAL`.
  The US storefront confirms 1.0.7, released `2026-10-12T01:59:13Z`. No public
  release or review-selection action is performed by this delivery lane.
- Apple validation rejected the original 1.0.7 (60) package with closed-train
  `90186` and version `90062` errors after approval of 1.0.7. Only
  `mobile/pubspec.yaml` changes to 1.0.8+60 in runtime `a6ea4c5`. Signed archive
  and export pass; strict app/ShareExtension signatures, unexpired App Store
  profiles, disabled debugging, production API/auth/APNs, anon-role client key
  and compiled feature markers are verified. All five runtime CI jobs pass
  in `38302159412`; original candidate simulator checks apply to identical code.
- Apple validation and upload pass without errors. Delivery
  `87711752-2586-445c-a2a5-ebc12e7b4b94` was accepted at 13:17:03 PDT October 12.
  Apple processing is `COMPLETE` without errors/warnings; the build is `VALID`,
  `APP_STORE_ELIGIBLE`, nonexpired and `IN_BETA_TESTING`. Both existing internal
  groups (`Testers` and `Internal Pilot Findez AI`) include 60, and its test notes
  are saved. Released build-59 selection/release type are verified unchanged.
  The durable package, receipt, script, checksums, phone checklist and report are
  in `Documents/FindEZ/AppStore/1.0.8-build60`. IPA SHA-256 is
  `ab3a606d28932f5d581b2ba3497733c5db9b711a1d5869b5dcc473b3b80401b1`.
  The rejected 1.0.7 artifact remains preserved in its original prepared folder.
  Physical acceptance is deferred by the user; TestFlight availability does not
  prove physical delivery,
  browser legal links, camera/library/voice or account-change behavior.

## October 11 mobile notification candidate

- Prepared on `fix/mobile-notification-permissions` based on legal deployment
  `5b21899`. Existing OS permission can reconnect on launch/resume; a new prompt
  only follows the inbox's Enable action. Denied permission points to Settings.
  Native registration has a 30-second bound and cannot overwrite an outstanding
  result; Dart serializes it and rejects account changes before device writes.
  Device requests capture auth headers. Logout stops OS delivery and clears
  delivered/pending alerts; the next registration reassigns the device token.
- Inbox opening no longer marks everything read. Explicit reads re-fetch,
  preserve newly arriving unread events, retain rows with visible failure copy,
  validate server counts and refresh on visible/resumed timers. Shell counts
  consume fresh snapshots and invalidate late responses. Shells are keyed by
  user and old routes close on account changes. Local stock refreshes no longer
  request permission without a chosen threshold/reminder action. Feed rows are
  plain, with meaningful unread state and no decorative dividers/test button.
- All 312 mobile tests with coverage, clean analysis, Swift parse and native
  simulator compilation pass. Candidate version is 1.0.7 (60), with verified
  production API/auth inputs and no onboarding preview. The user asked to prepare
  it and will test physically later; `devicectl` currently reports the iPhone
  unavailable. Actual camera/library/voice, browser legal links, APNs delivery
  and account-change/foreground/background acceptance are not claimed as passed.
  Signed archive and App Store export completed before interruption. October 12
  verification confirms strict app/ShareExtension signatures, unexpired App Store
  profiles, disabled debugging, production APNs/auth/API, public anon-role client
  key, canonical legal/inbox markers and new native registration handlers in the
  compiled app. All five runtime CI jobs pass on `37c5055` (`38210945770`), draft
  PR #55 stacked on #54. Durable IPA/checksums, verification script/JSON, phone
  checklist and legal/privacy follow-up report are saved in
  `Documents/FindEZ/AppStore/1.0.7-build60-prepared`. IPA SHA-256 is
  `4f07de9e189809ef219a9cf9aa5558cd8a16a1231184b6be188882f7e5c208bc`.
  Existing default launch-image asset warning remains; the native storyboard
  uses the FindEZ text wordmark. No Apple validation/upload/submission occurred
  for 60. Physical checks remain deferred by the user; do not present this local
  package as a TestFlight delivery or change build 59's review selection.

## October 11 canonical legal pages and mobile links

- Web source `1e6a8b3` is live from
  `/home/ubuntu/findez-web-releases/web-canonical-legal-20261011/frontend`;
  draft PR #54 is stacked on notification PR #53. All five CI jobs pass on
  `d459df3` (`38209066849`), which adds the native signup Material correction
  needed by the newer Flutter CI version; its web source is identical.
  Privacy and Terms now share readable public layouts, current factual content,
  working section links and canonical URLs. Mobile opens those HTTPS documents
  in the browser with retry/copy fallback. Redundant public feature pages redirect
  to their actual authenticated tools; the old mega menus are removed.
- Only essential authentication and requested feature storage are in use. The
  informational cookie notice can be dismissed without accepting Terms or
  enabling tracking. No analytics or advertising provider is installed. Signup
  requires an eligibility/Terms acknowledgment and stores a timestamped receipt
  in user metadata. This is an attestation, not verified age or immutable legal
  evidence; sign-in OAuth can still create an account after the continuing notice.
- Official California registry lookup on October 11, with the user's CAPTCHA
  authorization, confirms AI ROBOTS INC (4578465), Active, filed March 16, 2020,
  principal and mailing address 887 Poppy Ct, Sunnyvale, CA 94086. No private
  agent information is published. The legal contact is info@findez.ai.
- Read-only deployed Edge function inspection confirms document/image cleanup
  and ordered owned-row deletion with failure propagation. Its SHA-256 is
  `e55c0a6df8bdaf0102fc6fdf7db048ee0739630117cc6fe81e41c21b067896c1`.
  No real account was deleted. Failed deletion can partially complete; UI and
  notice no longer imply that failure leaves all data untouched.
- Known limits are disclosed: inventory photos have link-accessible public URLs,
  a legacy photo-processing connection is unencrypted, and logs/backups do not
  have a verified comprehensive retention schedule. The user's October 4
  withdrawal of FIND transport changes is preserved. Text changes do not fix
  these engineering issues. Private image access, TLS, retention/processor audits
  and a documented privacy-request/breach procedure remain follow-up work.
- Counsel should review minor/guardian and school agreements, country-specific
  eligibility and data-transfer requirements, legal bases and processor terms,
  consumer remedies, liability limits and effective assent. Worldwide Apple
  availability and a 13+ checkbox do not establish worldwide compliance. Relevant
  primary guidance: [FTC schools and COPPA](https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions),
  [FERPA vendors](https://studentprivacy.ed.gov/resources/responsibilities-third-party-service-providers-under-ferpa),
  [EU children's safeguards](https://commission.europa.eu/law/law-topic/data-protection/information-business-and-organisations/legal-grounds-processing-data/are-there-any-specific-safeguards-data-about-children_en),
  [ICO storage exceptions](https://ico.org.uk/for-organisations/direct-marketing-and-privacy-and-electronic-communications/guidance-on-the-use-of-storage-and-access-technologies/what-are-the-exceptions/).
- Web: all 210 tests, TypeScript, changed-file ESLint and production webpack
  build pass. Safari verifies readable Privacy/Terms, section navigation,
  notice dismissal and absence of the old menus. All 301 mobile tests with
  coverage and clean analysis pass, including legal-link and signup gates;
  native camera/library/voice and
  push acceptance are required for a future binary. Build 59 App Review is held
  unchanged; this lane does not upload or resubmit it.
- Server build and 210 tests pass. Candidate/public checks verify both legal
  documents, canonical URLs, five redirects, 18 sign-in guards, static assets,
  exact API docs, production origins, headers and zero production dependency
  vulnerabilities. Both services are healthy; 702 previous static files are
  retained. Source manifest and rollback drop-in are beside the release. Safari
  confirms the deployed Privacy layout and absence of the old menus.

## October 11 notification inbox refresh

- Web runtime `0189a17` is live from
  `/home/ubuntu/findez-web-releases/web-notification-refresh-20261011/frontend`,
  draft PR #53 stacked on #52. Read state and bell snapshots stay in sync;
  stale requests and sender-document broadcast echoes are invalidated, visible
  inboxes refresh on focus/poll, and failed refreshes retain rows with an error.
  Read writes re-fetch instead of assuming no new events arrived.
- All 203 web and 380 backend/API-doc tests, TypeScript, webpack builds and five
  CI jobs pass (`38204481906`). ESLint has no errors and one generation-ref
  warning. Safari verifies a fictional update's unread marker and bell clear
  together. Production schema/APNs configuration checks are read-only; no actual
  push was sent. Physical APNs delivery and native permission/read races remain
  for the later mobile lane; existing App Review submission is preserved.
- Candidate and public title/headers, 18 page guards, static assets, exact API
  reference and production origins pass. 622 previous static files are retained;
  dependencies and all other live source stay unchanged. Restore the release's
  `previous-web-rebuild.conf` to the existing drop-in and restart only the web
  service for rollback. No backend runtime or schema is changed.

## October 11 professional web polish

- Runtime `6960b2d`, draft PR #52 stacked on #51, is live from
  `/home/ubuntu/findez-web-releases/web-professional-polish-20261011/frontend`.
  AI-only Source Sans 3, safe Markdown, collapsed Sources, plain history,
  message-scoped pending status, reduced decorative chrome, actionable Home
  attention counts, contextual pipe titles and remembered desktop pinning are
  delivered. Existing app fonts and routes are retained.
- All 195 web tests, TypeScript, webpack builds and five CI jobs pass
  (`38203294862`). Changed-file ESLint has no errors; existing warnings remain.
  Production dependency audit reports zero known vulnerabilities. Safari verifies
  dark/light replies, Sources, pin resizing, Home/settings/feed appearance and
  narrow navigation isolation. Local content was fictional, not recognition QA.
- Candidate and public HTTPS checks verify title/headers, 18 guarded pages,
  static assets, exact API docs and production origins. Unrelated live global
  CSS/dialog/import styling is preserved and 527 previous static files retained.
  Both services are healthy. Restore the release's `previous-web-rebuild.conf`
  to the existing systemd drop-in and restart only `findez-web` for rollback.
  Notification behavior and canonical legal/mobile content remain separate lanes.

## October 11 Ask photo reply clarity

- Shared backend runtime `fefcfe9` is deployed for web/mobile photo chat. Replies
  group duplicates, summarize stock and uncertainty once, skip generic unknown
  name matches and omit noisy categories. Scenes with several labels and no
  product identifiers use validated selection of up to three existing subject
  labels, with a bounded optional request and deterministic fallback. The
  original FIND evidence and Review records remain authoritative; this is not a
  guarantee of recognition accuracy or a rewrite of saved conversations.
- All 376 backend/API documentation tests and all five exact-runtime CI jobs pass
  (`38195426179`). Live synthetic-label consolidation took 4.66 seconds. Deployed
  hashes match; the configured `https://findez.openstack.ftctools.com` API passes
  health/database checks and rejects unauthenticated photo requests with 401.
  Backups and verification are in `/home/ubuntu/findez-ask-photo-20261011`.
  Draft PR #51 is stacked on #50. No client binary, web rebuild or migration is
  needed. New-photo user acceptance remains unverified.

## October 8 App Review corrections

- Apple rejected 1.0.7 (58), submission
  `2b777948-f7bd-46b3-bf43-9a2e60074361`, on October 7 with 2.1 AI information
  questions and 2.3.10 non-iOS screenshot status bars. Confirmed in the signed-in
  App Store Connect submission page. Public manual-release status is preserved.
- `fix/app-review-build58`, based on `669dde0`, prepares a policy-only candidate
  59. The developer confirms model inference runs on their servers. Current
  backend source and non-secret process settings route to their FIND and agent
  gateway, without OpenAI runtime/fallback. Submitted 58's mobile policy and Terms
  still contained obsolete OpenAI text. The replacement describes self-hosted
  photo/language processing, optional Apple Speech audio transcription, and
  separately configured external API assistants. Runtime AI behavior is unchanged.
- Native build-58 iPhone 17 Pro Max and iPad Pro 13-inch (M5) captures use the
  existing review account's five sample records. No inventory data is modified.
  One typed sample Ask returns the correct Space and quantity through the live
  service. Screenshots and review reply are preserved under
  `Documents/FindEZ/AppStore/1.0.7-review-fix`; originals remain preserved. All six
  iPhone captures are 1320x2868 and all six iPad captures are 2064x2752. Media
  Manager confirms every smaller family inherits the primary sets with zero
  separate uploads. Both native Ask tests return the correct Space and quantity.
- Runtime `68fbe55` passes Flutter analysis, all 296 tests with coverage,
  formatting and all five shared CI jobs (`37866116183`). Candidate 59 compiles
  for the simulator, opens the corrected policy date, and its compiled debug and
  release text contains the new disclosures without the obsolete OpenAI copy.
  Signed archive and App Store IPA export pass strict signature, App Store
  profile, non-debug, production API/auth and push checks. IPA SHA-256 is
  `f955090596197783cf3818b396c5ee040928f4f9f002630611cea08123e78296`.
- Draft PR #50 is stacked on #49. The durable folder contains the IPA, response
  draft, all 12 PNGs, screenshot ZIP, native policy first-page capture and
  verification records. Initial disk-space failures were recovered by approved
  rebuildable cache/dependency cleanup; all task-booted simulators were stopped.
  The user's continuation authorizes delivery of the prepared correction package.
  Apple validation passes without errors; upload accepted at 18:08:32 PDT,
  delivery `4c3ff9ff-6310-48cb-91ff-79c89af796d3`. All twelve native screenshots
  replace the original primary sets, pass Apple's COMPLETE processing and match
  their source checksums/order. App Store Connect verifies iPad's six direct
  screenshots and the inherited native iPhone set; no other direct sets exist.
  The four-answer AI clarification is sent and visible in Messages (2) at
  18:09 PDT. Apple processing is VALID/APP_STORE_ELIGIBLE, nonexpired, with
  encryption declaration false and internal state IN_BETA_TESTING. Build 59 is
  selected for 1.0.7 and the existing submission was resubmitted at 18:19:39 PDT
  October 8; both submission/version are WAITING_FOR_REVIEW. Release type is
  MANUAL. Physical-device acceptance has not been repeated; public release
  remains held. All five CI jobs also pass on docs head `28f8ffe` in run
  `37867707683`. Durable selected-build, upload-processing and resubmission JSON
  plus the guarded delivery script record the completed actions.

## October 8 landing copy and returning-user navigation

- Implemented on `fix/landing-dashboard-link` in
  `/Users/tanyasmritivictorcharles/dev/findez-web-navigation`, based on `f36ca25`.
  The user explicitly authorizes these landing edits after the interior release.
  The chatbot/database hero paragraph is removed without replacement. Signed-in
  landing visitors receive Dashboard linking to `/home` from server-verified
  identity, then browser session events keep the link current. Shared marketing
  desktop/mobile actions also replace signup/sign-in with Dashboard.
- All 184 web tests with coverage, TypeScript, changed-file ESLint and production
  webpack builds pass. Safari verified the live anonymous hero without the removed
  copy and signup action, then fictional local signed-in landing and desktop/mobile
  marketing Dashboard actions opening Home. The previous live browser session had
  ended; no new production login or data write was made. Final CI evidence is
  recorded on draft PR #49, stacked on the navigation branch.
- Deployed runtime `a4d1fc1` runs from
  `/home/ubuntu/findez-web-releases/web-landing-dashboard-20261008/frontend`.
  Candidate/live HTTPS checks verify the requested paragraph is the only landing
  visible-text removal, anonymous signup, all 18 workspace guards and exact API
  JSON. The production environment, 220 other source/config files, original dirty
  checkout, backend process, existing collection colors and prior static assets
  are preserved. Restore this release's `previous-web-rebuild.conf` to the existing
  systemd drop-in, reload systemd and restart only `findez-web` to roll back.
  Landing animation/assets, interior source, backend, mobile and schema are
  unchanged. Existing workspace server guards still authorize data.

## October 8 web navigation follow-up

- Implemented on `fix/web-navigation-hover` in
  `/Users/tanyasmritivictorcharles/dev/findez-web-navigation`, based on `5473694`.
  The earlier uncommitted temporary checkout was gone and was restored from the
  committed web rebuild. Workspace routes now share one persistent shell; each
  page still verifies authentication and keeps its existing URL and parameters.
- Content skeletons replace the full-page Opening message. Desktop navigation
  expands from 72px to 232px on mouse entry, collapses on exit, and overlays the
  page without changing its position. Keyboard labels, tooltips, reduced motion
  and the narrow focus-trapped drawer remain. Home/profile links close the drawer.
- All 181 web tests with coverage, TypeScript, changed-file ESLint and local and
  production webpack builds pass. All five runtime CI jobs pass in run
  `37861622831` on `0cc9f44`. Safari verified fictional local navigation and slow
  reads, then all 18 actual sidebar destinations, live Home data, hover/exit,
  stationary content and public API docs with theme cleanup. This was read-only;
  inventory, membership, key creation and profile saves were not tested by writes.
- Deployed runtime `0cc9f44` runs from
  `/home/ubuntu/findez-web-releases/web-navigation-hover-20261008/frontend`.
  Preflight verified all 18 anonymous workspace guards, public pages, preserved
  landing visible text and exact API JSON. Live HTTPS checks pass. The existing
  Smart Collections heading colors are retained as a recorded runtime override.
  Production environment, dirty original checkout and backend process remain
  unchanged. Prior static assets are retained. To roll back, install this release's
  `previous-web-rebuild.conf` over the existing `web-rebuild.conf` drop-in, reload
  systemd and restart only `findez-web`. Release manifests, build/preflight and
  activation records are beside the deployed frontend. Draft PR #48 is stacked
  on #47's web branch to keep the follow-up diff scoped.

## October 6 authenticated web rebuild

- `web/mobile-parity-rebuild` in `/private/tmp/findez-web-rebuild`, based on
  submitted build-58 record `1e36998`, rebuilds the web interior around the
  current mobile behavior. Draft review targets `release/appstore-build58`;
  targeting the old `main` would include unrelated stacked mobile changes.
- Permanent desktop labels, grouped feature links, searchable navigation,
  a narrow-screen focus-trapped drawer, mobile mark and a real-data Home make
  existing capabilities easier to reach. Spaces remains the actual flat
  personal/shared model; Teams retains its separate membership model.
- Find details follow mobile field order and include permission-aware personal,
  shared and Team photo galleries. Capture has full manual fields and JSON
  spreadsheet import. Existing review, lending, kits, labels, Team utilities,
  notifications, API keys and public documentation remain reachable.
- Ask handles text/photo streams, public answer context, confirmed conversation
  IDs and visible interrupted/save failures. Documents and notes use existing
  upload/rename/link/storage routes with retained failed drafts. Account changes
  discard stale responses and clear private views in rebuilt clients.
- Restock requires item opt-in, separates To buy from On order and confirms an
  absolute arrival count before clearing an order. Lost-response retries reuse
  the saved count. Personal/shared/Team stock uses existing permission-checked
  routes; viewers cannot write stock. Purchase plans remain account/browser-local
  and do not sync with mobile purchase plans or another device.
- Scoped `workspace.css` affects only interior classes. Landing source, its
  styling/assets, public API/downloads, backend, mobile, schema, billing and FIND
  are unchanged. Existing API documentation matches the mounted public router,
  so no contract regeneration was required. New form copy avoids em dashes.
- Local final checks: all 176 web tests across 24 suites with coverage,
  TypeScript, changed-file ESLint (0 errors, 38 warnings) and production webpack
  compilation/prerender pass. Shared exact-head CI status is recorded on the PR.
  Native Safari checks used a fictional local API: desktop Home/navigation, Ask
  query handoff and sources, Find/details/photos, document failure/draft retention,
  Restock ordering/arrival, Settings, 390px Home/drawer and manual Capture fields.
  No production inventory or membership was mutated. Light/Dark theme logic is
  covered by tests; this browser pass observed the device's dark theme.
- Deployed to the existing self-hosted Ubuntu server at `www.findez.ai` on
  runtime `afea356`. `findez-web` runs from
  `/home/ubuntu/findez-web-releases/web-mobile-parity-20261006-live/frontend`
  through its existing Caddy/nginx proxy and production environment. Backend
  service `findez` is unchanged and both services are active. Vercel and Render
  are retired hosting targets and were not used for this deployment.
- The dirty VM checkout was preserved. The isolated release overlays only this
  lane's frontend changes plus the reviewed theme-provider dependency; it keeps
  the VM's unrelated import success colors and all 160 other staged files,
  including deployed public assets/styles/configuration. Production build,
  self-hosted bundle origins, static assets, anonymous guards, HTTPS public
  pages, original landing visible text and exact public API JSON are verified.
- Native Safari observed actual Home data, Documents, Restock and Settings.
  Profile fields and the saved header/sidebar photo load correctly. Legacy
  pending signup completion is bounded to one attempt per account per mounted
  shell to prevent USER_UPDATED recursion and profile API throttling. Save stays
  disabled until profile loads; photo uploads use the backend's `photo` field.
  No inventory or membership was mutated during these checks.
- Previous builds and immutable assets are retained. Deployment, preflight and
  activation JSON records live beside the release. To restore the original web
  build, remove only this task's
  `/etc/systemd/system/findez-web.service.d/web-rebuild.conf`, reload systemd
  and restart `findez-web`; preserve the existing network drop-in.
- Ignored local fixture/environment/build output was excluded. Full live
  multi-account, file upload/storage and collaboration acceptance was not
  repeated and is not claimed. Purchase plans remain browser-local.

## October 5 App Store submission

- The user's final instruction authorizes checking the current mobile app and
  submitting to Apple, superseding the earlier screenshot hold. FindEZ AI
  1.0.7 (58), runtime `9657aed`, was submitted at 2026-10-06 06:06:37.722 UTC
  (October 5, 11:06 PM PDT). Both the version and submission report
  WAITING_FOR_REVIEW. Submission ID: `2b777948-f7bd-46b3-bf43-9a2e60074361`.
- Manual release is preserved. Existing public 1.0.6 (17) remains available
  during review; Apple approval does not automatically publish this update.
- Six supplied 1320x2868 iPhone screenshots and six supplied 2064x2752 iPad
  screenshots are uploaded in order, COMPLETE, with matching original MD5s.
  Earlier draft artwork was backed up before replacement. Original supplied
  screenshots and logo assets were not edited.
- Description, subtitle, promotional text, keywords, release notes and review
  instructions are saved and verified without em dashes. Copy follows the
  supplied AI-memory-for-the-physical-world vision while advertising only the
  current Capture, Ask, Find, sharing and personal-device purchase planning.
- The reviewer account signs in and loads eight live read endpoints. Six
  consecutive inventory reads consistently return five sample items. Public
  support/marketing and privacy URLs return 200. All five exact-runtime CI jobs
  pass in run `37412454402`, including mobile analysis and coverage tests. The
  existing release manifest records 296 mobile tests and Apple/signature checks.
- This pass observed populated simulator Home and Spaces. Further native UI
  automation became unavailable. Full physical-device acceptance was not
  repeated and is not claimed. No inventory, membership, runtime, backend,
  schema, billing, native lifecycle or FIND transport change was made.
- Submitted text/checks are in `appstore/metadata.json` and
  `appstore/submission.json`. Durable original artwork and records are at
  `/Users/tanyasmritivictorcharles/Documents/FindEZ/AppStore/1.0.7-build58`.

## Earlier October 5 simulator preparation

- The earlier user instruction paused immediate Apple submission and asked for a newly
  built simulator so they can capture current screens and recreate artwork.
- App Store 1.0.7 now selects valid/eligible build 58, with MANUAL release and
  PREPARE_FOR_SUBMISSION. Description, release notes and review instructions are
  saved without em dashes. The dedicated review account signs in successfully.
- Supplied iPhone and iPad ZIPs were inspected and extracted without editing.
  Their UI differs from the release source, including Mark as taken. No new
  screenshots have been uploaded and no review submission has been created.
- Simulator runtime source is `9657aed`, the exact source of TestFlight 58.
  The ARM64 Debug build succeeded after approved cleanup of regenerable caches
  corrupted by disk exhaustion. Production API/Supabase configuration and public
  anon role match the release environment; source remains unchanged and clean.
- Build 1.0.7 (58) is installed and launched on iPhone 17 Pro and iPad Pro 13-inch
  (M5), both iOS 26.2. Installed bundle metadata confirms 58 on both. Actual SDK
  screen captures verify populated Home on iPhone and onboarding on iPad.
  Native UI automation became unavailable, so final screen verification used
  the iOS Simulator SDK screenshot command. This is simulator verification, not
  a physical-device acceptance pass. The user can take fresh captures with Save
  Screen or Command-S. No inventory or membership edits were made.
- Simulator app is retained at
  `/private/tmp/findez-build58-simulator-cache/Build/Products/Debug-iphonesimulator/Runner.app`.
  Signed release archives, IPAs and manifests are preserved. Public release and
  screenshot upload remain pending the user's replacement artwork.


Last reviewed on 2026-10-05 during scoped launch-blocker fixes.

## Restrained mobile accents and monochrome Teams (October 5)

- `fix/mobile-accent-consistency` in `/private/tmp/findez-accent-consistency`,
  Draft PR #46 stacked on restock PR #45 (`64c4e47`), delivers internal TestFlight
  build `1.0.7 (58)` on runtime `9657aed`. The user rejected build 57's orange
  Teams list as too orange and requested this page black and white. Create,
  Join and Team-row icons now use neutral foreground; the selected Teams
  segment and bottom-nav highlight are neutral while this page is active.
  Team Documents icons are also neutral, retaining distinct file-type glyphs.
- Other main screens and the Team workspace retain restrained orange action/
  selection roles from build 56: original Signal for filled primary actions,
  readable orange foreground derivatives and 8% selected-control tints in
  Light/Dark. Surfaces and most text remain neutral. Genuine warning/error/
  success meanings, supplied logos, photos and personal avatar colors remain.
  Active purchase counts retain orange with To buy/On order labels and cart/
  delivery icons; zero counts stay neutral. Stock writes, purchase persistence,
  permissions, routes, layouts and shared typography are retained. No backend/
  web/schema/billing/FIND/native lifecycle change.
- Clean analysis and all 296 mobile tests with coverage pass, including existing
  large-text, navigation, save/error, stock and brand-contrast regressions.
  Both themes' actual-shell previews of the five tabs and populated Teams list
  -> workspace -> Documents pass with stubbed data. The complete monochrome
  list/segment/nav and all document glyphs were visually inspected; switching
  to another tab restores its standard shared brand styling. Build 56's earlier
  Team preview covered only its workspace and missed the separate list palette.
- All five exact-source CI jobs pass on `9657aed` (`37412454402`). Signed archive/
  export, deep strict signature, packaged production configuration/public anon
  credential, original SVG/native icon checks and Apple validation pass.
  Apple validation reports no errors at 21:14:19 PDT October 5. Apple accepted
  delivery `b9a53267-2cea-4d13-903f-a885f9e62351` with no upload errors at
  21:16:01 PDT October 5. Processing is COMPLETE/VALID with no errors/warnings;
  APP_STORE_ELIGIBLE, nonexpired and both internal groups (Testers and Internal
  Pilot Findez AI) are verified at 21:20:52 PDT.
- Final archive/IPA and manifest are preserved under
  `/private/tmp/findez-build58-native` and
  `/private/tmp/findez-build58-verification.json`. IPA SHA-256:
  `7673f09a77e21194ac41984b8f89f11f3f58bc7b9c581c3c6cd94da410053d4d`.
  Builds 56 and 57 remain VALID in both internal groups with native artifacts
  and manifests preserved under `/private/tmp/findez-build56-native`,
  `/private/tmp/findez-build57-native` and their matching verification JSON files. Build 57's initial missing-defines export was rejected before upload;
  the verified final IPA and source `6037389` passed all release gates. The
  user's TestFlight screenshot showed its orange list and rejected that density.
  Build 55 passed checks but was not uploaded after the palette request.
- The user chose final verification through TestFlight; physical build-58
  visual/stock/notification acceptance remains unverified. Public App Store
  review and publication remain held.

## Restock planner replacement (October 5)

- The user reported that Shopping List checked items still appeared as needing
  restocking in Find. Checkmarks only persisted an ordered selection; the old
  banner independently counted quantity against thresholds. Replace that mobile
  destination with a Restock planner on `feat/mobile-restock-planner` in
  `/private/tmp/findez-restock-planner`, based on build-53 record `3a08fd1`.
  Build `1.0.7 (54)` is available internally; Draft PR #45 is stacked on
  typography PR #44. The compact follow-up candidate is `1.0.7 (55)`.
- To buy and On order are separate, persisted states. Find/Space summaries,
  Home's To buy action, Ask's summary and the shared Space Restock tab use the
  same purchase rules. Mark ordered immediately stops requesting that purchase;
  it does not change physical stock. Editable quantities, Move to To buy,
  per-item removal, an inventory chooser and copying only the to-buy list are
  available. New post-capture planning chooses specific items rather than
  applying threshold 1 to every item in the category.
- Record arrival asks for the actual total on hand and saves only quantity
  through the existing authenticated personal/Team or membership-authorized
  shared-item route. Persist the absolute count before submitting, retain it
  after a failed/lost response, and finish the purchase only after confirming
  item ID and quantity. Explicit retry saves the same count without double
  addition. Shared viewers cannot save stock. A later drop below an explicit
  threshold reopens To buy; untracked single belongings are not automatically
  treated as low stock.
- Purchase planning and thresholds remain personal, account/device-local, with
  that scope disclosed in the planner. Inventory quantities sync through the
  existing API. Legacy thresholds and checked selections migrate without
  inventing historical order quantities; old account-scoped preferences remain
  as rollback copies. Failed preference writes restore the prior cache and
  surface a retry, malformed saved plans fail visibly, and stale account writes
  are rejected. Local restock notifications follow To buy and cancel evaluated
  ordered/removed items; native permission/delivery acceptance is unverified.
- All 292 mobile tests with coverage and clean analysis pass, including 18
  restock regressions. Phone-sized sample renders and Light/Dark 320pt/2.6x
  action/dialog checks pass. All five exact-runtime CI jobs pass for `98f019e`
  (`37406983954`). Signed archive/export, strict signature, packaged production
  configuration/public anon credential and supplied-logo checks pass. Apple
  validation reports no errors. Apple accepted delivery
  `99fa3764-17eb-4d95-95c9-d02a518324d9` with no upload errors at 20:09:15 PDT
  October 5. Processing is COMPLETE/VALID with no errors/warnings;
  APP_STORE_ELIGIBLE and both internal groups are verified. The user supplied a
  planner screenshot showing migrated 0 to buy / 8 on order.
  Final archive/IPA and verification manifest are preserved under
  `/private/tmp/findez-build54-native` and
  `/private/tmp/findez-build54-verification.json`.
  Final IPA SHA-256: `86f0c084a38542983ed4c4226db3ece8508df6cbdd8f6067a14bfedbbb8dbddb`.
  The user's earlier choice to check through
  TestFlight applies; no physical stock write or full device acceptance is
  claimed. Logo, shared typography, existing inventory data, billing, backend,
  web, database schema, FIND and native lifecycle are unchanged. Public App
  Store review/publication remains held.

- Build 55 addresses the user's wordiness and status-color feedback. The main
  screen contains counts, concise item/stock details and one main action per
  card; explanations move to Info, and editing/removal/back-to-buy actions move
  to each item's accessible menu. Legacy orders with unknown quantities omit
  that detail without inventing a count. Pending stock confirmation stays
  visible. Amber indicates To buy and blue indicates On order in Find and the
  planner; zero counts remain neutral, and labels remain readable without color.
  Purchase persistence, stock confirmation, account and permission rules are
  unchanged. Clean analysis and all 296 mobile tests with coverage pass, including
  22 restock regressions and Light/Dark large-text/contrast checks. All five exact-source CI jobs pass for `5d24797` (`37408858103`), as do
  signed archive/export, signature, configuration/logo and Apple validation.
  Build 55 was not uploaded: the user requested app-wide orange/white/black
  consistency during validation, and released build 56 now includes both changes.
  Artifacts/manifest are preserved under `/private/tmp/findez-build55-native`
  and `/private/tmp/findez-build55-verification.json`. Physical verification
  follows the user's TestFlight preference.

## App-wide typography consistency (October 5)

- The user approved build 52 Home on the physical iPhone with Bold Text enabled,
  then requested consistent typography throughout the app. The same
  `fix/mobile-home-bold-text` lane in `/private/tmp/findez-home-bold-text`, based
  on release record `e123c22`, now implements the complete app-wide change for
  `1.0.7 (53)`; Draft PR #44 describes the final app-wide scope.
- Shared `AppTypography` and `AppText` retain San Francisco and existing font
  sizes, colors, layouts and semantics. With Bold Text enabled, supporting text
  and editable fields use Medium (500); headings, counts and emphasis use
  Semibold (600). Normal styling remains when off, with old 700-900 emphasis
  capped at 600. Intentional monospace code/status text remains monospace.
- The actual OS preference is retained in the inherited typography scope while
  Flutter's blanket 700 override is suppressed below it. All app-owned text,
  input decorations, selectable answers, Markdown and the nested date-picker
  theme use the shared policy. OS-composed text scaling and other accessibility
  preferences remain intact; live preference changes retain routes and drafts.
- All 274 mobile tests with coverage and clean analysis pass, including rendered
  weights for app/framework text and editable fields, real-root preference
  changes, retained drafts and Light/Dark Home at 320pt through 3.4x scaling.
  Build 53 signed archive/export, strict signature, production-config and supplied-logo checks pass. All five CI jobs pass on runtime `afc39ac` (`37398740825`), and Apple validation reports no errors. The exact signed app installed before the user elected to check it through TestFlight; native process launch and app-wide visual acceptance are unverified. Apple accepted the upload with no errors at 19:00:26 PDT on October 5;
  delivery `67e8af04-e91a-4157-aa8d-e758c3222d3b`. Apple processing is `COMPLETE`/`VALID` with no errors/warnings;
  `APP_STORE_ELIGIBLE` and assignment to Testers and Internal Pilot Findez AI
  are verified. The final signed archive/IPA and verification manifest are
  preserved under `/private/tmp/findez-build53-native` and
  `/private/tmp/findez-build53-verification.json`.
  Final IPA SHA-256: `69cf90f89bd2748016fdae6b406d84548f27e7ddac280d775e8a0f913961d6b8`.
- Historical Home-only build 52 (`d37eb49`) passed 270 mobile tests, analysis,
  all five CI jobs (`37393604316`), signed archive/export, production-config and
  supplied-logo checks, Apple validation, and native install/process launch.
  The user confirmed its Home appearance. It was not uploaded after the scope
  expanded; build 53 replaces that local candidate.
- Branding and all routes/data/actions are retained. No backend/web/schema/FIND,
  Stripe/billing or native lifecycle implementation changed. Public App Store
  review/publication remains held; the existing TestFlight request authorizes
  the updated beta and existing internal-group availability.

## Current TestFlight beta (October 5)

- The user explicitly requested the current mobile build on TestFlight and
  reaffirmed using the previously supplied logo. That instruction authorizes
  this beta upload; the public App Store review/submission hold remains.
- `release/testflight-current` in `/private/tmp/findez-testflight-current` is
  based on latest mobile head `671e304`, not the older build-29 Interior v2
  checkout. Runtime source is unchanged; release commit `15b6374` advances the
  version to `1.0.7 (51)`. It includes appearance/branding, Space icons,
  physical-memory onboarding, November pilot copy, and the cold Home-to-Space fix.
- Clean Flutter analysis and all 265 mobile tests pass locally. The underlying
  runtime `ab506f2` has all five CI jobs passing in `37385102041`. The signed
  archive/export passes, the final IPA contains the production compile-time
  configuration, and the Supabase credential is public anon rather than service
  role. Signature verification and Apple server-side validation pass.
- The exported package's brand assets match the committed originals. Its three
  SVGs match the supplied Downloads files except newline formatting, and the
  native icon uses the supplied orange/white mark flattened onto opaque Ink as
  already authorized by the branding lane. No logo was redrawn or generated.
- Apple accepted the upload at 17:01:18 PDT on 2026-10-05. Delivery ID:
  `c005740a-d226-4fcf-a9f6-149c3968939e`. Apple reports `COMPLETE`/`VALID`, `APP_STORE_ELIGIBLE`, and both existing
  internal groups (Testers and Internal Pilot Findez AI) are verified. Final IPA SHA-256:
  `cacb003d9c3f84e733c8a0137b1be499cfa7a8b1ce418af59308a9b30ad601c9`.
- The paired iPhone reports installed `1.0.7 (51)`, and native process launch
  passed after it was unlocked. This is not a TestFlight-app download, visual
  first-frame confirmation, fresh-install/auth check, or full physical acceptance.
  The existing default-launch-image warning and broader release gates remain.
- No backend/schema/FIND, Stripe/billing, public website, Apple screenshots,
  App Store draft selection, review submission, or public release was changed.

## Cold Home-to-Space correction (October 5)

- `fix/mobile-home-space-cold-load` in `/private/tmp/findez-home-space-fix`,
  based on `2758498`, reproduces the observed failure in the actual shell:
  Home is populated, Find registers its destination before its first inventory
  request finishes, and the Space route captures the still-empty list.
- Space navigation now waits for the confirmed inventory read (including an
  active refresh), deduplicates reads and route taps, and refuses a false empty
  destination after a failed read. Retry and genuinely empty Spaces remain valid.
  Exact Space IDs and complete Home inventories are preserved independently of
  Find filters. Late disposed/account-changed reads cannot open a destination.
- All 265 mobile tests with coverage and clean Flutter analysis pass. Five new
  regressions cover actual cold-shell navigation in Light/Dark, failure/retry,
  confirmed empty data, duplicate taps and disposed late reads. The cold-shell
  assertion failed against the original source before the fix.
- Runtime `ab506f2`, PR #42, passes all five CI jobs in `37385102041`.
- Separate backend PR #43 runtime `4ac3c56` deployed private document storage
  after all five CI jobs passed (`37385848403`). Disposable personal/Team
  upload/open/denied foreign access and membership revocation checks pass; all QA
  data removed. Item photos remain public, and processor retention unconfirmed.
- This is source-only, not a newly installed native binary or physical acceptance
  pass. Apple upload/submission remains held, FIND unchanged. The unrelated
  public item-image storage, legal publication and physical release gates remain.

## November pilot date and current launch verdict

- User requested free pilot through **November 1, 2026**, inclusive. The API
  notice, dormant web pricing copy and mobile fallback now use that date, with
  November 2 as the following-day plan copy. Lane: `fix/free-pilot-november1`
  in `/private/tmp/findez-pilot-november`, based on `19da889` / onboarding PR #39.
  `PILOT_MODE=true`, optional `PILOT_ENDS_AT` (still unset in production), public
  visibility flags, Stripe guards, limits and manual activation are unchanged.
  This does not schedule a cutoff, enable payments or charge users automatically.
  Mobile fallback and narrow-card wrapping are source-only for the next approved
  binary; no native build, phone install or Apple upload/submission was performed.
  Active clients receive the API notice on successful Profile refresh; offline
  clients intentionally retain cached values rather than changing their plan.
- All 350 backend/API-doc, 134 web and 260 mobile tests pass, with clean Flutter
  analysis, TypeScript and local web production build. Pilot card regressions
  cover API/fallback copy in Light/Dark at 320pt and 1x/2.6x/3.4x text, preserving
  the existing free tier and failed-read cache behavior. Connector tests, exact
  Desktop bundle check and standalone bundle smoke test pass with lockfile-local
  dependencies (the initial symlinked dependency check had nonhermetic notices).
- Only `backend/app/services/limits.py` and the unused
  `frontend/src/lib/pilot.ts` were selectively copied to production after exact
  pre-change hashes matched. Rollback copies and the isolated web build are in
  `/home/ubuntu/findez-pilot-november.1t5vaz` (private directory). Backend restarted;
  both services are active. The current dirty deployed frontend built successfully
  in isolation, but `/pricing` redirects to `/` and does not render this copy;
  preserve that redirect and existing live web artifact rather than adding a
  pricing screen. Environment-file hashes are unchanged, including FIND and
  billing configuration. A read-only nil-user deployed-service probe confirms
  the exact new notice and unlimited maxima; it creates no account/data. Public
  API and database health from the Mac return healthy. The server's requests to
  its own public API timed out; local service checks and independent public
  checks pass. Public `/pricing` still returns its existing 307 redirect.
- **Not yet ready for broad public launch or Apple submission.** Automated CI
  and simulator passes do not close the physical release checklist. Latest
  mobile feature source is local build-50-era work, while the last verified
  unsubmitted App Store draft selects build 46. The exact final release binary,
  accurate final screenshots and physical fresh-auth/photo/profile/Documents,
  offline draft protection, second-account revoke and real invitation acceptance
  remain outstanding. The cold Home -> Space issue now has a separately tested
  source correction above; final-binary/device acceptance remains outstanding.
- The original storage audit found both documents and item images public. The
  separate October 5 PR #43 deployment above made documents private; item images
  remain public and profile photos private. Public item-photo URLs remain a
  privacy/access concern after revocation. Legal PR #40 is still draft/unpublished
  and needs
  provider/deletion verification and final publication/mobile alignment. The
  user's no-current-customer-training clarification is not proof of all provider
  practices. The existing unencrypted server-to-FIND hop is also a retained,
  documented risk; the user explicitly withdrew changing it. Apple holds remain.

## App Store submission preflight

- The physical-memory introduction is implemented as local `1.0.7 (50)` on
  `feat/mobile-physical-memory-onboarding`, stacked on icon-picker PR #38
  (`bea71f5`) in `/private/tmp/findez-appearance`. Four branded screens teach
  physical memory, Capture/Review, Ask/Find and personal/shared Spaces using
  interactive, code-native sample graphics. Samples are explicitly local and
  do not create a Space, save inventory, request permissions or call APIs.
  Fresh signed-out launch shows onboarding before Auth; Complete/Skip saves
  only the confirmed completion flag. Returning sessions, completed installs,
  queued Space/Team invitations and replay/legacy signup state are preserved.
  Navigation/fade/sample transitions respect Reduce Motion and pages scroll
  independently above the pinned action at large text sizes.
  PR #39, runtime `f6782d3`, passes all 246 mobile tests with coverage, clean
  Flutter analysis and all five CI gates (runtime run `37265597966`, repeated
  on documentation head `ff15a5d` in run `37265970841`). Local targeted
  regressions pass; the final local full-suite compiler rerun stalled on the
  disk-constrained Mac and was stopped after CI passed. A prior local 245-test
  full suite passed before the final compact-answer layout adjustment.
  Native iOS simulator build 50
  passes and the final app is installed/launched locally. Simulator verifies
  sample object/capture/location/question/sharing changes, Dark and Light/Larger
  styling, retained sample location, visible normal-size Ask answer and replay
  returning to Profile. CUA mouse drags did not confirm native vertical scrolling;
  automated scroll/layout tests pass through 3.4x at 320pt. Physical touch,
  VoiceOver, fresh-install/auth and reduced-motion checks remain deferred.
  A follow-up native signed-out cold-launch check reset only the existing
  simulator's completion flag while it was stopped, without erasing app data.
  Build 50 showed the welcome introduction before Auth; all four sample steps
  worked, final Continue opened Auth, and a force-quit/relaunch stayed on Auth.
  Completion was restored to its original confirmed `true` through the UI.
  This is a reset-flag simulator check, not an App Store download or physical
  fresh-install/auth pass. Dark/Default preferences are retained; the simulator
  is now left on sign-in, with no credentials entered during this follow-up.
  No inventory/membership/document data, auth credentials,
  backend/web/schema/FIND, native lifecycle, App Store draft or Apple release
  was changed. Submission remains held; the separate cold Home-to-Space issue
  and broader release gates still apply.

- Optional personal Space icons are implemented as local `1.0.7 (49)` on
  `feat/mobile-space-icon-picker`, stacked on brand PR #37 (`1d49e27`). Tap the
  leading icon in personal/owned, joined/shared or Team Space lists to open a
  searchable 24-icon picker, with Automatic reset and explicit Save/Cancel.
  Choices are saved per account and stable Space/share ID on this device only;
  they survive rename/restart and do not change shared data or permissions.
  Confirmed-write, safe read/write failures, duplicate saves, stale account
  reads/writes, draft retention and disposal are guarded. The themed picker has
  one native handle, named selected semantics, 44pt icon targets and adaptive
  large-text columns. All 226 mobile tests with coverage, clean analysis and
  native simulator build pass. Simulator confirms search, Cancel/no save,
  immediate saved card icon, restart persistence and Dark/Light with Larger text.
  Inventory, memberships and documents are untouched. There is no backend/web/
  schema/FIND or native lifecycle change, phone install or Apple upload/submission.
  Physical accessibility/touch acceptance remains deferred; existing broader
  release gates and the cold Home-to-Space issue remain separate.

- The user authorized the supplied FindEZ brand on mobile and identified two
  duplicated grabbers in Edit item. Local `1.0.7 (48)` on
  `feat/mobile-brand-theme`, stacked on appearance PR #36 (`def3d3c`), uses the
  original outlined SVG wordmark and new native icon, exact light-brand tokens
  and readable dark counterparts. Retired decorative blue/purple gradients are
  removed; orange is reserved for the mark and promoted primary actions, with
  separate warning/success/danger roles. The PNG's transparent outer corners
  are flattened onto Ink for native icon generation; the original SVGs remain
  unchanged. Existing five-icon/56pt navigation, routes, preferences and writes
  are preserved. The system sheet grabber is now opt-in so the custom editor
  draws one handle; simple photo/Space pickers retain their single native handle.
  Protected item-info dismissal code is unchanged.
  All 203 mobile tests with coverage, clean analysis and the native iOS
  simulator build pass. Simulator verifies the single editor handle in both
  modes, larger text, live System mode, restart persistence, readable Space
  counts, all five tabs and Documents/item-info presentation. Physical
  camera/QR/accessibility/swipe checks remain deferred by the user's explicit
  simulator-only choice. Build 48 has not been installed on a phone or uploaded
  to Apple; the submission hold and live build/draft remain unchanged.
  A separate release check remains: after a cold launch, a Home Space shortcut
  displayed an empty item list although Home showed five items; opening that
  same Space through Find displayed all five. That routing code was not changed
  in this presentation lane. Investigate before a release, not by changing
  backend/schema/FIND as part of this task.

- The user explicitly renewed the Apple submission hold while requesting mobile
  Light/Dark/System appearance and text-size settings. Work is isolated on
  `feat/mobile-appearance-accessibility` in `/private/tmp/findez-appearance`,
  based on `df7e1d1`. Local `1.0.7 (47)` adds persisted device-local
  Light/Dark/System and Small/Default/Large/Larger text choices under
  Profile → Settings → Appearance. Default remains Dark with OS text scaling;
  other sizes compose with OS accessibility scaling, and OS bold text is honored.
  Legacy fixed-color presentation now adapts across mobile screens without
  recoloring photos, identity colors, camera imagery or printed QR output.
  Light foreground/semantic contrast and status-bar styling have regressions.
  Large-text fixes cover item-info fields, populated Space cards/restock notices,
  Capture controls and scrollable forms. Routes, drafts, five-icon/56pt nav and
  protected swipe dismissal remain intact. All 190 mobile tests with coverage,
  clean Flutter analysis and the local iOS simulator build pass. Simulator
  checks are complete; this is not a phone/TestFlight/App Store release.
  The user explicitly chose simulator checks for now, so physical appearance,
  camera/photo/QR and accessibility acceptance remain deferred. FIND, real
  inventory, native lifecycle and the App Store draft are unchanged.
  Item-info presentation/navigation was checked in the simulator; CUA mouse
  drag attempts did not dismiss it, so native swipe is not marked passed.
  The existing protected-swipe widget regressions still pass in both themes.
  The user chose raw app screenshots; the image-edit
  trial was rejected and no generated artwork was uploaded.

- User requested submission and authorized isolated QA accounts and a dedicated
  Apple review account. App Store `1.0.7` now selects build `46`, remains
  `PREPARE_FOR_SUBMISSION` with manual release, and has not been submitted.
  The public `1.0.6 (17)`, pricing, real memberships and Team-only AASA are
  unchanged. The next-release privacy URL is saved as
  `https://www.findez.ai/privacy`.
- The user subsequently asked to wait for their assets. Original
  `findez-wordmark.svg`, `findez-icon.svg`, `findez-mark.svg` and
  `findez-icon-1024.png` have now been supplied in their Downloads directory.
  All three SVGs are readable path-based assets; the wordmark uses outlines,
  not a font dependency. The PNG is 1024x1024 RGBA with alpha. No assets were
  modified or installed during the earlier build-46 preflight; mobile now uses
  local build-48 brand assets as recorded above. Six supplied `findez-appstore-1.png`
  through `findez-appstore-6.png` have now arrived in Downloads. All are
  1320x2868 PNGs without alpha, accepted iPhone screenshot dimensions. They are
  not uploaded: depicted phone UI differs from build 46's icons-only navigation
  and Profile destination, and image 5 includes a drawer-location diagram and
  `Mark as taken` action absent from the current mobile source. Apple guidelines
  2.3/2.3.3 require metadata to reflect the shipping app. Request corrected
  current-app captures or permission to revise the artwork; do not silently
  expand into a redesign or publish these as accurate build-46 screenshots.
  Existing release checks remain recorded separately; no submission occurred.
- The previous saved review login failed. Three new task-only accounts were
  created with confirmed emails; password sign-in passed for each. Dedicated
  review credentials were saved to Apple and re-read successfully, without
  logging secrets. Its inventory contains five sample items across Hardware,
  Tools and Electronics, plus an empty sample Space. This admin-created setup
  does not prove public signup/email-confirmation acceptance.
- Live API-only checks passed for recipient access to the five sample items,
  denial before joining, unrelated-account denial, view-only write denial,
  individual-member removal, share revocation, and revoked-code rejoin denial.
  No real account inventory or memberships were changed. These results do not
  satisfy the physical multi-account/invitation acceptance gates by themselves.
- The build-46 simulator app built, installed and signed in to the review
  account. All six Ask-to-Find cycles retained the two Spaces and their counts.
  The rename check failed: changing `Test Workshop` to `Main Workshop` showed
  `0 items` on the Space card, while all five entries remained accessible by
  Space ID inside it. An isolated live API reproduction at
  `2026-10-04T22:10:26Z` confirmed canonical Space count 5 and no old Space, but
  all five `/search_items` results still had the old location (zero new-location
  results). Production `spaces_repo.py` and `items_repo.py` match the inspected
  source byte-for-byte. The root cause was missing invalidation of the 60-second
  per-user inventory cache. The user then approved the scoped correction.
- `fix/release-cache-find-transport`, based on `2376d0f`, now invalidates only
  the affected owner's inventory after Space rename and cascade deletion,
  including failure paths without swallowing errors. Six hermetic regressions
  and all 349 backend/API-documentation tests pass. Only `spaces_repo.py` was
  selectively deployed after matching its original hash, preserving unrelated VM
  work and a mode-600 backup in
  `/home/ubuntu/findez-space-cache-backup-es4heqOb`. Backend and database health
  pass. The live QA rename at `2026-10-04T22:27:04Z` retained all five items,
  returned five new locations and zero old locations immediately, with no old
  Space. A subsequent build-46 simulator UI rename also immediately displayed
  `Sample Workshop / 5 items` and retained the empty Space. All-category behavior
  is covered automatically; broader physical/filtered acceptance remains open.
  The existing two database writes are not transactional; this fix invalidates
  stale snapshots and propagates failures, rather than claiming atomic rollback.
  Runtime `6027a87` is pushed in PR #35 against the release-record branch; all five
  CI gates pass (run `37240403382`). Live API-only access/revocation checks were
  repeated after deployment and again passed, including unrelated-user and
  read-only-write denial, member removal, revoked reads and revoked-code reuse.
- Updated screenshots are not uploaded; supplied new iPhone artwork needs
  current-app UI correction as noted above, and existing iPhone/iPad screenshots still
  show old navigation/Ask. Camera, profile/Documents, offline writes and real
  invitation acceptance remain unverified. iPhone Mirroring repeatedly reports
  the phone in use despite the user's lock confirmation. No real-account sign-out
  was performed in this preflight.
- Exact signed IPA hash remains
  `0c0bf3a0db16dc2603acf7576eae9ddb8713423b6d8bc5678624517209b65a0e`;
  all five CI jobs remain green on runtime `78404fa` (run `37033574121`).
  Regenerable Xcode compiler/intermediate caches were removed with approval to
  make the simulator build; source, signed archive/IPA and verified backups were
  preserved. The embedded ShareExtension still declares build 17 (Apple already
  marks main build 46 valid/eligible); native handoff remains unverified.
  Production FIND plain-HTTP transport remains a separate security limitation.
  No TLS correction was deployed: verified-certificate probes of
  `https://pipeline.findez.ai/health` fail with a TLS internal-error alert from
  both the Mac and the backend VM, including a TLS-1.2 probe. Current production
  settings still select HTTP with the explicit insecure allowance. Caddy runs on
  a separate operator-managed machine, not the accessible FindEZ VM. The user
  subsequently explicitly withdrew the transport change and instructed keeping
  the existing working connection unchanged. Preserve the FIND URL, HTTP
  allowance, key and proxy settings; do not continue this transport change
  without new authorization. No certificate bypass, credentials or images were
  sent in these probes, and photo extraction was not disabled. The unencrypted
  server-to-FIND hop remains a documented risk, not a completed security fix.
  Transport migration is no longer part of this release's requested work;
  the outstanding release checks and screenshots still remain.

## Working and deployed

- The self-hosted backend, web app, Supabase database, Auth, and Storage are the
  production architecture. `/health` and `/health/db` were verified healthy after
  the physical-memory backend and web deployment on 2026-09-30. Migration `036`
  is applied in production with RLS enabled; direct authenticated mutations and
  authenticated resolver execution are denied.
- The public landing page and authenticated Next.js workspace are in source and
  first-class routes. The old redirect-only web description in `CLAUDE.md` is stale.
- Mobile is a substantial iOS client with inventory, scan, Ask FindEZ, sharing,
  teams, projects, documents, check-outs, notifications, onboarding, and profile.
- Item photo galleries are deployed in the backend and included in TestFlight build
  31. FIND captures retain their crop or source photo, and personal, Team Space, and
  legacy Shared Space items can add, view, and delete up to ten photos.
- The live backend and web now persist uncertain FIND captures for Review and show
  structured, model-neutral scan evidence. The authenticated web workspace and
  public integration bundle were deployed and checked against the public host.
- OpenAI runtime code has been removed. FIND serves photo analysis and the private
  agent gateway serves language tasks.
- A real production parts-bin smoke test returned 18 mapped FIND items with scan
  evidence. A later client-lifecycle fix is on `main`.
- The scoped integration API, API key management, public API docs, local Claude
  Desktop MCP extension, ChatGPT Actions assets, and OpenCode MCP configuration exist.
- Automated backend, frontend, Flutter, connector, and PostgreSQL RLS checks run in
  CI through the commands documented in `TESTING.md`.

## Active development

- `fix/icon-only-mobile-nav`, based on released build 42, hides visible labels
  in the existing five-icon navigation pill (PR #33). Icons, touch targets,
  accessible names, profile avatar, routes and tutorial targets are preserved.
  Branding and screen content are unchanged; backend/web/native lifecycle files
  are not modified. Build-43 source `4adaea9` passes all 117 mobile tests with
  coverage, clean analysis and all five CI gates (run `36973804731`). Its signed
  app installed, reports 43, and launched; the user confirmed icons-only but
  rejected the appearance. The supplied screenshot shows the old tall pill and
  wide selected badge. Build 43 was not uploaded: Apple validation hit low disk
  and was stopped. Its archive/IPA are recoverable from the verified private
  server backup `/home/ubuntu/findez-preserved-build43.tar.gz` (683 entries,
  SHA-256 `d5a7e68f4bf61cef91910889c9b8f2155b799e8c0bd02c2c9811832dc71bdc34`);
  only the local copies were removed. The compact build-44 correction
  reduces visible navigation height to 56pt, keeps safe insets outside the pill,
  and uses a subtle circular selected indicator. All 117 mobile tests with
  coverage, focused glyph-loaded layout capture and clean analysis pass. The
  captured fake-data pill was inspected. Exact runtime `42f977c` passes all five
  CI gates (run `36976126350`). Signed build 44 installed, reports 44, and
  launched; the user approved the slimmer pill and circular highlight. Apple
  validation and upload passed (delivery `350a7049-8b9d-4654-bccc-722be9d53916`);
  processing is `VALID` / `APP_STORE_ELIGIBLE`, with both internal groups
  (Testers and Internal Pilot Findez AI) assigned. Production compile
  configuration matches the existing mobile environment without logging values.
  IPA SHA-256 is `0dbc24b0db6776679c9c8c073e471b496f5aff90c723a8117ae09111cc905949`.
  Signed build 44 is preserved in verified private backup
  `/home/ubuntu/findez-preserved-build44.tar.gz` (mode 600, 683 entries, SHA-256
  `3b196d02806bf20691a95aad4d7a46771770ba90f683c10ddf40fa5a0b44429d`).
  Build 42 remains recoverable from verified private server backup
  `/home/ubuntu/findez-preserved-build42.tar.gz` (683 entries, SHA-256
  `ba374f01046d82ce2b6c98b45e1213a190152cd827a8ff1f6a716c705b67ad6b`).
  At build-44 delivery the App Store draft still selected build 42. The current
  build-46 draft and submission hold are recorded above.

- `fix/item-detail-swipe-dismiss`, stacked on navbar PR #33, updates the shared
  item information panel used by personal, joined/shared and Team Spaces, not
  the separate Edit item form. Its content uses the draggable sheet's scroll
  controller: pulling down at the top closes, scrolling inside the body does
  not. Small pulls restore the full sheet and horizontal photo swipes stay in
  the gallery. Downward dismissal, Close, system Back and barrier dismissal
  share unsaved-note confirmation and confirmed autosave flushing; read-only
  access cannot write. Build 45/runtime `55dd4fd` passed all five CI gates
  (run `37032241160`), Apple validation, signed installation and launch, but the
  user reported an uneven exit. It was not uploaded. A regression reproduced
  late scroll-end events restoring the sheet to full height during route exit;
  build 46 keeps accepted dismissal latched until disposal. All 135 mobile
  tests with coverage and clean analysis pass, including 18 item-info tests and
  two animation regressions. Runtime `78404fa` passed all five CI gates
  (run `37033574121`). Signed build 46 installed, reports 46, and launched on
  the paired iPhone; the user confirmed a smooth Parts Room info-panel exit.
  Apple validation and upload passed; delivery
  `6d44ee23-5d42-4abb-a196-0df58223f415`. Apple processing completed with
  `VALID` and `APP_STORE_ELIGIBLE`; build 46 is assigned to both internal groups
  (`Testers` and `Internal Pilot Findez AI`). No external review/submission was
  started during that delivery. The public App Store release remains unchanged;
  the later build-46 draft selection and acceptance hold are recorded above.
  IPA SHA-256:
  `0c0bf3a0db16dc2603acf7576eae9ddb8713423b6d8bc5678624517209b65a0e`.
  Build 45 is recoverable from verified private backup
  `/home/ubuntu/findez-preserved-build45.tar.gz` (mode 600, 683 entries, SHA-256
  `7868dd3e8aa84baddff2f12f1cc4836b83be76ea4675e8a175d89a5f4ee1014e`).
  Signed build 46 remains local and is also preserved in verified private backup
  `/home/ubuntu/findez-preserved-build46.tar.gz` (mode 600, 683 entries, SHA-256
  `1e3d6a916af48c7795d2e1a754c8a6d12561a672e6e503f51e938623116a3133`).
  Its extracted IPA matches the signed/uploaded hash above.
  Redundant local build-42/45 archives and IPAs were removed with approval after
  backup integrity and extracted IPA hashes matched. Test caches were cleared
  and are regenerable. The original shared checkout and device data are untouched.
  Backend/web, API/schema, navbar and native lifecycle files are unchanged.

- `feat/workspace-invite-links`, based on released build 39, adds authenticated
  read-only Space/Team previews, explicit join consent, existing-owner links for
  joined/shared Spaces, and restart/account-safe mobile presentation. An optional
  account-first download handoff uses a private, expiring invitation pointer;
  downloading first still requires reopening the link. No membership is granted
  by the handoff. The public Team-only AASA remains unchanged while App Store
  build 17 is live. The reviewed backend/web are deployed, public backend/DB
  health pass, anonymous previews return 401, and all five CI gates passed on
  `47aa8ef` (PR #32). Build `1.0.7 (40)` is valid in both internal groups and
  installed/launched, but the signed-in user did not see its cold Team prompt.
  The application-only link library does not register scene callbacks. Build
  41 pins the scene-compatible library and minimum compatible auth adapter;
  the user confirmed its cold Team prompt and Space prompt from a real Safari
  tap. Final build 42 adds actor-bound membership requests so a queued request
  cannot use a switched account's token. Runtime source `0b4c207` passes all five
  CI gates (run `36969482272`), 343 backend/133 web/114 mobile tests,
  MCP/bundle checks, analysis, typecheck and production web compilation. The
  final web actor-binding files are deployed byte-for-byte with rollback output
  retained. Signed `1.0.7 (42)` passed Apple validation/upload, `VALID`
  processing and `APP_STORE_ELIGIBLE`; both internal TestFlight groups are
  assigned. Exact final archived app installed, reports 42, and launched. The
  user repeated cold Team and real Safari Space prompt confirmations on build
  42; nonexistent test codes added no membership. At that delivery App Store
  1.0.7 selected build 42 with manual release and release notes, in
  `PREPARE_FOR_SUBMISSION`. The current selection is build 46 as recorded above;
  it is not submitted/published. Fresh-install/account-confirmation continuity,
  real acceptance/revocation, additional platform/browser checks and the broader
  physical/security checklist remain before submission. The public 1.0.6(17)
  and Team-only AASA are unchanged.

  Build-40/41 archives and IPAs were removed locally only after private server
  backups passed gzip validation and each listed both artifacts (683 entries):
  `/home/ubuntu/findez-preserved-build40.tar.gz`, SHA-256
  `45ef01c99b682200645ab605805d13306787e38e27a98b44fd9eb70628e7c9b2`;
  `/home/ubuntu/findez-preserved-build41.tar.gz`, SHA-256
  `c0d2650597535615df2c371b767f9eb0be763a9e1e7397c775e9d1342b74dc68`.
  Build 42 is preserved in its verified private server backup above. The older
  build-39 originals were
  removed only after the private server backup passed gzip validation and listed
  both artifacts: `/home/ubuntu/findez-preserved-build39.tar.gz` (683 entries,
  SHA-256 `349809879acea986d541fe1c7c96b11dbdb6c1db73ec092efae52437cfaa4151`).
  Builds 36-38 remain recoverable from verified private server backup
  `/home/ubuntu/findez-preserved-builds36-38.tar.gz` (mode 600, SHA-256
  `e997c5fab2520bc49fdf7a6b76d96ca65096d53b894e17b5933fe3162b2d4caf`).
  Its SHA-256 matches the local tar; gzip validation passed, with 2,049 GNU tar
  entries (2,046 on macOS tar). Only the redundant local backup was removed.

- A production-dependency audit flags Next.js 16.3.4 under
  GHSA-vcvr-r3jv-pc5j, patched in 16.3.6. No `next/og` or `ImageResponse` usage
  exists in this source, so its vulnerable SVG-generation condition is absent.
  A separate minimal web patch and validation remain; do not report a clean
  web dependency audit from the invitation tests.

- A separate local branch, `mobile/flutter-uiscene-migration`, contains committed
  and uncommitted iOS lifecycle work in the Podfiles, Xcode project, and
  `AppDelegate.swift`. Its owner and release status are not recorded in the repo.
- Branch `feat/physical-memory-home-review` implements a Home/Capture/Ask/Find
  shell, model-neutral structured scan evidence, a durable Review queue, and
  conditional item thumbnails. Its backend, migration, and web are deployed.
  Builds 32 and 33 were rejected visually. The current Home matches the user's
  supplied reference with actual Spaces, four decision cards, and retained-photo
  captures. The user subsequently requested restoring the previous four-tab icon
  rounded pill; build 35 has uploaded, with analysis and all 34 Flutter tests
  passing, including embedded Ask composer spacing. All five CI test jobs passed
  on implementation commit `c4c95fa`. Apple processing completed with `VALID` and
  `APP_STORE_ELIGIBLE` status, and build 35 is available in both internal
  TestFlight groups.
- Fixed editor ownership rules in older documents are stale. Current work is
  assigned per task and coordinated through `.agents/ACTIVE_WORK.md`.
- Branch `feat/ask-grounded-reference`, based on build 35, recreates the supplied
  Ask reference without changing Home or the pill. It adds collapsed checked
  sources, authorized project-readiness rows, and saved public answer snapshots
  through migration `037`. Flutter analysis, all 46 mobile tests with coverage,
  and all 292 backend tests pass. The narrowly scoped backend and migration are
  deployed and healthy. Signed build `1.0.7 (36)` passed Apple validation,
  uploaded, and installed/launched on the physical iPhone. Apple processing is
  `VALID` and `APP_STORE_ELIGIBLE`, with assignment to both internal TestFlight
  groups confirmed. Failed conversation or
  snapshot writes now surface safe errors rather than silently losing history.

- Ask photo attachments are implemented on `feat/ask-fast-photo-questions` in
  `/private/tmp/findez-ask-reference` (a separate lane based on build 36). One
  camera/library image can be previewed/replaced/removed, sent with a question or
  the default identification/ownership question, and retained in saved answer
  context. Photo identification checks access-scoped inventory, labels possible
  matches honestly, and sends uncertain objects to Review without automatically
  adding inventory. The user cancelled text-speed work; it is excluded. All 327
  backend and 55 mobile tests, clean analysis, and all five CI test jobs pass on
  implementation `6944ed3` (PR #29 stacked on #28). The selected backend files
  are deployed and healthy; build `1.0.7 (37)` is valid and in both internal
  TestFlight groups. Native physical install/launch passed. Hands-on photo
  acceptance is not yet claimed.

- `feat/profile-nav-hub` adds the user's requested fifth circular Profile tab
  to the restored rounded icon pill. Profile groups account editing, settings,
  documents/notes, notifications, lent items and the app tour; duplicate utility
  header icons and Find's old More sheet are replaced by this destination.
  Existing account, billing, scanning and support actions are preserved. Home,
  Ask/photo attachments, text speed, backend and web are unchanged. All 66 Flutter
  tests with coverage, clean analysis and all five CI test jobs pass. Build 38
  is valid and available in both internal TestFlight groups. Native physical
  install/launch passed; full hands-on acceptance remains unverified.

## Known limitations and risks

- FIND production transport currently uses a public plain-HTTP endpoint behind an
  explicit temporary allow flag because the private route was unreachable.
  On October 4 the user explicitly instructed preserving this connection and
  withdrew the proposed TLS migration. Keep the risk visible without changing
  runtime configuration or representing it as encrypted.
- FIND jobs are deleted after mapping. Uploaded source images and available object
  crops survive as item photos. Unresolved objects, public evidence, and review
  status persist. Masks, geometry, and training-quality
  correction events remain outside the durable data contract.
- Photo scans can take tens of seconds. The documented production smoke completed,
  but user reports include scans timing out or appearing stuck.
- The production VM checkout is dirty and has been deployed by carefully copying
  reviewed files. A blind pull, reset, or full checkout replacement can destroy work.
- Numbered migrations alone do not reconstruct the database. The schema baseline
  and live verification are required.
- Three physical release gates remain documented: Google sign-in, Apple sign-in,
  and APNs delivery on a real iPhone. Password recovery also needs a fresh-link
  device check.
- Offline inventory is not implemented. The mobile cache is memory-only.
- Low-stock thresholds are stored on one device and do not sync.
- Two Stripe route families are mounted. The live webhook source and iOS payment
  strategy must be settled before changing pricing or shipping paid digital access.
- Backups are restore-checked on the same disk. Off-machine backup is not implemented.
- The broader AI grounding path can still rely on bounded previews and remembered
  facts outside the explicit inventory knowledge tool.

## Release status requiring verification

- The current US App Store release is FindEZ AI `1.0.7 (59)`, verified October 12
  as recorded above. The recovery history below concerns former public
  `1.0.6 (17)`. The recovery branch
  restores the complete `mobile/` tree from its matching release commit,
  `0bb4f01066ca8326e0bc807e8a790bf54bba935f`, with only the version metadata
  advanced to `1.0.7+30`.
- Recovery build 30 passed Flutter analysis and all 19 tests in the recovered
  suite. Its signed release installed and launched on a physical iPhone, where
  the installed app reported `1.0.7 (30)`. The exported IPA contains the
  production Supabase and API configuration and was delivered to App Store
  Connect at 11:23 PM PDT on 2026-09-28. Apple finished processing it and App
  Store Connect lists build 30 in the internal TestFlight groups. An install from
  TestFlight remains to be verified.
- Item-photo build 31 is FindEZ `1.0.7 (31)`. Its signed IPA contains the production
  API configuration, passed Apple server-side validation without errors, uploaded on
  2026-09-29, and finished processing with `VALID` and `APP_STORE_ELIGIBLE` status.
  TestFlight group assignment and a physical install from TestFlight remain to be
  verified; the camera/library add, gallery, and delete flows also need that device
  check against the deployed backend.
- Physical-memory build 32 passed Apple validation, uploaded and processed as
  `VALID` and `APP_STORE_ELIGIBLE`, and is linked to the two internal TestFlight
  groups. It installed and launched on the paired iPhone as `1.0.7 (32)`. The user
  rejected its crowded Home layout; later build 33 was also rejected visually.
- Build 33 (`1.0.7`) passed Flutter analysis, all 27 Flutter tests, signed archive,
  and Apple server-side validation. It uploaded on 2026-09-30, processed as
  `VALID` and `APP_STORE_ELIGIBLE`, and is linked to both internal TestFlight
  groups. Its signed release installed and launched on the paired iPhone, which
  reports `1.0.7 (33)`. Installation through the TestFlight app and hands-on
  capture, review, photo editing, and multi-account checks remain unverified.
  The public App Store release remains `1.0.6 (17)`.
- Build 34 (`1.0.7`) recreated the supplied Home and initially used the reference's
  text-only five-tab bar. Analysis, all 33 Flutter tests, signed archive, Apple
  validation, upload, and native physical-device install/launch passed. The user
  requested the previous four-tab icon navigation while upload was underway;
  build 34 is superseded by build 35.
- Build 35 (`1.0.7`) restores the user's exact floating rounded four-tab pill,
  keeps the reference-matching Home, and removes duplicate overlay-clearance
  padding from embedded Ask/Capture/Find. The scan evidence panel has its own
  Material ink surface for compatibility with the newer Flutter CI runner.
  Analysis, all 34 Flutter tests with coverage, all five CI jobs, signed archive,
  Apple server-side validation, upload, and native physical install/launch passed.
  Upload delivery ID: `58ec17b7-1985-4cce-a101-c487ac1d1c08` at 9:43 PM PDT on
  2026-09-30. Apple processing completed with `VALID` and `APP_STORE_ELIGIBLE`
  status; App Store Connect confirms assignment to `Testers` and
  `Internal Pilot Findez AI`, both internal TestFlight groups.
  Installation through the TestFlight app and the hands-on release checklist
  remain unverified. Existing default-launch-image archive warning is unchanged.
- Deployment notes and source agree on self-hosting, but older documents still name
  retired Render, Vercel, or cloud Supabase paths. Check live DNS and service state
  before a release.

- Build 36 (`1.0.7`) implements the supplied Ask reference: plain title/question
  card, collapsed "What it read", readable streamed answer, and grouped real
  quantity rows with missing/low/have badges. Home and the original four-tab pill
  are unchanged. Named project questions use authorized requirements and
  reservation-aware stock; unknown or ambiguous projects ask for clarification.
  No invented requirements, private reasoning, or internal provider/tool names
  are added to the public evidence contract. Saved snapshots use migration `037`
  and existing conversation RLS; safe errors report history-write failures.
  Flutter analysis, all 46 mobile tests with coverage, all 292 backend tests,
  PostgreSQL 17 ownership/constraint checks, and all five CI test jobs pass on
  implementation `f1204d8`; the final server safeguard is `44a2a14`.
  Signed archive, Apple validation, upload, and native physical install/launch
  passed. Delivery/build ID: `02154bba-e589-4447-b529-8e7331ddac9a`; App Store
  Connect uploaded date: 10:59 PM PDT on 2026-09-30. Processing completed with
  `VALID` and `APP_STORE_ELIGIBLE` status, and assignment to `Testers` and
  `Internal Pilot Findez AI` is confirmed. The deployed backend and public
  database health checks pass, unauthenticated Ask/history reads return 401, and
  deployed file hashes match the reviewed source. PR #28 is stacked on #27.
  TestFlight-app installation and hands-on keyboard, voice, source navigation,
  ambiguous-project, and multi-account checks remain unverified. The broader
  physical-memory vision and existing launch-image warning remain separate work;
  the public App Store release is still `1.0.6 (17)`.

- Build 37 (`1.0.7`) adds one camera/library attachment to Ask with preview,
  replace/remove, image-only default question, photo identification, strong
  identifier versus possible-name inventory matches, public saved photo context,
  and uncertain objects in Home Review. No attached object is automatically
  added to inventory. Text-chat speed, Home, Capture, FIND, and navigation are
  unchanged. Existing migration `037` stores the photo snapshot; no new schema
  was required. Uploads are validated/downscaled with metadata stripped; quota,
  conversation ownership, URL owner/origin and safe failure tests are included.
  All 327 backend and 55 Flutter tests with coverage, clean Flutter analysis,
  and all five CI test jobs passed on `6944ed3`. The signed final archive passed
  Apple validation, physical install/launch (installed `1.0.7 (37)`), upload,
  `VALID` processing and `APP_STORE_ELIGIBLE`. Delivery/build ID:
  `e671ac63-e931-48bc-ba52-655258142a9e`; uploaded 00:09:43 PDT on 2026-10-01;
  assigned to `Testers` and `Internal Pilot Findez AI`. Build-36 archive and IPA
  are retained under `mobile/build/ios/archive-build36` and `ipa-build36`.
  Four selected Ask backend files were deployed only after matching the build-36
  base hashes; backup: `/home/ubuntu/findez-backup-ask-photo-20261001.tar.gz`.
  Deployed hashes match, service/database health passes, unauthenticated photo
  requests return 401, and unrelated production changes are preserved. PR #29
  is stacked on #28. TestFlight-app installation and hands-on camera/library,
  matching/Review, follow-up and account-switch acceptance remain unverified.
  The existing public-HTTP FIND transport security limitation and default launch
  image warning remain; this is not a claim that the whole app is production-ready.

- Build 38 (`1.0.7`) adds the requested fifth circular Profile pill destination
  and utility hub, with separate account editing/settings and existing documents,
  notifications, lent items and app tour. Duplicate utility header icons and
  Find More are replaced by Profile. All 66 mobile tests with coverage, clean
  analysis and all five CI jobs pass on `b4aa726`; newer-Flutter Material ink
  compatibility is included. Apple validation, signed native install/launch,
  upload and `VALID` processing passed. Delivery/build ID:
  `f3fd1470-274e-4b93-be11-f9aba147546e`; uploaded 00:43:33 PDT on 2026-10-01;
  both internal groups are assigned. Build 37 archive/IPA are preserved in
  `archive-build37`/`ipa-build37`. PR #30 is stacked on #29. Home, Ask attachments,
  text speed, backend and web are unchanged. Hands-on acceptance remains
  unverified. The user subsequently reported cramped profile editing, missing
  overview avatars and old Documents styling; a scoped follow-up is required.

- Build 39 (`1.0.7`) follow-up is released on `fix/profile-documents-polish` in the
  existing `/private/tmp/findez-ask-reference` worktree: labeled profile editing,
  shared saved avatars in editor/overview/pill, correct image MIME uploads and
  matte Documents/note/link/rename flows. Private upload logs are removed;
  foreign URLs, stale account reads/draft writes and asynchronous document-link
  cache keys are guarded. All 94 Flutter tests with coverage and clean analysis
  pass, including 28 new failure/security/keyboard and note Back-autosave
  regressions. All five CI jobs pass on final implementation `6a0118e` (run
  `36958595854`); PR #31 is stacked on #30. Fake-data layout captures were
  inspected. Final signed archive, Apple validation/upload, `VALID` processing,
  `APP_STORE_ELIGIBLE` and assignment to `Testers`/`Internal Pilot Findez AI` are
  confirmed. Delivery/build ID: `8b7ff936-fefa-4ff1-8cd7-095c40aab00f`; uploaded
  20:11:17 PDT on 2026-10-01. The exact final app installed on the paired iPhone
  and reports `1.0.7 (39)`, but final launch was blocked by iOS `Locked`; user
  unlock was requested. An earlier superseded build-39 binary launched, not the
  final source, so do not report final launch as passed. Final launch,
  TestFlight-app install and hands-on photo/document/account-switch acceptance
  remain unverified. Build-38 artifacts are retained in `archive-build38` and
  `ipa-build38`. Home, Ask speed/attachments, Capture, Find, backend/web and
  existing settings behavior remain unchanged; no server deployment/migration
  was required. The public App Store stays `1.0.6 (17)` and existing broader
  FIND transport/native acceptance limitations remain separate work.
