# Mobile audit, November 12, 2026

## Scope

The current iOS release source is build 221 (`897d5911`). This audit uses that
checkout, not the older mobile files in the web audit checkout. Candidate:
1.1.4 (222). Backend, web, database, public App Store submission and existing
App Store screenshots are unchanged.

## Fixed defects

Supabase can emit a transient token-refresh error on its authentication event
stream without signing the user out. Eleven account-aware view subscriptions
did not handle stream errors, so an ordinary offline refresh could become an
unhandled exception. Documents supplied the reproducible failing regression.

Those view subscriptions now leave reconnect/retry handling with the existing
launch auth gate and retain their current state until a confirmed auth event.
Existing account-switch and sign-out cleanup is unchanged. Failed writes still
surface through their existing error handling.

Regression coverage checks both the mounted Documents view and the signed-in
launch shell. It asserts that the transient error does not escape, clear the
current session, replace the view with sign-in, or delete documents.

The native replay also exposed a 56-pixel overflow in the setup error screen at
320 x 568 with 3.2x text. An independent host regression reproduced it. The error
screen now respects safe areas and scrolls so Retry remains reachable. Exercising
Retry uncovered a callback returning a Future to setState, plus immediate future
errors occurring before FutureBuilder attached on the next frame. Retry now uses
a synchronous state callback, and the setup future is observed immediately while
FutureBuilder retains responsibility for displaying the error. The regression
checks both the layout and a repeated failed retry.

## Completed host checks

- Final suite: 1,393 passed, one intentionally gated release-config test skipped.
- Explicit production-config run: that gated test passed with the existing
  production defines, checking HTTPS endpoints and anonymous client-key role.
- `flutter analyze --no-pub`: no issues.
- Coverage output: `mobile/coverage/lcov.info` (generated, not committed).
- Line coverage: 24,999 of 37,790 instrumented lines, or 66.2%. This is not a
  claim that all possible device behavior or bugs have been covered.

The first audit attempt exhausted local disk space during native compilation.
That incomplete run is not counted as a pass. Only regenerable caches and an
unavailable-runtime simulator were removed before the successful host rerun.

## Simulator audit

`integration_test/mobile_full_audit_test.dart` combines 29 existing synthetic
audit entry points into one native build. It covers account restoration,
onboarding, documents, permissions, invitations, spaces, capture/review, chat,
voice-controller behavior, appearance, typography and responsive surfaces.
It uses fake identities and services and does not mutate customer inventory.

The initial broad replay binary was compiled before the auth correction. It
passed the early suites but reached an isolation defect when an earlier suite's
Supabase singleton replaced onboarding's mock transport. The aggregate harness
now resets auth and native-control overrides between audit groups. That
interrupted run is not reported as
an all-passing suite. The remaining groups and new regressions run in a rebuilt
binary; final counts and delivery are recorded in the release receipt.

Some imported suites intentionally use Flutter control fallbacks, synthetic
camera/audio input, and simulated viewports. This replay is not an assertion
that every UIKit control or physical sensor has been tested. The iOS linker
source-file assertion is host-only and intentionally skipped on the simulator.

## Remaining acceptance boundary

Physical iPhone checks remain deferred to the user: actual camera/barcode,
microphone, Apple/Google sign-in, push delivery, VoiceOver and final motion.
Automated success does not establish those physical behaviors or authorize a
public App Store submission.
