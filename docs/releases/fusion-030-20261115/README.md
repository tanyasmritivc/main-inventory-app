# Fusion AI search and in-project model picker, 0.3.0

Published November 15, 2026 (server UTC November 16).

## Behavior

AI parts search interprets natural language using the existing gateway. Search
retrieves only the connected inventory or public verified catalog and computes
stock from recorded quantities, reservations, and checkouts. The model receives
the question, not inventory records. Missing specifications stay unverified;
results never establish engineering compatibility. Keyword search remains.

The native picker offers current-design components and saved Fusion project
folders. Opaque selections are bound to the active design, part, and inventory.
Confirmed geometry is copied into a new component and positioned with the
existing triad command. Cancellation or insertion failure removes the new copy.
No stock is reserved or consumed. STEP/F3D import remains optional. Manufacturer
model delivery, previews, and the deferred generation API are not connected.
Sign-in still uses the normal browser; search, picking, placement and BOM run
inside the Fusion panel after connection. Native Windows/macOS Fusion acceptance
is still required; mocked native tests do not establish host compatibility.

## Validation

- Backend: 1276 tests passed, 206 existing deprecation warnings.
- Web: 700 tests in 95 suites passed; documentation rerun passed after copy edits.
- TypeScript, scoped ESLint, diff whitespace check passed.
- Native API mocks cover independent geometry copy, project insertion, explicit
  confirmation, failed/cancelled placement rollback, stale handles, and design
  switches. Palette DOM tests cover AI search, source separation and picker.
- Production-configured web build passed on the final current production source.
- Candidate backend imported using installed production dependencies. Synthetic
  live AI query “Find 12 M4 screws” returned structured terms and quantity 12.
- Live backend health and unauthenticated /fusion/search rejection passed.
- Live /docs/cad and /docs/api health passed. Safari renders AI search guidance,
  0.3.0 download links and in-Fusion insertion instructions correctly.
- Public download hash and manifest verified. All eight runtime download links
  use ?v=0.3.0. Seven frontend modules changed; unrelated source/assets preserved.

## Deployment

Self-hosted only, no Vercel or Render deployment. No git push to avoid unrelated
preview automation. No database migration, environment, auth policy, or mobile
change. The public CAD marketing page only changes two download hrefs.

Backend service findez: /home/ubuntu/findez/backend. Three scoped runtime files
changed: app/api/routes/cad_workspace.py, app/services/cad/workspace.py and new
app/services/cad/search.py. Old files were hash-guarded and backed up under
/home/ubuntu/findez-fusion-ai-20261115/backend-rollback. Existing service config
and production environment were retained.

Frontend service findez-web:
/home/ubuntu/findez-fusion-ai-current-20261115/frontend
Build: K_u9iUkv15KtP-_A9IWv8
Previous: /home/ubuntu/findez-world-web-20261116/frontend

A concurrent World deployment invalidated the first built web candidate. Its
activation guard prevented replacing newer source. The CAD patch was reapplied
to that newer production release and rebuilt; all World files and package/config
files are preserved. An initial switch used an older, overridden service drop-in
and failed its version health check, restoring the previous config. The final
switch updates the effective existing World drop-in, preserves its other settings,
and passes health checks. Old static assets remain available for open tabs.

ZIP: https://findez.ai/downloads/findez-fusion-workspace.zip?v=0.3.0
SHA256: 8db8d69281f32a3b873f558496286523cd97957a6f4662992e07afa696ff1eaf

## Rollback

The final release contains previous-service.conf and activation.json. Restore
previous-service.conf to the same effective service drop-in recorded by the
release script, daemon-reload and restart findez-web; verify /docs/cad and
/docs/api. Verify no newer release first. Backend rollback restores the two
backed-up modules, removes the new search.py, restarts findez and checks health.
No schema rollback is needed. The old add-in endpoints remain compatible.
