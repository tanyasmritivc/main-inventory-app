# Shopify development-store acceptance

Scope: source milestones 1A and 1B are implemented. Continue real development setup
and acceptance once a Shopify app/store exists; neither is deployed or live-store
verified. Do not describe the full migration/planning vision as implemented.

Branch: `feat/shopify-catalog-connection`; worktree
`/Users/tanyasmritivictorcharles/dev/findez-shopify-connector`, based on discovery
`08f06ca`. Use the latest branch head/draft implementation PR, not the stale
primary checkout. Discovery PR #60 records the earlier architecture audit.
Physical-memory lane: `feat/commerce-physical-memory` in
`/Users/tanyasmritivictorcharles/dev/findez-commerce-memory`, based on connector
`1a49e1c` (PR #61). Its acceptance contract is `docs/physical-memory.md`.

Completed: `backend/app/api/routes/shopify.py`, `services/shopify_api.py` and
`shopify_sync.py`, `scripts/shopify_worker.py`, migration 042, optional Team >
People web panel/API helpers, placeholder app configuration and tests. OAuth is
owner/browser/state bound, credentials AEAD encrypted, catalog/stock separate,
jobs page/lease/generation fenced and callbacks signed/store bound. Disconnect
does not modify native physical records. Feature flag defaults off. Shared
architecture/current state/tasks and `docs/shopify-development.md` are updated.

Milestone 1B adds migration 043, `routes/physical_memory.py`, deterministic lookup
service, web Memory tab and mobile Team page. Confirmations reuse Team Spaces/bins,
preserve independently authored names after disconnect, separate observed counts,
enforce revisions/idempotency and keep append-only history. Ambiguous/unknown/stale
locations are explicit; personal Ask mutation tools remain isolated. Local 482
backend, 232 web and 347 mobile tests with coverage pass, as do SQL isolation and
analysis/type/lint. Exact-source CI/build results must be recorded at final PR head.

Validation: 457 backend/API-doc and 221 web tests, TypeScript, changed-file ESLint,
production webpack build and real disposable PostgreSQL RLS/lifecycle pass.
Safari renders actual panel with sample data in Light/Dark and wide/320px widths;
temporary fixture is removed and final build contains no QA route. Live-store
OAuth, exact grants/query execution/costs, refresh, webhook timing and backups are
not tested by mocks or SQL. CI status belongs to the actual PR head.

User confirms no Shopify app/development store exists and chose preparation for
development testing. Remaining: app/store registration and selected distribution,
isolated backend/web/Supabase configuration, migrations 042/043 on that test database,
private credentials/vault key, HTTPS same-site origins and callback query-log
redaction at all proxies. Verify app TOML with Shopify CLI, supervise the worker,
then complete the real-store checklist in `docs/shopify-development.md`.
Do not put secrets in chat/source/logs and do not point fixtures at production.

Production schema is untouched. Explicit user authorization is required for
production migrations/deployment/merchant installation. Preserve dirty deployed
backend/Team/router work and apply verified migrations before dependent runtime.
Disabled feature is the safe runtime rollback; leave independent physical data
intact and keep compliance receiver credentials until redaction is complete.
Public App Store distribution/billing/policy/backup-retention review remains a
separate gate. Physical-location observations and bounded Team-aware read-only
lookup exist in 1B source only. Guided migration, photo matching and operational
planning are later increments. Existing FIND HTTP transport deferral stands.
