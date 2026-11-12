# Web launch readiness audit, November 11, 2026

The tested web release is live at https://findez.ai on the existing self-hosted
production server. No Vercel or Render deployment was used. Build:
`pS9L5T2qUaiLpKJGxnlQF`.

## Fixes

- Updated Next.js from 16.3.8 to 16.4.6. The production dependency audit reports
  zero vulnerabilities. Kept the established ESLint toolchain; an unrelated lint
  toolchain migration is not part of this runtime security patch.
- Removal dialogs reset on account, resource, or resource-name changes. Late
  responses cannot complete the new dialog. Deletion requires a deletion receipt;
  a move receipt cannot falsely confirm deletion.
- Review data is isolated by account. Obsolete fetches cannot repopulate the new
  account's queue. A pending dismissal confirmation cannot write after unmount.
  Errors and success notices now have accessible alert/status roles.
- Added CAD Intelligence, CAD setup, solution detail pages, Founders Access and
  desktop download routes to the public sitemap.
- Corrected assistant setup instructions: the shipped Claude Desktop extension
  supports inventory reads/writes/imports; organization management and deletion
  request tools are available through the published ChatGPT Actions schema.
- Repaired outdated test fixtures for current routes, deletion previews, account
  ownership, copy, and browser-only APIs. No tests were skipped or disabled.

The source baseline was first reconciled with the actual deployed frontend, then
refreshed to preserve concurrently deployed CAD title styling. No backend,
Supabase, mobile, customer-record or Apple relay-account changes were made.

## Validation

| Check | Result |
| --- | --- |
| Full web suite with coverage | 677 passed, 88 suites, 0 failed, 0 skipped |
| Backend repository regressions | 1,146 passed, 206 warnings |
| Connector tests | 36 passed |
| Downloadable extension integrity | Passed |
| Standalone extension test | 1 passed |
| TypeScript | Passed |
| ESLint | 0 errors, 71 warnings |
| Production Next.js webpack build | Passed |
| Production dependency audit | 0 vulnerabilities |
| Live public routes/downloads/auth redirects | 34 passed |

The full suite passed after the runtime dependency update. The final connector
copy correction additionally passed its two focused tests, lint, and the final
production build. Detailed route checks, source hashes and check summaries are
stored alongside this report. Coverage output remains in `frontend/coverage/`.

## Live browser acceptance

Safari verified successful sign-in to the personal workspace, rather than an
unrequested Connections redirect. Checked personal and organization Connections,
organization action menu, server-backed removal impact preview, disabled exact-
name confirmation, and cancellation preserving the organization. Verified CAD
inventory selection, Fusion and CSV/Excel controls, disabled empty submission,
and authenticated Review rendering. No inventory mutations were submitted.

At 390 x 844, checked the public landing layout, cookie-notice dismissal, working
tour Pause/Play control and scroll-driven photo section. The authenticated web
shell was checked at the desktop window size. This is a browser smoke check,
not a comprehensive device/browser matrix or measured Safari memory benchmark.

## Deployment and operations

Built `/home/ubuntu/findez-launch-readiness-20261111/frontend` using the production
environment already on the host, without displaying credentials. Verified hashes
for 624 existing files and the 37-file patch before switching `findez-web` to the
new release. Local health checks and public HTTPS checks passed. The previous
release remains available at
`/home/ubuntu/findez-cad-title-refine-20261111/frontend`.

The service override is
`/etc/systemd/system/findez-web.service.d/zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz-launch-readiness.conf`.
Rollback consists of removing only this override, reloading systemd and restarting
`findez-web`; the deployment script performed this automatically on failure.
The service was active with zero automatic restarts after deployment.

Removed 3,363 MiB of old, inactive webpack build caches. This restored 4.2 GiB free
space. Compiled rollback releases, public assets, images and customer data remain.

## Remaining acceptance limits

Automated gates and the live read-only smoke checks are green. They do not certify
all possible bugs or every production integration. Before broad launch, complete
fresh-account signup/confirmation/password-recovery delivery, separate Google and
Apple OAuth, real camera/microphone uploads, representative CAD/spreadsheet
uploads, and a create/edit/save round trip in a designated disposable account.
This audit intentionally did not send email or mutate customer inventory.

There are 71 lint warnings (primarily legacy typing, image usage and hook-ref
analysis) and development-tool dependency advisories. Production dependency audit
is clean. The backend test count is the repository regression suite with mocked
external services, not a production database migration or RLS certification.
