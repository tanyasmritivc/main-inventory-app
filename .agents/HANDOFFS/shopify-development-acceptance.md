# Shopify development-store acceptance

Status: PAUSED by the user's latest October 14 instruction. Shopify is excluded
from the current launch, superseding the earlier launch requirement. Preserve
all source slices, draft PRs and development resources. Do not continue setup,
implementation or review until the user asks to resume. Keep the four feature
flags off, migrations 042 through 045 out of production and Shopify runtime out
of the launch branch. The remaining steps below are for a later release.

October 14 setup: the user creates the Partner organization, and the agent creates
and verifies the read-only standalone development app plus sample-data Basic dev
store. The app's active initial version uses a Shopify placeholder home, legacy
authorization-code install flow and API 2026-10. Callback URLs, webhook subscriptions
and optional writes are not yet configured there. No app installation, actual
grants, token/refresh/query acceptance or secret access is performed. Private links
are saved in the local Documents/FindEZ/Shopify setup record.

For a later release, test resources verify the preserved integration. The current
single-store development gate must be extended to a merchant-ready installation
path before merchant rollout, followed by public distribution
review/approval, real API and security acceptance. Do not choose custom distribution
for the future multi-merchant app or select any irreversible method without
specific authorization. Source template installation mode now matches the current
adapter; evaluate managed installation deliberately rather than changing one flag.

Scope: source milestones 1A and 1B are implemented. When the user resumes, continue
isolated development setup and acceptance; neither is deployed or live-store
verified. Do not describe the full migration/planning vision as implemented.

Subsequent owner-edit source: `feat/shopify-owner-permissions` in the same
`dev/findez-commerce-memory` worktree, based on `ef9489e` (PR #63). User selects
adjustable owner permissions, stock adjustments and product details, followed by
guided merchant adoption or appropriate acceptance. Migration 044 and
`docs/shopify-owner-permissions.md` add policy/grant/role intersection, reviewed
fixed mutations, IO leases, immutable intents, receipts and honest unknown recovery.
No actual external grant/write or production change is authorized/performed.

Owner-edit runtime `a58e84e` passes all five CI gates in `38521256695`, including
real PostgreSQL and production web compilation. Guided setup follows in
`feat/merchant-guided-migration`, based on that head, with migration 045 and
`docs/merchant-guided-migration.md`. The factual report, bounded variant queue and
reviewed name reuse existing confirmation and lookup. `MERCHANT_MIGRATION_ENABLED`
defaults false. Extend isolated acceptance through the actual migration guide;
no real merchant or production outcome is claimed. Guided runtime `d4cf468`
(draft PR #65) passes all five CI gates in `38525045435`, with 509 backend/API-doc
and 259 web tests, production web compilation, SQL isolation and mobile regressions.
Source work is complete; real app/store configuration and acceptance are deferred.

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
analysis/type/lint and production webpack compilation with placeholder configuration.
Exact-source CI results must be recorded at final PR head.

Validation: 457 backend/API-doc and 221 web tests, TypeScript, changed-file ESLint,
production webpack build and real disposable PostgreSQL RLS/lifecycle pass.
Safari renders actual panel with sample data in Light/Dark and wide/320px widths;
temporary fixture is removed and final build contains no QA route. Live-store
OAuth, exact grants/query execution/costs, refresh, webhook timing and backups are
not tested by mocks or SQL. CI status belongs to the actual PR head.

The initial no-app/no-store condition is resolved. Remaining: launch distribution
and customer installation design, isolated backend/web/Supabase configuration,
migrations 042 through 045 on that test database,
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
lookup exist in 1B source only. Guided stockroom migration and owner edits exist in
further disabled source. Photo matching and operational planning remain unbuilt.
Existing FIND HTTP transport deferral stands.
