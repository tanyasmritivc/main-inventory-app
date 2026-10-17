# Shared barcode catalog permission hardening

## Scope and starting state

Requested implementation of audit F01 and the related F07 verified-record
overwrite. Started on clean commit `16eb6a1e1443f8497d8e1ed760074f23c436a37e`
on `feat/hierarchy-navigation-20261016`; implementation branch is
`fix/catalog-write-permissions-20261017`. The application/database host is the
self-hosted OpenStack VM. GPU/FIND, provider selection, private inventory edits,
API response shapes and web/mobile presentation are outside this patch.

The live audit found broad client grants on barcode aliases without RLS. The
backend's existing optional learning helper could also overwrite verified product
details. This patch addresses both write paths. It does not certify that earlier
catalog contents are accurate or remediate unrelated audit findings.

## Implemented candidate

Migration 053 enables RLS on `parts_catalog` and `part_catalog_barcodes`, revokes
all PUBLIC/anon/authenticated table privileges, then restores authenticated SELECT
only. Client INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES and TRIGGER privileges
are removed. Backend service-role access and trusted manufacturer maintenance
remain available. The migration itself changes no records.

Two service-only transactions replace direct application writes:

- Community learning validates barcode, source and the five permitted identity
  fields. New records stay community. Existing verified records and aliases are
  protected; supplied verification/evidence/private fields are ignored.
- Alias linking rechecks that the target exists and is verified. Existing
  canonical and alias owners cannot be replaced. Replays are idempotent.

Both lock the same normalized barcode key, including UPC, zero-prefixed EAN and
GTIN forms. Confirmation counts increment in the database. Genuine leading zeros
are preserved. The scoped backend client allows exactly these two catalog RPCs,
as it already allows global usage accounting. Inventory authorization remains
unchanged. Read-only barcode lookup can still populate the optional community
cache. Verified alias linking retains its existing authenticated inventory-save
caller and server-side exact manufacturer/part identity resolution.

An unavailable/rejected optional learning operation returns false and never falls
back to a direct write. Authoritative inventory saves retain their own error
handling. No new client credential, endpoint, schema field or third-party service
is introduced. The service-role credential must remain server-only.

## Validation

- Full backend suite: 817 passed, 10 subtests, 212 existing dependency warnings.
- Focused catalog/importer run: 11 passed, four subtests; final catalog-only run:
  seven passed, four subtests.
- Composed PostgreSQL 17 fixture: 321 PASS notices. Tests cover actual anonymous
  and two-account permission denial, RLS separately from grants, retained reads,
  verified/alias protection, field validation, replay and unchanged records.
- Real concurrent connections: eight updates retain all eight confirmations;
  eight equivalent-alias races and eight community-versus-alias races produce no
  conflicting owners. These tests are included in the existing CI SQL job.
- Fresh full dump restored with existing public/auth/extensions grants in a
  network-isolated PostgreSQL container: migration and repeat application pass.
  All public/auth row counts/hashes and unrelated tables, policies, constraints
  and functions remain unchanged. RLS, table/column write denial, client RPC
  denial, signed-in reads and backend execution privileges all pass. Private
  receipt: `findez-catalog-release-20261017/rehearsal-result.json` on the VM.
- Synthetic SQL fixtures never run against production. The unchanged native
  runtime reuses the prior 466 Flutter passes and clean analysis; no new mobile
  feature acceptance is claimed.

## Production activation and rollback

Production activation is pending separate reviewed approval required by
`AGENTS.md`. Private preparation lives in
`/home/ubuntu/findez-catalog-release-20261017`, with a fresh full database dump,
92-file backend backup, source overlay and original git status/hashes. No live
catalog records have been changed for QA.

After approval, apply the exact reviewed 053 transaction first. Deploy only
`catalog_service.py` and `inventory_scope.py`, preserving all unrelated server
changes. Restart the backend and verify configuration/hash preservation and
read-only health/auth boundaries. Do not write synthetic records to production.
Web publication and GPU changes are unnecessary for this fix.

Keep tightened ACLs/RLS and the additive functions on rollback. Do not restore
anonymous writes or the old verified-overwriting helper. Prefer a forward fix;
disable optional catalog learning if necessary while retaining barcode reads.
Restoring a historical full database is not the routine runtime rollback.

Build 77 is a standing-instruction TestFlight delivery increment only; native
runtime behavior is unchanged. Activation depends on the database/backend rollout,
not installing the new binary. Stop at Apple's upload acknowledgment; processing
and device acceptance are reported separately.

## Files

- `backend/supabase/migrations/053_catalog_write_permissions.sql`: ACL/RLS and two
  service-only transactional writers.
- `backend/app/services/catalog_service.py`: normalized equivalents and validated
  transaction calls, with no unsafe fallback.
- `backend/app/services/inventory_scope.py`: exact global catalog RPC allowlist.
- `backend/tests/test_catalog_barcode_alias.py`: backend safety regressions.
- `backend/tests/sql/catalog_write_permissions.sql`: real grants/RLS/provenance tests.
- `backend/tests/sql/catalog_write_permissions_bootstrap.sql`: standalone fixture.
- `backend/tests/sql/catalog_write_concurrency.py`: simultaneous real connections.
- `backend/tests/sql/api_key_rls.sql`, `.github/workflows/test.yml`: existing SQL
  suite/CI integration.
- `mobile/pubspec.yaml`: delivery build number 77 only.
- `TESTING.md`, `.agents/ARCHITECTURE.md`, `.agents/DECISIONS.md`,
  `.agents/ACTIVE_WORK.md`, `.agents/CURRENT_STATE.md`, this plan: test commands,
  authority decisions, current scope and release status.
