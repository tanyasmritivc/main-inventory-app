# Release readiness 220

Version 1.1.3 (220), branch `fix/app-store-readiness-220`.

The user requested the complete automated audit and an App Store-ready candidate,
with physical iPhone acceptance deferred. Public review submission is not authorized.

## Corrections

- Keep imported widget assertions on discoverable Flutter controls during synthetic
  iOS integration tests. Dedicated UIKit suites retain real native controls.
- Allow assertion-enabled tests to inject their zone-scoped HTTP client instead of
  accidentally bypassing fixtures through native URLSession. The override is
  unreachable in release mode; production networking is unchanged.
- Normalize synthetic keyboard/safe-area coordinates, wait for onboarding scroll
  completion, and distinguish virtual-clock timing assertions from real frame timing.
- Let the conversation-reset fixture own its injected text input instead of
  racing the live IME, and accept the animated placeholder widget. The stronger
  reset assertion verifies the fresh command and all three conversation IDs.
- Retain release configuration validation and increment the candidate to build 220.

## Verified checks

- Complete Flutter host suite: 1,384 passed, one existing opt-in configuration skip.
- Explicit production configuration test: passed using private release definitions.
- Flutter analysis: no issues. Final chat/world follow-up: 82 host tests passed;
  both corrected chat assertions also passed on the native simulator.
- Onboarding follow-up: all 29 host cases passed; the retained-trial sign-in
  flow also passed on iOS after normalizing its synthetic viewport and giving
  the fixture ownership of injected text input. The other 28 native cases
  passed in the preceding full onboarding run.
- Shared imported-widget simulator fixtures now own injected text input; this
  prevents a physical IME from overwriting values or obscuring synthetic views.
  All 25 native Spaces/detail assertions passed after that correction.
- Backend mobile-branch snapshot: 845 passed. Current deployed backend source:
  1,625 passed. No backend source or customer inventory was changed.
- PostgreSQL 17 isolation, concurrent writes, and account-memory suites: passed on
  disposable databases.
- MCP tests and packaged bundle checks: passed.
- Web: 324 tests passed, TypeScript and production build passed after compatible
  dependency security updates. Separate PR #386; not a production deployment.
  No high/critical dependency advisories remain in that patch. Lower-severity
  development dependency advisories and existing web lint findings remain.
- Review-account login, read-only inventory directory, service health, privacy,
  terms, website and universal-link association checks passed.

## Native and release evidence

All 25 planned native replay groups passed, plus the separate keyboard regressions.
This includes 210 screen-layout cases across light/dark, phone/iPad, and large text.
Duplicate integration wrappers were mapped to their shared underlying test cases;
corrected failures were rerun rather than silently skipped. Initial failures and
corrected replay logs are retained privately. The native notification check also
passed: passive launch, explicit permission request, denial retained without a
second prompt, and no signed-out server registration.

Final simulator visual inspection confirmed contained organization menus,
continuous home/chat ambient backgrounds, native Settings/history/attachment
sheet backgrounds, plain dark Spaces, light surface separation, and compact
native camera controls. The synthetic preview does not provide organization-detail
endpoints; its organization access error cleared on returning to Personal.

Do not interpret host mocks or simulator tests as physical camera, barcode,
microphone, OAuth, VoiceOver or APNs acceptance. Physical-device acceptance was
explicitly deferred by the user. The opt-in live extraction service suite was not
run against customer/review inventory; synthetic scan suites and backend tests
passed. Existing web lint findings remain (38 errors, 55 warnings); the separate
web dependency patch has zero high/critical advisories, with 27 low/moderate
development-tool advisories remaining. Both PR #386 and #387 have five passing
CI jobs at their implementation commits. The web patch is not deployed.

Private evidence directory: `projects/findez-readiness220-private`.
It contains credentials and must never be committed.

App Store Connect draft 1.1.3 was prepared with manual release and retained review
information. All 14 existing screenshots have matching checksums and order:
seven iPhone and seven iPad screenshots. No replacement screenshots were uploaded.
No public review submission or release was performed.

## Delivery

Apple validated and acknowledged TestFlight upload of **1.1.3 (220)**.
Runtime commit: `3e0cc9afd1a1fb2d83cdab1e0887020d107349d4`.
CI run: `42957050450`; all five jobs passed.
Delivery: `93e74361-5439-4bd8-bb94-d388a9d4166a`.
IPA SHA-256: `5bb1907d604151fd471409b863edc84cff09694bd789768ce51eab09edcebd3b`.

Strict signing checks passed for archive and export; 33 device executables and 27
privacy manifests verified. App and share extension versions match; production
configuration, APNs entitlement, fonts, and device-only architectures verified.
Processing and tester availability are pending and were not polled. The draft
does not yet have this processing build selected. Public review remains untouched.
The disposable simulator and database were removed; signed IPA/archive and logs
were retained. Receipt: `docs/plans/mobile220-release.json`.
