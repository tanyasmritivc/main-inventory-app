# Connected Fusion workspace candidate

First increment of the full [CAD roadmap](../../plans/findez-cad-roadmap.md).
Published directly to the self-hosted FindEZ server. No Vercel or Render release,
preview, or repository push was used.

## Try it

Download https://www.findez.ai/downloads/findez-fusion-workspace.zip and follow
its README. Stop the old add-in, select the inner FindEZ folder in Fusion's
Scripts and Add-Ins dialog, run it, and choose Open FindEZ. Sign in from the
palette, select an inventory in the browser and verify the matching code.

Connection management: https://www.findez.ai/cad/fusion/connect

Inventory and catalog browsing, local STEP/F3D insertion, direct BOM comparison
and shortages export are included. Hosted models, pricing, purchase/receiving,
saved Fusion corrections and nightly model jobs are not included. Local model
geometry remains unverified. Native Fusion acceptance is pending.

## Validation

- Full backend regression suite: 1,277 passed, 10 subtests passed.
- Full web coverage suite: 690 passed across 92 suites.
- Subsequent native/transport/packaging regression checks: 75 passed.
- Three additional palette DOM tests passed: identity/stock separation, inert
  untrusted text, uncertainty, export, disconnect isolation and busy state.
- TypeScript and changed-file ESLint passed. Compile-only fixture build passed
  but was not published. The real production-source webpack build also passed.
- Disposable SQL checked private credentials, actor/inventory authorization,
  replay, expiry, revocation and account deletion. Eight simultaneous exchanges
  issued one session and rejected seven replays.
- Fresh production backup restored into a network-disabled disposable database.
  All original rows across 119 public/auth/storage tables, existing policies and
  existing functions were unchanged after applying the migration.
- Runtime modules imported against the actual production backend interfaces.
- Live health, unauthorized session rejection, unapproved pairing/poll behavior
  and candidate ZIP hash verified over public HTTPS. The first public check caught
  an incorrect API hostname; the package was corrected to the actual production
  origin, retested and verified live before delivery.
- Safari sign-in redirect preserves /cad/fusion/connect. Signed-in chooser and selected-inventory form were verified in Safari. The
  check caught a nested AppShell and duplicate title suffix; the two-file repair
  passed its production build and was visually verified live. No code was
  approved and no customer stock was changed during browser QA. Native Fusion
  acceptance remains pending.

## Publication and preservation

The user explicitly approved `20261115_cad_workspace.sql` and this candidate
release. It adds `cad_device_grants` and two service-only pairing functions, with
RLS and no anon/authenticated direct access. Bearer secrets are stored only as
hashes. Sessions are memory-only in Fusion, not in the palette or local files.
No inventory rows or existing schema objects were modified by the migration.

Backend publication adds only `app/api/routes/cad_workspace.py`,
`app/services/cad/workspace.py` and their router registration. The production
comparison implementation and unrelated backend work were preserved.

Web publication adds the connection route/component and candidate ZIP, plus the
minimal destination-query support in the existing CadEntry inventory chooser.
All other source/configuration came from the active font-unification release.
Existing immutable assets were retained for already-open browser tabs. The
export-only ZIP, public CAD marketing page, setup guide, mobile and Onshape
activation were unchanged.

The server initially had only 453 MB free. With tool approval, only rebuildable
Next.js caches in twelve inactive releases were removed across two cleanup passes.
The first repair build exhausted disk and was not activated; its failed generated
output was removed before retrying.
Active release assets, source and database backups were preserved.

Private backups, source guards, migration/build logs and activation receipt are
retained on the server under `/home/ubuntu/findez-cad-workspace-20261115`.
Do not copy those private backups into Git. Runtime rollback restores the prior
service working directory/router and removes the two new runtime files; retain
the additive table for review rather than deleting any issued connections.
