# CAD documentation hub, November 15, 2026

Live: https://findez.ai/docs/cad

The CAD Intelligence entry in the signed-in sidebar, account navigation and
organization navigation now opens this hub. Organization links retain their
world parameter for the comparison tool. The public /cad-intelligence marketing
page and its links remain unchanged at the user's explicit request.

The hub reuses the API documentation stylesheet, appearance controls, code
examples, header and footer. Nineteen searchable topics cover downloads,
installation, updates, pairing, inventory browsing, local insertion, BOMs,
comparison, Onshape CSV, spreadsheets, statuses, limits, privacy and troubleshooting.
The primary download is workspace candidate 0.2.1; export-only 0.1.0 remains
identified separately. Planned catalog, pricing, generation and procurement
capabilities are not presented as live features.

## Delivery

Self-hosted service: findez-web.
Active frontend: /home/ubuntu/findez-cad-docs-20261115/frontend.
Build ID: z1TrFkN-y0PfMiN2i5aNI.
Previous frontend: /home/ubuntu/findez-cad-workspace-20261115/frontend-fixed.

Built from the active production source with ten scoped runtime file changes.
Unrelated production source/assets and existing environment settings were
preserved. Source guards ran before activation. Existing immutable static assets
were retained for open browser tabs. No Vercel or Render deployment was made.
No backend, database, authentication, mobile or native add-in changes were made.

Server receipts: source-receipt.json, activation.json and previous-service.conf
in /home/ubuntu/findez-cad-docs-20261115.

## Validation

- Full frontend Jest suite: 696 tests across 94 suites passed.
- TypeScript, changed-file ESLint and whitespace checks passed.
- Production-source Next.js webpack build passed with existing production settings.
- Live documentation, API docs, marketing page and downloads returned HTTP 200.
- Comparison and pairing links reached their sign-in flow.
- Safari desktop rendering and topic search/clear were verified live.
- Phone-width visual verification could not be completed because Safari computer
  control stopped returning screenshots. The existing shared API docs responsive
  stylesheet is reused without modification. Native Fusion acceptance remains
  outside this documentation-only change.

Local changes were committed without pushing to avoid an automatic hosting
preview outside the user's self-hosted-only deployment scope.
