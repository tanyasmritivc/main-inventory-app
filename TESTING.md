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

## Release testing

Automation does not replace physical-device checks for OAuth, APNs, camera/barcode
scanning, share-extension handoff, or multi-account permissions. Before a release,
also complete `test-data/release-checklist.md`; its access-revocation and offline-write
sections are release gates.
