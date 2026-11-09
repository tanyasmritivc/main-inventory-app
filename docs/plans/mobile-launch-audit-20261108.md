# Mobile launch audit — November 8, 2026

Baseline: TestFlight 1.1.2 (210), runtime `f4d888969ae977e726ac99c50f37cd50a46b75a9`.
The user resumed the broader audit after approving the native scan presentation.
Keep its diagonal shine, rounded photograph, existing scan behavior and navigation
timing. Use synthetic accounts and fixtures; never modify customer inventory.

## Repeatable automated run

Run from `mobile/`, replacing `IOS_DEVICE` with a disposable iOS simulator UUID.
Run native suites sequentially because they install the same application.

```sh
flutter test --coverage --no-pub --concurrency=1 --reporter expanded
flutter analyze --no-pub
flutter test integration_test/launch_extended_audit_test.dart -d IOS_DEVICE --no-pub --dart-define=FINDEZ_NATIVE_AUDIT=true --reporter expanded
flutter test integration_test/release_audit_test.dart -d IOS_DEVICE --no-pub --reporter expanded
flutter test integration_test/native_scan_progress_test.dart -d IOS_DEVICE --no-pub --reporter expanded
flutter test integration_test/space_chat_layout_test.dart -d IOS_DEVICE --no-pub --reporter expanded
```

The full host suite covers network failures, delayed responses, account changes,
cancel/retry, duplicate submission protection and data boundaries. Native suites
exercise the real rendering engine and UIKit scan view, with synthetic APIs.
Some dialog assertions deliberately use Flutter fallbacks because WidgetTester
cannot tap embedded UIKit controls; inspect those controls separately. The native
audit flag excludes a repository-file assertion that still runs on the host.

## Functional acceptance cases

Use a designated test account with two Spaces and distinguishable items. Repeat
visual cases in light/dark, with default and accessibility text, and with the
keyboard open where relevant. Record build, device, expected/actual and evidence.

| Case | Steps | Required result |
|---|---|---|
| Sign up / sign in | Email, Google and Apple; accept/deny notifications | Provider name retained; permission resolves before Founders Access; closing welcome does not open Settings |
| Navigation | Ask → Spaces, rapid return, Add, Back; repeat with Reduce Motion | Selection leads page normally, no stale navigation or lost draft; reduced motion remains usable |
| Space lifecycle | Create Space, add items, delete Space, reopen all pickers | Deleted Space disappears everywhere; inventory remains; counts refresh |
| Ordinary extraction | Scan a small clear image from Ask | Progress ends in a populated draft or actionable error; no permanent spinner; crops and uncertain quantities retained |
| Dense extraction | Scan an overly crowded image | Progress remains live; completes or exposes a recoverable failure; timing is measured, not guaranteed |
| Space extraction | Start from a chosen Space, edit/save or save as-is | Existing extraction controls work; items save only to that Space; unknown count does not require invented quantity |
| Cancel / navigation | Stop scan/chat, leave page, return; start another | No late stale answer or duplicate save; new request works |
| Background | Lock phone/switch app during scan/chat; return | Existing continuation/recovery behavior works; no lost draft or duplicated write |
| Chat | Main and Space text question, attached image/file, retry | Complete answer without false Retry; Space answer uses only intended context; main chat unchanged |
| History | Open text/photo chats, delete, reload | Correct conversation opens; deletion persists; errors remain actionable |
| Import | CSV, XLSX and JSON with varied headers and unknown quantities | Destination selected once outside Space; scoped import uses current Space; direct import without review; source fields preserved |
| Documents | Upload/open/rename/link/delete; edit note; fail each write | Correct record updated; failed writes retain user input; long names and keyboard fit |
| Item / restock | Open/edit item; change threshold and count | Fields and save actions remain reachable; validation works; counts refresh |
| Settings | Theme, profile, notifications, Founders Access, account switch | Colors/contrast consistent; sheets close correctly; no cross-account state |
| Accessibility | VoiceOver, largest practical text, landscape/compact layout | Labels meaningful; controls reachable; decorative shimmer not announced; Reduce Motion respected |
| Native media | Photos, Files, camera and barcode; grant/deny/cancel | Correct return route; cancellation harmless; denied permission recoverable |

## Evidence and status

Active private evidence directory: `projects/findez-mobile-launch211-private`.
Completed results and the original failing runs are retained in the evidence logs. An interrupted run is not a
pass. Provider/OAuth, physical camera, microphone, APNs, background execution and
VoiceOver require physical-device acceptance; synthetic or simulator checks do
not certify those services. No public App Store submission is part of this audit.

## Confirmed findings and fixes

- **Documents rename:** large text plus an open keyboard overflowed the dialog.
  The title, field and action buttons now scroll together. Saving, cancellation,
  filename validation and API behavior are unchanged. Two new 320pt / 2.6x /
  320pt-keyboard regression cases cover both themes.
- **Restock notification error:** a long floating error could be pushed off-screen
  above inventory controls at 2.6x/3.4x text. This error now uses the fixed bottom
  placement. A deterministic native API failure verifies the message, then clears
  the queued test messages before the underlying list checks continue.
- **Audit fixtures:** native keyboard physical pixels were interpreted as logical
  pixels after synthetic screen overrides; some taps raced caret scrolling.
  Fixtures now normalize those insets and settle before finding actions. Viewer
  checks target the inventory row, and access-review checks target the decision
  request rather than unrelated notification-rule synchronization.

## Completed automated evidence

| Check | Result |
|---|---|
| Full host suite after Documents fix | 1,365 passed; one existing skip; 65.90% line coverage |
| Static analysis | No issues |
| Extended iOS workflow matrix | 171 unique cases passed across the initial run and focused fixes; one host-only assertion skipped |
| Primary iOS release matrix | 177 unique cases passed across the initial run and focused replays |
| Keyboard/profile replay | 21 passed, including the three Documents and two Restock layout cases |
| Error banner replay | Six normal/large-text cases passed in light/dark |
| Host suites for updated fixtures | 79 passed; 56 Documents/profile checks passed after the error-placement fix |

Initial native failures remain in the private logs; they are not represented as
clean initial runs. All original failures were covered by passing focused
replays. The native scan view, request code, chat runtime, palette and tab
implementation match build210; only the two UI error/layout fixes above affect
app runtime. Eight UIKit scan cases, four Space layout cases, fifteen contrast/layout cases
and two Documents visual replays passed. Visual review includes light/dark scan
photo corners and shine, Space empty/populated states, Ask, attachment fallbacks,
item details, photo chooser and the extreme keyboard rename Save position.
All five exact-runtime CI jobs passed (42542851869). Apple acknowledged build211
with delivery `cdcf906e-6c89-4750-b322-a936ae817bc7`. Processing/tester availability were not
polled. See `mobile211-release.json` for the verified package receipt.
