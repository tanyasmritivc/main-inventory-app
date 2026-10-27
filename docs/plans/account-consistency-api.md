# Account consistency: API

Authenticated item reads bypass the process-local 60-second inventory cache. Other workers, SQL RPCs, and the second client can commit writes without invalidating that cache; every authenticated read now queries the canonical scoped database. Background calls without a request actor retain their existing cache behavior. World directory/Spaces responses explicitly use private, no-store.

No database, authentication, permission, endpoint, pricing, or GLM configuration changes.

Validation: 7 focused cache/mutation tests; full backend suite 1,560 tests and 10 subtests passed (452 existing warnings). Regression simulates an external quantity/location change and deletion without invoking local cache invalidation, and verifies owner isolation. Deployment and exact-source CI pending.

Deployed runtime `1f21a1fa701cb025884f9320c27066b1ad5c5b53` after all five CI gates passed. Guarded live health/route checks passed; rollback release and unrelated files preserved. See the adjacent deployment receipt.
