# Commerce lane handoff

Owner: this user's Amazon/Shopify terminal. Branch `feat/commerce-connectors`.
Checkout: `projects/findez-command-center/findez-commerce`.
Backend base: `17632a92024a986cb08dcfb795ba518fd9897ee9` (barcode217).

Keep other lanes out of `backend/app/services/commerce/`, routes/commerce.py,
commerce tests and `20261110_commerce_connectors.sql` while this branch is active.
The shared router has one additive import/registration; merge that hunk only.
No CAD, canonical item/purchase schema, Assist orchestration, mobile or web edits.

Implemented backend candidate: Shopify merchant OAuth/catalog/stock/order lines,
Amazon seller OAuth/orders/FBA stock, consumer purchase CSV review/confirmation,
encrypted tokens, actor-private source evidence, disconnect/purge, Shopify privacy
and uninstall hooks. Full contract/setup/limits: `docs/plans/commerce-connectors.md`.

Web lane: implement the authenticated connect UI and HTTPS callback pages described
in the contract. The URLs in commerce.env.example are proposed callback routes,
not existing pages. Preserve actor-bound connection ID through navigation; reject
duplicate callback keys, strip query credentials, then POST all parameters with
the existing FindEZ JWT to `/commerce/connections/{id}/complete`.

FIND/unified-inventory lane: consume SourceRecord with connection and observation
metadata. Sales, merchant stock and consumer purchases are separate record kinds;
none is physically verified. No direct stock writes or auto-reconciliation here.
Keep actor/inventory authorization and provider-grant scope through any adapter.

User has no developer apps/accounts yet. Live setup/testing, production schema
approval, deployment, UI and FIND binding remain pending. No production changes
or outbound messages have occurred. No TestFlight build is required for this
backend-only lane. Do not label the integrations as available in existing clients.
