## October 28 — Immediate streaming and inventory contextual chat

`feat/mobile-context-chat`: immediate received deltas on main chat, isolated inventory assistant sheets on work pages, keyboard-aware monochrome presentation. Full 1,204 host tests, 36 final focused checks and clean analysis. Native verification and build153 delivery tracked in `docs/plans/context-chat-mobile.md`. Main unchanged.

## October 28 - Onboarding v5 delivered to TestFlight 152

Apple acknowledged TestFlight 1.1.1 (152), source a9bf2f09f6135b49133f32722ac57d3e42b79e73, delivery 7ad953ff-2000-464b-a4d0-1194b2fba15c. All five CI gates (40809523164), 1,199 mobile tests with one existing skip, clean analysis, nine native iOS flow checks, approved disposable account persistence/cleanup, 34 archive/export device binaries, 26 privacy manifests and Apple validation passed. Processing/tester availability remains pending and was not polled. Physical OAuth, VoiceOver and motion acceptance remains pending. User requested main unchanged; release uses feat/onboarding-v5 and draft PR263 against release/onboarding-v5-base. No database migration or public App Store submission. Receipt: docs/onboarding-v5/RELEASE-152.json.

## October 27 - Mobile branding v5 (completed locally)

User-supplied launch handoff. Isolated mobile-brand-v5 branch; branding only outside web landing. Latest user authorizes self-hosted web publication after verification. Mobile remains local, no TestFlight upload.

## October 26 — Build149 rollback delivered as TestFlight151

At the user's request, the complete mobile tree is restored to build149 (`ca3a43a`, runtime `6044eb0`), with only the release number changed to151. Build150 onboarding/Scan changes are removed and its unmerged PR260 is closed. Replacement runtime `7da9f72`, PR261. Apple acknowledged TestFlight1.1.1(151), delivery `ee9a130a-e4d9-42db-98a7-0d376e128ed1`. All five exact-source CI gates (40460187327), 1,190 mobile tests plus one existing skip, clean analysis, strict signing, 34 archive/export device binaries, 26 privacy manifests, production configuration and Apple validation passed. Simulator151 is installed with app data preserved; simulator returned to its prior shut-down state. IPA/archive preserved. Processing/tester availability pending, not polled; physical acceptance unverified. Public submission stays held. No web/server/database/customer-data changes. Receipt: `docs/plans/mobile-build149-rollback-receipt.json`.

## October 26 — Photo-only Scan entry delivered to TestFlight 150

Apple acknowledged TestFlight 1.1.1 (150), runtime `7f0e5f7`, PR260, delivery `2fb5cce0-e2ba-4a16-907d-ebc11770a7a0`. Personal/Team precedes authentication; Personal opens Ask, Team creates its organization and answers a single-choice referral question. Monochrome Scan, first-scan preview and Space Scan use Take Photo or Photo Library with existing extraction and explicit review/save. Live Scan Frames, periodic capture and Auto-add are removed at the user's request. Existing draft recovery is preserved; no web/API/schema/provider changes.

1,209 mobile regression tests (one existing skip), 20 final focused tests, 23 synthetic iOS flow/layout checks in light/dark and large text, clean analysis, all five exact-source CI gates (40458324893), strict signing, 34 archive/export device binaries, 26 privacy manifests, production config and Apple validation passed. The normal simulator app is installed and open on iPhone 17 Pro, with a copy in the build150 release directory. IPA/archive preserved. Apple processing/tester availability is pending and was not polled. Physical camera, permissions, OAuth, VoiceOver and resume acceptance remain pending; public submission remains held. Receipt: `docs/plans/mobile-photo-scan-entry-receipt.json`.

## October 26 - Mobile welcome shimmer delivered

Apple acknowledged TestFlight 1.1.1 (149), runtime `6044eb0`, PR259, delivery `26c6c078-ae68-4312-88cb-d5ccfeb9d9de`. All empty-chat headings use a monochrome four-second left-to-right sweep with a one-second pause, matching web. Mobile progress was already bird-free; the separate Auto Extract mascot stays. Build149 includes startup recovery148. 1,190 full tests (one existing skip), four final timing tests, clean analysis, four native iOS checks, all five exact-source CI gates (40450237050), Apple validation, strict signing, 34 archive/export device binaries, 26 privacy manifests and production configuration passed. IPA/archive preserved. Processing/tester availability pending and not polled; physical acceptance unverified. Public submission stays held. Receipt: `docs/plans/mobile-chat-welcome-shimmer-receipt.json`.

## October 26 - Startup onboarding save recovery delivered

Apple acknowledged TestFlight 1.1.1 (148), runtime `a0c9c64`, PR257, delivery `e8ded15a-fed2-49dc-9d79-b08ec63f44ce`. Retained onboarding drafts with empty categories now use Other at the save boundary while preserving request IDs and supplied categories. Startup recovery offers Continue to app without deleting the draft, differentiates read failures from save failures, and supports large text. 1,188 mobile tests plus one existing skip, clean analysis, three native iOS checks, all five CI gates (40446544011), Apple validation, strict signing, 34 archive/export device executables and privacy/configuration checks passed. No server or schema change. Processing/tester availability is pending and not polled; physical startup acceptance for148 remains unverified. Public submission is held. Receipt: `docs/plans/onboarding-save-recovery-mobile-receipt.json`.

## October 26 - Organization recall, saved-photo vision, Tools and extraction progress

Apple acknowledged TestFlight 1.1.1 (147), source `4a6ae7d`, PR256, delivery `ae945b42-3114-4f8e-aac4-747593e0024c`. Extraction loaders consume real preparation/upload/provider progress and show elapsed time during a long stage. Stop, late-result protection, reduced motion, large text and old JSON API compatibility are preserved; scans are not resubmitted for compatibility. 1,185 host tests passed with one existing skip, analysis is clean, and six selected native iOS checks passed. All five exact-source CI gates (40443344737), Apple validation, strict signing, 34 archive and 34 export device-binary checks, 26 privacy manifests and production configuration passed. Archive/IPA preserved. Processing/tester availability was not polled. Physical acceptance for build147 is unverified; public submission remains held. Receipt: `docs/plans/extraction-live-progress-mobile-receipt.json`.

## October 26 — Mobile signup plans delivered to TestFlight 145

Apple acknowledged 1.1.1 (145), source `4e41564526e9c91d4c3c158c119ee1e20304c0a0`,
delivery `3d9be244-7275-4680-8173-5759447e8ba7`. PR244 adds a skippable verified-signup
popup and Settings plan cards with a baby-blue glass finish. Prices match web;
Team includes ten people. Early access stays free; paid billing remains inactive.
All five CI gates (40426021126), Apple validation, strict signing, 34 archive/export
device binaries, 26 privacy manifests and production configuration passed.
1,178 host tests passed/one existing skip; final 14 focused tests, six native cases
and Flutter analysis passed. Final screenshots reviewed in both themes and large
text. Processing/tester availability is pending and was not polled. Physical
signup/VoiceOver acceptance for this build is unverified; public submission stays
held. No server deployment or migration. Receipt:
`docs/plans/mobile-signup-plans-receipt.json`.

## October 26 - Extraction keyboard follow-up, public submission held

User reported inaccessible composer/keyboard and duplicate headers in Auto Extract after pausing submission. Mobile lane fix/mobile-app-store-audit now pins the composer below a bounded scrollable preview, focuses the outer shell on scan start, adds keyboard dismissal, simplifies scan status and preview, and restores world response actions/photo retry. Full suite 1,167 passed plus one existing skip; 11 focused native checks passed in both themes/small/standard phones/large text. Apple acknowledged TestFlight1.1.1(144), delivery 383aea8e-cbb8-4fc8-9699-127e5df50e84, source 8a8bb6c. All five CI gates, Apple validation, signing/device-platform/privacy/config checks passed. Processing/tester availability pending, not polled. Delivery receipt docs/plans/mobile-extraction-keyboard-receipt.json. User reported physical acceptance on their earlier latest TestFlight; new screenshots supersede any blanket UI acceptance. Keep public submission on hold; beta delivery remains authorized. See docs/plans/mobile-app-store-audit-20261025.md.

## October 25 - App Store release audit

Active mobile lane `fix/mobile-app-store-audit`, based on delivered build142. User explicitly authorizes comprehensive mobile workflow/UI/error testing, fixes, and public App Review submission after verification. Audit current Apple requirements and metadata; preserve manual-release setting. Use synthetic/disposable data. Track physical-only coverage separately. Shared error presentation and legal fallback accessibility are reproduced defects under repair. Backend fixes, if required by a verified service defect, remain in a separate lane.

## October 25 — Photo draft preview and compact actions delivered (PR237)

Apple acknowledged TestFlight 1.1.1 (142), runtime `8ca37ba`, delivery `cc7b440b-ea4b-4911-924c-6b68949dc67d`. Auto Extract opens the durable preview above chat; typed edits and save use the same draft. Ordinary photos wait for Send with optional caption. Prompt edit removed, confirmed ratings visually selected, resource links blue. API preview dependency/migration084 deployed separately. 938 host tests + one existing skip, 46 photo-focused and 41 control-focused tests; four iOS synthetic photo integration cases; analysis clean. All five CI gates pass (40272802298). 34 archive/export executables device-verified; 26 privacy manifests; production HTTPS/anon config, strict signature and Apple validation pass. Processing and tester availability not polled; physical camera/library acceptance unverified. No public App Store submission. Receipt docs/plans/mobile-photo-draft-composer-receipt.json.

## October 25 - Photo draft composer and truthful memory

Active lane: Mobile photo attachment staging, nonmodal extraction preview above composer, shared-draft refinement/save. Existing navigation retained. User authorized implementation; preserve explicit opt-outs. Separate backend/mobile commits and releases.

## October 25 — Mobile response controls (not uploaded)

## October 25 — Response controls delivered to TestFlight 141

Apple acknowledged 1.1.1 (141), source `895a4c4d6e81abdfb0b69053323ea9f6200ee5cc`, delivery `37e20d76-fb6e-4563-ad52-14c224f28497`. Compact response/prompt controls, exact-message ratings, timestamps, safe retry, canonical completion handling and confirmed-save feedback are included. All five CI gates passed (40255674101); 936 mobile tests passed with one existing skip, clean analysis, and five synthetic simulator feedback cases passed. A simulator-framework cache was caught during archive verification; the clean rebuild passed all 34 archive/export device binaries, signing, 26 privacy manifests, production config and Apple validation. Processing/tester availability not polled; physical acceptance unverified. No public App Store submission. Receipt: `docs/plans/response-feedback-mobile-receipt.json`.

Branch `feat/mobile-message-controls` adds compact copy/rating/retry/timestamp
controls and prompt editing, plus a verified creation confirmation. Feedback stays
unselected until the exact-message backend receipt; history loads ratings in a
single account-scoped batch. Negative reasons/comments use a small optional sheet.
The stream accepts completion once, ignores trailing errors/markers, preserves
cancellation, and presents canonical text after validation/persistence. Successful
world-chat regeneration is server read-only and references the original prompt.
Flutter analysis clean; 936 tests passed, 1 existing skip. Five synthetic feedback
interaction tests passed on iOS 26.5 / iPhone 17 Pro simulator. Full live persistence
requires migration 082 and API lane `feat/response-feedback-api` first.
No TestFlight upload or production deployment authorized for this task.

## October 25 — Chat reliability fix delivered (TestFlight 140)

Apple acknowledged 1.1.1 (140), runtime `35d34e34b35e4c5fa862c3c62e61164a31f484a2`,
delivery `af1fa51c-0fee-4b17-a2bd-e2c0177771a6`. All five exact-source CI gates
passed (40246789775), 33 focused chat tests passed, and Flutter analysis is clean.
Retries reuse the failed assistant row and original request ID, removing duplicate
error messages without changing layout or navigation. Signed archive/export each
verified 34 device executables; strict signing, privacy/configuration checks and
Apple validation passed. Processing/tester availability were not polled;
physical-device acceptance remains unverified. No public App Store submission.
Receipt: `docs/plans/chat-retry-mobile-receipt.json`.

Shared backend fix `84a8991` is live for web and mobile: bounded generation budgets
now allow internal reasoning plus final tool output. The deployed long-request
probe completed with 30 records across five locations and a review card, using
synthetic context and mocked writes. Personalization migration 081 and API PR223
were also deployed in the separate API lane; personalized push remains disabled.

## October 25 — Personalization routing delivered to TestFlight139 (PR224)

Apple acknowledged 1.1.1 (139), runtime `d7cfb0590c41a69ff528d6b4d1b06365b3a6a818`,
delivery `c0eb1702-45ea-425c-96c9-118ae45fcba3`. All five exact-source CI gates
passed (40244305919). Signed archive/export each verified 34 device executables,
strict signing, 26 privacy manifests, production configuration and Apple validation.
Processing/tester availability were not polled. Physical APNs acceptance remains
unverified. No public App Store submission. No existing UI layout/navigation changes.
API PR223/migration081 remain undeployed; personalized dispatch stays disabled.
Receipt: `docs/plans/personalization-mobile-receipt.json`.

## October 25 — Personalization notification routing (beta139 preparation)

Lane `feat/mobile-personalization` extends existing APNs lifecycle handling and
opens existing authorized item/review sheets. No screen, layout, theme, navigation
or composer redesign. Capability registration prevents older clients receiving the
new destinations. API migration 081/deployment and opt-in are prerequisites; the
notification worker remains off. No real-user notifications were sent.
Verified: 925 full-suite tests (one existing optional visual skip), 28 subsequent
focused lifecycle/destination tests, clean analysis and simulator native build.
Physical APNs/background/terminated acceptance remains unverified. Build139 signed
archive/upload status will be recorded separately after Apple acknowledgment.

## October 25 - Sample onboarding delivered to TestFlight 138 (PR222)

Apple acknowledged 1.1.1 (138), runtime `79cc169f3c488f3b6455585ee0d5de1887afd407`,
delivery `1327b03b-29b8-45f9-a817-b17d75cdde4c`. All five exact-source CI gates
passed (40239099906), including clean Flutter analysis and 921 mobile tests with
one optional visual skip. All 26 focused host and 26 iOS simulator cases passed;
manual sample, broader choices and native Reduce Motion checks passed. Archive
and export verified 34 device executables each, strict signing, 26 privacy
manifests, production configuration and Apple validation. Processing and tester
availability were not polled; physical-device acceptance remains unverified.
No public App Store submission. Receipt: `docs/onboarding-v2/testflight-138-receipt.json`.

## October 25 - Pre-launch access delivered (PR221)

Apple acknowledged TestFlight 1.1.1 (137), runtime `6c498571131d867ab778d696c3cc5f14ee66ad1e`,
delivery `aa22f3c7-cdd9-4a5f-bc04-dcec4bf7f085`. All five exact-source CI gates
passed in 40235815810. Flutter analysis clean; 912 tests passed, one optional
visual test skipped. Plans verified in light/dark on iOS simulator. Signed device
archive/export, privacy/production configuration and Apple validation passed.
Processing/tester availability not polled; physical-device acceptance unverified.
No public App Store submission. API/web pre-launch changes are live; plan quotas,
purchases and automatic cutoff remain off. Subscription WIP remains separate and
unfinished. See `docs/plans/prelaunch-mobile-receipt.json`.

## October 25 - Missing iPhone Plans entry

Root cause: the prior pricing change exposed Plans only in Flutter ProfilePage; iOS showAccountMenu opens the separate UIKit menu. Added Plans to the native menu and routed its action to PlansPage. Team capacity remains five pending a pricing decision. Native navigation regression and actual UIKit simulator checks passed in light/dark. Apple accepted TestFlight 1.1.1 (136), runtime `9031c9cec09629c706de28a6592e8de099054e02`, delivery `3f71608d-1261-40c7-afbf-8610d5956d1e`. All five CI jobs passed (40230657021); signing, 34 device executables per archive/export, privacy/config and Apple validation passed. Processing/tester availability not polled; physical-device acceptance unverified. No public App Store submission. Details: `docs/plans/native-plans-entry.md`; receipt: `docs/plans/native-plans-entry-receipt.json`.

## October 25 - Standard pricing only

User rejected promotional offers. Removed the student/robotics 50% discount from the plan comparison. Keep standard Free/Plus/Team prices and larger-team contact. No discounts are authorized. Apple accepted TestFlight 1.1.1 (135), runtime `969c03ff4ca65ab81fa7526ee002a50d6726981d`, delivery `9e39bf43-955c-49b5-bcb7-055bc4cbc81a`. All five CI jobs passed (40221148268); Flutter analysis and three focused plan tests passed. Signed archive/export each verified 34 device executables; privacy/config/signing and Apple validation passed. Processing/tester availability not polled; physical-device acceptance unverified. No public App Store submission. Receipt: `docs/plans/no-offers-mobile-receipt.json`.

## October 25 - Free, Plus and Team plan comparison (mobile)

User approved the proposed three-tier prices and asked for both apps to match,
with Stripe/Apple setup deferred. Plans are informational: $0, Plus $9.99/month
or $99/year, Team $29/month or $299/year for five people. Current access and
server quotas remain unchanged; purchases stay unavailable. See
`docs/pricing-and-limits.md` for exact allowances and future payment gates.
Apple accepted TestFlight 1.1.1 (134), runtime `ed1f89e3ce9c49660adb7ad37846fed28159b991` (PR218), delivery `03aa6e45-73df-4174-8f15-2bccb8c255a6`. All five CI jobs passed (40219539005). Clean Flutter analysis, final host tests and two iOS simulator comparison cases passed, covering light/dark and annual prices; large-text regressions passed. Signed archive/export each verified 34 device executables; signing, 26 privacy manifests, production configuration and Apple validation passed. Processing/tester availability not polled; physical-device acceptance unverified. Receipt: `docs/plans/launch-plans-mobile-receipt.json`. Artifacts: Documents/FindEZ/AppStore/1.1.1-build134. No public App Store submission.

## October 25 — Petals and chat onboarding beta133 delivered (PR214)

Apple accepted 1.1.1 (133), runtime `f80248d8813ad88a47909bd5a030d7480382e9db`, delivery `4d60ceee-7770-44db-985d-5eaa164884f7`. All five exact-runtime CI jobs passed (40216741053). Signed archive/export verified 34 device executables each; strict signing, 26 privacy manifests, production configuration and Apple validation passed. IPA SHA256 `7ad1b6c5e5eb0a079c0d70000622c01a61762530e9140c3cbae37cc049f55c4f`. Processing and tester availability were not polled. Physical-device acceptance remains unverified. Artifacts: Documents/FindEZ/AppStore/1.1.1-build133.

All 24 supplied v5 screenshots were uploaded and verified COMPLETE in numbered order across four device sets (six each), replacing v4 with backups retained. Version 1.1.1/en-US remains PREPARE_FOR_SUBMISSION. No review submission, public release or build selection was performed. Screenshot receipt: mobile/design/brand-v4/screenshots-v5-receipt.json.

## October 25 — Petals release authorized

The user subsequently requested TestFlight delivery and website deployment. This supersedes the brand prompts’ local-only restriction. Public App Store submission remains explicitly held. Preparing 1.1.1 (133), including chat-first onboarding.

## October 25 — Petals brand v4 (mobile, local only)

Branch `mobile-brand-v4` applies the supplied v4 brand kit to logos/icons and theme tokens. Validation and the complete file list are in `mobile/design/brand-v4/IMPLEMENTATION.md`. The latest prompts say not to push/deploy; no release or TestFlight upload was performed. This branch includes the completed chat-first onboarding commit `90d4881`. Backend, schema, env and deployment configuration are untouched.

## October 25 - Chat-first onboarding complete locally

Branch `feat/chat-onboarding` replaces first-run structure setup with native
Snap/Type/Describe trials before signup, local answers, the supplied 3D scene,
durable drafts and idempotent Personal/Space saves into Ask. Existing permanent
sessions bypass the trial. Apple/Google linking and email fallback reuse auth.
No web/backend/schema/env/CI/deploy changes. No push, TestFlight or submission,
as explicitly requested for this lane.

Validation: clean Flutter analysis; final 44 focused host regressions and all 17
iOS simulator integration cases passed. The broad host run passed 901 cases with
one optional skip and one obsolete headline expectation; that expectation was
corrected and its entire 14-case file passed in the final focused run. One added
photo re-extraction regression also passes. Manual reference and native visual
checks covered the scene, list/edit/answer/Keep and Reduce Motion. Camera and
provider/network peers in integration tests are synthetic; live physical camera,
production OAuth/anonymous conversion and device acceptance remain outstanding.
Full implementation, file list and limitations: docs/onboarding-chat/IMPLEMENTATION.md.

## October 24 - Mobile thorough audit delivered (beta132; PR211)

Runtime `e8372ce2c161c0a2832787409946e171e1d3503a` on `fix/mobile-thorough-audit-20261024`.
Fixed light/dark hint contrast, visible Review refresh errors, protected unsaved
and pending-save drafts, short-screen/large-text Review layout, and accessible
quantity controls. Unknown captures remain in their destination Space's Review.
No web, backend, database, extraction model or stock-promotion changes.

Clean Flutter analysis, 886 tests with one optional skip and all five exact-runtime
CI jobs passed (40165620311). Final focused checks: 27 passed. Extended and corrected
native runs cover 167 distinct passing cases; UIKit Settings/appearance and Memory
confirmation were separately inspected on iPhone 17 Pro/iOS 26.5. Synthetic data
only. Physical camera, live extraction accuracy/latency, background APNs, OAuth
and physical-device acceptance remain unverified. Audit details:
`docs/plans/mobile-thorough-audit-20261024.md`.

Apple accepted 1.1.1 (132), delivery `8b873952-8afe-4f38-a5e2-abcaa48c4154`.
Processing/tester availability were not polled. All 32 archive/export native
executables, strict signature, 24 privacy manifests, production configuration and
Apple validation passed. IPA SHA256 `979c1497825f87f2901d895dbff2338463d019fc866013a31fb685611c0789aa`.
Artifacts: Documents/FindEZ/AppStore/1.1.1-build132. No public App Store submission.

## October 24 - Space Review saving and quantities delivered (beta131; PR208)

Runtime c4bc448ad2bd0832702b037d6bd1c55f1a1067c3 on fix/mobile-capture-save-edit-later.
Save to Space accepts identified/countable items directly and saves unknown or
uncounted captures in the selected Space's Review section without requiring a
quantity. Tapping the record opens the existing editor. Quantity and counted unit
are editable above collapsed evidence; no unknown placeholder becomes stock.
The Space entry is labeled Review. Existing receipt/retry and permission behavior
remain; backend and web code are unchanged in this mobile lane.

Clean analysis, 879 host tests (one optional skip), and all five exact-runtime CI
jobs passed (40161030215). Native synthetic iPhone 17 Pro/iOS26.5 QA verified blank
quantity Save, the saved Pantry Review row, and its editable details. Physical
customer-device acceptance remains unverified.

Apple accepted 1.1.1 (131), delivery 5449a60b-dd02-43cb-9ebe-db151501a2b5.
Processing and tester availability were not polled. All 32 archive/export native
executables, strict signature, 24 privacy manifests, production config and Apple
validation passed. IPA SHA256 d5314b55494109e8178b7ca04afe557e0d931cd73473709597f17628b2a358f9.
Artifacts: Documents/FindEZ/AppStore/1.1.1-build131. No public App Store submission.

Separate backend PR209/runtime962dddc is live with additive quantity units/notes
and preserved estimated counts. All five API CI jobs and 1480 Python tests passed;
health/database and anonymous denial passed. A real photo check returned one
blister strip with contents explicitly uncounted behind foil. See
`docs/plans/capture-save-quantity-20261024.md` for evidence and limits.


## October 24 - Mobile Pip cancellation and Space menu delivered (beta130; PR207)

Runtime `af3e64c182bd09e08830b6a7bd3a05c90718faee` on
`fix/mobile-pip-stop-space-menu`. The loader has one artwork shadow, a darker
backdrop, compact progress and a readable Stop extraction action. Stop cancels
client transport immediately and suppresses late success/errors and confirmation;
server computation may continue. Space options use the Flutter popup on iOS.
Other native controls, bottom tabs, extraction endpoint and save contract remain.

All five exact-runtime CI jobs passed (40158963134), including clean Flutter
analysis and 873 tests with one optional skip. Simulator iPhone 17 Pro/iOS 26.5
verified light/dark rendering, Flutter menu, immediate Stop, suppression of late
results and a subsequent two-item confirmation using a network-free delayed fixture.
Physical-device acceptance and real model performance remain unverified.

Apple accepted 1.1.1 (130), delivery `de7de827-d343-4607-b48f-688c33566059`.
Processing/tester availability were not polled. All 32 archive/export executables,
strict signature, 24 privacy manifests, production configuration and Apple
validation passed. IPA SHA256
`fa5ad56f652e0160a85e7becc425d16277e9785c21c81fb868ea1988bb5f723b`.
Artifacts and receipts: Documents/FindEZ/AppStore/1.1.1-build130.
No public App Store submission. User-authorized cleanup removed only rebuildable
inactive simulator caches and disposable build output; projects/data/releases kept.

## October 24 - Pip extraction loader delivered (beta129; PR205)

Branch `feat/pip-extract-loader`; runtime `7fa398c1a4f83fa1c4bdecfc4c2e1e8373365ce8`.
The shared Flutter photo extraction overlay shows the supplied Pip artwork directly
on a blurred, dimmed backdrop, timed captions, seed chips and indeterminate progress.
Actual returned item count drives the 600 ms found-it moment before existing review.
Space photos and Scan capture use it. Extraction APIs, retries/errors, save behavior,
backend, web and database are unchanged. Native iOS Reduce Motion is observed in
addition to Flutter disabled animations; all loader motion stops when enabled.

All five runtime CI jobs passed (40155086930), including clean Flutter analysis and
868 tests with one optional skip. Native iPhone 17 Pro/iOS 26.5 simulator exercised
photo selection through the real Space flow with a delayed network-free two-item
fixture, normal motion/success/Confirm Items and actual system Reduce Motion. This
validates loading UI, not live model latency/accuracy. Physical-device acceptance
remains unverified.

Apple accepted 1.1.1 (129), delivery `141bf00a-26cc-419d-b983-e6bc4c70ec03`.
All 32 archive/export native executables, strict signing, 24 privacy manifests,
production configuration and Apple validation passed. IPA SHA256
`620f9e553caa0a2ed6db98e0a998de05cd33832cb8eb5e05e1ecf9a1f6aeae3a`.
Preserved IPA/archive, recordings and receipts: Documents/FindEZ/AppStore/1.1.1-build129.
Processing/tester availability were not polled. No public App Store submission.
Reference, changed files and differences: docs/extract-loader/README.md.

## October 24 - Extraction reliability delivered (API203; beta128/PR204)

API runtime `ddaf60fb857acf5eb67fd9d50b1ab4d78877b319` is live with GLM retained; all five CI jobs passed (40152537949), including 1,477 Python tests. The two-file guarded overlay preserved 116 unrelated files; API/database health and anonymous denial passed. Rollback: /home/ubuntu/findez-extraction-reliability-20261024-v2. Real candidate/live API checks passed full fields, confidence/crops, signed previews, cross-account denial and explicit review/save with two disposable accounts per run removed. Live close-up extraction took 16.9s. No customer records or schema changes.

Mobile runtime `088c8fb85e6cb2f185082fbf46e03ccb0d6ce6b1`; all five CI jobs passed (40152324269), clean analysis and 860 Flutter tests with one optional skip. Apple accepted 1.1.1 (128), delivery `4015725e-2f11-412d-aada-eb932adffc97`. All 32 archive/export native executables, strict signature, 24 privacy manifests and production configuration passed; Apple validation passed. IPA SHA256 `cb0e558daa29b2102e6e9d2a4bcb7fd6599454b6e3fb705d31798aee7699bbc8`. Preserved archive/IPA/receipts: Documents/FindEZ/AppStore/1.1.1-build128. Processing/tester availability were not polled; physical-device acceptance remains unverified.

The API recovers valid sibling results without retrying a usable batch and keeps unreadable grounded crops as Unknown Review drafts, with unknown count/confidence. Mobile preserves clearer EXIF-correct 2048px photos, prepares images off the UI thread and offers explicit same-photo retry with public errors. Bottom navigation and explicit save remain unchanged. Crowded-scene latency remains a model limitation: the workbench probe took 61.9s versus 63.6s baseline (individual runs, no general speed/accuracy claim). Larger batches were rejected after timeouts. See docs/plans/extraction-reliability-20261024.md. No public App Store submission.

## October 24 - Mobile utility page polish delivered (beta127; PR202)

Mobile runtime `5cb8b885ed228af43b7403e7d9e668987609b00a`; PR #202, stacked on build126. Notifications, plus-menu context/connections/import destinations, and Settings Memory now use compact typography, separated rows, tidy fields and clear states. Existing actions, API behavior and bottom navigation remain unchanged.

All five exact-runtime CI jobs passed in run 40150209867, including clean Flutter analysis and 856 tests with one optional skip. Six light/dark layout scenarios cover eight pages at 1x, 2x and 3.2x text; sixteen bundled-font previews were inspected. The full suite caught a large-text header overflow, corrected before the final passing CI and signed build. Apple accepted 1.1.1 (127), delivery `1a776a1f-697e-45cb-807f-710f84d2a784`. Processing/tester availability were not polled; physical-device acceptance remains unverified. Preserved IPA/archive and receipts: Documents/FindEZ/AppStore/1.1.1-build127. All 32 archive/export executables, strict signature, 24 privacy manifests, production configuration and Apple validation passed. IPA SHA-256 `2a77fac2c5a2439200219551aec09fe6f70aeeb5c35da747da8a1c051f6ef035`. See `docs/plans/mobile-utility-pages-20261024.md`. No public App Store submission.

## October 24 — clearer drafts and correct photo quantities (mobile)

Runtime `8e40596142be213f51730874186c3eb87e06fed4`; PR #199; all five exact-runtime CI checks passed in run 40146414106. Apple accepted FindEZ 1.1.1 (126), delivery 373106d3-45e4-4cf0-bb0a-f1dfb14106ac. Processing and tester availability were not polled. Physical-device acceptance is unverified. IPA SHA-256 45c9284b80a7db787f6cf63d2f0b2301e18537142e5c705c4c2b70a5bac57619. Preserved archive, IPA and receipts: Documents/FindEZ/AppStore/1.1.1-build126. All 32 archive/export native executables, strict signatures, 24 privacy manifests and production configuration passed. Apple validation passed. A cached simulator framework was rejected locally; the clean rebuilt package passed and only that package was uploaded. See `docs/plans/draft-flow-20261024.md`. Bottom navigation remains unchanged; no schema migration.

## October 24 — Chat activity and current echo icons delivered (beta125; PR197)

Apple acknowledged 1.1.1 (125), delivery `e5f4a8f8-2426-4a60-8d99-4a86a23beffb`.
Runtime 52a82725900e32c2021d71a48d9ac55d58d7d94f includes actual activity with a two-second
left-to-right soft shine, expandable steps, text scaling and Reduce Motion. Text
drafts are labeled Inventory draft. Native navigation and its motion are untouched.
The latest findez-logo-echo.zip round/ artwork and matching app-icon-*-2.svg are now
canonical; native launchers, bundled/legacy and other platform exports match.

849 Flutter tests (one optional skip), clean analysis, focused progress checks and
13 brand checks passed. All 46 raster exports match the supplied SVG pixels/sizes/
opacity, and the launcher decoded from the signed IPA matches exactly. All five
runtime CI jobs passed (40143399990). Archive/export each passed 32 device-executable
checks, strict signing, 24 privacy manifests and production HTTPS configuration.
Apple validation passed. IPA SHA256: `de441e88902c521203d63db8581d06d95c0314d194ad2e37cbc8570ed4504f9e`.

Artifacts: Documents/FindEZ/AppStore/1.1.1-build125. Processing/tester availability
was not polled; physical-device acceptance remains unverified. No public App Store
submission. Build124's earlier upload is superseded by this build with the latest
artwork and reversed shine. Web/API were deployed through their separate lanes.

## October 24 - Authoritative brand icons delivered (beta 123; PR 189)

User-selected findez-logo-svg.zip and seven standalone SVGs are canonical, with
originals/checksums in docs/brand-authoritative-20261024. The later round/echo
launcher variants are superseded. Mobile iOS/Android and bundled/legacy launcher
copies are corrected; all 46 generated exports match the source pixels, size and
opacity. The launcher extracted from the signed IPA also matches exactly.
Mobile in-app logos/theme and all 15 live web branding/browser/touch/social/legacy
assets already match this set; no web redeployment was needed. All mobile Dart,
native UI/nav, page fades and behavior source remain unchanged from build 122.

Apple acknowledged 1.1.1 (123), delivery `cc77bb73-b867-44c6-b7d7-8add63508fd8`.
Runtime 1ddc102 / PR 189 passed all five CI jobs (40075508703), 847 Flutter tests
(one optional skip) and clean analysis. Archive/export each passed 32 iOS device
executable checks, strict signing, 24 privacy manifests and production HTTPS
configuration. Apple validation passed. IPA SHA256:
`29773e4d7b367af0c3b28f7d8a111cb76542f49f59cdf6b77aa6a36a441389ed`.

Artifacts: Documents/FindEZ/AppStore/1.1.1-build123. Processing/tester availability
was not polled; physical home-screen acceptance remains unverified. No public
App Store submission, backend/schema change or web behavior change.

## October 24 — Attach menus and quick page entry delivered (beta 122; PR 188)

Apple acknowledged 1.1.1 (122), delivery `be073265-056e-4e33-b8f3-c8b9e4e453a9`.
Nav shell, native tab widget and Swift tab implementation are unchanged from
build 121. Page opacity alone completes in 150ms. The root + menu and context/tool
submenus use FindEZ UI; only Attach opens native Photo Library/Take Photo/Choose
Files. All three composer layouts now show the selected photo thumbnail before
Send, retaining regular chat versus explicit Auto Extract routing.

Final full Flutter suite: 847 passed, one optional skip. Focused checks: 67 plus
2 menu regressions; analysis clean. Two native integration checks and iOS 26.5
manual menu/photo-preview inspection passed. All five CI jobs passed on 4389b88
(run 40074291896). The binary was built from e6e748c; only a test changed afterward,
with runtime-source equivalence recorded. Archive/export each passed 32 iOS
executable checks, strict signing, 24 privacy manifests and production HTTPS
config. Apple validation passed. IPA SHA256:
`060fe732667f3cb3f8f205f6f8f128676789236f96e4159ab0ebce7c5099a9c5`.

Private artifacts: `Documents/FindEZ/AppStore/1.1.1-build122`. Processing and tester
availability were not polled. Physical iPhone acceptance remains unverified; no
public App Store submission or backend/web/schema changes. See
`docs/plans/chat-attachments-20261024.md` for manual acceptance.

## October 24 — Smart search delivered (beta121; PR187)

Apple acknowledged1.1.1(121), delivery8604efa5-2f43-40ff-96e8-e051dc2a5a11.
Runtimec4fe0b8 passed all five CI jobs (run40071676839),847 Flutter tests
(one optional skip),21 focused search checks and clean analysis. Signed archive
and export each passed32 iOS executable checks;24 privacy manifests, production
HTTPS config, strict signature and Apple validation passed. Processing/tester
availability were not polled; physical-device acceptance remains unverified.
No public App Store submission. IPA SHA256:
42ab988f74bd263bf6237ef6361101d360de6cb16e86291ad94fb10a0112f0ff.
Artifacts: `Documents/FindEZ/AppStore/1.1.1-build121`.

Companion backend39ed171 / PR186 is live. Five authenticated search variants,
cross-user denial and three real-model chat lookups passed on temporary synthetic
inventory; stock stayed unchanged and both test accounts were removed. No customer
data changed. See `docs/plans/smart-space-search-20261024.md` for acceptance.

## October 24 — Smart Space search (build121 preparation)

Lane `fix/mobile-smart-space-search-20261024` fixes the visible part-number/search
mismatch. Space, global and Team-space discovery now share deterministic keyword
matching across saved item details and imported column values, identifier-format
variants, plural/adaptor variants and conservative word typos. Numeric identifiers
are not fuzzy. Existing Space/category/low-stock scope stays intact. Full Flutter
suite:847 passed,1 optional skip;21 focused search checks passed. Backend search
has a separate API lane/PR186. No UI/native motion changes. Build121 delivery is
pending; see `docs/plans/smart-space-search-20261024.md`.

## October 24 - Quiet composer and history typography delivered as beta120

Apple acknowledged 1.1.1 (120), delivery `71ce9f9d-276c-4610-8897-690b2b3b208c`.
Runtime `e70bdc43b397cc9b9cb3f1ee669ba90c4dc3f85f`, PR185 stacked on PR184. All five CI jobs
passed (40068444703). Full Flutter suite: 826 passed, one optional skip; final
focused native/history/voice/composer tests: 19 passed; analysis clean.

Ask now has a plain compact 18pt history clock with a 44pt hit area. Composer
has a flatter, softly translucent surface and plain microphone. History uses the
app text-size preference for titles, dates, search and empty states, with OS
Dynamic Type applied once. Native iOS26.5 simulator verified dark/light composer,
Default dark and Larger light history, wrapping and history search/clear.
Physical iPhone appearance/voice acceptance remains pending.

Signed archive/export each verified 32 iOS device executables; strict signing,
24 privacy manifests and production HTTPS configuration passed. Apple validation
and upload succeeded. Private artifacts: `~/Documents/FindEZ/AppStore/1.1.1-build120`.
Processing/tester availability not polled; no public submission. Backgrounds,
native Liquid Glass tabs, web/backend/database unchanged. See
`docs/plans/mobile-quiet-composer-history-20261024.md`.

## October 24 - Rounded app icons and tab fades delivered as beta 119

Apple acknowledged 1.1.1 (119), delivery `6a2505b0-3175-4743-abe6-56bb4d30f3ed`.
Runtime `0156e671784e280d0a2a6118676d0eda748c1ade`, PR184, all five CI gates
passed (run 40066591685). Local Flutter suite: 822 passed, one optional skip;
analysis clean. Native iOS 26.5 simulator shell inspected in both themes.
Physical-device motion/feel remains pending.

Exact supplied rounded light/dark app artwork replaces launcher icons. Complete
retained pages, including headers/footer actions, fade without relayout jumps;
340ms ease-out responds immediately. Native Liquid Glass is retained with gentler
layer timing and no delayed selection callback. Reduced motion is respected.
Signed archive/export each verified 32 device executables, strict signing and 24
privacy manifests; Apple validation passed. Artifacts preserved under
`~/Documents/FindEZ/AppStore/1.1.1-build119`. Processing/tester availability not
polled; no public App Store submission. Web/backend/database unchanged.
See `docs/plans/mobile-echo-icons-motion-20261024.md`.

## October 23 - Blue echo, tab motion and Settings type delivered as beta 118

Apple acknowledged 1.1.1 (118), delivery `7ea3cc3c-c89b-4ec3-ab84-a4d1862ce1bb`.
Runtime `28187b5d719bab41ccd52288cd315fcf4a4265c3`, PR181. All five CI jobs
passed on that exact commit (run 40049512512). Full Flutter suite: 821 passed,
one optional skip; analysis clean. Native Settings Default dark/light visually
verified on iOS 26.5 simulator. Physical-device acceptance remains pending.

Native Liquid Glass remains, with retained 300ms content transitions and Reduce
Motion support. Native Settings matches app size preferences and Dynamic Type.
Primary Blue echo icons/logos and bundled Plus Jakarta Sans / Geist Mono applied.
Plain chat background preserved. Web branding delivered in separate PR182.

The initial archive's simulator objective_c framework was caught before upload.
Preserved that rejected local candidate, cleaned Flutter caches and rebuilt.
Final archive/export: all 32 Mach-O executables target iOS devices, strict signing,
24 privacy manifests and HTTPS production configuration verified. Apple validation
and upload succeeded. Processing was not polled; no public App Store submission.
Receipt: `docs/plans/mobile-blue-echo-20261023.md`.

## October 23 - Native iOS controls delivered as beta 117

Apple acknowledged 1.1.1 (117), delivery `81e1133e-f035-4b0c-bf55-af1197d5eaa3`.
Runtime `ffda41d5850550b6f32d38079beee0b2b00f77ee`, PR179 stacked on PR178.
All five CI gates passed on that exact commit (run 40036587851). Local full Flutter
suite: 816 passed / one optional skip; six final focused presentation/settings/
toolbar tests passed; analysis clean. Native iOS 26.5 simulator checks passed for
history search/selection, keyboard-open plus menu, attachment callback, dark/light
appearance, scanning toggle, Space prompt/save and alert cancellation.

UIKit now presents history/settings sheets, menus, simple alerts/choices and
standard toolbar controls. Inventory cards use quieter content surfaces. Existing
APIs/auth, upload-versus-extraction routing, restored chat background, native tabs
and hidden unfinished connectors remain. Signed archive/export verified 32 device
executables each, 24 privacy manifests; Apple validation passed. Artifacts retained
privately under AppStore/1.1.1-build117. Processing/tester availability was not polled.
Physical iPhone, VoiceOver, Reduce Motion/Transparency and older-iOS acceptance
remain pending. No public App Store submission or backend/database changes.
See `docs/plans/native-ios-controls-20261023.md` for scope and acceptance steps.

## October 23 - Native iOS tabs and restored chat background (beta 116)

PR #178 now also replaces the iOS custom bottom navigation with a real UIKit
UITabBar. Native material/selection/drag behavior comes from the system;
Flutter keeps existing page state and the non-iOS fallback. Default platform-view
gesture arbitration is intentional. The ancestor keyboard-dismiss gesture is
active only with the keyboard visible, when tabs are hidden. Restored beta 114
chat background remains.
Full host suite: 812 passed, one optional skip (including channel/shell checks).
Actual native taps, sliding selection and both themes verified in a running iOS
26.5 Simulator harness. Physical-device/accessibility acceptance remains pending.
Apple acknowledged 1.1.1 (116), delivery 2a1a948f-cfde-47a8-9f5e-4f519f5ff8a2.
Runtime `d4ccc0d`; all five CI gates passed (run 40029940276).
Signed archive/export, privacy/device-platform checks and Apple validation passed.
Processing and tester availability were not polled; no public App Store submission.
Earlier candidates were never uploaded.
See `docs/plans/native-ios-tabs-20261023.md`.

## October 23 - Restore the previous chat background

User rejected beta 115's stronger gradient. Restore the exact beta 114 background:
black in dark mode; warm off-white with the original subtle landing glow in light
mode. All other beta 115 UI/voice changes remain. Delivered in beta 116 above. Existing
23 shell tests passed (including both themes); analysis clean. No new tests needed
for this exact visual restoration.

## October 23 - Mobile UI refinement uploaded as beta 115

Apple acknowledged 1.1.1 (115), delivery ba84b6af-5da2-47a8-9dad-78666abc095b.
Runtime f98d6d4, PR #177 (stacked on mobile connector PR #175). All five CI gates
passed on that exact commit. Local full suite: 810 Flutter tests, one optional
skip; eight focused voice tests passed after the native cached-callback fix.
Analysis clean. Native iOS: 17 cases plus four corrected settings/detail cases
passed; light/dark screenshots inspected. Signed archive/export verified 32 device
executables each and 24 privacy manifests. Processing/tester availability was not
polled. Physical iPhone voice/gesture acceptance remains pending. No public store
submission or backend/database changes. Google/unfinished connectors stay hidden.
See `docs/plans/mobile-fluid-shell-20261022.md` for exact acceptance steps.

## October 22 — Connector release live; beta 114 uploaded

User approved migration 079 and activation. Migration/backend/web are live; Google
and unfinished connectors remain hidden. Apple acknowledged 1.1.1 (114), delivery
b5637833-5240-4f71-b04b-e48c0ddf238d. Processing, tester availability and physical-device acceptance
were not polled/verified. No public App Store submission.

API runtime 595f269 (PR #176), mobile bc426f2 (PR #175), web f7bac21 (PR #174).
All five CI gates passed in each lane. Full local suites: 1,409 Python tests and
10 subtests, 799 Flutter tests (one optional skip), 478 web tests. Six native iOS
cases passed, screenshots inspected. Full-data rehearsal preserved all 91 existing
tables; live synthetic CSV/XLSX/BOM/replay/isolation checks passed and both accounts
were removed. Deployment preserved 109 unrelated API and 348 web files. No paid
SDKs/new model calls; no Google configuration needed. See
`docs/plans/connectors-phase1-20261022.md` for files, limits and exact test steps.

## October 22 — Connector imports and compact cards (mobile)

Implementation prepared; migration 079 and activation approved in this session.
Google and all unfinished connectors remain hidden. CSV/XLSX and file BOM review
reuse the shared backend. Existing outbound assistant setup remains available.
Native light/dark screenshots inspected; 799 mobile tests and six native cases
passed, 478 web tests passed, TypeScript/lint and Flutter analysis clean.
Release/build114 not yet delivered. See docs/plans/connectors-phase1-20261022.md.

## October 22 — Compact attachment menu delivered in beta 113

Mobile runtime `9906ecc` (PR #173), API runtime `1beab28` (PR #172). All five CI
gates passed on both exact runtime commits. Mobile: 795 tests pass, one optional
skip, clean analysis, native dark/light simulator menu and callback checks.
Apple acknowledged 1.1.1 (113): `19c2790f-c6bb-41cf-b1b8-9cb888b1835c`.
Processing/tester availability not polled; physical-device acceptance unverified.
Artifacts: Documents/FindEZ/AppStore/1.1.1-build113. Smaller light plus/X, compact
searchable/nested menu, separate native attachment menu. Ordinary photos wait for
Send and use GLM directly; only Auto Extract invokes extraction. FIND stays the
default because experimental GLM grounding hit gateway output failures.

## October 22 - Direct chat vision and compact attachment menu

Active isolated API/mobile lanes `fix/chat-direct-vision-api-20261022` and
`fix/chat-direct-vision-mobile-20261022`. Separate direct GLM image chat from
explicit Auto Extract, keep ordinary attachments in composer until Send, shrink
plus/menu, and compare opt-in GLM grounded crops with FIND before activation.
No schema changes. Runtime base API223b95b/mobile2b2ea7c; beta target113.

## October 22 — Chat fixes live; beta 112 upload acknowledged

User explicitly approved migrations 077 and 078. Both are applied with a fresh
backup; final API runtime `223b95b` is live and healthy (PR #170). Guarded selective
publication preserved unrelated VM work. The previous create_space confirmation
shortcut was deliberately removed to honor the new creation-confirmation policy.

Actual deployed HTTPS/model/database checks with one disposable account passed:
one confirmation creates structure plus 10 batteries; repeated confirmation adds
nothing; set 8/use 3 saves 5; the same-request retry stays at 5; one confirmation
creates Garage and moves the same item; existing-Space moves execute directly;
resource navigation reads the current location. The account and its inventories
were removed. Customer inventory was not modified.

Apple validated and acknowledged **1.1.1 (112)**, mobile source `2b2ea7c` (PR #171),
delivery `2141c0fa-35c8-41ab-b935-1c6f108dccb3`. Apple rejected the initial 1.1.0
candidate because that approved version's train is closed; the final 1.1.1 upload
succeeded. Processing/tester availability was not polled. No new public App Store
submission. Physical-device acceptance remains unverified.

Validation: 1,355 Python tests plus 10 subtests; 793 Flutter tests (one optional
visual skip), clean analysis; 33 focused native iOS tests and two inspected native
light/dark visual cases. The exploratory unfiltered native suite's seven host-only
menu/semantics failures are documented in TESTING.md. Both final runtime commits
passed all five CI gates. PostgreSQL fixtures and seven synthetic real-model cases
passed. Isolated migration replay preserved all 91 tables' original data. Signed
archive/export checks verified 32 device executables each and 24 privacy manifests.

Artifacts: `Documents/FindEZ/AppStore/1.1.1-build112`, including receipts, logs,
previews and `delivery.md`. Product scope, known gaps and 25 acceptance prompts:
`docs/plans/chat-control-center-20261022.md`. Advanced visual search, inbound
connectors, arbitrary autobiographical memory, chat-native project reservations,
and photo-draft structure/save consolidation remain explicitly documented work.
This delivery does not claim the entire future product vision is implemented.

## October 21 — Build 111 launch audit

Lane `audit/app-store-launch-20261021`, stacked on build 110. Native iOS testing
found the restock count dialog overflowed at large text with the keyboard open.
Its title, form and actions now scroll together. Build 1.1.0 (111) retains build 110
onboarding, organization Chat landing, UIKit plus menus and confirmed item photos.

Validation: 788 Flutter tests passed (one default release-config skip), clean
analysis, 228 native checks across the primary audit suites and 161 extended native
checks (one host-only source test skipped on iOS). Extended tests cover documents,
onboarding, organization setup, inventories, permissions, restock, notifications,
memory, review, imported items, profile, invitations and session restoration.
The native harness now disposes mocked Supabase clients between suites; native
menu tests use the UIKit callback instead of looking for Flutter-rendered rows.
The real app also launched against the dedicated App Review account on simulator.

Cross-stack results and physical limitations are in
`docs/plans/app-store-launch-audit-20261021.md`. Approved migration 076 is live in
the separate API lane, with a fresh backup and91-table rehearsal. The user later supplied
`findez-appstore-v9.zip`:nine iPhone images are uploaded in numbered order and
checksum verified; the five existing iPad assets remain unchanged, all COMPLETE.
Build 111 passed all five CI gates, signed packaging and Apple validation, and
Apple acknowledged upload and processed the build as VALID. The authorized
version1.1.0/build111 submission is WAITING_FOR_REVIEW as of
2026-10-22T05:56:50Z, submission3eef3590-11b3-4d75-85cd-fce87b1bf45d.
Release is AFTER_APPROVAL. Reviewer login, screenshot checksums and public/service
URLs passed; physical camera/microphone/APNs/VoiceOver limits remain documented. Do not use the debug review harness or QA credentials in release builds.

## October 21 — Build 110 onboarding, native menus and chat photos

Full onboarding is restored for incomplete/fresh installs. Created organization IDs
persist through setup, and fresh sign-ins select an owned organization with current
access checks; existing explicit Personal selection is respected. Chat photos can
link to existing items after choosing an exact saved candidate, including typo and
similar-name suggestions. Quantities and existing primary photos are preserved.

The iPhone plus button now has no circle and uses actual UIKit UIMenu for the root,
Attach and Add context menus. Apple controls compact spacing and materials; camera
and gallery still use native UIImagePickerController/PHPicker. Other platforms use
a smaller content-sized fallback menu. Build 1.1.0 (110).

Validation: 788 Flutter tests passed (one existing skip), 44 targeted onboarding/
auth/organization tests, seven native photo-card flows, and direct native menu
interaction verified root/submenu ordering and the selection callback. Light/dark
photo cards and large text inspected. Clean static analysis passed.
Physical camera/gallery, VoiceOver and final TestFlight acceptance remain unverified.

Release: runtime7ef16fc / PR167, all five CI gates passed on run39721774176.
The newer CI Flutter identified hidden ListTile ink feedback; a transparent Material
ancestor fixed it, and seven targeted photo tests plus clean analysis passed.
Apple validated and acknowledged1.1.0(110), delivery
9a4db965-4167-4df5-a26f-f23cd2b1693b. Processing/tester availability not polled.
Verified32 device binaries in archive/export, strict signatures,24 privacy manifests
and production configuration. Final IPA SHA256:
90e896dd9319260f17c3908844c39f4d9f2e46c8abca4c9801d88a712ccc2be8.
Artifacts and native previews: Documents/FindEZ/AppStore/1.1.0-build110.
API49374c1 / PR166 is live with guarded three-file activation,104 unrelated Python
files preserved,health/database200,private endpoints401,and synthetic typo/model
verification. No migration or customer QA writes. Earlier unuploaded mobile package
retained separately under superseded-pre-ci. Physical acceptance remains unverified.


## October 21 - Build 109 delivered: chat sources and connections

Runtime 1724a94 / PR165 adds the anchored plus menu, native iPhone camera and
PHPicker photo library, PDF/TXT/Markdown attachments, saved context chips and
existing Claude Desktop MCP/ChatGPT Actions setup links. Build 108 Space navigation
and menus are retained. 779 mobile tests passed across the full run and corrected
menu checks, one existing skip, clean analysis and seven native simulator flows.
All five CI gates and web preview passed. Physical camera/gallery acceptance is
unverified. Apple validated and acknowledged 1.1.0 (109), delivery
37d70e05-ca15-4050-8b96-8a491992ab0b. Processing/tester availability were not polled.
A clean device build verified 32 binaries in archive/export, strict signatures,
24 privacy manifests and production configuration. Signed artifacts and previews:
Documents/FindEZ/AppStore/1.1.0-build109. API5507499 / PR164 is live; no migration.

## October 21 - Spaces-only inventory entry and Space menus

Lane: fix/mobile-space-navigation-menus-20261021, build1.1.0(108).
Workspace inventory rows and accepted inventory invitations open the scoped Spaces
directory. The normal workspace flow preserves Back to the inventory list and
Ask/Spaces/More. Both Spaces directories share an anchored Open/Rename/Delete
menu with current inventory authorization. Existing removal previews offer moving
contents or deleting them after exact-name confirmation. No backend/schema changes
or customer QA writes.

Validation:772 Flutter tests, clean analysis, enabled production configuration and
14 native Spaces cases passed. Light/dark menus and directories plus large type
were visually reviewed; both final directory previews were refreshed and verified.
All five CI gates and the web preview passed for runtime d2a3606 / PR163. Apple
validated and acknowledged1.1.0(108), delivery aa13a46b-d98b-4883-b7f8-705e511a6d3d.
Verified32 device executables in both archive/export, strict signatures,24 privacy
manifests and production configuration. Signed artifacts, checks and five previews
are preserved privately in Documents/FindEZ/AppStore/1.1.0-build108. Apple processing
and tester availability were not polled. Physical-device acceptance remains pending.

## October 21 — Build107 delivered

Apple validated and acknowledged1.1.0(107), runtime9cc6de6 / PR162, delivery
62acc207-dba0-42c5-a39b-5542c31e20ee. All five CI gates and both runtime web previews
passed. The signed archive/export contain32 verified device executables each;
strict signatures,24 privacy manifests and production configuration passed.
Artifacts/previews/receipts remain private in Documents/FindEZ/AppStore/1.1.0-build107.

758 Flutter tests,1,276 Python tests plus10subtests, clean analysis, enabled
production-config check and11 native extraction cases passed. Both themes were
visually checked with1000-item compact cards. Apple processing/tester availability
were not polled; physical-device acceptance remains pending.

API1d638dc / PR161 activated at2026-10-22T02:16:34Z with3 guarded file replacements,
102 unrelated Python files preserved, healthy service/database and private access
boundaries. New save-status replies use current confirmed receipts. No migration,
customer QA writes, re-import or re-save is required for existing saved extractions.

## October 21 — Compact saved extraction cards

Lane: fix/mobile-compact-extraction-receipts-20261021, build1.1.0(107).
A saved capture now displays its saved/Review counts, one destination Space link,
and an optional details sheet. It no longer expands every receipt item into an Open
button in chat. The sheet builds selected item rows lazily. Unsaved Space pills,
direct select/save, duplicate confirmation and Review behavior are preserved.

Validation:758 Flutter tests, clean analysis, enabled production-config check and
11 native capture cases passed. Both light/dark1000-item receipt screenshots were
inspected; card height stays bounded and the destination opens the exact Space.
No customer QA writes. Signed production archive and Apple acknowledgment pending.

## October 21 — Build106 delivery receipt

Apple validated and acknowledged 1.1.0(106), runtime e02b7b1 / PR160, delivery
c60752ee-c06f-4204-b321-54ffcec9bb21. All five code CI gates passed. The separate
Vercel preview failed; its logs require an unconnected Vercel login. No web runtime
files changed in this lane.

756 Flutter tests, clean analysis, enabled production-config verification,9 native
capture cases and2 native New Chat cases passed. Verified32 device executables in
each archive/export, strict archive signatures,24 privacy manifests and production
configuration. Preserved signed IPA/archive and previews privately under
Documents/FindEZ/AppStore/1.1.0-build106. The first upload attempt could not access
Apple's Defaults.properties; retry outside the sandbox succeeded with the same
validated IPA. Processing and tester availability were not polled. Physical-device
acceptance remains pending.

API144a120 / PR159 is live since2026-10-22T01:40:24Z: three guarded file replacements,
102 unrelated Python files preserved, health/database200 and anonymous private401.
No migration or customer QA writes. Refresh and retry the same failed draft; the
Review record is reused. Destination pills stay with unsaved drafts and tap directly
to select/save in106. New Chat clears prior context and cancels the prior response.

## October 21 — Persistent destination pills and fresh-chat isolation

Lane: fix/mobile-chat-reset-destinations-20261021, build 1.1.0(106).
Writable Space pills belong to each unsaved extraction card and remain available
after follow-ups. A tap selects and saves directly; uncertain records still go to
Review and duplicate creation still needs explicit confirmation. A saving draft can
resume through its existing destination pill.

New Chat and return-to-home clear conversation IDs, draft keys, queued prompts and
reply presentation. Stream cancellation propagates to the response transport rather
than waiting for another event. Late history/import/photo results cannot restore a
reset conversation, and old request cleanup cannot cancel new progress timers.

Validation: 756 Flutter tests, clean analysis, enabled production-config check,
9 native capture tests with light/dark previews and 2 native New Chat regressions.
No customer QA writes. API save receipt repair is separate PR159. Signed device
archive and Apple acknowledgment pending; physical acceptance remains unverified.

## October 21 — Build105 delivered

Apple validated and acknowledged1.1.0(105), runtime9fd9c10 / PR158, delivery
fac9b202-02d0-46f0-91cb-ad371e797d53. All five CI gates passed for both runtime
PR157 and PR158. API1f31f97 activated at2026-10-22T00:44:17Z with nine guarded
file replacements, no migration and96 unrelated Python files preserved.

753 Flutter tests, clean analysis, production-config check,20 native simulator
cases, and1,273 Python tests plus10subtests passed. The first device export was
rejected locally for a cached simulator framework. A clean rebuild verified all
32 archive/export binaries as iOS device code, strict signatures,24 privacy
manifests and production configuration before upload. The correct archive and IPA
are preserved privately under Documents/FindEZ/AppStore/1.1.0-build105.
Processing/tester availability were not polled. Physical haptics, camera/barcode
capture and APNs receipt remain pending. No customer QA writes or test pushes.

## October 21 — Chat polish and unified capture delivery

Lane: fix/mobile-chat-workspace-flows-20261021, build1.1.0(105).
Chat scrolls across the full viewport beneath measured, fading glass overlays.
The composer has suggestion chips; send/backend-ack/first-visible-reply haptics
are discrete. Suggested Space chips select and save immediately (user-selected
behavior); inline links still navigate and duplicate confirmation remains.
Spreadsheet and barcode actions now create chat drafts before destination choice,
with resumable large import saves. The plus menus open immediately, Appearance
starts collapsed, and the chat header has a notification bell. Board notifications
open the team board, while historical accepted/expired invitations are read-only.

Validation: 753 Flutter tests passed plus enabled production configuration check;
20 native iOS simulator cases passed with preserved light/dark previews. Static
analysis is clean. No customer QA writes or test pushes. Physical haptic feel,
camera/barcode capture and APNs receipt need real-device acceptance. Signed105
archive/upload is pending; public App Store submission is not authorized here.
API dependency is PR157, with no migration and separate guarded activation.

## October21 — Auto Extract chat restoration active

Lane ownership: this task owns chat capture, its mobile cards and tests in
feat/mobile-chat-auto-extract-20261021 and feat/api-chat-auto-extract-20261021.
Reuse FIND, capture-save, Review and existing structure actions. Migration075 is
explicitly approved and activated with APIe47deb0 at2026-10-21T23:24:51Z.
Apple acknowledged mobile104 (90f1ae5e-6571-4476-8647-3bfe62f40fc6).
Physical-device acceptance remains pending; processing was not polled. See docs/plans/chat-auto-extract-20261021.md.

## October21 — Build103 uploaded; approved074 and API live

The user explicitly approved production074. The guarded activation applied it
transactionally after a fresh backup and published APIba8a2ce. Three runtime files
changed;101 unrelated Python files and existing database functions were preserved.
Health/database return200; anonymous World/private-photo access returns401. No
customer QA writes. Activation:2026-10-21T07:23:34Z.

Apple validated and acknowledged1.1.0(103), delivery`b5928b86-5154-4874-b1b7-db123c0e2220`.
Mobile source14285ce, notification parent6aae4a6; PR151/152/153 all pass five CI
gates.741 Flutter tests, enabled production-config check,20 native iOS cases,
1236 backend tests plus10subtests, and isolatedSQL/data-preservation rehearsal pass.
32+32 device executables,24 privacy manifests and signatures verified;13 previews
and signed artifacts preserved in Documents/FindEZ/AppStore/1.1.0-build103.
Processing/tester availability was not polled. Physical-device acceptance remains
pending. No public App Store submission. See docs/plans/chat-polish-item-management-20261021.md.

## October 21 — Chat polish and reviewed item management prepared

Mobile `fix/mobile-chat-polish-20261020` builds on launch notifications for103.
API `fix/api-chat-links-latency-20261020` adds verified links, parallel photo reads,
and reviewed edit/move/price/expiry/reorder actions. User chose reorder requests
for approval, never purchases. Migration074 is additive and rehearsed against an
isolated fresh restore; **production application is not yet authorized**. Apply
074 only after explicit approval, before deploying dependent runtime. No customer
QA writes. See docs/plans/chat-polish-item-management-20261021.md.

## October 20 — Automatic launch notification permission in progress

Mobile-only branch `fix/mobile-launch-notification-permission-20261020` adds the
native iOS permission request after the first active app frame, including before
sign-in. Existing OS choices are respected; push token registration remains
account-bound. Build103 is planned under standing TestFlight authorization.
727 Flutter tests, clean analysis and the actual native Apple alert/Allow/no-repeat
check pass. Delivery is pending the user's subsequent chat presentation/latency
feedback. This lane has no backend/schema/customer-data changes.

## October 20 — Mobile glass polish 1.1.0 (102) delivered

Runtime 08b7f8c on `feat/mobile-glass-polish-20261020`, PR150, refines World
controls, navigation, chat, Spaces, More, and organization/account presentation.
History supports local scoped title search. 714 Flutter tests pass (one skipped),
analysis is clean, 18 native iOS cases pass, and eight previews were reviewed.
All five CI jobs pass on run39548738411; Vercel preview also passes. Signed
archive/export,32+32 iOS executables,24 privacy manifests, configuration and
Apple validation pass. Apple acknowledged build102, delivery `63b221a4-481b-4c23-b19f-8c035385aac0`.
TestFlight processing/availability were not polled; physical-device acceptance
remains pending. No public submission or backend/web/schema/customer-data changes.
Photo-to-inventory provider behavior remains outside this UI task. Details:
`docs/plans/mobile-glass-polish-20261020.md`.

## October 20 — Ask typography 1.1.0 (101) delivered

Mobile-only typography correction is committed on 0e7bf9a / PR149. Smaller native
iOS display heading, regular composer text and lighter labels match the reference
proportions; its exact font identity is not verified. 35 targeted tests, 16 native
simulator cases, clean analysis and all five CI test jobs pass (39545769323;
712 Flutter tests passed, one compiled-config test skipped). Archive/export,
privacy/config and Apple validation pass. Apple acknowledged 1.1.0 (101), delivery
1f58c797-1cae-4824-8efb-c9ce90c5ca59. Processing and physical-device acceptance
remain pending; no public submission. The separate Vercel web preview failed on
unchanged Next.js Google font resolution. No web/API/schema/data changes.
See `docs/plans/ask-typography-20261020.md`.

## October 20 — Ask-first 1.1.0 (100) delivered

Ask/Spaces/More, subtle peach glass controls, organization-wide private Chat and
reviewed inventory/Space creation are delivered on runtime58411f5 / PR148. All
five CI gates pass (39543694110);710 Flutter tests, separately enabled production
config, clean analysis,14 new native cases and161 existing native cases pass.
Approved073 and supporting API are live; customer data was preserved. Apple
validated and acknowledged signed1.1.0(100), deliverycb293add-bf18-49c1-89e1-24692f195964.
TestFlight processing/availability and physical-device acceptance remain pending.
No public submission of100. See `docs/plans/ask-world-mobile-20261020.md`.

## October 20 — simulator audit and beta99 delivered

User requested tests/fixes before App Store submission and allowed Simulator or
Mirroring. The simulator audit found and fixed narrow large-text/keyboard issues
in deletion dialogs, Capture status panels, focused Chat and avatar initials.
Dashboard, permissions and production data remain unchanged. Synthetic identities
only; the excluded founder account was not used.

Final696 Flutter tests, clean analysis, separately enabled production config,
159 native flow tests plus12 focused follow-ups,1,145 backend tests,495 deployed
web tests with matching fixtures, SQL/concurrency and MCP/bundle checks pass.
All five CI gates pass on runtimee219ac5, run39391119476, PR145. Apple acknowledged
signed1.0.9(99), deliverycc288dfb-0fc0-4ea3-8160-03962e8dfc5f. Archive/IPA/evidence
are preserved. TestFlight availability and physical-device acceptance are pending;
public App Store submission was not performed. See
`docs/plans/simulator-release-audit-20261020.md` for coverage and limits.

## October 19 - organization Admin access and beta98

User approved migration072 and a new TestFlight build. The shared directory SQL
now honors effective Organization Owner/Admin access without requiring a separate
workspace membership row. The fix is live for both mobile and web, including
existing installations. The private activation receipt records two corrected
checks, fresh backup, healthy API/database and denied anonymous photo access;
no customer data was changed. Backend PR143 contains the tested correction.

This release increments only mobile version metadata to1.0.9(98), source0dfb9e8.
Native runtime/UI remain build97. Twenty-one workspace/configuration tests pass;
693 previous mobile regressions remain applicable. Signed archive/export, all
31+31 iOS executables,24 privacy manifests and production HTTPS/anon config pass.
Apple acknowledged signed production1.0.9(98), delivery `7d00d31e-465a-4ca2-844b-536721d9a2f3`.
All five CI gates pass (run39382888411), including693 Flutter tests and clean
analysis; the skipped compiled-config gate was separately enabled and passed.
The signed IPA/archive are preserved; SHA256 `3ba1466a8f7d442139227215ec8904c85ca38210faadfb330e4d9cad336af55b`.
TestFlight processing and availability were not polled; physical-device acceptance
remains pending. No public App Store submission was performed.
Artifacts: Documents/FindEZ/AppStore/1.0.9-build98. No public App Store submission
and no testing with the excluded founder account.

## Organization leave and removal choices — delivered (October 19)

Scoped web/API/mobile branches `feat/organization-leave-*-20261020` are prepared.
Admins cannot remove the organization Owner. Keep/move versus cascade deletion
replaces empty-first prerequisites; web item rows expand without repeated titles.
Use only synthetic test identities; the founder account is excluded from QA.
All CI lanes pass. User-approved migrations 069/070 and matching API/web are live.
Apple acknowledged signed build 97, delivery f7f277d6-3bda-4182-a4cd-1d27c3dc21d4.
Stop at acknowledgment: processing, tester availability and device acceptance
remain unverified. See `docs/plans/organization-removal-choices-20261019.md`.

## Organization access and inline item update — live (2026-10-19)

User approved “yes publish and apply 068.” Migration 068 and the reviewed web/API
release are live after a fresh private database backup. Admins access all resources
within their organization; only Owners delete the organization. Viewers remain
read-only. Inline item editing, original import fields and task/invite attribution
are published. Deployment source hashes, attribution columns, permission precedence,
API/database/site health and unauthorized photo/Chat checks pass.

Mobile 1.0.9 (96), implementation efd7209, is signed, Apple-validated and
upload acknowledged (ea38eaff-6bfa-4a30-8af2-6c65e2e43c4a). Processing/tester
availability is unverified. Includes full-photo zoom/pan and session restoration. All three CI lanes
pass; 670 mobile tests pass. Device acceptance remains pending.
See docs/plans/organization-items-update-20261019.md for evidence and receipts.

## Organization access and inline item update — candidate (2026-10-19)

Active lane: findez-items-mobile-20261020. User explicitly superseded the old organization-admin
restriction: Owners/Admins access all organization workspaces/inventories/Spaces,
including custom No access. Only Owner deletes the organization. Other Viewers
remain read-only; Editors can rename accessible workspaces/inventories and edit
items. Personal and unrelated organizations remain isolated.

Item rows open full details, editable fields save inline, original spreadsheet
columns are displayed, purchasing destinations exclude vendor part numbers,
and invitations/tasks show sender/assigner identities with photos.

Migration 068 is a candidate only; production database approval is outstanding.
Mobile 1.0.9 (96) is signed; all three final CI lanes pass. Apple upload and device
acceptance are not complete. Isolated live-copy migration rehearsal preserves all
original values across 90 tables. Session restoration and full-photo zoom are included.
See docs/plans/organization-items-update-20261019.md for validation and release gates.

## Final submission audit — build 95 delivered; notification arrival confirmed

Signed 1.0.8 (95), source ca5c195, is installed and acknowledged by Apple (375271f5-080e-429c-9054-8b42518280df). All five CI gates 39188238121 pass. Native notification-center delegate registration fixed; user confirmed visible arrival. Camera/barcode/Ask microphone happy paths were user-confirmed on 94. Plans remain hidden. See docs/plans/final-mobile-delivery-20261018.md for completed checks and remaining provider, recovery, share-extension, offline, VoiceOver and cold-tap acceptance. GPU HTTP/origin restriction remain launch blockers; legacy server nonce bypass needs coordinated provider testing. Processing/tester availability not polled; public submission held. This supersedes historical candidate/pending entries below.

## Chat actions and profile photos — delivered (2026-10-18)

The user approved "Apply 057 and publish build 91." Migration 057 is applied after
a fresh private database backup. API `65c90d4` and web `bee5088` are live. Public health
and database checks return 200; invalid-session Chat and anonymous private-photo
requests return 401. The deployment preserves 87 unrelated Python and 227 unrelated
web runtime source files. No customer QA writes or existing record rewrites.
Private activation receipts: /home/ubuntu/findez-chat-actions-release-20261018.

Chat can prepare item additions/deletions for explicit review and confirmation.
Service-only atomic receipts enforce current role/scope, stale-record protection,
limits, rollback and idempotent retries. Model-written replies use paced fades;
active mobile Chat hides the main header/navigation while keeping Back available.
Older clients receive ordinary model-written guidance until upgraded. The gateway
still batches a text event; upstream token-by-token delivery is not claimed.

The saved Settings photo appears in People, task assignees/creators, file
attribution and activity. Replacements/removal refresh correctly. Circular preview
supports drag, pinch zoom, zoom controls and Reset before explicit Use photo;
preview/export share the same crop and output 512px PNG. Cancel never uploads.
Dashboard content/layout, current inventory permissions and private photos remain.

Validation: 1,032 Python tests plus 10 subtests; 365 branch web tests/48 suites,
types and scoped lint; 651 Flutter tests with coverage and clean analysis.
The one compiled-production-config gate is separately enabled and passes.
Both-theme crop pixels/gestures, Settings, People/task refresh and Chat action
checks pass. SQL replay, real concurrent confirmation/revocation,87-table isolated
restore preservation and synthetic configured-model add/delete probes pass.
All five CI gates pass for API 39170702187, web 39170702070, mobile 39170880574.
The actual preserved web runtime builds/types and route smoke pass; its full
suite retains18 unrelated failures in five older signup/API-key/landing/legal/
account-deletion fixture suites. Do not change unrelated runtime to hide these.

Apple acknowledged signed production 1.0.8 (91), source `79b9abe`, delivery
c6cab1f6-1254-4395-87f7-9e449ad60d18. IPA SHA256:
aa4d26c06fb2a89cbe8ec3bbecee844c063de43a1bb2695e022ddbe0e2242647.
Strict signature, all 31 archive +31 export device executables, production defines
and main.dart target, archive preservation and Apple validation pass. Artifacts
and acknowledgment: Documents/FindEZ/AppStore/1.0.8-build91. Original 90 binaries/
Apple receipts remain intact;91 includes 90's 96b00d3 terms/config source fixes.
Stop at upload acknowledgment: processing/tester availability were not polled;
physical-device acceptance remains pending. Public App Store submission is held.
PRs120/119/121 contain Chat; stacked PRs123/122/124 contain photo consistency/crop.
This receipt supersedes earlier candidate/pending delivery notes below.

# October 18 photo save/return — beta87 uploaded

Apple acknowledged signed production1.0.8(87), source445d3c7, delivery
e421ff27-a8c5-48bb-aef2-9ea6aeaaf8dc. Full627 Flutter tests, clean analysis,
Light/Dark Viewer gallery/return checks and all five CI gates39156943197 pass.
All31 archive and31 export executables are iOS device code; strict signatures,
production defines/main target and Apple validation pass. IPA/archive preserved
in Documents/FindEZ/AppStore/1.0.8-build87. Stop at this upload acknowledgment:
processing/tester availability were not polled, physical acceptance remains
pending, public App Store stays held. Approved migration056 and matching API/web
are live. Captures return to the saved Space's items, keeping failed drafts open;
the gallery shows crop first/original second. Dashboard content/layout is unchanged.

# October 18 model-written Chat - delivered

The user requested removing scripted/fallback Chat answers and then reported a
photo-attachment request receiving an irrelevant identification report. Backend
0d2f38f removes the deterministic answer paths; final runtime 71c0ca4 keeps photo
answers focused on the actual requested action with truthful capability facts.
Both are live. Every successful text/photo/file Chat reply uses the configured
model. Model errors/empty replies are errors, never substitute assistant answers.
Permission checks, data-only tools, bounded evidence and conditional edit receipts
remain authoritative. No schema, provider configuration, FIND or client UI change.

The old interpreter/answer script is deleted. The model chooses semantic tools on
every turn, including planning and follow-ups. Photo-name matches cannot prove a
Space is empty. Attaching one photo to all existing entries from Chat is currently
unsupported; the model explains the per-item Add photo/Add another gallery flow
instead of listing objects, falsely claiming changes or directing this to Capture.
Customer Dashboard, stored conversations, permissions and private photos remain.

990 Python tests plus 10 subtests pass. All 127 former question fixtures exercise
model invocation in sync/events. Eight actual configured-model cases use synthetic
facts and no customer writes, including Roadrunner requirements/stock, empty
inventory clarification, preferences, uncertain photo and the exact Garage photo
request. All five runtime CI gates pass on 71c0ca4 (39152846348); the initial
0d2f38f run 39152004764 and native increment run 39152005559 also passed.

Production health/db and invalid-session Chat/private-photo denial pass. Initial
overlay preserves 86 unrelated Python files; the two-file follow-up preserves
92. The first non-privileged restart failed, restored the reviewed files and left
the existing service healthy; the corrected privileged restart succeeded.
Private backups/manifests/evaluations/receipts:
/home/ubuntu/findez-model-chat-release-20261018 and its -photo-intent sibling.
No customer inventory, membership, invitation or configuration writes for QA.

Apple acknowledged 1.0.8 (86), native source 326d578, delivery
a0d40e13-003f-4885-a83b-6c7539f9681c. Native runtime is unchanged from beta85;
the completed 623 Flutter tests and clean analysis are reused. All 31 archive/
export executables verify as iOS device code, strict signatures, production
configuration/main target and Apple validation pass. No Apple processing/group
polling followed acknowledgment. Availability and physical acceptance remain
unverified; public App Store submission remains held. Chat behavior is shared
backend delivery and does not depend on a new mobile install. PRs 105 and 106.

# October 18 permissions, private photos and Account — delivered

This entry supersedes the prepared/active rollout notes below. The user approved
"Apply 054/055 and publish the fixes." Migrations 054/055 were applied atomically
after a fresh private backup; backend, web and gateway rules are live. Inherited
Editor stays Editor, deliberate custom/No access remains authoritative, and
administrative access does not silently expose restricted contents. Source is
API b0c04e3 (Python runtime 1c2280c), web eccccc1, mobile 9cec0bc. PRs 102/103/104.
No Founder Dashboard is included; customer Dashboard content/layout is preserved.

Authorized teammates retain photo access through authenticated app requests;
copied URLs grant none. A follow-up accepts existing trusted-origin //storage
locators and rebuilds the two SQL expression indexes. All 16 existing photos are
recognized, 28 authorized member/photo pairs have 0 lookup failures, and an actual
authorized backend Storage download validates as an image. Old public links all
return 404; anonymous application photo requests return 401. No photos, locators
or customer membership/invitation data were rewritten for QA.

The initial gateway template rewrite missed real entrypoint substitution and
briefly prevented startup. The original was restored; the corrected fragment-only
insertion preserves original template bytes and passes all 7 actual-entrypoint
isolated HTTP privacy cases. Gateway/auth/health/database checks pass. Deployments
preserve 79 unrelated Python and 242 unrelated web source files. Private backups,
manifests and live receipts: /home/ubuntu/findez-permission-release-20261018.
Final web: /home/ubuntu/findez-web-releases/permissions-url-compat-20261018/frontend.

Mobile main-page account controls now open the existing compact Profile hub in an
opaque Account Scaffold with safe AppBar/back navigation. Profile editing and
Settings are separate destinations. This fixes the transparent previous-page
overlay and status-bar clipping without changing Dashboard content. Light/Dark
widget checks cover opacity, top insets, navigation and actual private Image
requests; test-font captures are synthetic, not native/device acceptance.

Completed validation: Python 901 + 10 subtests, web 344/46 suites plus types/build
(lint 0 errors, 54 existing warnings), Flutter 623 with coverage and clean analysis,
latest 25 focused profile/Review/photo cases, SQL replay/matrix, two real concurrent
revocations, and the isolated production restore preserving values across 86
tables. Runtime CI is green: API 39115338261, web 39115340558, mobile 39115340763.
No completed regression checks were repeated after push/build.

Apple acknowledged signed production TestFlight 1.0.8 (85), delivery
6a197534-7e09-453d-a1fa-efe1bf9adeec. All 31 archive/export executables are iOS device code;
strict signatures, production configuration/main target and Apple validation pass.
Private IPA and archive: Documents/FindEZ/AppStore/1.0.8-build85. Beta85 supersedes
acknowledged beta84, which missed legacy photo locators and the Account fix.
Older mobile builds need beta85 for private photo/crop loading. Processing and
tester availability were not polled; physical-device acceptance remains pending.
Public App Store submission remains held. Documentation receipts need no binary.

# October 17 unified permission policy and profile access

Active mobile lane fix/mobile-workspace-editor-profile-20261017 from e9c3e27.
Implement the supplied Roles and Permissions Specification across inheritance,
custom restrictions, admin-only Space deletion, ownership transfer and role
refresh. Then keep the account/profile control at the top right of main pages.
Preserve dashboard content, auth and capture/chat behavior outside permissions.
Backend/schema and web use separate lanes. No customer membership probes.

# October 17 invitation handoff refresh

Completed mobile lane `fix/invitation-org-handoff-20261017`, clean start d53a320.
Repair accepted organization/inventory destinations, root-shell retirement and
manual invitation entry for organization-scoped navigation. Preserve explicit
recipient consent and all API/schema grants. Verify both themes, link/code, auth
continuity, expired/revoked/wrong-account paths. Web/backend are live in separate lanes; all five runtime CI gates pass in each.
Apple acknowledged build 83; availability and physical acceptance remain unverified.
See docs/plans/mobile-invitation-handoff.md.

# October 17 organization-scoped mobile navigation

Completed mobile lane fix/mobile-organization-scope-20261017, clean start 24bbcac.
Replace the global workspace selector with a top-left organization pill and
organization-contained workspace/inventory navigation. People, Tasks and Files
remain visible in the workspace directory. Preserve dashboard content, Scan,
Ask, Spaces, auth and existing API/schema/data. Personal contains existing
independent workspaces; no customer records are moved. All 588 Flutter coverage tests pass. Native iPhone 16e review covers
organization isolation and both light/dark appearances. Apple acknowledged TestFlight 1.0.8 (82), runtime 8e7ee6b, delivery
10545da8-eadf-447d-be11-de5957dfbc98. All 31 archive/export executables verify as
iOS device code, and strict archive signatures pass. All five automatic CI jobs
pass on runtime source (run 39079363353). Processing/tester availability remains
unverified; no Apple polling or post-push regression reruns. Physical acceptance
remains open. PR 98: https://github.com/tanyasmritivc/main-inventory-app/pull/98. This supersedes the previous global workspace picker design.

# October 17 Space Add Item starts with capture

Active mobile lane fix/space-add-capture-20261017, clean start be4ab48.
Space empty-state Add Item opens the same action chooser as its plus control:
Scan Photo, Scan Barcode and Import Spreadsheet only. Reuse the existing scoped
flows and selected Space; remove the unused direct manual-create path from this
page. Preserve editing, capture confirmation, dashboard and other entry points.
No backend/web/schema changes. All 557 coverage tests and analysis pass. Native
iPhone 16e chooser/photo/import review is complete. Apple acknowledged 1.0.8 (81),
runtime 257bb3e, delivery 0ada0dcc-7654-425e-870a-15607fdeb248. All 31 native
archive/export binaries verify as iOS device code. Processing/tester availability
remain unverified; no polling. PR 97 tracks automatic checks. The prior deletion
follow-up was canceled after the user confirmed it worked; no memory/chat
follow-up implementation was made. Beta80 and both review heads passed all CI.

# October 17 simpler mobile context directories and deletion audit

Active mobile lane fix/mobile-context-directory-20261017, clean start 75db5c5.
Replace mixed organization/workspace switcher with focused workspace selection
and separate organization management. Compact inventory directory and hide
collaboration utilities behind management. Dashboard, Scan, Ask and Spaces remain
untouched. Trace reported deletion errors, retain confirmations/explicit purge,
keep failed confirmations usable and remove stale resources after success.
Audit real constraints only in a network-isolated restored copy; never delete
customer records for QA. Backend/schema work, if needed, uses a separate lane.
Migration 053 remains pending separately. Implementation complete: 549 Flutter
tests pass, final analysis clean, 29 backend deletion tests pass. A network-none
restored production copy passes 21 deletion cases including expected guard
blocks. No customer records changed; no backend/schema change required. Native
iPhone 16e fixture review complete; physical acceptance remains pending. Deliver
checked beta80. Apple acknowledged 1.0.8 (80), runtime fed141e, delivery
30ec26e0-4246-4085-b0cc-42b22bceeb1b. Processing/tester availability remain
unverified; no polling. See design/mobile-context-directory/IMPLEMENTATION.md.
CI follow-up: separate test-only parent ae81586 (PR 96) uses installed AnyIO for
crop tests, full 817 Python plus 10 subtests pass. Newer Flutter CI also flags a
settings Memory-row ink layer; transparent Material fixes it, with 32 profile
tests/analysis passing. No dashboard change. First beta80 export was rejected
for a cached simulator framework; the clean rebuild verifies 31 device binaries
in both archive/export with strict signatures and is acknowledged by Apple.
All five CI jobs pass on runtime fed141e and compatibility parent bac43eb.
Mobile PR 95 is stacked on compatibility PR 96; no production schema changes.

# October 17 responsive onboarding follow-up

Same mobile lane feat/build-your-world-onboarding-20261017, clean start eab8962.
User device screenshots show platform/input/chip overlap. Production wraps the
onboarding in AppGradientBackground/SafeArea, reducing height; QA previously
mounted the page without that wrapper. Fit the canvas model and live tags between
actual heading/control bounds, include native safe areas, and verify a phone-size,
keyboard and text-size matrix through the production wrapper. Preserve data/auth,
motion durations, inventory interiors and the light default. Deliver beta79 under
the standing push/TestFlight instruction; no production schema changes.
Implementation complete: 545 Flutter tests pass and analysis is clean. Ten size
profiles and actual production safe areas/keyboard are covered; iPhone 16e team
path is visually reviewed. Apple acknowledged TestFlight 1.0.8 (79), source
2897788, delivery 527fb98f-8feb-48d9-ad3b-f47a85c28e77; processing unpolled.
Separate follow-ups are published: dashboard aafcbd5 in PR 93 and shared Ask
f54517a in PR 94. Their checked overlays preserve unrelated live sources; no
schema changes. See each lane's docs/plans report for checks and rollback.

# October 17 interactive mobile setup

First-run onboarding now builds a persistent native canvas world. Team/personal
choices are local until auth, then an account-bound provisioner reuses existing
create APIs and opens the new inventory dashboard. Selection steps advance on
tap; typed names use Done; the empty organization hint is e.g. FindEZ AI.
Personal recap remains Personal / Only you. Provider-first auth follows the
user's later Wispr reference; existing auth handlers are unchanged. Optional
settings questionnaire is preserved separately. Default appearance is already
light and explicit stored choices remain honored. No backend/web/schema or
inventory-dashboard/Space interior changes. Migration 053 remains separately
pending. Baseline 466 tests; final full Flutter suite 506 pass, final focused
motion/onboarding 20 pass after a palette-only correction; analysis clean.
Both iPhone 16e paths recorded at normal speed, keyboard/restart/back/custom and
auth variants visually reviewed. Debug overlay worst UI 59.89 ms / raster 28.804 ms;
strict 16 ms and physical OAuth/email/VoiceOver acceptance are not claimed.
Apple acknowledged TestFlight 1.0.8 (78), source 269f1f0, delivery
5f203ae7-9cdd-437f-b149-eb9383f5241b. Processing/tester availability unverified;
no polling or post-push/build regressions. Full file list, motion audit,
API retry limits and comparison artifacts: design/onboarding-a/IMPLEMENTATION.md.

# October 17 catalog permission hardening

Active lane: fix/catalog-write-permissions-20261017, starting clean 16eb6a1.
User approved implementing the barcode database/backend fix. Scope is audit F01
and the related F07 verified-catalog overwrite, not other audit findings. Candidate
053 and two service-only catalog transactions are complete. 817 backend tests,
321 composed SQL PASS notices and real concurrent-write cases pass. Fresh private
dump restored with existing grants; applying 053 twice preserves all public/auth
row hashes and unrelated objects. Direct client table/column/RPC writes fail;
signed-in reads/backend transactions remain available. Production activation
awaits separate reviewed approval. Patch 07c6d62 is pushed in draft PR 91. Apple
acknowledged TestFlight 1.0.8 (77), delivery cd2e3a2c-3ca2-4d2c-a2dd-cf6d8f1967ef.
Processing/tester availability unverified; no polling or repeated regressions.
Native runtime unchanged, prior 466 Flutter passes/clean analysis reused.
Details/files/rollback: docs/plans/catalog-write-permissions.md.

# October 16 simplified web inventory sidebar

Apple acknowledged TestFlight 1.0.8 (76), source d3109b3, delivery f8d15676-774f-4d88-9468-d0044da2db33. Native UI unchanged; processing/tester availability not checked. Web sidebar is published and visually verified.

Review is grouped under Your world. Restock, Lent items, Project kits, Smart
collections and Labels are removed from the shared web navigation and command
list; the empty Organize group disappears. Existing routes/data are preserved.
324 web tests, TypeScript, changed-file lint and a normal production webpack build
pass. Five old route-selection cases disappear with the removed entries; the
existing sidebar assertion now checks Review's group and absent links. Live
signed-in Safari visually confirms the exact sidebar. Self-hosted web release:
/home/ubuntu/findez-web-releases/web-sidebar-simplify-20261016/frontend. Its one-file
overlay preserves 285 unrelated source files, including the homepage. Public/auth
checks pass, no schema/backend/customer-data change. Mobile UI is unchanged;
beta76 is a standing-instruction delivery increment, reusing the prior 466 Flutter
passes. No checks repeated after push/build; stop at Apple upload acknowledgment.

# October 16 web sidebar simplification

Same lane, clean starting 22a0e27. Move Review into Your world and remove Restock,
Lent items, Project kits, Smart collections and Labels from the shared web
navigation list. Remove the now-empty Organize group. Preserve routes/data and
inventory dashboard behavior. Publish a checked one-file web overlay on the
self-hosted server. Follow standing push/release instructions with beta76 only
as a delivery-number increment; no mobile UI/backend/schema changes.

# October 16 extraction overlay fix

Owned root-dialog cleanup replaces the mismatched local pop in in-Space photo
upload. Success/error removes exactly the progress route; departing Space routes
cannot receive stale confirmation. Four nested-navigation regressions and the full
466 Flutter tests pass; analysis is clean. No backend/web/schema changes in this
stage. Beta74 was acknowledged (0ebf355, 9106117d-0272-4d90-a140-687db472ee06);
Apple acknowledged TestFlight 1.0.8 (75), runtime 7ec84bb, delivery 2b18a905-cc65-4659-a391-20737ab6ed7e. Processing and tester availability remain unverified; no polling. Existing crop/notification changes remain.
No processing polling or post-push/build regression reruns. Manual iPhone camera,
background push and fresh email acceptance remain pending. Details and all files:
docs/plans/capture-progress-fix.md.

# October 16 extraction dialog ownership

Same lane, starting 0ebf355 while beta74 upload is pending. User screenshot shows
Confirm Items behind an Extracting items modal. The in-Space upload flow opens a
root dialog but pops the local nested navigator. Replace unscoped pops with owned
route cleanup in finally; keep the Space and confirmation routes intact. Test
nested navigation, failures and interruption; deliver checked beta75. No backend,
schema, confidence or inventory-layout changes in this stage.

# October 16 per-item scan crop fix

The reviewed adapter now uses the documented item-ID crop endpoint when no URL
is supplied, and reads bbox as x/y/width/height in the stored image frame. Crops
remain independent of confidence and are persisted before job deletion; source
images and Review safeguards are retained. Missing crops fall back to scaled
boxes without discarding detections. The Review and Space toolbars also expose
the notification bell. 814 backend tests plus six subtests, 462 Flutter tests and
clean analysis pass. One-file backend overlay is live with 91 unrelated files
preserved, health 200 and missing-auth scan 401. No schema or customer-data writes.
Apple acknowledged TestFlight 1.0.8 (74), runtime 0ebf355, delivery 9106117d-0272-4d90-a140-687db472ee06. Processing/tester availability remain unverified and were not polled. Real new-camera/device acceptance is pending. Existing
records with missing geometry require a fresh scan. See docs/plans/capture-crop-fix.md.

# October 16 per-item scan close-ups

Same hierarchy lane, starting 258e39e. User reports full-scene thumbnails for
unknown/low-confidence detections. Verify against the existing FIND integration
contract: item crops use the item-ID endpoint and bbox is x/y/width/height in the
stored frame. Fix adapter persistence/fallback only, preserve confidence/review
rules, inventory UI, transport configuration and source image. No production
record backfill or customer photo scan for QA. Deliver checked backend and beta74.

# October 16 notification and reliability follow-up

Approved migration 051 fixed intermittent workspace creation (legacy UUID codes
violated the existing alphabet check); 052 adds a service-only confirmed invitation
recipient lookup with current sender permission. Both restored-schema rehearsals
and composed SQL pass. Reviewed backend overlay is live; 87 unrelated backend
files preserved. No customer mutations or notifications performed for QA.
Mobile now has a direct inbox bell on primary authenticated routes, badge refresh,
explicit phone-alert setup/test, account-bound registration cleanup and cold-tap
retention. Physical background delivery remains unverified. Ask planning no longer
becomes a literal saved-item search; provider selection and authorization unchanged.
Web auth recovery/resend is published; a fresh real email-link success remains
unverified. 802 backend tests plus six subtests, 329 web and 462 Flutter tests pass; analysis
is clean. Apple acknowledged TestFlight 1.0.8 (73), runtime d212f95, delivery cc0229a0-325c-42f4-90e2-04deec6a302d. Processing and tester availability remain unverified; no polling. Actual iPhone background delivery and fresh email-link success remain manual acceptance. See docs/plans/notification-reliability.md.

# October 16 deletion completion and account pages

Same hierarchy lane, includes workspace controls from 5d5f530. Approved migration
050, reviewed API/cleanup worker and Auth-first Edge handler are live. Explicit
purge preserves empty-only default and shared references; account ownership is
checked before deletion; borrower history remains. Web settings now have separate
category pages, compact layout/menu and persistent visible account navigation.
786 backend tests plus six subtests, 322 web tests, 457 Flutter tests, static
analysis, composed SQL, restored-schema rehearsal and normal production builds
pass. Public/auth/schema/hash rollout passes; no customer deletions for QA.
Final signed-in visual review and beta72 delivery are being completed.
See docs/plans/deletion-completion.md for files, receipts, limits and rollback.

# Workspace deletion visibility follow-up (October 16)

Same hierarchy lane, clean starting f6e492b. User reports missing workspace delete.
Reuse existing owner-only DELETE /teams/{id}; no backend/schema changes. Expose
workspace management on mobile home/settings and web header/directory cards.
Exact-name confirmation describes collaboration removal and physical inventory
retention. Preserve inventory dashboard/Spaces. Deliver checked web and beta72.

# Hierarchy navigation repair (October 16)

Active lane feat/hierarchy-navigation-20261016, based on dec9cf9. Replaces mobile/
web organization and workspace directories only; working inventory/dashboard/
Spaces remain unchanged. Always-visible creation, explicit organization cards,
focused workspace lists and authorized rename/delete menus are implemented.
Deletion uses reviewed migration 049, which rejects nonempty inventories and
requires current owner/admin plus typed name. Source checks: 780 backend, 305 web,
448 Flutter full suite; clean static checks and passing composed SQL. Native
visual/accessibility review is isolated. Web candidate build passes with real
production fonts/config. Tanya approved 049 and publishing; migration/backend and
web-hierarchy-20261016 are live with private backups and rollout health/auth checks.
Authenticated Safari confirms the new directory/menu without writes. Apple
acknowledged signed TestFlight 71 from runtime 9bec964 (PR #90). Processing,
tester availability and physical acceptance are pending; no processing poll. See docs/plans/hierarchy-navigation.md.

# Account memory production activation receipt (October 16)

Approved migration 048 and reviewed backend 967ab48 are live on the self-hosted
server, including the PR #88 dependency. Fresh backup restore/migration rehearsal,
public/local health, authentication denial, anonymous PostgREST denial and live
RLS/grant/trigger checks pass. Unrelated VM changes are preserved. Web controls
are published from web-account-memory-20261016 after a normal server production
webpack build with real fonts; only three UI files changed. Candidate/public
route and signed-out protection checks pass. Authenticated device/cross-client
acceptance is pending.
TestFlight 70 was already uploaded; no new binary for this activation receipt.
See docs/plans/account-memory-implementation.md and CURRENT_STATE.md. Older
entries below describe the source/beta state before this explicit approval.

# Active work

## October 16 account memory foundation

Lane `feat/account-memory-foundation-20261016`, based on `5ca4e97`. Tanya approved
stages 1-4 of `docs/plans/account-memory-foundation.md`. Source now includes typed
explicit preferences, private inventory location aliases, transactional receipts,
RLS/legacy-collector guards, grounded personalization and web/mobile controls.
772 Python tests plus six subtests, 302 web tests, 444 Flutter tests, static checks
and standalone/composed SQL including concurrent edits pass. A read-only live
metadata check found unsafe public legacy memory policy/grants; migration 048
subsequently closed them live after explicit approval. No customer records were
changed for QA. The normal server production webpack build passes with real fonts
and configuration; the earlier local fixture output was never published. Apple acknowledged signed TestFlight 70,
runtime `967ab48`, delivery `a4f9218f-38c5-405f-bb60-3de7c938bd3d` (PR #89).
No processing wait. Backend and web are activated; real two-client/device acceptance remains pending. Full files/risks/commands:
`docs/plans/account-memory-implementation.md`.

## October 16 assistant grounded retrieval

Active lane `feat/assistant-grounded-retrieval-20261016`, clean starting commit
`3e3e095`. Read `docs/plans/assistant-grounded-retrieval.md` for discovery,
baseline, stages and risks. Latest user instruction authorizes commit, push
and a new TestFlight build using completed checks, with no repeated post-push
or post-build checks. Preserve gateway selection, client chat contracts, authorization and
FIND transport. Local implementation adds scoped natural-language reads,
evidence/follow-ups, retained HTTP stream scope and caller-tool safety. 127
synthetic cases, 727 Python tests plus six subtests, 296 web tests, 434 Flutter
tests, static checks and connector/bundle checks pass. Review and live acceptance
remain separate; backend deployment is not part of the beta upload. Apple acknowledged build 69
(`dce3e75e-aaba-4994-b609-5953086d88b6`), PR #88; no processing wait. Full files, security limits
and remaining work are in the plan/report above.

## October 16 mobile workspace home and place switcher

Lane `feat/mobile-place-switcher-20261016`, based on mobile build 66. Mobile only:
replace root Your world with the supplied workspace home and grouped bottom-sheet
place switcher, bundled Geist fonts, account-bound last-place storage and
authorized restoration. Reuse current APIs, membership controls and inventory
session boundaries; preserve inventory, Tasks and Files screens. Move leaving to
People. Reference assets are in `design/workspace-switcher/`. Tests, iPhone 16e
comparison screenshots and a subsequent checked TestFlight upload are required.
430 full Flutter tests and analysis pass. The blank space-creation screen is
reproduced and fixed at the nested dialog navigator. Native visual comparisons
and cold restore pass with isolated data. Build 67 uploaded successfully after
all five CI gates, clean signed native package verification and Apple validation;
processing/group availability and physical acceptance remain pending.
No web/backend/schema publication. Xcode regenerable caches were cleared with
approval to recover native-build space; signed release artifacts are preserved.
Follow-up for build 68: the first delivery left old organization, management
and Search routes reachable. Those routes now use the place styling, and opening
a workspace from an organization returns to the home. Search shows only scoped
inventories. Production-connected iPhone 16e simulator navigation confirms the
new flow, real Tasks/Files loading and Space Create/Cancel without a blank page.
434 full Flutter tests and 29 focused tests pass; analysis and all five
exact-runtime CI jobs are clean. Apple validated and acknowledged signed
TestFlight build 68. Processing and tester availability are pending; no wait
per Tanya's request. The public App Store version was unchanged.

## October 16 mobile hierarchy TestFlight delivery

Apple acknowledged 1.0.8 (66), runtime `8dc9fdd`, on PR #85. All five exact-runtime
CI gates, signed package/production configuration/31 native executable checks and
Apple validation pass. Tanya requests uploads after completed mobile changes and
said not to wait after submission. Processing, group assignment and physical
acceptance remain unverified. Public App Store version selection and submission
were not changed; no backend/schema deployment. Receipts and the later
status/assign helper are in `Documents/FindEZ/AppStore/1.0.8-build66`.

## October 16 mobile hierarchy parity

Source implementation complete on `feat/mobile-inventory-context-20261016`.
Mobile-only organization/workspace/inventory navigation, consent and membership
management, physical locations and immutable scoped API clients replace the old
Teams shell entry while preserving backend records and personal inventory.
409 Flutter tests, clean static analysis, 75 targeted backend tests and 59 web
compatibility tests pass. All five CI gates pass for `a49f03d` on draft PR #85
(run `38872280350`). No backend, web, schema, native configuration or
production backend changes. The later build-66 upload is recorded above.
Native/device, real email and two-client acceptance remain
release gates. See `docs/plans/mobile-hierarchy-parity.md` for matrix, files and
the disposable-account test plan.


## October 15 organization actions menu

Completed and published PR #84, runtime `a21ea8d`, migration 047, build
`3hd1z4zQK8kaRdhzoIf3X`. Owner-only three-dot menus offer Rename and Delete on
organization cards and selected Workspaces/People pages. Delete requires the
exact current name and no attached workspaces, enforced transactionally with a
durable audit. Existing workspace/inventory controls remain unchanged. 565
backend tests plus six subtests, 296 web tests, TypeScript, lint with zero errors,
production build, isolated SQL/concurrency checks and all five CI gates pass.
Live signed-in Safari opens/cancels both dialogs and verifies context menus;
no customer QA writes. See CURRENT_STATE.md for release and rollback receipts.

## October 15 approved Lab homepage publication

Published at `/` on PR #83, runtime `4caa38c`, build
`nGSlTwykEqoUG8MlgI06u`. Retains only Developers, iOS App and session-aware
Get started/Dashboard in the header, and all six footer destinations at the
bottom. The header moves at half scroll speed and smoothly fades out after
moving half its height, restoring on return to the top. Hidden links are inert;
reduced motion uses normal page scrolling. The announcement banner is removed.
288 web tests, TypeScript, changed-file lint and production build pass. Desktop
and 390px checks verify retained links, no overflow/errors, scrolling header,
waitlist confirmation-only behavior and reduced motion. Live public/protected
routes, assets and backend health pass. `/lab` remains the original noindex
preview. Backend/mobile/database unchanged. See CURRENT_STATE.md for rollback.

## October 15 isolated Lab landing preview

Completed on `feat/landing-lab-20261015`, based on `2d8d3f7`. Approved ZIP
prototype ported to `/lab` with noindex, scoped fonts/CSS, direct DOM animation,
hero canvas and reduced-motion support. Homepage and live production unchanged;
private production preview forwarded to localhost:3000. Waitlist is deliberately
confirmation-only with no API request. Production build, TypeScript, lint and
287 web tests pass. All 46 desktop/mobile comparison pairs verified, with matching
geometry and only hero drift plus a few phone-frame raster edge pixels remaining.
No console errors or horizontal overflow. See
`frontend/design/landing-lab/VERIFICATION.md` for files, receipts and preview details.
Tanya subsequently approved homepage publication as recorded above.

## October 15 workspace hub and discoverable inventory directory

Completed and published PR #81 runtime `5a2bc55`, migration 046. Workspace
Overview, separate inventory navigation, approved directory metadata, hidden
inventories and recipient-initiated viewer requests are live. 550 backend/276 web
tests, TypeScript/lint, SQL/concurrent decisions, restored-copy preservation,
production build and all five CI gates pass. Live signed-in chooser/context flow
verified; no customer QA writes. Later collaboration phases remain planned.
See CURRENT_STATE.md for validation limits and rollback receipts.

## October 15 creator rename

Completed and published PR #80 runtime `905923a`, lane
`feat/creator-rename-20261015`. Organization/workspace owners and inventory creators
have name-only Rename controls with backend access checks; existing inventory
manager rights and all stable resource relationships remain. 537 backend/268 web
tests, TypeScript, lint, production build, all five CI gates and signed-in live
Safari dialog/cancel checks pass. No customer data changed for QA. No migration or
mobile change. See CURRENT_STATE.md for runtime and rollback receipts.

## October 15 recipient-approved membership

Completed and published PR #79 (`8592a4d`), migration 045, on lane
`feat/member-invitation-consent-20261015`. It replaces immediate new
organization/workspace membership and newly granted inventory access with pending
recipient-approved invitations, email review links, recipient-bound codes,
Notifications, Accept/Decline, expiry and sender cancellation. Consent is enforced
in the database-backed API, with existing memberships preserved and sender/parent
authorization rechecked on acceptance. No real invitations or
customer access changes during QA. All 528 backend/262 web tests, TypeScript,
lint, all five CI gates, production build, isolated/concurrent SQL checks,
restored-copy migration rehearsal and live signed-in Safari checks pass. Existing
memberships and public-table values/policies are preserved. See CURRENT_STATE.md
for runtime/rollback records and web-only invitation review behavior.

## October 15 contextual website navigation

Completed and published PR #78, runtime `5d9906f`, on lane
`fix/web-context-navigation-20261015`. Context selection and management are
separate; organization/workspace/inventory navigation and creation dialogs adapt
the user's reference to FindEZ. 253 web tests, TypeScript, changed-file lint,
production build, all five CI gates and signed-in Safari checks pass. Existing
routes, APIs, memberships and data are preserved. Backend/database/mobile are
unchanged. Release and rollback details are recorded in CURRENT_STATE.md.

## October 15 organization and inventory access

Completed and published PR #77, runtime `5462d87`, migration 044. Organizations,
workspace overviews, inventory-specific roles, physical-location attachments and
audit history are live. Original data and legacy permissions preserved. All five
CI gates, 516 backend tests, 243 web tests, restored-copy migration rehearsal,
production build and signed-in Safari checks pass. See CURRENT_STATE.md and
`docs/plans/organization-inventory-access.md` for scope and remaining limitations.

## October 15 centered Ask FindEZ

Completed and published PR #76, runtime `80ba01b`, with centered Ask content,
static light/dark gradient, history dialog and right-aligned neutral user bubbles.
238 web tests, TypeScript, lint (zero errors), all five CI jobs and responsive
Safari previews pass. Live route/assets checks pass. Existing Safari login had
expired before the signed-in recheck. Backend/database unchanged; release and
rollback details are recorded in CURRENT_STATE.md.

## October 14 workspace and inventory selection

User explicitly authorizes planning and executing a website-wide hierarchy,
illustrated by Supabase organization/project pickers. Lane
`feat/web-workspace-inventories-20261014`, based on import runtime `bd1c8a1`,
owns: choose personal or Team workspace, choose inventory, then its dashboard.
Keep physical Spaces inside inventories and keep account/profile/billing global.
Scope Home, capture/import, Find, Assist context/history, documents, Review,
activity, lending, kits and browser purchase plans. Preserve existing ownership
and permissions; backfill source associations into default inventories without
deleting/reimporting customer data. Add an authorized server-side inventory API
boundary and ensure stale responses, caches, photo proofs and IDs cannot cross
inventories. Existing mobile and integration contracts remain compatible.
Implement two quiet selection pages, visible workspace/inventory switching and
context-preserving navigation. Validate different inventories, different members,
view-only roles, writes/reads, forged IDs, refresh/back and narrow layouts before
release. Import PR #74 runtime `bd1c8a1` is published with migration 042.
Completed and published October 15. Backend `eb3eee0` plus migration 043 and
website `eb67ce1` are live. Original values across 21 tables preserved, including
removed-owner legacy records. 511 backend/API-doc tests, 237 web tests, TypeScript,
SQL isolation/preservation checks and all five final-source CI jobs pass. Live
Safari confirms scoped navigation, capture, documents and Assist histories.
Release receipts and rollback paths are recorded in CURRENT_STATE.md.

## October 14 preserve uploaded inventory columns

Lane `feat/import-original-columns-20261014`, based on `7b44165`, owns durable
original column names and values for Excel/CSV/JSON imports, per-sheet mapping,
and imported details on mobile and web. The supplied workbook has 280 populated
rows in Sheet1 and 15 in a different Timing Belts layout, including unnamed
columns containing data. Preserve ordered duplicate/unnamed headers and structured
JSON values. Add an additive item snapshot column only after live-schema checking;
keep ordinary capture/CRUD and sharing permissions unchanged. Do not reimport or
modify existing customer inventory as verification. Settings/navigation PR #73
continues its separate exact-source release checks.

## October 14 Settings and navigation popup layout correction

Lane `fix/web-settings-rows-20261014`, based on `fc20f3a`, owns the user's
Settings screenshot follow-up. Text-only links inherit a three-column icon grid,
putting Plans/legal labels in its 32px icon column. Normalize link rows to a
flexible content column plus a trailing chevron, group existing Developer icons
with their labels, and keep Appearance compact. Preserve all routes, actions and
account state. All 223 web tests, TypeScript and Settings lint pass. Actual
component previews verify all sections in both themes and desktop/390px widths.
The top navigation popup also resets the independent utility translate, stays
inside short viewports, scrolls results beneath its visible input, removes repeated
section captions and restores trigger focus on close. Use the existing isolated
website release process. Published runtime `7b44165` after all five exact-source CI gates, 224 web tests,
TypeScript, changed-file lint, actual-config production build and Safari
short/narrow/both-theme previews. Live build `D-x-qQyJQDdszMNcrtfXh` uses
`web-settings-navigation-20261014/frontend`, preserves production configuration
and 1,064 prior static assets. 11 public routes, 17 auth guards and three CSS
assets pass; backend unchanged. Receipts/rollback are in the matching local
release folder and `/home/ubuntu/findez-settings-navigation-20261014`.
The user additionally requests durable
original spreadsheet columns across backend, mobile and web; that work follows
in a separate implementation lane.

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
# October 18 capture return — active

Lane fix/mobile-scan-original-return-20261018 from 3414fc0. Confirmed auto-extract
saves return to Items in the current inventory; partial saves stay in Capture.
Existing item gallery receives crop first/original second from backend. Preserve
Dashboard layout and permissions. Verify both themes and deliver signed beta87.

## October 18 final submission audit
Active lane `fix/mobile-final-audit-20261018`: user requested hiding mobile Plans. Build 93 hides Settings plan/pilot promotion and the limit-sheet comparison link; server quotas and memberships remain unchanged. Build 92 delivery and backend security audit are recorded in the API lane report.

## October 26 account consistency - TestFlight 146 delivered

Account consistency lane: canonical uncached authenticated reads, quiet visible-client refresh, stable Space identity, deletion/access invalidation, and cross-client regression checks. Preserve open drafts and monochrome UI. No database migration or public App Store submission.
