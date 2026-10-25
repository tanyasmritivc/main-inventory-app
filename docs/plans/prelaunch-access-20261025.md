# Pre-launch access - October 25

Scope: mobile. Branch: `fix/mobile-prelaunch-access`. Delivered to TestFlight; Apple processing/tester availability pending, not polled.

The user wants unrestricted use of the planned Free allowances before launch.
PILOT_MODE remains the server authority and has no automatic expiry. Live policy
was read on October 25: PILOT_MODE=true, PILOT_ENDS_AT unset, all new subscription
switches unset. Paid plans remain informational; no purchases or quotas are activated.
Technical upload/rate limits and authorization remain intact.

API exposes additive `limits_enabled` in /me/limits and removes the obsolete
November deadline. Mobile/web show free pre-launch access and suppress upgrade
prompts unless a fresh account-bound server response explicitly enables limits
and disables pilot mode. Unknown/offline status never authorizes a paywall.
Mobile replaces obsolete cached deadline copy and retains non-modal retry feedback
when an operation fails. There is no database migration or payment dependency.

Validation: 912 Flutter tests passed with one optional visual test skipped; Flutter analysis is clean. Build 137 was uploaded and acknowledged by Apple.

Release requires all five exact-source CI gates. Web/API use guarded source
overlays preserving unrelated live changes and rollback. Mobile uploads a signed
TestFlight beta and stops at Apple's acknowledgment. Public App Store submission
is still on hold. The larger subscription implementation remains unfinished in
the separate feat/*-subscriptions worktrees and is not part of this release.

Delivery: TestFlight 1.1.1 (137), runtime 6c498571131d867ab778d696c3cc5f14ee66ad1e.
All five exact-source CI jobs passed (40235815810). Light/dark Plans simulator
checks, signed device executables (34 in both archive and export), privacy and
production configuration, and Apple validation passed. Upload delivery:
`aa22f3c7-cdd9-4a5f-bc04-dcec4bf7f085`. Processing/tester availability not polled;
physical-device acceptance unverified. No public App Store submission.
Receipt: `prelaunch-mobile-receipt.json`. API/web companion changes are live.
