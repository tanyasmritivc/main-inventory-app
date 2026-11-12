# Sign-in resume fix

Cause: the account-scoped findez-resume cookie accepted every protected route,
including /settings/connections. Both the server proxy and client WorldEntry used
that saved route on normal entry, so opening Connections could make it the next
sign-in destination for the cookie's lifetime.

Fix: exclude /settings and /inventory/connect (including child routes) from
resumePath. Validation runs on both writes and reads. Old utility-page cookies
are ignored immediately without a user clearing browser storage. Visiting a
utility page no longer replaces a valid saved workspace page. Explicit sign-in
return links still work; no authentication or authorization is bypassed.

Tests cover stale personal/organization Connections paths, encoded paths, settings,
legacy inventory connections, account isolation, saved workspace preservation,
server redirects from /, /signin and /signup, explicit return links, and callbacks.
All 56 tests across the four targeted suites pass after synchronizing the local
protected-route list with production's already-present /cad entry. ESLint passes.
Only app-resume.ts needs deployment; production's protected routes are unchanged.

Deployed directly to active self-hosted findez-landing-consistency-20261111.
Production build lee60OcGN_hEj8GxNLEou passed, findez-web is active, /signin returns
200, and before/after source manifests show only app-resume.ts changed.
No real user sign-in or account mutation was performed during verification.
