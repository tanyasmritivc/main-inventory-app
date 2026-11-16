# Connected CAD page release

Published to self-hosted findez.ai on November16 UTC (November15 Pacific).

The signed-in /cad comparison tool now leads with the connected Fusion workflow:
installation/update, Open FindEZ, browser pairing, AI search, project model
selection and open-assembly comparison. JSON/CSV/XLSX upload remains available
as an explicit alternative. Shared installation instructions now lead with
Open FindEZ. Help links lead to current CAD documentation and connection management.
The candidate limitations remain explicit. No new native functionality is claimed.

## Validation

- All702 frontend tests in95 suites pass;17 focused CAD tests also pass.
- Scoped ESLint, TypeScript and git diff --check pass.
- Real production-source webpack build passes.
- Signed-in Safari reload shows the new headline, selected inventory,0.3.1
  download, connected workflow and upload controls. Desktop dark layout checked.
- Public CAD and both documentation routes respond after activation.
- Live workspace ZIP remains SHA-256
  bba16d75a4fcd181261f0a9d0bd428a04eb85024442e56add7b8cdcfa388f5e0.

## Release and preservation

Active: /home/ubuntu/findez-cad-page-20261116/frontend

Build: qY971QoEypRUNBRuC0wNU

Previous: /home/ubuntu/findez-world-storage-final-20261116/frontend

Production had an older inline comparison-results implementation than this
branch. web.patch changes only presentation blocks and preserves that runtime,
all unrelated World changes, configuration and public assets. Exactly three
source files differ from the production base: cad-client.tsx, cad-help.tsx and
cad.module.css. Public landing page, ZIP, backend and database are unchanged.
No Vercel/Render, mobile or schema release.

The guarded deploy.py checks active release and baseline hashes, keeps prior
static assets for open tabs and saves previous-service.conf for rollback.
The inactive CAD-labels compiler cache was removed to make build space; its
runtime build and source remain intact. Restore previous-service.conf to the
recorded effective service override and restart findez-web if rollback is needed.
Native Fusion placement acceptance remains pending and is not validated by this
web-only release. No customer stock or design records were changed.
