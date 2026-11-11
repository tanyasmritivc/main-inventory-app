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
- Retain release configuration validation and increment the candidate to build 220.

## Verified checks

- Complete Flutter host suite: 1,384 passed, one existing opt-in configuration skip.
- Explicit production configuration test: passed using private release definitions.
- Flutter analysis: no issues.
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

Native simulator replay and signed package preparation are in progress. Initial
native failures and corrected replay logs are retained privately. Do not interpret
host mocks or simulator tests as physical camera, barcode, microphone, OAuth,
VoiceOver or APNs acceptance.

Private evidence directory: `projects/findez-readiness220-private`.
It contains credentials and must never be committed.

App Store Connect draft 1.1.3 was prepared with manual release and retained review
information. All 14 existing screenshots have matching checksums and order:
seven iPhone and seven iPad screenshots. No replacement screenshots were uploaded.
No public review submission or release was performed.
