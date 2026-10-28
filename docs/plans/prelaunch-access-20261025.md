# Pre-launch access - October 25

Scope: web. Branch: `fix/web-prelaunch-access`. Deployed; see receipt below.

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

Validation: 574 Jest tests, TypeScript and changed-file ESLint passed.

Release requires all five exact-source CI gates. Web/API use guarded source
overlays preserving unrelated live changes and rollback. Mobile uploads a signed
TestFlight beta and stops at Apple's acknowledgment. Public App Store submission
is still on hold. The larger subscription implementation remains unfinished in
the separate feat/*-subscriptions worktrees and is not part of this release.

## October 25 - Pre-launch access delivered (PR220)

Runtime `b8e5cc80669397cbaf2e3ca1d615c65f9eb463ac` is live; all five exact-source CI gates passed in 40235348641.
Plan quotas and purchases remain off, with no automatic cutoff.
Rollback: `/home/ubuntu/findez-web-releases/no-offers-20261025/frontend`. No production schema change.
Production build, 22 route checks, staged Chrome visual review and public HTTPS notice checks passed. Previous release and backend were preserved. Build ID: xRWAplxSZtohI0lJ31L2E.
See `docs/plans/prelaunch-access-20261025.md`. Paid subscription integration remains separate and unfinished.
