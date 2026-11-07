# Capture and import repair 200

Optional direct inventory imports reuse the existing authorized, durable connector RPC. Every worksheet, repeated row and original column is retained; the selected Space ID is validated within inventory scope. Known fields use deterministic aliases. Invalid quantities, invalid cells and formulas without cached results fail before importing. No schema migration. BOM review is unchanged.

Storage keys now use bounded ASCII filenames, fixing InvalidKey for macOS screenshots. Ownership and private-photo registration remain unchanged.

Validation: full backend 1514 passed; 64 focused import/storage tests passed. Deployment is staged; receipt will follow. Main chat and main extraction logic are unchanged.

## Deployment

Production deployed and healthy; five files changed, 141 unrelated Python files preserved. Database health 200; unauthenticated direct import returns 401. Full production-candidate tests: 64 passed. No schema changes. PR345.
