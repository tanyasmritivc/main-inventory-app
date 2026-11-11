# Commerce lane handoff

Owner: this user's Amazon/Shopify terminal. Branch `feat/commerce-connectors`.
Checkout: `projects/findez-command-center/findez-commerce`.
Backend base: `17632a92024a986cb08dcfb795ba518fd9897ee9` (barcode217).

Keep other lanes out of `backend/app/services/commerce/`, routes/commerce.py,
commerce tests and `20261110_commerce_connectors.sql` while this branch is active.
The shared router has one additive import/registration; merge that hunk only.
No CAD, canonical item/purchase schema, Assist orchestration or mobile edits.
The user subsequently assigned merchant connection UI and callbacks to this lane.

Implemented backend candidate: Shopify merchant OAuth/catalog/stock/order lines,
Amazon seller OAuth/orders/FBA stock, consumer purchase CSV review/confirmation,
encrypted tokens, actor-private source evidence, disconnect/purge, Shopify privacy
and uninstall hooks. Full contract/setup/limits: `docs/plans/commerce-connectors.md`.

Merchant web UI and callbacks are now implemented in this branch. Connections is
an inventory-scoped navigation entry at `/inventory/connect`. Callback routes are
`/connect/shopify/callback` and `/connect/amazon/callback`. They preserve actor-bound
connection identity in per-tab storage, reject duplicate callback keys, strip query
credentials, and POST all parameters with the original account's JWT to `/complete`.
Callbacks and backend are deployed, with commerce disabled. Match callback origin exactly to
the initiating web origin; cross-origin sessionStorage handoff is unsupported.
Web consumer purchase CSV upload, mobile integration and FIND binding remain future
work. Do not independently implement competing callback or connection screens.

FIND/unified-inventory lane: consume SourceRecord with connection and observation
metadata. Sales, merchant stock and consumer purchases are separate record kinds;
none is physically verified. No direct stock writes or auto-reconciliation here.
Keep actor/inventory authorization and provider-grant scope through any adapter.

Shopify signup and organization onboarding are complete. AI Robots INC organization
246688821 now has FindEZ Integration Test (generated sample data, free dev store)
and FindEZ Connect app 446104666113, active configuration commerce-dev-1. See the
setup receipt in the contract for dashboard URLs and exact settings. Client secret
remains unrevealed in Shopify; no FindEZ server credentials were configured.

Shopify distribution/webhook subscriptions, test installation,
live sync, public proxy callback correction and FIND binding remain
pending. The user approved the schema/backend/web deployment, completed at
04:34:44 UTC November 11. No outbound messages have been sent. All five CI
jobs passed for backend/web 8d78f05c in run 42957769542. No TestFlight build is
required for this backend/web lane. Do not label integrations as available.

Production preparation is complete; see `docs/plans/commerce-production-rollout.md`
for exact migration digest, deployed release path, live source preservation,
verification and rollback. The real staged build
and callback HTTP checks passed. The web baseline has 78 existing failing tests;
the candidate has those same failures, no new ones, and both commerce suites pass.
The isolated production database rehearsal preserved all 107 original tables and
checked schema objects after two migration applications. Live schema permission
checks and public health/anonymous-denial checks also pass. Nginx callback logs
omit sensitive query/referrer values. Caddy still overwrites no-referrer with
same-origin; two available SSH routes rejected authentication. See
`docs/plans/commerce-edge-proxy.md` for operator instructions. No edge change was
made, and no provider secret/encryption key was configured. Future changes must
preserve other terminals' live source and the now-deployed commerce files. Do not expose
the private server-only database backup, environment copies or raw logs.

## Consumer Gmail continuation

The user clarified personal US Amazon shopping accounts, then chose Gmail OAuth
instead of forwarding. Forwarding/Resend/company mail setup was withdrawn before
any deployment, account creation, DNS/mail routing or message access.

Amazon SP-API sandbox **FindEZ Connect Sandbox** was created in the FindEZ AI
account before that clarification; this does not provide consumer purchases. Its
secret remains unrevealed and no refresh token or seller API call was made. The
seller identity form is unfinished and should not be continued for this feature.

Gmail code, migration, worker commands, limits and activation gates are described
in docs/plans/gmail-purchases.md. New migration is unapproved/unapplied; server
credentials and real OAuth acceptance are pending. Own new purchase_email route,
service, migration/tests plus gmail service/client/callback files. Preserve other
lanes. Canonical item reconciliation and chat binding remain the foundation lane.

Local 1,698 backend tests + ten subtests, 358 web tests, TypeScript/lint and
compile-only webpack pass. Disposable PostgreSQL tests apply migrations twice;
47 assertions pass; temporary container removed. The compile used synthetic
environment/fonts and must not be deployed. SQL test used no production data.
Google Cloud project FindEZ Connect (`findez-connect`, number 757329840369) was created under findezai@gmail.com and verified. Gmail API is enabled. OAuth branding was created after explicit policy acceptance approval; external/testing, support findezai@gmail.com, developer contact info@findez.ai. No client created. Search Console was initially
mistaken for a Cloud project. Do not create a second project without checking the
latest UI and setup receipt. Never expose OAuth secrets or user email contents.

November 11 continuation: Google OAuth client created with user approval; Gmail read-only scope saved and findezai@gmail.com added as test user. Secret and encryption key staged privately with Gmail disabled. Full isolated production-copy rehearsal preserved 112 tables; live-source candidate preserves 578 unrelated files, focused tests and real server build pass, all three loopback callbacks pass. Exact release and pending database authorization are in docs/plans/gmail-purchases.md. Duplicate JSON in local Downloads needs manual removal because sandbox denied chmod. No live Gmail grant/data, database migration or deployment.
