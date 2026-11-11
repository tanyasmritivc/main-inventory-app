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
Neither callbacks nor the backend are deployed. Match callback origin exactly to
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

Amazon registration, Shopify distribution/webhook subscriptions, test installation,
live sync, production schema approval, deployment and FIND binding remain
pending. No production changes or outbound messages have occurred. All five CI
jobs passed for backend/web 8d78f05c in run 42957769542. No TestFlight build is
required for this backend/web lane. Do not label integrations as available.

Production preparation is complete; see `docs/plans/commerce-production-rollout.md`
for exact migration digest, staged release path, live source preservation,
verification, rollback and remaining authorization gate. The real staged build
and callback HTTP checks passed. The web baseline has 78 existing failing tests;
the candidate has those same failures, no new ones, and both commerce suites pass.
The isolated production database rehearsal preserved all 107 original tables and
checked schema objects after two migration applications. Live services/database
remain unchanged. Recheck private release-manifest hashes before deployment;
other terminals may have changed live source since preparation. Do not expose
the private server-only database backup, environment copies or raw logs.
