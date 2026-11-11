# Commerce production rollout — prepared, not applied

Implementation: `8d78f05c0884179b697b1a65019c9ce96475511b`, draft PR #388.
Prepared November 10, 2026 (Pacific). No live service, environment or database
changes have been made. Production database approval is still required by
`AGENTS.md`.

## Exact proposed change

Apply `backend/supabase/migrations/20261110_commerce_connectors.sql` to the existing
database. SHA-256:
`2702bc768f92abe3b454eed883264b8123948c92fb1ba565785f0d6f42f0a763`.
It adds five private commerce tables and three service-only functions. It does not
alter physical inventory quantities or existing table definitions. The migration
is transactional and replayable. Existing inventory membership controls remain
the authority for commerce writes.

Deploy the new commerce backend modules with one additive router registration,
and the Connections screen plus Shopify/Amazon callback routes. Keep commerce
disabled until provider credentials and test configuration are ready. Deployment
does not mean a merchant has connected or a sync has passed acceptance.

## Prepared release and verification

The production backend is `/home/ubuntu/findez/backend`; the web service actually
runs from `/home/ubuntu/findez-web-releases/ask-align-20261108/frontend`. Both differ
from the branch and must not be replaced by a branch checkout. The private staged
candidate at `/home/ubuntu/findez-commerce-20261110/candidate` overlays the new
commerce files onto the actual live source. It preserves 563 unrelated source
files, modifying only the shared backend router, web navigation and Next headers.
A private manifest records 584 candidate source hashes, original source hashes,
the build ID and migration digest. Final preparation found no live source drift.

Validation completed:

- All five GitHub CI jobs passed for implementation commit `8d78f05c` in run
  `42957769542`.
- A full production database copy was restored into a disposable PostgreSQL
  container with networking disabled. Applying the migration twice preserved all
  107 existing tables' row counts/content hashes and the checked existing
  functions, table ACL/RLS state, policies, columns and function permissions.
  All five new tables have RLS; anonymous/authenticated table access and public
  function execution are denied; service-role function execution is allowed.
  The rehearsal container was removed. The private backup remains only on server.
- All 46 commerce backend tests passed against the staged production source.
- Staged web tests: 420 passed, 78 failed, 62 suites. A separate copy of the
  unmodified live source produced 391 passed, the same 78 failures, 60 suites.
  Failure-heading comparison found no new failures; both commerce suites passed.
  Existing failures remain unresolved and the full staged suite is not green.
- A real production webpack build, including TypeScript, passed with the live
  environment and actual fonts. No fixture auth/font configuration was used.
- A temporary loopback HTTP server returned 200 for both callback pages with
  `Referrer-Policy: no-referrer` and `Cache-Control: no-store`. Anonymous access to
  Connections redirected to sign-in with 307. The temporary process was stopped.

Private receipts: `rehearsal.json`, `baseline-comparison.json`, `build.json`,
`http-smoke.json`, and `release-manifest.private.json` in the server staging
directory. Do not commit the private database dump, environments or raw logs.

## Apply after explicit database authorization

1. Recheck service working directories and original/candidate hashes. Stop and
   rebuild the overlay if another terminal changed the live source. Capture a
   fresh database backup and affected runtime/configuration files.
2. Apply the exact reviewed SQL with `ON_ERROR_STOP=1`, then verify the five
   tables and three service-only functions. Do not deploy dependent code first.
3. Copy only the new backend modules and the reviewed router registration into
   the preserved live backend. Its existing Python 3.12 environment already has
   the required `cryptography==50.0.2`; no production package installation is
   needed. Restart `findez.service` and check health and anonymous denial.
4. Switch `findez-web.service` to the tested staged frontend through a reversible
   service override, retaining the old release and its dependency target. Restart
   and verify existing routes, sign-in protection and both callback pages.
5. Verify callback headers through public HTTPS as well as loopback. The current
   public proxy reports a different general referrer policy from Next; confirm
   the callback-specific policy survives the proxy before starting OAuth. Do not
   log authorization query strings in callback access logs.

## Shopify test activation and remaining work

Configure the existing FindEZ Connect app's client secret only in protected
server configuration, generate a persistent independent encryption key, and use
`https://www.findez.ai/connect/shopify/callback` exactly. Start the connection from
the same `www` origin: pending state is per-tab sessionStorage, not shared across
hosts. Keep Amazon unavailable until its separate developer setup is complete.

Register uninstall/privacy webhook subscriptions and select an appropriate test
distribution/install path. Then enable the configured provider for the owned
development store and perform real OAuth, sync, rotation, error/denial,
disconnect/reconnect and webhook acceptance. No customer inventory writes or
public installation are part of this test. Provider secret configuration, app
installation, live sync and Amazon registration have not happened yet.

## Rollback

For a runtime failure, restore the saved backend router and the previous web
service working directory, restart only the affected services, and verify health.
Leave the additive commerce schema in place: dropping it could destroy newly
imported evidence. Disable new connections while investigating and preserve
encrypted data, its encryption key, and signed webhook handling. Never reset or
pull the dirty production checkout as a rollback mechanism.
