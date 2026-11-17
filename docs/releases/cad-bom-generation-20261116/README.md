# CAD 0.4.0 candidate: BOM history and RexCAD STEP generation

Published to the self-hosted production site after the user's explicit migration
and release approval. Version 0.4.0, including the improved Fusion panel, is served
by all eight CAD download links. This remains a candidate pending native Fusion
placement acceptance; it is not the entire CAD roadmap.

## Included

- Inventory-scoped immutable BOM versions, shared reviewed matches, and history
  in the Fusion panel and signed-in CAD page. A save recalculates current stock;
  historical results are labeled and never silently updated.
- Separate editor opt-in for CAD writing at pairing. Existing sessions remain
  read-only. Revocation, expiry, inventory changes and role downgrades block writes.
- Server-only RexCAD integration, actor/inventory-owned job receipts, stable
  idempotency keys, status/resume/clarification/cancel, and automatic STEP download
  directly into the active Fusion placement flow.
- Bounded responses, SHA-256/size checks and valid-solid metadata checks. No
  provider URLs are followed. Generated geometry is labeled unverified and
  fabricated, not an inventory purchase or manufacturer-certified model.
- Documentation, installation instructions and all eight CAD download links
  target the same 0.4.0 ZIP in this candidate. The public marketing layout is
  untouched; only its download version query changes.

No inventory quantity changes, direct purchases, Onshape activation or new package
dependencies. The RexCAD key is stored in an owner-only file outside the repository
and is absent from runtime source and uncompressed ZIP entries.
The provider key and CAD signing key are installed in a root-owned, mode-0600 backend environment file. They are not browser or add-in configuration.

## Validation

See [validation.json](validation.json) for exact migration and ZIP hashes.

- Full backend regression: 1,320 passed. Final Fusion host contract checks: 22 passed.
- Full web regression: 710 passed.
- TypeScript, changed-file ESLint and whitespace checks pass.
- Real PostgreSQL tests cover old read-only grants, private table/function ACLs,
  actor and inventory isolation, immutable history, retries, foreign-item rejection,
  revoked sessions and role downgrades. Eight simultaneous retries created one BOM
  version and one generation job; eight distinct saves got sequential versions.
- A fresh production backup was restored into a network-disabled disposable
  database. Applying the migration preserved original values across 131 tables,
  existing policies and existing functions. Existing grant write flags remained
  false. Production was not modified. Private backup stays on the server.
- Live authenticated RexCAD schema was checked against the supplied contract.
  A synthetic 60 x 40 x 5 mm plate with a 10 mm through hole succeeded. Its
  26,787-byte STEP matched the provider SHA-256. Provider geometry reported one
  valid solid, expected bounds and hole checks. This is provider evidence, not
  independent native Fusion validation or proof of arbitrary design intent.
- Candidate routes import and generate OpenAPI against actual production Python
  dependencies. The real production-configured webpack build passes, build
  `VWmoOFhFWLVqJVVZaKnVb`. No local preview, Vercel, Render or repository push.

Native Windows Fusion insertion/triad/cancel acceptance is still required. The
contract tests cover changed-design rejection and temporary-file cleanup but do
not prove Autodesk runtime behavior.

## Migration and activation

Candidate SQL: `backend/supabase/migrations/20261116_cad_bom_generation.sql`.
It adds four private tables: `cad_match_corrections`, `cad_projects`,
`cad_bom_versions`, `cad_generation_jobs`; one default-false permission column on
`cad_device_grants`; and service-only transactional functions. It changes no stock.
The Onshape migration 086 must not be applied as part of this release.

Staged root: `/home/ubuntu/findez-cad-bom-generation-20261116`.
`prepare.py` overlays only the files enumerated in `manifest.json` onto current
production source and verifies all unrelated source hashes remain unchanged.
`rehearse.py` never applies SQL to production and cleans up its disposable database.
The final build base is `findez-world-space-games-20261116/frontend`; refresh.py
carried the newest concurrent World changes into the candidate and the production
build passed again. Before activation, verify the active source still matches the
preparation receipt. If it changed, refresh and rebuild before switching. Never
switch back to an older base wholesale.

Activation procedure (completed after explicit approval):

1. Recheck source/migration hashes and retain a fresh private database backup.
2. Apply only the approved SQL to self-hosted Postgres and reload PostgREST schema.
3. Preserve any existing CAD secret. Install a valid private Fernet CAD_SECRET_KEY
   if absent, the supplied REXCAD_GENERATION_KEY, CAD_BOM_ENABLED=true and
   CAD_GENERATION_ENABLED=true into a protected backend-only environment file.
   Never copy the credential into source, public configuration, browser or ZIP.
4. Back up and overlay only the nine backend modules in the manifest, preserving
   the production router and unrelated code. Restart and check health/unauthorized
   route rejection. The inherited Onshape router is not published.
5. Activate the reviewed frontend from the latest base, retain old immutable assets,
   then verify public docs, all download links and ZIP hash. Read-only UI inspection
   must not create customer BOMs or generation jobs as probes.
6. Reconnect Fusion with the optional CAD writing permission and perform real host
   acceptance on a saved editable test design. Record results honestly.

Runtime rollback restores prior scoped backend files/environment and web service
directory. Keep the additive migration and newly saved records; do not delete user
data or expand/revoke existing grants as part of rollback.

## Remaining roadmap

Drawing reference uploads, generated previews, persistent licensed CAD assets,
canonical exact variants, nightly ingestion/generation, vendor pricing, procurement,
receiving, engineering substitution checks and advanced planning remain unfinished.
This release is one connected increment, not completion of the full CAD roadmap.

## Publication and UI acceptance

Published backend and approved additive migration, then the web release at
`/home/ubuntu/findez-cad-bom-generation-20261116/frontend`. All 21 scoped runtime
hashes match the manifest. Every CAD add-in download link serves the same 0.4.0
archive; its uncompressed add-in matches the source byte for byte. Public docs
and the signed-in comparison page display the new version and workflows.

The panel now has a compact brand/version header, responsive tabs, properly themed
text areas, clear action groups and visible progress/errors above results. It was
rendered at 280, 380 and 520 pixels without horizontal overflow. Server capability
flags disable unavailable features. A duplicate insertion cannot retarget an
in-flight generated-model download to another design.

Release checks caught two deployment issues and automatically restored prior
runtime code: the production API deliberately does not expose OpenAPI, and newly
retained static-asset directories needed service-readable permissions. Both checks
were corrected before the successful activation. The additive migration was kept;
no stock or existing grant permissions were changed. Live health, auth rejection,
PostgREST schema visibility and RexCAD status/download checks pass.

Safari verified the live documentation and the authenticated inventory chooser and
CAD workflow, successful empty BOM-history load, and Fusion connection form with
optional writing consent unchecked. Native Fusion on Windows is not available in this environment, so
actual insert/position/confirm/cancel acceptance remains outstanding. No claim of
full native testing is made. No Vercel, Render, local website preview or git push.
