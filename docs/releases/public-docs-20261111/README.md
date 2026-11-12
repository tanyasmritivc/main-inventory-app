# Public documentation refresh, November 11, 2026

Scope: Privacy Policy, Terms of Service and public API guide content. No backend,
database, permissions, provider configuration, mobile binary or API schema changes.

## Verified behavior reflected in the copy

- Amazon CSV/ZIP imports are explicitly initiated by the user. Preview uploads
  the file, save stores allowlisted purchase fields, and raw exports are not
  retained as stored files. Addresses and payment fields are excluded from saved
  purchase records. Imports do not update physical stock.
- Personal records and organization-owned records have separate access scopes.
  Organization connection records require owner/admin access. Selecting another
  scope does not transfer personal records.
- Optional provider authorization and legacy Gmail purchase updates are distinct
  from file imports. Gmail has read-only scope, encrypted credentials/message text,
  a 90-day initial query, and separate disconnect versus deletion controls.
- Fusion exports metadata locally. BOM preview/comparison uploads metadata or the
  spreadsheet to the signed-in, inventory-authorized endpoints. These endpoints
  do not persist CAD projects/results, upload geometry, reserve stock or buy parts.
- The desktop app loads the hosted web service with a persistent application
  profile and requires internet. Exported files remain separate from account data.
- Public integration keys do not enable the internal commerce/CAD contracts.
  The existing OpenAPI JSON is unchanged. API guide links explain actual UI setup.

Evidence: deployed backend at /home/ubuntu/findez/backend, specifically CAD routes,
commerce routes/repository/importer/purchase intelligence, Gmail and token encryption
services; deployed frontend Connections/CAD controls; desktop/src/main.cjs and
README in the desktop worktree. No credentials or customer records were accessed.

The deployed legal/API pages were newer than this branch. The legal source retains
all November 7 disclosures. The deployment payload applies the new API prose to
the newer production base, preserving its appearance control, key verification
section and existing links. It does not replace those with the older branch page.
Prior production SHA-256:
- legal-content.ts: 5f015c208fedef1c6632896fe94bc440a2b43f6877c05e647692a7cd1e2799b9
- api-docs.tsx: 3591ea4f66e389dab56b1ef6e7f872245f7c5d765bf8e5c3d205741f78c6ca82

## Validation

25 targeted tests pass across legal pages, cookie notice, API rendering/navigation,
API example syntax, and signup acknowledgment/version. Fixed the signup test's
missing matchMedia stub for its existing theme-aware layout. Changed-file ESLint
passes. No live accounts were created or modified.

This is a product-behavior documentation update, not a certification of legal
compliance. Existing consumer rights, dispute terms, AI limitations and privacy
rights remain in place. We did not add new data-use rights or model-training
permissions. Privacy representations were checked against implementation, consistent
with [FTC privacy guidance](https://www.ftc.gov/business-guidance/privacy-security).

## Deployment

Deployed only the two content modules directly to the active self-hosted
findez-cad-immediate-20261111 release. Production build
`9B4zBugQdeRc9W4i195a8` passed. No Vercel/Render deployment or local preview.
Source manifests confirm only legal-content.ts and api-docs.tsx changed.
/privacy, /terms, /docs/api, /docs/api/openapi.json, /docs/cad and /desktop return
200. /settings/connections and /cad correctly redirect unsigned visitors (307).
Both effective dates are November 11, 2026; the existing API key-verification
section remains present. OpenAPI SHA-256 remains
96633c0344d8e293724de28272df0d20f074d9e05b9581de096f80776cb1dbba.
