# CAD purchasing and Fusion 0.4.2 candidate

Published to self-hosted production after explicit user migration and release approval.
Current Fusion download: 0.4.2.
This increment does not complete the full CAD roadmap.

## Reviewable changes

- Saved BOM requirement differences for two versions of the same project. Stock
  counts remain historical, and this does not compare geometry or compatibility.
- Shared web purchase plans derived from a fresh inventory comparison of a saved
  Fusion snapshot. Incomplete extraction and ambiguous purchase lines block plan
  creation. Fabricated components are excluded. One active plan per project.
- Manual exact-part supplier quotes, source links and references, quote/expiry
  dates, currencies, availability labels, pack/MOQ arithmetic and bulk price
  breaks. Every quote is retained. Totals keep currencies separate and exclude
  shipping/tax. No vendor feeds or scraped prices are connected.
- Owner/admin approval, vendor-grouped CSV, manual vendor order references, and
  editor-confirmed partial receiving into an existing stock record. Only receiving
  increments stock. It writes a restock event and preserves the inventory audit.
- Optimistic revisions, actor-bound idempotency receipts, and tab-local recovery
  of unconfirmed browser operations. Retrying a delivery cannot add it twice.
- The CAD docs hub covers these controls and their boundaries. The public CAD
  marketing layout is unchanged; its current download version is updated.
- Fusion 0.4.2 avoids reading documentReference for known local occurrences.
  Unresolved external components still warn and remain uncounted. Official API:
  https://help.autodesk.com/cloudhelp/ENU/Fusion-360-API/files/fusion_Occurrence_documentReference.htm
  All current download links and the packaged manifest refer to 0.4.2.

Purchasing is a web workflow in this increment. Existing Fusion session grants
are unchanged and cannot authorize procurement or stock writes. Native Windows
Fusion acceptance is still required; tests use host protocol fakes.

## Validation

- Full backend regression: 1,386 passed.
- Full frontend regression: 717 passed. Additional receiving UI test: focused
  purchasing suite 6 passed (one new test after the full run).
- TypeScript, changed-file ESLint, package/source equality, and whitespace checks
  passed.
- Real PostgreSQL tests cover private table/RPC permissions, role changes,
  unpriced approval rejection, stale edits, exact request replay, duplicate active
  project plans, cross-inventory receiving, over-receipt, partial and full receipt.
- Concurrency: eight identical receipt requests added stock once; eight competing
  revisions produced one success and seven stale conflicts; a concurrent atomic
  stock increment was preserved.
- Fresh production backup restored into a network-disabled disposable database.
  Migration preserved original rows across 135 tables and all existing policies
  and functions. Approval/receiving passed against the restored schema, including
  restock and access-audit entries. Synthetic transaction rolled back. The rehearsal did not modify production. Backup remains private on the server.
- Candidate API imports and OpenAPI schema passed with actual production Python
  dependencies. Full production-configured webpack build passed:
  `ETdpqkfhqjB8-UDAmWCSZ`.

## Migration and activation boundary

`backend/supabase/migrations/20261117_cad_purchasing.sql` adds two private tables
(`cad_purchase_plans`, `cad_purchase_events`) and one service-only transaction
function. Applying it does not change existing inventory rows. Subsequent explicit
receiving actions can increase quantities. The user approved and the migration is applied; installation verified existing stock was unchanged.

Migration SHA-256:
`f316e63bc7b06797690fc5b214d82f2751076f49c2a1bcdaed092918be7f0f6b`

Fusion ZIP SHA-256:
`1fcbc00f574343be0c6d4916dfab4009ff2f9643a9bc72a57e38bd8a8fbd57a6`

Candidate: `/home/ubuntu/findez-cad-purchasing-20261116`.
Base: `/home/ubuntu/findez-cad-slate-20261116/frontend`.
`release.py stage` applied only the enumerated patch/new files to copies of current
production code and verified unrelated source preservation. The manifest records
before/after hashes. Existing download hardlinks were broken before patching.
The build used the real production configuration, without activating the candidate.

Activation completed after approval: apply_migration.py rechecked the SQL hash,
retained a fresh private backup, applied only this migration with ON_ERROR_STOP,
verified unchanged stock/private ACLs, and reloaded PostgREST. release.py activate
verified source guards, copied four scoped backend modules, enabled purchasing,
and switched the web service. Health, routes, docs and ZIP checks passed.
Public HTTPS download matches every packaged source byte. Anonymous purchasing
GET returns 401. Signed-in Safari loaded Purchase plans and Saved BOM versions
for the existing selected inventory; both are empty. No live test orders or stock
mutations were performed. Native installation/placement remains unverified.

Rollback restores the prior scoped backend modules, disables the new feature flag,
and restores the prior web service directory. Preserve the additive schema and
user receipts; do not delete user data.

No repository push or external hosting deployment is part of this candidate.

## Still unfinished

Canonical exact variants; licensed hosted manufacturer CAD and previews; approved
catalog/price feeds; incremental catalog generation and independent geometry
validation; drawing-reference uploads; Fusion purchase controls; automatic BOM
synchronization; engineering substitutions; multi-project stock planning;
purchase cancellations/returns and checkout; broader operational metrics and
curated catalog/native acceptance. No approved vendor feeds were supplied.
