# Fusion 0.5.0 purchasing and shared-stock planning candidate

Status: published to self-hosted production after explicit user migration approval.
Live workspace ZIP is 0.5.0. Full CAD roadmap remains incomplete.

## Changes

- Native Purchases tab: manual exact-part quotes, pack/MOQ/bulk estimates,
  owner/admin approval and order recording, editor-confirmed partial receiving,
  and vendor CSV. Uses the same transaction as the existing web workflow.
- Separate optional purchasing consent. Existing Fusion sessions remain unchanged.
  Grant row locking serializes revocation with receiving. Permission and inventory
  checks remain server-side. No vendor checkout or automatic order placement.
- Unknown native mutation outcomes retain the exact request locally for retry,
  scoped to actor and inventory. Credentials remain memory-only. Storage failures
  block further writes. Revoked/expired sessions cannot receive stock.
- Read-only planning across up to 20 saved projects, one version per project,
  ordered priority, one finite stock pool. All reservations and checkouts are
  excluded, including reservations for selected projects. On-order quantities
  remain separate; this preview creates no reservation or purchase.
- Native saved BOM differences. Nominal dimensions/material/finish checks block
  conflicting matches. Required specifications and canonical catalog identities
  survive extraction, revisions, purchase plans and CSV. Unknown evidence requires
  review; these checks do not establish engineering compatibility or certification.
- Central CAD documentation, navigation, installation help and all active download
  links agree on 0.5.0. Public CAD landing layout/content is unchanged except ZIP
  query versions. Slate-grey native panel styling is retained.

## Validation

- Full backend suite: 1,398 passed before final metadata/docs changes; subsequent
  affected backend suites: 71 passed, including new exact-variant plan retention.
- Full web suite: 726 passed. Subsequent affected UI/docs suites: 29 passed.
- TypeScript and changed-file ESLint passed after final changes.
- Package/source equality and whitespace checks passed.
- Real PostgreSQL fixture: native consent, independent CAD permission, roles,
  actor isolation, revocation/expiry and idempotent receiving passed.
- Real concurrency: revocation-first rejects the waiting receipt; receipt-first
  forces revocation to wait for commit. Stock increased once, only in the latter.
- Fresh production copy restored to a network-disabled disposable database.
  All 137 original tables retained values; existing policies/functions unchanged;
  old grants remained false. Synthetic native approval/order/receiving and audit
  workflow passed against restored schema and rolled back. An initial synthetic
  code used disallowed characters; corrected fixture uses the actual code alphabet.
- Production-configured webpack build: UcTg9gTeAGgsMWsg7C5II.
- Candidate API imports/OpenAPI routes pass using active production dependencies.
- Real Chrome rendering at 320/380/520 px: no horizontal overflow or browser
  errors. Visual inspection of fictional quote form passed. This is not native
  Autodesk Fusion placement acceptance; Windows/macOS real-host checks remain.

## Reproducible release

Candidate: /home/ubuntu/findez-cad-native-planning-20261116
Base: /home/ubuntu/findez-cad-purchasing-20261116/frontend
files.json / changes.patch enumerate runtime changes. New runtime source was
sent separately as new-files.tgz. release.py copies current production source,
verifies the exact changed-file set, and records before/after hashes. Stage required
sudo because production has existing private root-owned source files. The first
incomplete read-only copy is retained as frontend-incomplete-copy.

New migration: backend/supabase/migrations/20261118_cad_native_purchasing.sql
Adds one false-by-default grant column and two service-only functions. Applying it
does not modify stock. Subsequent explicitly confirmed receiving adds deliveries.
Migration SHA-256: e722b5af9a7606828699936410f168aa06415c62e1bfe4723702532bf39441de
Fusion ZIP SHA-256: 6f8e2ec2afec7332b9a3af23fc20ee8a2fa58d1ca51217e9dd46a5d491a97ada

The user approved this exact migration and candidate. apply_migration.py backed up again and checked
stock/permissions; release.py activate verified unchanged source, swapped only listed
backend files, enabled CAD_NATIVE_PURCHASING_ENABLED, and changed the web working
directory. Automatic rollback restores those files and drop-ins on failed checks.
No push or alternative hosting deployment.

## Still outside this increment

Hosted asset library/previews and exact-variant catalog administration; independent
CAD geometry qualification and nightly ingestion/generation; approved live vendor
feeds; engineering-reviewed substitutes; budget optimization; automatic sync;
order cancellation/returns; reservation writes from CAD; real native acceptance.
Do not call the full roadmap complete or claim a current vendor data connection.

## Live receipt

Both production services active. Public findez.ai and www.findez.ai return matching
0.5.0 documentation and ZIP digest. Unauthenticated session, purchasing and BOM
difference endpoints return 401. New migration left existing stock unchanged.
Candidate-only port 3108 service stopped after validation. Production remains on
normal ports. No test purchases/receipts were written to the production database.
See live-checks.json and the server private activation/migration receipts.

For rollback, restore the enumerated backend-before files (remove only new runtime
files listed as absent in manifest), remove only the activation.json web/API drop-ins,
reload systemd and restart both services. Preserve the additive grant column/functions
and any real purchase history; removing schema is not part of runtime rollback.
The server currently has about 368 MB root space and 610 MB /dev/shm free. Do not
start large geometry installations or delete prior releases/backups indiscriminately.
