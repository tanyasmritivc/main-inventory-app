# CAD download links, November 15, 2026

Every website Fusion add-in download now targets
`/downloads/findez-fusion-workspace.zip?v=0.2.2`.

Updated eight anchors in five runtime files:
- `cad-public-content.tsx`: public hero and closing download buttons, href only.
- `cad-docs.tsx`: overview, downloads table and installation guide.
- `cad-entry.tsx`: comparison entry help.
- `cad-client.tsx`: comparison tool download.
- `fusion-connect.tsx`: connection setup download.

The legacy 0.1.0 docs row remains historical text without a download link.
CSV template links and archive files remain unchanged. Documentation tests updated.

## Validation and release

36 relevant frontend tests passed; changed-file ESLint and production build passed.
Production source was copied from findez-fusion-022-20261115 and only these link
changes applied, preserving unrelated server changes. Source hashes guarded release
activation. Shared assets were hardlinked; no ZIP contents changed.

Self-hosted systemd service `findez-web` now runs
`/home/ubuntu/findez-cad-downloads-20261115/frontend`.
Build ID: `Ww02Ynbf3xjbiMtPfxzEg`.
Previous service configuration retained for rollback. No Vercel or Render deployment.

Live HTML verified two current ZIP links on /cad-intelligence and three on /docs/cad.
Live ZIP downloaded and manifest version 0.2.2 checked. SHA-256:
`f20487ebcd475411161a37d5136944db6f11e6bf323c2ce8d799673bd622ac99`.
Signed-in link changes verified in source and tests; no authenticated UI session run.
No backend, database, mobile or add-in binary changes. Native Fusion acceptance
remains pending from the previous release. No remote git push to avoid external
preview automation under the user's self-hosted-only instruction.
