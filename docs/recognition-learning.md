# Recognition correction learning

Implemented on 2026-11-08 for the deployed GLM extraction path. This is private
retrieval of reviewed examples, not fine-tuning or automatic model-weight updates.

## Data flow

1. An authenticated scan with an active inventory and memory enabled reads up to
   50 recent eligible correction examples belonging to that actor and inventory.
2. Grounding stays unchanged. At most two relevant, authorized example photos are
   resized and added to the existing identification request. No additional model
   request is made. Extra image inputs can increase inference cost and latency.
3. The server records its identity prediction, source/crop digests, model and
   pipeline versions, and example IDs against the stable crop locator.
4. Only a successful explicit capture save or Review resolution can record a
   correction. The database reads the actual saved item. Client labels are not
   accepted as training data. An unchanged accepted prediction is not a verified
   correctness label. Quantity, location and notes are excluded from learning.
5. Twenty percent of source-image hash groups are reserved for evaluation. Exact
   duplicate crop images cannot straddle reference and holdout data. These held-out
   corrections are never inserted into recognition prompts.

Reference labels are suggestions to visually compare, not identity overrides.
Unscoped legacy scans and captures made before choosing an inventory do not collect
or use examples. Old scans are not backfilled because their original prediction and
human review provenance cannot be reconstructed reliably. Other extraction providers
are unchanged. Web/mobile response contracts remain unchanged.

## Privacy and failure behavior

Examples remain private to the reviewing actor and inventory, even within a team.
Every use rechecks memory generation, current item identity, current photo, and
inventory/image access. Memory off suppresses reads and collection. Forget removes
prediction history and examples; in-flight writes using the old generation are
rejected. Item/account/inventory deletion removes dependent examples. A later item
edit invalidates the old example. The existing personalization cleanup timer purges
records after 90 days. No new image copies or external providers are introduced.

Optional context/storage failures preserve ordinary recognition and saving. They
emit diagnostic warnings without private content. Such failures must not be reported
as a successfully learned correction. Database access has a 0.5 second timeout;
reference-image storage requests have a 1 second timeout and at most two images.

## Evaluation

Run from the configured backend environment, with the normal server-only settings:

```
python backend/tools/recognition_quality.py --actor ACTOR_UUID --inventory INVENTORY_UUID
python backend/tools/recognition_quality.py --actor ACTOR_UUID --inventory INVENTORY_UUID --evaluate
```

Default mode is read-only status and makes no model calls. Evaluation requires 30
current held-out corrections, compares blind crop identification with and without
examples using the same configured vision model, and aborts if the reviewed set
changes. It does not evaluate grounding, quantity accuracy, or overall product
accuracy. Results are selection-biased because only corrected identities qualify.
The report records versions, a dataset checksum, exact normalized label agreement,
improvements and regressions. There is no automatic promotion. Operator-supplied
fixed datasets can also be compared with `backend/tools/evaluate_recognition.py`.

The first deployment has no historical reviewed dataset. Do not claim an accuracy
gain until a sufficiently large, independently checked evaluation supports it.
Actual fine-tuning needs a separate training-capable model service and reviewed
training data; this implementation does not claim to provide that infrastructure.

## Validation and deployment

The deployed backend contains newer files than the public-web main checkout.
Implementation and tests use a read-only production snapshot as the compatibility
baseline. Do not replace the live checkout with this branch wholesale. Only deploy:

- `app/services/recognition_learning.py`
- `app/services/glm_extraction.py`
- `app/services/capture_save.py`
- `app/services/review_queue.py`
- `tools/evaluate_recognition.py`
- `tools/recognition_quality.py`
- migration `085_recognition_learning.sql`

Apply migration before code activation. Compare existing-file hashes against the
snapshot, retain backups, compile/import the staged modules, copy only the listed
files, restart `findez`, and check both health endpoints. Rollback restores the three
previous service files and restarts the service. Additive tables can remain; do not
discard collected corrections during a rollback. The cleanup wrapper preserves the
pre-existing cleanup function and timer.

The isolated PostgreSQL fixture is `backend/tests/sql/recognition_learning.sql`.
Never run that fixture on production. Unit tests stub network I/O. Five legacy
regression tests fail unchanged against the production snapshot because their
fixtures predate small-scan batching and capture revision changes; they are recorded
separately and excluded from the passing compatibility run.

## Deployment receipt, 2026-11-08

Implementation commit `2f1c18b3` is pushed to `feat/recognition-learning` and deployed
to the configured self-hosted backend using the allowlisted overlay above. Migration
085 applied before activation; the `findez` systemd service restarted successfully.
The release and backups are at `/home/ubuntu/findez-recognition-learning-20261108`.
All seven deployed hashes match the tested payload. Local and public `/health` and
`/health/db` checks pass. The existing personalization cleanup timer is active and
its last service execution succeeded. Both new tables have RLS enabled, authenticated
clients cannot read them or execute the dataset function, and an unauthorized
context request returns no data. Initial observations and examples both count zero.

Validation: 99 relevant unit/compatibility checks passed, with five pre-existing
failures reproduced against the unchanged live snapshot and excluded. The isolated
PostgreSQL fixture passed, including privacy, correction receipts, Forget, revoked
access, retention, and holdout separation. No accuracy improvement is yet measured.
