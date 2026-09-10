# FindEZ test suite

The repository has one automated test entry point for all three product surfaces:

```bash
make test BACKEND_PYTHON=backend/venv/bin/python
```

When a Python virtual environment is already activated, omit the override and run
`make test`. To install the backend test dependencies from a fresh checkout:

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -r backend/requirements-dev.txt
npm --prefix frontend ci
cd mobile && flutter pub get && cd ..
```

## Test layers

| Layer | Command | Scope |
|---|---|---|
| Backend | `make test-backend` | FastAPI services, route behavior, auth, limits, search, imports, catalog, and notifications with external I/O stubbed |
| Web | `make test-frontend` | Next.js/TypeScript business logic and user-facing error behavior |
| Mobile | `make test-mobile` | Flutter model behavior and critical widget flows |
| All with coverage | `make test-coverage` | Produces backend XML, Jest coverage, and Flutter LCOV reports |

The unit suite uses placeholder credentials and must not make requests to production
Supabase, OpenAI, Stripe, or other external services. Backend-wide environment and
import-path setup lives in `backend/tests/conftest.py` so tests do not mutate shared
modules during collection.

GitHub Actions runs all three jobs independently on pull requests and pushes to
`main`. A change is green only when backend tests, web tests, `flutter analyze`, and
Flutter tests all pass.

API integrations also have a PostgreSQL 17 CI job that executes
`backend/tests/sql/api_key_rls.sql` against an empty disposable database. It verifies
the real RLS policies and triggers, including cross-team isolation, write-only
updates, repeat imports, aggregate queries, revocation, and Space detachment. To run
locally, point the standard `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, and
`PGDATABASE` variables at an **empty test database**, then run:

```bash
psql -X -v ON_ERROR_STOP=1 -f backend/tests/sql/api_key_rls.sql
```

This SQL fixture creates its schema and test roles. Never run it against production.

The API usage regressions also cover exact-part quantity totals across pages,
record counts versus unit totals, numeric low-stock filters, and zero matches.
Python HTTP tests check stable bulk-import identities, duplicate rejection,
validation of every target workspace before a batch write, and independent
per-key standard/bulk request limits. These run automatically in the existing
backend and PostgreSQL CI jobs; no real API key is needed.

## Public API documentation

The public `/docs/api` page and downloadable OpenAPI 3.1 reference use
`frontend/public/docs/api/openapi.json`. Generate it from the current mounted
integration router with:

```bash
make docs-api BACKEND_PYTHON=.venv/bin/python
```

`scripts/api_reference.py` owns the endpoint explanations, response shapes, and
examples. Request models, URL parameters, auth types, permission requirements, and
default rate limits are derived from backend code. Generation uses placeholder
configuration and never contacts a database or external service. Review the
generated diff when changing the API; do not edit the JSON directly.

`tests/api_docs` runs automatically with `make test-backend` and the existing Python
CI job. It fails on contract drift, missing errors, broken schema references,
invalid request examples, or HTTP response mismatches. Inventory I/O is stubbed;
database semantics remain covered by the existing PostgreSQL job.
The existing SQL entry point includes `tests/api_docs/semantics.sql`, so the
PostgreSQL job also runs documentation regressions for empty Spaces/Teams,
zero-quantity record counts, exact text matching, null inequality, and unowned
workspace reads. Web tests verify
public rendering, all navigation anchors, search, language selection, clipboard
success/failure, the downloadable link, and syntax of every generated shell,
Python, and JavaScript request example without executing requests. Those syntax
checks need `bash`, `python3`, and Node.js (available on the existing CI runner).

Before publication, build the web app, check `/docs/api` and
`/docs/api/openapi.json` without a session, and verify the link from Settings → API
keys and the public footer. The docs add no production API routes or migrations.

## Release testing

Automation does not replace physical-device checks for OAuth, APNs, camera/barcode
scanning, share-extension handoff, or multi-account permissions. Before a release,
also complete `test-data/release-checklist.md`; its access-revocation and offline-write
sections are release gates.
