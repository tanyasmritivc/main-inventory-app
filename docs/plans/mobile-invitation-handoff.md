# Invitations within organization navigation

Mobile lane fix/invitation-org-handoff-20261017, base d53a320. Build1.0.8(83).
The organization pill offers Review invitation for links or manual codes.
Twelve-character access codes use the same recipient-confirmed review as cold and
warm links. Legacy six-character codes retain Workspace / Shared Space selection.
Strict parsing preserves supported URLs without accepting foreign origins or
silently truncating malformed codes. Preview, expiry, declined/cancelled links
and Not now grant nothing; the backend rechecks acceptance.

An access receipt must match the invitation, resource, scope and requested action.
Confirmed organization invitations open that organization, including an empty one;
workspace invitations open its scoped directory, and inventory invitations open
that exact authorized inventory. The authenticated root consumes an account-bound
handoff instead of stacking another inventory shell. It retires the old client
and revalidates current parents. Known inventory parents are loaded directly to
avoid the legacy initialization race discovered by destination regressions.
Invitations accepted before root setup completes remain pending for that account.
Notification review and manual/hierarchy entry use the same destination handling.
Account changes hide stale previews, writes remain actor-bound, and preference
write failures are raised. Dashboard content, Scan, Ask and Space interiors remain.

All 601 Flutter tests pass with coverage, including 13 added destination/consent
cases across both themes and existing signed-out, restart, warm-link, revocation,
large-text and actor-binding checks. Analysis is clean. Native iPhone16e review
with network-free synthetic data verifies the initial consent prompt, acceptance,
organization handoff, manual lowercase code entry and light/dark presentation.
The original light simulator appearance is restored; the signed-in app is
untouched. Fixtures are tool/invitation_preview.dart, excluded from lib/main.dart.
Screenshots are in design/mobile-invitations/out.

Backend/web invitation fixes are published with no migration or customer writes.
Their guarded activation preserves 90 unrelated Python and 245 web source files;
health and database health pass. Local backend833 tests plus10 subtests and web331
Jest tests/coverage, TypeScript, lint and production build pass. Separate PR99/100
use compatibility parents containing the already reviewed AnyIO fixture and
Material ink fixes, so their runtime diffs stay in their own lanes. CI and Apple
receipts follow when complete. No post-push regression reruns are planned.

Native compilation hit the disk limit. Failed outputs and regenerable caches were
cleared; a debug build without symbol output completed. Source, installed
dependencies, prior releases and customer data are preserved. The production
archive is rebuilt clean for devices with production configuration and lib/main.
Actual email delivery, a real two-account phone acceptance/revocation and fresh
App Store installation are not proven by synthetic review. Public build17 and
Team-only AASA remain unchanged; do not claim access Universal Links/deferred
installation work in that older public binary. Current beta supports the explicit
installed-app link; web review remains available. No Apple processing polling.
