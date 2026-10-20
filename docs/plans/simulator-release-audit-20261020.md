# Simulator release audit — build 99 candidate

The user requested comprehensive testing before App Store submission and allowed
the simulator or iPhone Mirroring. This audit uses synthetic identities and
isolated storage. The excluded founder account is not used.

## Fixes found on iOS

- Move/delete confirmation actions could cover the choices on a small iPhone
  with large text, safe areas and the keyboard. Actions now scroll with the form;
  typed confirmation, destination validation and busy-state protection remain.
- Capture's loading and camera-unavailable panels could overflow at large text.
  These panels now scroll within their existing viewport.
- Embedded Chat could resize twice for the keyboard. MainShell now owns that
  resize. At large text with the keyboard open, New chat becomes a labeled icon
  and the composer uses one visible input line so Back and the conversation
  retain space. Normal-size editing keeps its existing multiline composer.
- Fallback avatar initials could be clipped by their circle at large text.
  The initial scales down to fit its avatar without reducing surrounding text.

The Dashboard layout, permissions, backend contracts and production data are
unchanged. Native test corrections use proportional swipe distance, explicitly
deny notification permission while verifying threshold persistence, and inject
photo-picker denial through the existing picker seam instead of an
Android-specific channel mock.

## Reproducible mobile checks

From `mobile/`:

```sh
flutter test --no-pub --coverage
flutter analyze --no-pub
flutter test integration_test/release_audit_test.dart -d <simulator-id> --no-pub --reporter expanded
```

The native harness runs the actual app widgets on iOS with synthetic APIs. It
covers hierarchy/navigation, invitations, move/delete choices, organization
leave, item inline editing and dismissals, private-gallery presentation, profile
navigation/crop, focused Chat/actions, task attribution and account deletion.
It is not a production-account end-to-end test.

For native image evidence, add `--dart-define=FINDEZ_NATIVE_SCREENSHOTS=true`.
Screenshots are written to the simulator app's temporary directory with the
`findez-audit-` prefix. This flag is test-only and must not be used for the signed
production build. The production target remains `lib/main.dart`.

## Cross-stack checks completed

- Full Flutter suite: 696 tests pass; the one normally skipped compiled-config
  test passes separately with production defines. Flutter analysis is clean.
- Current backend lane: 1,145 Python tests pass.
- Current web source branch: 493 tests and TypeScript pass.
- Exact deployed web source snapshot: 495 tests in 62 suites pass after supplying
  the matching current test fixtures. No web runtime changes were needed.
- MCP: 29 tests, bundle consistency and the standalone bundle test pass.
- Disposable PostgreSQL composition through migration 072, concurrency tests and
  HTTP-to-SQL organization Admin directory checks pass. No production QA writes.

The deployed web candidate contained old tests for signup, removal choices,
legal copy and independently delivered integration pages. Its first test run
failed 49 tests; running updated settings tests plus the matching integration
tests against the unchanged deployed source resolves those failures. Snapshot:
`/private/tmp/findez-runtime-audit-20261020/frontend`; final log:
`/private/tmp/findez-runtime-audit-reconciled.log`. The integration source files
match `~/dev/findez-agent-management-web` byte-for-byte. Do not revert current
product behavior to satisfy the stale tests.

## Remaining release gates

The 159-case native flow suite passes on iPhone 16e/iOS 26.2. After the avatar
follow-up, four targeted native light/dark checks pass. Final visual follow-up,
CI and signed build delivery are recorded below when completed. Simulator tests cannot establish real camera/barcode accuracy,
microphone recording, actual email/OAuth links, background APNs delivery,
overnight session retention, provider capacity or spoken VoiceOver behavior.
These remain physical-device/provider acceptance checks.

Public App Store submission has not been performed by this audit. Earlier
infrastructure notes about the GPU transport/origin and provider nonce settings
must be verified with the infrastructure owner before claiming launch readiness;
this mobile UI audit does not silently change those systems.
