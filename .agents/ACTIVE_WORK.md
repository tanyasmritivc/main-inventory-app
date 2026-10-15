# Active work

## October 14 Settings link layout correction

Lane `fix/web-settings-rows-20261014`, based on `fc20f3a`, owns the user's
Settings screenshot follow-up. Text-only links inherit a three-column icon grid,
putting Plans/legal labels in its 32px icon column. Normalize link rows to a
flexible content column plus a trailing chevron, group existing Developer icons
with their labels, and keep Appearance compact. Preserve all routes, actions and
account state. All 223 web tests, TypeScript and Settings lint pass. Actual
component previews verify all sections in both themes and desktop/390px widths.
Use the existing isolated website release process. Not deployed yet.

## October 14 website clarity live

Lane `release/web-launch-20261014`, based on `4e71506`, is complete in PR #72.
Runtime `65226c5` removes repeated shell/Collections/Space titles and the redundant
FindEZ section caption. Open rows, quiet dividers, simpler filters/secondary
actions, consistent spacing and bounded Review photos replace crowded containers.
Teams uses its visible tabs for section identity, Project kits has one Space
prompt and Labels tabs have proper spacing. Sidebar contraction is verified and
the original pinned preference restored. Routes, actions and permissions remain.
223 web tests, TypeScript, the actual-config production build and all five
exact-runtime CI gates pass (`38683070099`); lint has existing warnings only.
Both-theme/narrow component fixtures and signed-in Safari pages are checked.
The live web service now uses `web-clarity-20261014-r3/frontend`, build ID
`bSG_l1U3Nn-HPx_vC7FHX`. Public checks cover 11 routes, 17 protected route guards
and three workspace CSS assets; 1,006 old static assets remain for open tabs.
Production configuration and the dirty VM checkout are preserved. Backend PID
and start time are unchanged. Receipts, source hashes, build log and rollback
records are in `Documents/FindEZ/Releases/web-clarity-2026-10-14/published` and
`/home/ubuntu/findez-web-clarity-20261014-r3`. Shopify and public Apple submission
remain held; pricing is planned UI with paid purchases unavailable. Supporting
backend reliability work is not deployed by this web-only lane.

## October 14 one-time guided tour fix and TestFlight preparation

The user authorizes an updated TestFlight beta, then requires the intermittent
returning-user tour bug fixed first. Lane `fix/first-install-tour` is based on
`89b1bb9`. Replace per-account signup/rearm triggers with one installation claim,
consumed before display. Migrate existing installs to quiet state, cancel delayed
starts on disposal/account changes, and remove later automatic Space tours.
All 375 mobile tests with coverage and five runtime CI gates pass; analysis is
clean. Native upgrade/Space/cold-restart checks pass. TestFlight 1.0.8 (65) is
VALID and available to the two existing internal groups. Vinod's existing private
group is assigned, but Apple rejects 65's external review submission while build
64 is WAITING_FOR_REVIEW. Retry the saved build-65 helper's `prepare` and `status`
after 64 finishes; 65 is READY_FOR_BETA_SUBMISSION, not externally available yet.
Runtime source is `8fbfacd`, PR #71. Durable signed IPA/archive/receipts are in
`Documents/FindEZ/AppStore/1.0.8-build65`. Public App Store selection is verified
unchanged, Shopify remains held and no production backend deployment occurred.

## October 14 launch reliability candidate

Lane `fix/launch-find-reliability`, based on `3543cb7`, fixes name-only capture
aggregation, silent limit truncation, unsafe retries and web/mobile partial draft
loss. Real saved receipts and account-bound requests preserve capture identity.
ASK exposes match evidence and recorded-location semantics with unknown counts.
The user explicitly defers visual-similarity work because FIND source is absent;
Shopify stays disabled. Five-tier web/mobile pricing UI is planned only. Stripe,
StoreKit purchases/restores, verified entitlements and new limits remain unbuilt.
455 backend/API-doc tests, 223 web tests, 362 mobile tests with coverage, analysis,
TypeScript and the fictional-config web build pass. The native arm64 simulator
build passes; Plans, annual prices and back navigation are checked in both themes
and Light is restored. No production migration/deployment or Apple upload/submission.
See `HANDOFFS/2026-10-14-launch-readiness.md` for the capability audit and next gates.

## October 14 app-wide neutral UI accent refinement

Lane `feat/mobile-color-accents` now covers the user's app-wide accent request:
all shared action/selection roles are neutral grey/glass; bottom navigation
retains dedicated orange tokens. Floating plus buttons, Space filter pills,
Teams invite/icons, chat, onboarding/tour and default button styles follow the
same roles. Brand artwork and accepted Home number colours remain. The final
arm64 simulator app is installed, with native checks in both themes and Light
restored on Find. Analysis and all 357 mobile tests with coverage pass.
Screenshot proof is in the existing mobile-colors design
folder. No customer writes, TestFlight upload or public submission.

## October 14 two neutral glass selectors complete locally

The user explicitly confirms Capture's Scan Barcode/Auto Extract selector and
Find's Spaces/Teams selector. Neutral grey selection glass replaces their
orange fills and orange selected foregrounds. Existing motion, callbacks,
navigation palette and high-contrast fallback remain. Analysis and all 357
mobile tests with coverage pass. A complete arm64 native simulator app is now
installed and running, including the accepted Home changes. Native Capture,
Spaces, Teams and Home are visually verified; screenshots/receipt are in
`Documents/FindEZ/Design/mobile-colors-2026-10-14`. The older attach-only preview
was not persistent across relaunch; the new installed app addresses that.
Capture's initially heavy grey pill is subsequently softened on user feedback:
lighter tint/outline and regular label weights, with high-contrast fallback
retained. Analysis and all 357 tests pass again; the updated installed app is
visually checked in light and dark themes and left on Capture in Light mode.
Native proof uses the `capture-soft-grey-glass` filenames in the same folder.
No new TestFlight upload or public submission. Wait for further directions.

## October 14 Home-only colour correction complete locally

Lane `feat/mobile-color-accents` in `dev/findez-mobile-color-accents`, based on
`3a36026`. The accepted scope is Home numbers only: mustard identifying,
purple buying, maroon out of stock, forest green lent. Cards/labels stay neutral;
search hint is smaller regular grey (14pt), with regular grey suggestion text
(12pt) and full-size typed input (17pt). Unknown counts retain neutral dashes.
Rejected card fills and other-page experiments are removed from the candidate.
Analysis, all 357 existing mobile tests with coverage and both-theme colour
contrast pass. Home is visually checked on the actual iPhone 16e debug simulator
after attach/hot restart, using the existing native shell. Proof is in
`Documents/FindEZ/Design/mobile-colors-2026-10-14/home-numbers-light-native.png`.
No new TestFlight upload or public submission. Wait for next-page directions.

## October 14 backend fixes live; mobile 64 internal TestFlight delivery complete

Lane `fix/capture-review-save-boundary` in
`/Users/tanyasmritivictorcharles/dev/findez-capture-save-boundary`, based on
`722b5c0` from punctuation PR #67. Capture previews are local to the client and
carry a bounded 24-hour signature binding owner, identity, source key, original
FIND evidence and photos. A new authenticated POST saves a preview into existing
`capture_reviews`; editable identity fields cannot replace signed observations
or photos. Duplicate saves reuse one source key, handled records cannot revive,
and tampering, another account or expiry fail before a queue write. Mobile/web
preserve proof through edits/confirmation and save only after the explicit action.
Old saved reviews keep PATCH/resolve/dismiss; extraction without the new flag
retains old-client compatibility. Chat photo questions no longer create reviews.

Local validation passes 438 backend/API documentation tests and six subtests,
212 web tests, TypeScript, changed-file lint with existing warnings only, 357
mobile tests, clean Flutter analysis and a production web build with fictional
configuration. Runtime `19089e9` in Draft PR #68 passes all five CI gates
(`38551614029`). Preflight matched eight existing backend file hashes and
confirmed both new helpers absent. The combined ten-file
backend bundle, patches and manifest are in
`Documents/FindEZ/Releases/capture-save-boundary-2026-10-14`. Web uses
the installed dependencies from an identical lockfile, with a gitignored local
node_modules symlink. Local build configuration is fictional and must not ship.
The user authorizes deployment. The ten backend files are selectively deployed
with guarded hashes and rollback backups at
`/home/ubuntu/findez-capture-fixes-20261014.1ztxtg/backup`. Unrelated checkout
files are verified unchanged. Service/database health, missing-session and
invalid-key 401s, reply punctuation, real preview signing, owner binding and
the signed save route pass without database writes or FIND/model requests.
Receipts are beside the source bundle. No migration or historical Review
deletion was performed. Updated web source is not deployed.

Mobile 1.0.8 (64), runtime `8001b13`, passes all five exact-source CI gates
(`38554740296`), clean signed archive/export, production configuration/assets,
strict signatures and all 31 native device-platform checks. Apple validation,
upload and processing complete without errors/warnings. Delivery
`3dc129af-4c32-48f7-a69d-d55c9e97cdef` is VALID/APP_STORE_ELIGIBLE/
IN_BETA_TESTING in Testers and Internal Pilot Findez AI with saved test notes,
verified at 04:54 PDT October 14. Durable receipts, archive/IPA and phone
acceptance checklist are in `Documents/FindEZ/AppStore/1.0.8-build64`.
The new binary uses preview-only extraction and the signed Save route.
TestFlight 63 stays available with the legacy Capture contract. No build-64
simulator or physical pass is claimed. Repeat physical camera/library
random-photo/cancel/Home, photo chat, explicit Save, retry and owner isolation
on build 64, plus the outstanding native service and accessibility checks.
Public App Store selection/release type are verified unchanged; public
submission and Shopify remain held.

Build 64 is also submitted to TestFlight beta review at the user's request for
one existing external tester. The private `Vinod Private Testing` group has
only that tester, no public link and build 64. Status at 05:08 PDT October 14
is WAITING_FOR_REVIEW/WAITING_FOR_BETA_REVIEW with automatic notification
enabled. The tester previously accepted FindEZ's invitation; Apple returns
ALREADY_ACCEPTED to resend, so no new invitation is claimed. External access
needs Apple approval. Receipts and the helper are in the build-64 release folder.
Existing internal groups stay available, the broader external pilot group is
unchanged, and public submission stays held. Do not grant App Store Connect
roles or remove/recreate the tester to bypass review.

## October 14 chat punctuation prepared

Backend-only lane `fix/ask-response-punctuation` in
`/Users/tanyasmritivictorcharles/dev/findez-chat-punctuation`, based on `1604e68`.
Shared response instruction and output normalization cover normal/streamed
text chat, deterministic project replies, photo explanations, document/image
upload replies and legacy EEZY. Normalization happens before session/history
persistence; it does not change user messages, tool payloads or source records.
Runtime `3b1c824` in Draft PR #67 passes all five CI gates (`38548331842`), all
426 local backend/API documentation tests and six subtests. The added tests
check emitted/final/session consistency and preservation of tool data, Unicode,
newlines, source labels and input. Preflight matched four live hashes and
confirmed the new helper absent. The exact five-file bundle,
patch and hash manifest are in
`Documents/FindEZ/Releases/chat-punctuation-2026-10-14`.
This is live in the combined deployment above; no schema, FIND, auth, frontend
or mobile source changes belong to punctuation. Existing history,
TestFlight 63 and held public submission remain as recorded below.

## October 14 build-63 internal TestFlight delivery complete

Final runtime `8abe3cc` on `feat/mobile-submission-polish` (PR #62) is delivered
as 1.0.8 (63) to both existing internal groups. Analysis, 353 mobile tests with
coverage, all five exact-source CI gates (`38543470459`), clean signed export,
production configuration/supplied assets, app/extension signatures, 31 native
device executables and Apple validation/upload pass. Apple delivery
`81fcc8ae-92f0-4d05-9dd0-e4a0a492e0c1` is COMPLETE without errors/warnings, and
63 is VALID/APP_STORE_ELIGIBLE/IN_BETA_TESTING with saved test notes at 02:56 PDT.

Includes Home Account/four tabs, light weights independent of OS Bold Text,
focused chat, concise import, supplied logo/Light default, setup X, compact tour,
spring navigation and neutral glass controls. Native Home/Account, image-backed
captures, Light/Dark glass choices, setup and empty Ask are checked; the inner
chip canvas is transparent to retain continuous glass outlines. Native typed
chat, full tour/import and physical accessibility/native-service acceptance are
still pending through the final TestFlight binary. No real inventory/setup writes
or global phone preferences were changed. User-authorized generated cache cleanup
resolved disk pressure, preserving source, signed packages and supplied assets.

Durable release records are in `Documents/FindEZ/AppStore/1.0.8-build63`.
The earlier validated candidate remains preserved and was not uploaded. Public
59, manual/unselected draft 1.0.8 and Shopify's separate paused source are
verified unchanged. Public App Review remains held; Shopify is excluded.

## October 14 Home account entry and stable light typography

Delivered in build 63 on `feat/mobile-submission-polish`. User removes the
Profile tab, moves its entry to the top of Home and requires stable light weights
regardless of iOS Bold Text. The pill now has Home/Capture/Ask/Find with four-tab
spring geometry. A small Home control opens Account, preserving profile editing,
settings, documents, notifications, lent items and setup questions. The same
profile store and live notification notifier serve both Home and Account; late
badge reads remain fenced. Shared body/input weights are 400 and emphasis caps
at 500; only automatic weight changes are suppressed. Text size and other
accessibility preferences remain. Shopify stays paused; no API/schema, native
lifecycle, production or Apple submission changes.

## October 14 spreadsheet clarity and focused chat

Delivered in build 63 from `feat/mobile-submission-polish` in
`dev/findez-logo-light-default`. User requests fewer import-page words/icons and
conversation focus after sending, in the existing screen. The import ready view
now shows the destination, Choose file and format/size limit. Existing picker,
validation, import, retry, partial-result reporting and navigation are retained.
MainShell uses ChatPage's message state to hide its pill during conversations.
Pinned Back returns to the previous tab without resetting the same ChatPage,
messages, draft or in-flight stream. New chat restores the normal Ask navigation.
No backend/API/schema, Shopify, production or Apple submission changes.

## October 13 mobile pre-submission polish

User requests an unbranded questionnaire header with an accessible X, exclusion
of pictureless imports from Home captures, a compact translucent guided tour,
350 ms spring navigation with fixed icons and Reduce Motion cross-fades, and
simpler Ask presentation. Source lane `feat/mobile-submission-polish` in
`dev/findez-logo-light-default` continues the authorized supplied logo and
Light-default changes from build 62. Existing source branding edits are preserved.
No App Review submission or production change is performed. Screenshot ZIPs are
uploaded and checksum/order verified in the 1.0.8 draft. The user's latest October
14 instruction pauses Shopify and excludes it from this launch. Preserve its
separate source, draft PRs and test resources; keep them disabled and unshipped.
Do not continue Shopify work until the user asks to resume.

## October 12 clarified tutorial and onboarding questions

The user identifies the six-step in-app spotlight tutorial, then requests useful
onboarding questions recorded for the operator. They choose intended use,
inventory types, primary goal, and working alone/with others, with production
database storage first. Current lane `feat/onboarding-questions` includes the
adaptive tutorial (`92d5f9a`), a four-question optional setup replacing demo
slides, account-bound pending answers, confirmed-save retry and Profile editing.
Migration 041 adds owned `onboarding_responses` with account-deletion cascade,
owner-only reads and backend-only writes; no Team/inventory data is generated.
419 backend, 211 web and 338 mobile tests pass; PostgreSQL isolation/validation,
clean analysis, native questionnaire completion and Light/Dark/Auth screenshots
pass. Production migration/API and privacy disclosure are selectively deployed
with private backups; authenticated save/read/idempotency/owner checks pass and
the new review-account QA row is removed. The user’s final outlined-choice
reference is implemented without radio circles or a decorative badge. Auth is
concise, with optional work-detail expansion and preserved signup eligibility.
All five exact-runtime CI jobs pass on `346d9ae` in `38346877463`. Clean signed
1.0.8+62 passes signatures/configuration, all 31 native device executables and
Apple validation/upload. Upload `3ab7200b-5045-499f-accb-2d5f4f7b6f2c` is COMPLETE
without errors/warnings; build 62 is VALID/APP_STORE_ELIGIBLE/IN_BETA_TESTING and
both existing internal groups/test notes are verified at 21:49 PDT October 12.
This lane is complete. Durable release records and the deferred phone checklist
are in `Documents/FindEZ/AppStore/1.0.8-build62`. Public 1.0.7 (59), manual/unselected
1.0.8 and requested metadata are unchanged. Physical acceptance remains deferred,
public submission held, and unrelated live VM work preserved. The older build-61
introduction is superseded and did not correct the spotlight tutorial.

## October 12 requested sequential updates

The user requests: exact App Store name `FindEZ: AI Inventory` and subtitle
`AI item recognition & search`; deletion of Space-owned Home attention/review
entries; broader inventory positioning and alphabetized/custom team categories;
and a cleaner first-launch walkthrough in Light/Dark. Name/subtitle are saved
in the editable 1.0.8 App Store draft (metadata requires a new approved version).
Build 60 is already delivered to both existing internal TestFlight groups.

Completed lane `fix/deleted-space-review-refresh`, based on `6a406e8`, in the
existing mobile-notifications checkout. Production review rows have only a
location string, so pending identifications survive Space deletion. Home/cache
also need immediate mutation invalidation. Migration 039 binds owned matching
reviews to a stable Space ID with cascade deletion and rename synchronization;
unassigned reviews and other owners remain separate. Mobile invalidates old
reads and refreshes Home after confirmed deletion without fabricating a count.
All 317 mobile tests/coverage, clean analysis and full disposable PostgreSQL 17
permissions/lifecycle checks pass. All five exact-runtime CI jobs pass on
`e3bb2f6` in `38310437658`, draft PR #56. Migration 039 is deployed with verified
cascade FK/triggers, unchanged pending count and healthy database. The mobile
fix awaits the combined next binary; web copy deploys with the next lane.
The web delete confirmation also describes item/review deletion accurately.
The user identifies deleted
Robot Room and provides their account privately for a targeted existing-entry
repair; do not write that email or private row snapshots to repository context.
Their Robot Room still exists with six pending records, so do not purge them as
orphans. Binding them to the current Space lets its next deletion remove them.
Completed lane `feat/inventory-team-categories`, based on `e34b37b`, adds 29
alphabetical general inventory group categories with a bounded persisted custom
label, neutral create forms and shared display labels. Migration 040 precedes
backend/client deployment. Existing program keys, licensing and access stay
compatible. README, current product context, learning guide and the legacy EEZY
prompt describe homes, businesses, labs, teams and industry. Focused backend,
mobile Light/Dark failed-draft and PostgreSQL checks pass; full checks/deployment
pass. All five CI jobs pass on `2384bbd` (`38312460669`, draft PR #57).
Migration 040, selected backend files and isolated web release are deployed;
private backups/verified manifests and web rollback remain available. Public
checks pass without creating real data. Current lane `fix/onboarding-light-dark`
from `2384bbd` simplifies the four local examples in both themes while preserving
Skip/Back/replay/invitation/launch state. All 319 tests, clean analysis and rendered
Light/Dark/narrow/large-text checks and native walkthrough completion/restart
pass. All five CI jobs pass on `86669ee` (`38314482069`). Apple validation catches
a cached simulator `objective_c.framework` in the first signed 1.0.8+61 export;
the rejected package/receipts are preserved. Clean runtime `5acd4c7` passes all
five CI jobs in `38336413029`, strict signatures, production configuration and
device-platform checks for 31 native executables. Apple validation/upload pass
without errors at 19:27 PDT October 12; delivery
`f6a6c33f-7c34-4091-8df7-1c4ebf35e274` is COMPLETE without errors/warnings.
Build 61 is VALID, APP_STORE_ELIGIBLE, nonexpired and IN_BETA_TESTING; both
existing internal groups and saved test notes are verified at 19:31 PDT.
This delivery lane is complete. Durable archive/IPA, verifier,
receipts and deferred phone checklist are in `Documents/FindEZ/AppStore/1.0.8-build61`.
Public App Store submission remains held; released 59 and the manual/unselected
1.0.8 draft, including requested metadata, are verified unchanged after delivery.
Physical phone acceptance remains deferred by the user.

## October 12 build-60 TestFlight delivery

The user authorizes TestFlight upload/internal-group delivery with phone testing
still deferred. Apple has approved/released 1.0.7 (59); the US storefront confirms
1.0.7 and ASC reports `READY_FOR_SALE` with selected 59 and manual release type.
The original 1.0.7 (60) validation fails because that train is closed. Runtime
`a6ea4c5` changes only version metadata to 1.0.8+60. All five CI jobs in
`38302159412`, signed archive/export, strict app/extension signatures, App Store
profiles and production configuration checks pass. Apple validates and accepts
upload `87711752-2586-445c-a2a5-ebc12e7b4b94` at 13:17:03 PDT.
Apple processing is COMPLETE without errors/warnings. Build 60 is VALID,
APP_STORE_ELIGIBLE, nonexpired and IN_BETA_TESTING. Both existing internal groups
include it and the test notes are saved; public build-59 selection/manual release
type are verified unchanged. Phone acceptance remains deferred. No
App Store selection, review submission or public release change is authorized.
Durable artifacts are in `Documents/FindEZ/AppStore/1.0.8-build60`.

## Native notification permission and read state (October 11)

Sequential lane `fix/mobile-notification-permissions` in
`/Users/tanyasmritivictorcharles/dev/findez-mobile-notifications`, based on
`5b21899`. Existing OS authorization reconnects without a launch prompt; the
inbox has an explicit Enable action and denied permission links to Settings.
Registration is serialized, bounded natively and guarded against an account
change. Device writes capture authentication. Logout stops OS delivery and clears
alerts; next registration reassigns the server token to the authenticated user.
The app does not issue a server token-delete request during offline logout.
Inbox reads are explicit, re-fetch after a successful write, keep rows on failure,
refresh while visible/resumed and publish validated account-scoped counts. Shell
generations prevent late badge reads from undoing inbox writes. The auth gate
keys the shell by account; old routes close on account changes. Local stock
refreshes no longer trigger the first permission request; setting a threshold
remains the explicit reminder action. Decorative feed cards/dividers and the
test-push toolbar action are removed.

All 312 mobile tests with coverage and clean analysis pass, including a delayed
shell-count regression; Swift parses and native simulator compilation succeeds
with production defines. Candidate is 1.0.7 (60). Signed archive/export and
October 12 package verification are complete: strict main/extension signatures,
App Store profiles, production configuration/APNs and compiled feature markers
pass. All five runtime CI jobs pass on `37c5055` in `38210945770`, draft PR #55.
IPA SHA-256 is `4f07de9e189809ef219a9cf9aa5558cd8a16a1231184b6be188882f7e5c208bc`.
The durable package in `Documents/FindEZ/AppStore/1.0.7-build60-prepared` includes
verification JSON/script, checksums, phone acceptance checklist and the requested
legal/privacy follow-up report. Apple server validation/upload/submission are not
performed. The user explicitly chose preparation now and physical testing later
because the connected iPhone is unavailable. Keep camera/library/voice, public
legal links, actual APNs delivery/tap/badge and logout/relogin acceptance pending.
Do not upload or replace pending App Review build 59 without release authorization.

## Canonical legal and permissions (October 11)

Sequential lane `fix/canonical-legal-pages` in
`/Users/tanyasmritivictorcharles/dev/findez-canonical-legal`, based on `a67260e`.
Prepared web Privacy/Terms, informational cookie notice, simple public navigation,
legacy page redirects, signup acknowledgment and honest deletion-failure copy.
Mobile links open the same public documents; purpose strings describe actual
camera/library/voice uses and unused location/save-photo declarations are removed.
Official registry verifies AI ROBOTS INC (4578465), Active, filed March 16, 2020,
887 Poppy Ct, Sunnyvale, CA 94086. Current facts, legal-review priorities and
engineering limitations are recorded in CURRENT_STATE. Web 210 tests, TypeScript,
changed-file ESLint, webpack build and Safari public-page checks pass. All 301
mobile tests with coverage and clean Flutter analysis pass. Web `1e6a8b3` is live
from `web-canonical-legal-20261011`, draft PR #54; all five CI jobs pass on
`d459df3` (`38209066849`), whose web source is identical and whose signup checkbox
has its own Material layer for the newer Flutter CI version. Server build/tests,
public guards/redirects/assets/docs/origins and Safari pass. 702 old static files
are retained with a rollback drop-in. No new native binary, push-delivery
acceptance or Apple submission is claimed yet.
Mobile notifications remain the next scoped lane. Preserve pending build 59.

## Notification refresh and read state (October 11)

Sequential second lane: `fix/notification-refresh` in
`/Users/tanyasmritivictorcharles/dev/findez-notification-refresh`, stacked on #52.
Web bell counts consume account-scoped inbox snapshots and invalidate pending
reads after writes; cross-tab invalidations trigger a fresh server read. Inbox
refreshes on focus/visibility and every 30 seconds while visible, preserves rows
during refresh/failure, validates payloads, and re-reads after marking read so a
new event stays unread. Empty copy explains the Team feed. Tests cover failed
reads/writes, account switches, stale badge responses and new events during reads.
All 203 web tests and 380 backend/API-doc tests pass; TypeScript and ESLint have
no errors (one intentional generation-ref warning). Web webpack compilation
passes with the fictional local environment. Safari confirms a successful read
clears both the unread dot and bell immediately. Broadcasts carry a source ID
to avoid invalidating the sender document twice. Runtime `0189a17` is live from
`web-notification-refresh-20261011`, draft PR #53 stacked on #52. All five CI jobs
pass (`38204481906`); server build/tests and public guards/assets/origins/headers
pass, with zero production dependency vulnerabilities and 622 old static files
retained. A rollback drop-in and source manifest are beside the release.
No backend runtime, schema or native files are
changed. Seven focused notification backend/APNs tests pass.

Read-only production checks confirm recipient/read/activity/push tables and
APNs configuration/key file availability. No push message was sent; neither
configuration nor mocked APNs payload tests prove physical delivery. Native
auto-permission prompts, inbox badge/read races and physical push acceptance must
be addressed with the later mobile permissions/link lane and a new binary.
Keep pending build-59 App Review unchanged until explicit release authorization.

## Professional interface, notifications and canonical legal pages (October 11)

User requests sequential completion: (1) Markdown and cleaner chat, (2) less
unnecessary web chrome/copy and lines, (3) tab titles with a vertical bar,
(4) a pinned sidebar that resizes the page, (5) working notifications,
(6) consistent, readable Privacy/Terms opened on the website from mobile,
(7) appropriate cookies/permissions and a concrete lawyer-review report,
(8) removal of redundant marketing dropdowns/pages from legal browsing.

Current lane: web-only `fix/web-professional-polish` in
`/Users/tanyasmritivictorcharles/dev/findez-web-professional-polish`, based on
`9073143`. Markdown is safely rendered with generated images/raw HTML disabled;
Sources collapse, history is unboxed, redundant copy/status is reduced, empty
states/list wrappers lose decorative borders. Tab titles are contextual and use
`|`. Sidebar has a keyboard-accessible pin, blank-area double click, remembered
preference and responsive frame sizing; the closed narrow drawer is inert.
The user explicitly corrected the font scope: keep the current app font, change
AI responses only. Source Sans 3 is self hosted for those responses. Next.js and
compatible dependency patches are applied; production npm audit reports zero
known vulnerabilities. Full web run passes 195 tests; TypeScript, changed-file
ESLint (no errors, existing warnings) and production webpack compilation pass.
Safari checks confirm Markdown, Sources, desktop pin resizing, clean Home and
notification/settings layouts. Home hides zero-work attention sections and
suggestion chips; pending reply status is scoped to its message during retries.
The web lane is deployed; no new native binary is delivered for this lane.

Fictional browser fixture: `/private/tmp/findez-web-polish-fixture.cjs` on
localhost:4109 (session 13259), production Next on 127.0.0.1:3017 (session 80626).
`frontend/.env.local` contains fictional local URLs only and MUST NOT be deployed.
Safari has an isolated `Ask | FindEZ` tab, verified bold/list rendering, source
disclosure, double-click pinning and page resizing. Do not alter real inventory.
The isolated server candidate is `web-professional-polish-20261011`. Preflight
hashes preserve 217 baseline files; its source archive excludes the local fixture
environment. Three unrelated live presentation files (globals.css, shared dialog,
spreadsheet import modal) are carried unchanged from the previous running release.
Collections uses the existing theme tokens to correct hardcoded dark-mode text.
Older live tests are replaced with the current repository tests, including the
previously missing review queue suite. Source manifest and rollback drop-in are
beside the candidate. Runtime `6960b2d` is live; all five PR-head CI jobs pass
(`38203294862`, draft PR #52, stacked on #51). Candidate and public HTTPS checks
verify title/headers, all 18 protected page guards, 16 static assets, exact API
reference and production origins with no fixture URL. Both services are healthy;
527 previous static assets are retained. Safari also verifies light-mode replies
and the 800px drawer's background isolation/open/close behavior. Notification
behavior and legal/mobile content remain the next lanes.

User confirmations: AI Robots Inc, registered in 2020 in Sunnyvale on Poppy Ct.
Official California registry details have now been verified as recorded above.
Serve countries where Apple permits availability; student accounts are 13+.
Analytics/advertising are not in use and no providers are selected. Cookie
disclosures must reflect actual essential storage; do not add trackers or fake
optional consent controls. Canonical mobile legal links/permission changes will
need a new iOS binary. Do not replace the pending build-59 App Review submission
without explicit release authorization. Remaining lanes: notifications, then
shared legal/content/permission controls and public navigation cleanup. Legal
accuracy needs primary-source research, factual data-flow audit, and specific
lawyer-review gaps; do not promise protection from all legal risk.

## Ask photo clarity (October 11)

User-requested fix for repetitive, confusing image replies in web and mobile.
Backend-only lane `fix/ask-photo-summary` in
`/Users/tanyasmritivictorcharles/dev/findez-ask-photo-summary`, based on `7de3913`.
The shared photo formatter groups duplicates, puts clear identifications first,
summarizes uncertainty and stock once, omits noisy categories and generic unknown
matches, and shows measurements only when requested. For noisy scenes without
product identifiers, the existing language gateway selects at most three coherent
main subject labels using validated indices; it cannot introduce an identity or
stock fact. The 12-second timeout and invalid/unavailable-response fallback keep
deterministic output available. Preserve the SSE/snapshot contract, access scope, Review
persistence and explicit inventory confirmation. Existing clients consume the
same text; no mobile binary or web rebuild is required. Focused photo tests pass
(60). Full backend suite passes (376), and all five exact-runtime CI jobs pass
on `fefcfe9` (`38195426179`). Draft PR #51 is stacked on #50. Both reviewed backend
files are deployed with original hash guards and backups in
`/home/ubuntu/findez-ask-photo-20261011`. Live consolidation with synthetic labels
returned a validated subject in 4.66 seconds; no source image or inventory data
was sent to selection. Both deployed hashes match, `findez` is active, and
public `/health` and `/health/db` return 200 on the configured API origin
`https://findez.openstack.ftctools.com`; unauthenticated `/ai_photo_question`
returns 401. The initial public check used the obsolete `api.findez.ai` hostname;
current-origin verification is recorded in `deployment.json`. Original dirty VM
work, both clients and the pending App Review binary are preserved. Genuine new
image recognition still needs user acceptance; saved conversations are not
rewritten, and consolidation does not guarantee every underlying identification.

## App Review clarification and native screenshots (October 8)

Continued on `fix/app-review-build58` in
`/Users/tanyasmritivictorcharles/dev/findez-app-review`, based on `669dde0`.
Apple rejected submission `2b777948-f7bd-46b3-bf43-9a2e60074361` for AI information
and non-iOS screenshot status bars. The developer confirms that FIND and agent
model inference run on their own servers. Source and running non-secret backend
configuration match that architecture. Optional Apple Speech transcription and
user-configured external API assistants are separate exceptions and must be
disclosed. Mobile Privacy Policy and Terms still named OpenAI in submitted 58;
the correction is prepared as candidate 59. Runtime AI, permissions and API
behavior remain unchanged. All twelve genuine build-58 iPhone/iPad captures are
verified using the existing review sample account, with no inventory writes.
Runtime `68fbe55` passes analysis, all 296 mobile tests with coverage, formatting,
native simulator compilation and all five shared CI jobs (`37866116183`). Native
59 opens with the corrected effective date; compiled debug and release text
checks verify all disclosures and absence of the obsolete OpenAI wording.
Signed archive/export, strict exported signature, App Store provisioning,
production API/auth and push configuration all pass. Durable IPA, draft response,
screenshots/ZIP and verification JSON are in
`Documents/FindEZ/AppStore/1.0.7-review-fix`; Draft PR #50 is stacked on #49.
Local storage interrupted the first builds; user-approved build/dependency/cache
cleanup recovered them. Original artwork, source, production and public release
are preserved. The user authorized continuing the prepared delivery. Apple
validation and build-59 upload pass without errors (delivery
`4c3ff9ff-6310-48cb-91ff-79c89af796d3`, 18:08:32 PDT). All six native iPhone and
six iPad screenshots are uploaded, COMPLETE and verified in order/checksum;
smaller sizes inherit these sets. The clarification is sent and visible in the
review thread at 18:09 PDT. Build 59 is VALID/APP_STORE_ELIGIBLE, nonexpired and
IN_BETA_TESTING. It is selected for 1.0.7, and the existing submission was
resubmitted at 18:19:39 PDT October 8. Submission/version are WAITING_FOR_REVIEW.
Manual release remains selected and public build 17 remains live. All five
docs-head CI jobs pass (`37867707683`, `28f8ffe`).

## Landing copy and returning-user navigation (October 8)

Implemented and deployed on `fix/landing-dashboard-link` in
`/Users/tanyasmritivictorcharles/dev/findez-web-navigation`, based on `f36ca25`.
Runtime `a4d1fc1` removes the hero's chatbot/database paragraph and replaces top
signup/sign-in actions with Dashboard for signed-in visitors. The landing uses
server-verified initial identity; marketing navigation follows browser session
events. All 184 web tests, TypeScript, lint and local/server builds pass. Safari
verified the live anonymous hero, fictional signed-in landing/desktop marketing
headers and mobile Dashboard opening Home. Final CI evidence is recorded on
draft PR #49, stacked on #48. Self-hosted release:
`/home/ubuntu/findez-web-releases/web-landing-dashboard-20261008/frontend`.
Interior source, animation/assets, API, backend, mobile, production environment,
original dirty checkout, existing collection colors and prior assets are retained.

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

The October 5 instruction authorized the original submission. FindEZ AI 1.0.7
(58) was submitted at 2026-10-06 06:06:37 UTC (October 5, 11:06 PM PDT), then
rejected on October 7 for AI information and non-iOS screenshot status bars.
Submission `2b777948-f7bd-46b3-bf43-9a2e60074361` remains rejected. The October 8
correction package above is prepared locally; manual release is preserved.

All six supplied iPhone PNGs and six supplied iPad PNGs are uploaded in order,
COMPLETE, and checksum-identical to the ZIP originals. Listing description,
subtitle, promotional text, keywords, release notes and reviewer instructions
follow the supplied physical-memory vision and contain no em dashes. Future
roadmap features are not advertised as implemented. Reviewer login, eight live
read endpoints, six consistent sample-inventory reads, website/privacy URLs and
all five exact-runtime CI jobs pass. Simulator Home/Spaces were observed; a full
physical-device acceptance pass was not repeated. Public version 1.0.6 (17)
remains available while the review correction is prepared. Runtime, backend, database,
billing, original logo assets, native lifecycle and FIND transport are unchanged.

| Work | Area | State | Dependencies and handoff |
|---|---|---|---|
| App Store review correction | Apple listing, screenshots and release records | October 7 rejection `2b777948-f7bd-46b3-bf43-9a2e60074361` was corrected and resubmitted October 8 at 18:19:39 PDT. Version 1.0.7 selects VALID/APP_STORE_ELIGIBLE policy-only build 59 (`68fbe55`), WAITING_FOR_REVIEW, manual release. | All twelve native screenshot replacements are COMPLETE and verified; the four-answer AI reply is sent October 8 at 18:09 PDT. Apple validation, upload, selection and resubmission are verified. Original artwork and release records are preserved in the durable AppStore folder; Draft PR #50 records the correction. Physical acceptance was not repeated. |
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
