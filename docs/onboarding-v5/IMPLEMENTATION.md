# Mobile onboarding v5

The signed-out launch now presents the native Flutter welcome, four skippable single-choice questions, an account summary with existing Apple/Google/email authentication, and a short confirmation. Signed-in accounts retain the existing app entry. Ask, Spaces, More, permissions and sharing behavior are unchanged.

The supplied HTML, video and flow image define the layout and motion. Inter 400/500, monochrome controls, persistent soft gradient, overlapping step transitions, selection pause and reduced-motion behavior are implemented in Flutter. Large-text content scrolls without hiding the account actions.

Answers are retained under `findez_onboarding` before authentication and written to existing Supabase user metadata under `onboarding` after signup. An account-bound receipt retries failed writes on a later authenticated launch. Returning accounts cannot acquire an anonymous draft through the existing-sign-in shortcut. Back navigation invalidates delayed selection advances; late auth responses cannot finish another account's flow. No database migration is needed. Read-only production schema inspection found no JSON/JSONB profile field, so no profile mirror was added.

Existing AuthPage provider and email handlers are reused through an optional presentation adapter. Legacy onboarding files still used by retained-item recovery remain; only the unreferenced onboarding_flow.dart and onboarding_graphics.dart were removed. The previous mobile branding commit remains part of this release.

## Validation

- Final focused onboarding and launch suite: 17 tests passed.
- Native iPhone 17 Pro simulator: all 9 v5 flow tests passed, including exact answer persistence, skip/back, existing sign-in, verification, failed save retry, account isolation, large text and reduced motion.
- Native widget PNG captures in `verification/` were inspected. Simulator video recording captured the test harness rather than app frames and is not accepted as motion evidence.
- Approved disposable live-account test passed: real Supabase auth metadata held the exact selected answers, local answers and account receipt cleared, and the tagged disposable account was deleted. Admin provisioning avoided verification email; this does not claim a physical Apple/Google chooser test.
- Full final mobile regression: 1,199 passed, one existing skip. Flutter analysis: no issues.

Physical iPhone OAuth, email deep-link return, spoken VoiceOver and motion smoothness remain device acceptance checks. Public App Store submission is not included.

## Delivery

User authorized TestFlight upload and explicitly requested leaving main as-is. Apple acknowledged upload of build 1.1.1 (152) from feat/onboarding-v5. An isolated draft PR against its mobile branding baseline is used only for CI; main is not merged or changed. No web, backend, database, environment or CI configuration changes are included. Apple acknowledgment and exact source are recorded in RELEASE-152.json. Processing/tester availability is pending and was not polled.
