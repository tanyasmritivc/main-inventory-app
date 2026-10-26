# Pre-launch access - October 25

Scope: api. Branch: `fix/api-prelaunch-access`. Deployed; see receipt below.

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

Validation: 1484 Python tests and ten subtests passed. No schema change.

Release requires all five exact-source CI gates. Web/API use guarded source
overlays preserving unrelated live changes and rollback. Mobile uploads a signed
TestFlight beta and stops at Apple's acknowledgment. Public App Store submission
is still on hold. The larger subscription implementation remains unfinished in
the separate feat/*-subscriptions worktrees and is not part of this release.

## October 25 - Pre-launch access delivered (PR219)

Runtime `b24c0bdcf8204b80dd8f140328788b451cece86a` is live; all five exact-source CI gates passed in 40235308444.
Plan quotas and purchases remain off, with no automatic cutoff.
Rollback: `/home/ubuntu/findez-prelaunch-api-20261025`. No production schema change.
Read-only production verification confirms pilot=true, limits_enabled=false, no end date, and null item/Space/chat/scan maxima. API/database health and anonymous denial passed; 117 unrelated files preserved.
See `docs/plans/prelaunch-access-20261025.md`. Paid subscription integration remains separate and unfinished.
