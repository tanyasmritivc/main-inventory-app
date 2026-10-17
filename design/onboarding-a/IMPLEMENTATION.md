# Build your world mobile onboarding

Implemented October 17, 2026 on `feat/build-your-world-onboarding-20261017`.
Clean starting commit: `7cb8459853816382d8c9bde8681b4c60eb795c03`.
Apple acknowledged TestFlight 1.0.8 (78). Processing and tester availability are unverified.

## Responsive follow-up, beta79

The beta78 preview omitted the production AppGradientBackground/SafeArea wrapper.
On a device, that wrapper shortened the canvas while the camera retained its
fixed prototype position; the field and chips then overlapped the platform.
The preview now uses the production wrapper. The scene fits between measured
heading and control bounds, accounts for keyboard height and wrapped tags, and
caps wide layouts. The persistent painter, motion timings, copy, creation and
auth logic are unchanged. The mobile default remains light.

All 545 Flutter tests pass and static analysis is clean. The 39 added responsive
cases cover ten phone/tablet/landscape profiles from 320 x 568 to 768 x 1024,
native safe areas, organization/workspace/inventory clearances, keyboard height,
long labels, large text and scrollable recap. The original production-wrapper
regressions failed before the fix. A disposable iPhone 16e simulator app was
reviewed with the native keyboard through the team path; screenshots are in
out/responsive. No customer accounts or records were created. This does not
replace physical-device acceptance or establish the previously unmet 16 ms gate.

Changed runtime files: mobile/lib/features/onboarding/onboarding_page.dart,
mobile/lib/features/onboarding/world_scene.dart and mobile/pubspec.yaml.
Validation changes: mobile/test/world_responsive_test.dart,
mobile/test/world_onboarding_test.dart and mobile/tool/onboarding_visual.dart.
Delivery is pending the signed production beta79 archive and Apple acknowledgment.

## Result and scope

The first-run mobile introduction is a native, interactive canvas. Team setup
collects an organization name, workspace purpose and inventory name. Personal
setup collects a standalone workspace and inventory. Selecting tiles/chips
advances after 180 ms of selection feedback; there are no Continue buttons on
those steps. Keyboard Done confirms typed names. The recap opens authentication.
The organization hint is `e.g. FindEZ AI`, rendered only while the controller is
empty, in the supplied hint color. Personal recap remains Personal / Only you.

The user's later Wispr screenshots override the package's instruction to freeze
auth layout. Google and Apple are primary, Email is under More options, and no
Microsoft/SSO option is introduced. Email mode retains all existing fields,
validation, eligibility, reset and verification actions. Its provider buttons are
above the form and the consent/submit controls are below it. A source comparison
confirms the original validation/provider/email handler section is unchanged
apart from formatting. This is not proof that external providers or real email
delivery were exercised on a device.

The existing appearance controller already defaults to `ThemeMode.light`, both
before storage loads and when no valid preference is stored. The full regression
suite verifies that default and preserves explicit Light/Dark/System choices.
Onboarding/auth use the requested light presentation. No appearance preference
reset is introduced.

No web, backend, database, API, GPU/FIND, inventory-dashboard or Space interior
changes are included. Candidate migration 053 belongs to the previous barcode
permission task and remains separately awaiting production approval.

## Architecture and creation

All onboarding steps are state in one StatefulWidget with TickerProviderStateMixin.
A persistent Stack contains the world and the step layer. WorldModel owns camera,
growth, drops, ghosts, tags, shadow and opacity controllers. WorldPainter listens
directly through `CustomPainter(repaint: model)` inside RepaintBoundary. The form
does not rebuild on animation ticks; small tag/entrance widgets animate locally.
Camera interruption starts from the currently interpolated position. Paint alpha
provides face opacity without per-face saveLayer. Canvas coordinates scale from
390 x 844. Large text uses a scrollable presentation with the same controls.

Anonymous answers are serialized to SharedPreferences after every change. Auth
claims a ready draft for one account before making any create request. Account
receipts and the pending dashboard destination are keyed by user ID. Switching
accounts cannot claim another user's in-flight setup. Each successful create ID
is saved before the next call. Concurrent runs for the same account share a
single operation. Existing accounts get one persisted Add it / Skip choice.

Existing authenticated API order:

| Path | Calls after successful sign-in/sign-up |
|---|---|
| Team | POST /organizations, POST /organizations/{id}/workspaces, POST /inventory-workspaces/{id}/inventories |
| Personal | POST /teams with program=other, POST /inventory-workspaces/{id}/inventories |

The built-in Personal inventory is preserved. The landing uses the existing place
and inventory sessions, validates access, then mounts the existing MainShell in
the new inventory. Its local landing receipt is cleared only after opening.

These APIs do not offer idempotency keys. Before a POST, the client persists the
authorized baseline IDs. After an unknown outcome it reconciles a single newly
created, exact-name, actor-owned record in the correct parent scope; it never
blindly repeats a POST. Multiple/no matches remain an honest retry error. If the
server never committed and that outcome cannot be proven, setup can remain
unresolved. Server-backed idempotency would be a separate API change. Do not
represent the client receipt mechanism as server-level exactly-once creation.

The old questionnaire is preserved as the optional settings SetupQuestionsPage.
It is no longer the first-run setup. Existing in-inventory tutorials, invitation
handling and password-recovery routing remain in their original owners.

## Motion audit and final status

Both paths were walked in the iPhone 16e iOS 26.2 simulator. A temporary debug
`timeDilation = 5` pass was used for inspection, then removed. Final recordings
run at normal speed. There are no step route pushes or page slides.

Times below are controller durations verified in source and, for camera/growth/
drops/reduced motion, deterministic widget tests. They are not independent
stopwatch measurements from the videos. The requested universal 16 ms frame
budget has not passed, so this table deliberately does not label everything
fully accepted.

| # | Transition | Earlier implementation audit | Final implementation and timing | Status / owner |
|---|---|---|---|---|
| 1 | Intro | Animated marks, incomplete requested stagger/square behavior | dots 80 ms stagger / 500 ms; scan 1300 ms; squares 250 ms; logo 300+800 ms / 18 px; tagline 1000+600 ms; exit 600 ms, tap skip | Implemented; OnboardingPage intro painter/controllers |
| 2 | Choose entrance | Plain step fade | title 600 ms / 14 px; tiles 250/400 ms delay +600 ms /26 px; note 700+500 ms | Implemented; WorldEntrance |
| 3 | Selection / press | Border selection, incomplete shared press feedback | border/fill 180 ms; press .975 over 160 ms on tiles/chips/buttons | Implemented; WorldPress / tile / chips |
| 4 | Mini-to-world morph | Camera approximated from target instead of actual mini origin | GlobalKey mini center, scale .36 to camera195/500/.8 in800 ms; selected mini hidden; other content outgoing350 ms; shadow400+800 ms | Implemented with one timing deviation: other tile uses common 350 ms outgoing fade rather than 300 ms; OnboardingPage/WorldModel |
| 5 | Step text | Plain fade, incomplete stagger | outgoing350 ms, incoming500 ms /14 px; chips delayed300 ms then500 ms, stacked switcher | Implemented; AnimatedSwitcher / WorldEntrance |
| 6 | Field / keyboard | Needed keyboard-frame and interrupted-camera correction | field/helper use live viewInsets; focus350 ms, unfocus500 ms; focused camera moves above the actual native keyboard | Implemented with adaptive y clamp below prototype360; OnboardingPage / WorldModel |
| 7 | Live organization tag | Live text, incomplete first-entry fade | every keystroke updates; first nonempty tag400 ms, no per-character animation | Implemented; WorldScene / WorldModel |
| 8 | Workspace entrance | Camera motion coupled to general scene update | camera195/490/.9 over700 ms from current position | Implemented; WorldModel |
| 9 | Purpose selection | Growth present, missing settle/ghost timing separation | block700 ms backOut, tag400+400 ms, first ghosts1000+600 ms; reselect .96->1 in300 ms, tag200 ms crossfade | Implemented; WorldModel / WorldScene |
| 10 | Inventory entrance | General camera tween | camera195/480/1 over800 ms | Implemented; WorldModel |
| 11 | Inventory selection | Incomplete requested drop/bounce timeline | tray600 ms; tag400+400 ms; seven drops start800 ms, stagger120 ms,450 ms each; last completes1970 ms; reselect retains items and settles300 ms | Implemented; WorldModel / WorldPainter |
| 12 | Recap | Legend appeared together | camera112/520/.62 over800 ms; tags fade300 ms; legend800 ms delay then500 ms each,300 ms stagger | Implemented; WorldModel / WorldEntrance |
| 13 | Auth handoff | Fade/rise composite rather than a second route | camera150/120/.12 over900 ms; world fade300+500 ms; auth rise16 px /fade200+600 ms | Visual implemented; keeps existing auth gate rather than required literal PageRouteBuilder |
| 14 | Edge back | Retained values needed model restoration fixes | single-route gesture; reverse title direction and current-camera tween; retained block/tray restored; no route slide | Implemented and simulator reviewed; OnboardingPage / WorldModel |
| 15 | Reduce Motion | Partial final-state handling | model channels instant; text200 ms crossfade; press scale disabled | Deterministic tests pass; native OS toggle/device pass pending |

The architecture preserves the existing auth gate rather than pushing another
auth owner. During the exit the same AuthPage presentation is composited, then
the gate mounts the interactive AuthPage after completion. This intentional
deviation avoids duplicate auth navigation/state. The user's tap-to-advance
request also means block/tray growth continues while the next title arrives;
there is no extra button or artificial wait for the model to finish.

## Actual verification

- Baseline: 466 Flutter tests passed before implementation.
- Full relevant suite: `flutter test --no-pub --concurrency=1 --reporter expanded`,
  **506 passed**. Includes existing appearance, auth eligibility/layout,
  invitation launch, recovery routing, dashboard and inventory regressions.
- After the final one-line chooser-mini palette correction: world motion and
  onboarding suites **20 passed**, followed by clean `flutter analyze --no-pub`.
- New focused coverage: 15 draft/provisioner tests; 14 onboarding/layout tests;
  5 real-widget auth-to-dashboard tests against synthetic HTTP Auth/API peers;
  6 model/motion tests. No tests create customer records or send live email.
- Auth-to-dashboard cases cover email sign-in, immediate-session sign-up,
  verification-required sign-up and later session, Add it/Skip, session-required
  POSTs and the existing reset/resend requests. Provisioner tests cover lost
  responses for each creation stage, known rejection retry, concurrency,
  account switching and local-storage failure.
- Simulator: both paths, custom input, edge back, retained selection, restart
  after typing, native keyboard placement, empty hint, both auth variants and
  sign-up consent/submit organization reviewed. The signed-in original app was
  preserved; reviews used a separate disposable QA bundle with no network client.
- Accessible text layouts through 3.4x pass widget tests. Native AX exposes real
  fields/buttons/selection/world descriptions. Physical VoiceOver acceptance
  remains pending; AX inspection is not a spoken VoiceOver test.

Performance measurements with overlay enabled, normal speed, debug simulator:

| Capture | Frames | Worst UI | Worst raster |
|---|---:|---:|---:|
| Before scoped theme/form rebuild cleanup | 2896 | 66.849 ms | 15.655 ms |
| After cleanup | 1383 | 59.890 ms | 28.804 ms |

The samples differ in length, cold start and host load. They do not establish a
controlled speedup. The later keyboard-camera clamp and chooser palette fix do
not have another performance capture. **No claim of zero dropped frames or a
passed 16 ms limit is made.** Device profile/release measurement is still required.

## Review artifacts

- `out/team.mov`, `out/personal.mov`: normal-speed manual paths, with review pauses
  and reverse gestures. The personal recording predates only the chooser mini's
  isolated palette fix; the final personal02 PNG shows that correction.
- `out/team/`, `out/personal/`: all supplied onboarding PNG poses, including the
  native keyboard and the updated auth presentation.
- `out/auth-returning-user.png`, `out/auth-signup-footer.png`: auth review.
- `out/comparisons/`:14 supplied onboarding poses plus returning auth side by
  side, reference left / native right. Known deliberate differences are the
  user's new auth layout, muted placeholder, no selection Continue buttons,
  Open my dashboard recap action and sample name Northstar Lab.
- `out/motion/`: FFmpeg-extracted phase pairs and timestamp manifest, overlay
  recordings and raw frame-batch summaries. Native videos include human pauses;
  pairs align by phase or pose, not equal absolute elapsed time. These seven phase
  pairs do not constitute a measured frame pair for every motion-table row.

All reference PNGs/videos and both prototype paths were inspected. Source fonts
are references only; native UI reuses the existing bundled Geist/Geist Mono.
The actual iOS keyboard is taller than the prototype's drawn keyboard. Its focus
camera y adapts to retain space between the tag and the field. No copied HTML,
WebView, model runtime or new Flutter dependency is introduced.

## Files changed

| File | Reason |
|---|---|
| mobile/lib/features/onboarding/onboarding_page.dart | Native interactive flow, input and step transitions |
| mobile/lib/features/onboarding/world_motion.dart | Direct-listenable camera/model animation state |
| mobile/lib/features/onboarding/world_scene.dart | Persistent painter, geometry and live tags |
| mobile/lib/features/onboarding/world_transitions.dart | Scoped entrance/press feedback |
| mobile/lib/features/onboarding/pending_world.dart | Durable account-isolated draft and existing-API provisioning |
| mobile/lib/features/onboarding/world_setup_gate.dart | Existing-account decision, authenticated setup/retry/landing |
| mobile/lib/features/onboarding/setup_questions_page.dart | Retain optional settings questionnaire under a distinct name |
| mobile/lib/features/auth/auth_page.dart | User-requested provider-first presentation and email form grouping |
| mobile/lib/main.dart | First-run/authenticated setup gates |
| mobile/lib/features/workspaces/inventory_context_host.dart | Validate/open newly created inventory and acknowledge landing |
| mobile/lib/features/profile/settings_page.dart | Import retained questionnaire under its distinct name |
| mobile/lib/features/shell/main_shell.dart | Import retained questionnaire under its distinct name |
| mobile/pubspec.yaml | Delivery build increment to 78 |
| mobile/test/pending_world_test.dart | Draft, retry, concurrency and account-boundary tests |
| mobile/test/world_auth_handoff_test.dart | Real auth widgets through provisioning and dashboard, synthetic peers |
| mobile/test/world_motion_test.dart | Camera/growth/drop/reduced-motion timeline and mounted-state regressions |
| mobile/test/world_onboarding_test.dart | Interactive inputs, placeholder, keyboard, back and large text |
| mobile/test/auth_eligibility_test.dart | Reach original eligibility controls through new email option |
| mobile/test/auth_layout_test.dart | Exercise existing large-text auth controls through new entry |
| mobile/test/onboarding_launch_test.dart | New first-run draft/auth path with existing invitation guards |
| mobile/test/onboarding_page_test.dart | Retained optional questionnaire import rename |
| mobile/tool/onboarding_visual.dart | Debug-only, network-free simulator/performance review target |
| design/onboarding-a/ | User-supplied references, review evidence and this report |
| .agents/ACTIVE_WORK.md, CURRENT_STATE.md, DECISIONS.md, ARCHITECTURE.md; TESTING.md | Current scope, architecture, verification and release context |

No existing source file is deleted. No schema migration or rollback is required.
Runtime rollback restores the earlier binary. Anonymous draft and account
receipts remain in versioned local keys so a later compatible build can recover
them; rollback cannot undo an organization/workspace/inventory the user already
confirmed and created. Do not delete those server records as a rollback step.

## Required acceptance and next steps

1. On a physical iPhone, sign in/sign up through Google, Apple and email; open a
   fresh verification/reset email and confirm the new inventory dashboard.
2. Profile both paths in the signed device build, including first launch and
   keyboard; resolve any frame over 16 ms before claiming the strict motion gate.
3. Check native Reduce Motion and spoken VoiceOver on device. Server idempotency
   for uncertain setup requests needs a separately scoped API design if desired.

No new backend security issue is identified by this mobile-only change. Existing
audit findings, including the pending barcode permission rollout, are not closed
by this work. TestFlight processing and tester availability are not implied by
upload acknowledgment. No public App Store submission is authorized or performed.

## Delivery receipt

- PR: https://github.com/tanyasmritivc/main-inventory-app/pull/92 (draft for device acceptance).
- Source commit: `269f1f071477243a0d15c08ba5bbe261bea751ef`.
- Branch: `feat/build-your-world-onboarding-20261017`.
- Signed production target: `lib/main.dart`, bundle `com.findez.app`, version 1.0.8, build 78.
- Existing private production defines and export configuration copied unchanged.
- Archive/export succeeded. Flutter also reports the existing native launch-image
  placeholder warning; native launch assets were not changed in this UI task.
- IPA SHA-256: `c068f5e9218b331cbecce76a10c95f85678843ab4aec7ed49fcd480a9369002e`.
- Apple delivery UUID: `5f203ae7-9cdd-437f-b149-eb9383f5241b`.
- IPA, zipped archive, export configuration and private upload acknowledgment:
  `/Users/tanyasmritivictorcharles/Documents/FindEZ/AppStore/1.0.8-build78`.
- Upload acknowledged October 17, 2026. Processing and tester availability remain
  unverified. No processing polls, post-push/build regressions or public App Store
  submission were performed. No production data or schema was changed.
- Runtime commits are complete and pushed; this final receipt is documentation
  only and does not require another binary. Physical acceptance items above
  remain open. No remaining uncommitted changes are intended.
