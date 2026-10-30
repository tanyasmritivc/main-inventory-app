# Public App Store release audit - October 30

The user explicitly requested broad testing, fixes, and public App Store review.
The user confirmed App Store review rather than TestFlight-only delivery and
enabled iPhone Mirroring for physical-device checks. Preserve existing product
features and main; use isolated fixtures for destructive/error-path coverage.

Source starts at build161 runtime `0ff52f0`, receipt `c1a91fe`.
Lane: `fix/mobile-release-audit-162` in the persistent Projects checkout.

Completed: 172 native core tests, 168 extended tests (one documented skip), and
30 current onboarding/capture/surface tests passed on iOS 26.5. Full host suite:
1,234 passed, one existing skip; static analysis clean. Fixture tests do not write
to customer data. Dedicated live review login, authenticated workspace read,
health/database health and public legal pages passed.

Physical TestFlight161 checks covered Ask/Spaces/More, empty and populated Spaces,
photo-source menu cancellation, item details and scrolling, search, scoped chat,
Back and settings. A Spaces tooltip persisted over More because native tab
callbacks bypass Flutter pointer dismissal. Explicitly dismiss hints when the
retained destination changes. A regression reproduces stale tooltip state when
returning to the old tab before the fix, and passes after it. Build162 includes
this fix; final native checks and physical candidate acceptance remain pending.

App Store draft 1.1.1 is PREPARE_FOR_SUBMISSION, release MANUAL, with no selected
build. Build161 is VALID. No active review must be canceled. Review instructions
and What's New still describe obsolete sample onboarding; listing screenshots
show the retired orange/cream interface and need current native captures.

Remaining: final native/device checks, current listing/screenshots, exact-source
CI, signed build and guarded App Store submission.
Do not claim camera, speech, APNs or OAuth acceptance from synthetic tests.
