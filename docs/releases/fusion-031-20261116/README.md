# Fusion design questions, 0.3.1

Published November 15, 2026 local time (November 16 UTC).

IMG_3575.DNG shows a connected workspace and the question "do i have the parts
required to make this" followed by a generic failure. Production request status
was503. Synthetic reproduction with the live gateway returned empty terms;
SearchPlan required at least one term and incorrectly classified this as an AI
service failure. The separate existing /fusion/compare request returned200.

The planner now distinguishes parts, compare_design, and clarify. Empty terms
produce clarification, not503. Design questions return a read-only comparison
intent. In add-in0.3.1, the main-thread result handler extracts the actual open
assembly metadata and calls the existing scoped comparison. The panel opens its
BOM view. No geometry goes to the AI and it never invents an assembly. Active
design switches or disconnected generations stop the follow-up. Existing0.3.0
clients receive a compatible response directing them to the BOM tab. Search
HTTP failures now offer keyword/BOM fallback without echoing raw error details.

Validation:1288 backend tests,702 web tests, TypeScript, scoped lint and final
production webpack build passed. Synthetic live checks classify the exact photo
question as compare_design and "Find12 M4 screws" (with normal spacing in the
actual test) as parts. Regression coverage includes empty terms, unknown intents,
real-snapshot dispatch via native mocks, design switches, disconnects, BOM-view
transition, clarification and safe HTTP errors. Native Windows acceptance of
this new dispatch remains pending.

Self-hosted backend: one module app/services/cad/search.py replaced with a
hash guard, prior copy retained in the release. No schema, stock or auth-policy
change. Web source based on active findez-world-json-20261116, preserving all
concurrent World work and package/config files. Six runtime modules changed,
including documentation copy and all eight download link versions. Public CAD
marketing changes only the two download hrefs. No mobile change or Vercel/Render
deployment. No git push to avoid preview automation.

Final release: /home/ubuntu/findez-fusion-031-20261116/frontend
Build: zFGmuu-B_leD5f-oRposv
Previous: /home/ubuntu/findez-world-json-20261116/frontend
ZIP: https://findez.ai/downloads/findez-fusion-workspace.zip?v=0.3.1
SHA256: bba16d75a4fcd181261f0a9d0bd428a04eb85024442e56add7b8cdcfa388f5e0

The first build failed ENOSPC. Only disposable compiler caches and this task's
never-activated initial0.3.0 build output were removed. Cold retry passed before
activation. Production was unchanged during the failed build. Local Mac disk
space also required clearing this checkout's disposable compiler cache.

Live checks: backend health, unauthenticated search401, docs/API health, exact
ZIP hash/manifest/native handler, documentation0.3.1 links, deployed backend hash,
and preservation of all unrelated production source/config passed.

Rollback: verify no newer release; restore previous-search.py to the backend
module and restart findez. Restore previous-service.conf to the effective drop-in
recorded in activation.json, daemon-reload/restart findez-web. Verify backend
health and /docs/cad. No schema rollback. The release contains both backups.
