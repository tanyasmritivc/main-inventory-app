# Fusion 0.5.1 purchase-plan error guidance

IMG_3652.DNG shows 0.5.0 Purchases with no listed plans and a generic conflict
message after choosing a saved BOM. The native client mapped every purchase HTTP
409 to stale plan/expired quote/action unavailable, masking valid creation guards.
The photo cannot establish which actual guard rejected this user's saved BOM.

0.5.1 recognizes a bounded allowlist of public purchase domain errors and provides
specific recovery: no shortages (covered or fabricated parts), incomplete/review
rows (compare, resolve, save/select new version), and existing active plan (load
existing plans). Quote, approval-role and receipt conflicts also retain relevant
guidance. Unknown bodies, nested validation input, HTML, oversized responses and
internal exceptions are never echoed. HTTP status and pending-request safety are
preserved. No purchasing rules, inventory data, API code or schema are changed.

All current documentation, installation help and download query versions are
0.5.1. Public CAD landing changes only its two download URLs. User must stop the
add-in, replace the complete folder, and restart Fusion to load the new client.

Validation: 108 affected backend/client/package checks and 21 web/palette/docs
checks passed. Two further actual backend-guard-to-client regressions passed in
the 7-test native suite. Scoped lint and production webpack/TypeScript build passed.
Build: FoZpM-svEnZxt13XRAK-k.
ZIP SHA-256: 84f4d50f2481eb878881d0264aaf8e092bb63683808efd7bfa22873f0d545773

Candidate /home/ubuntu/findez-fusion-051-20261117/frontend was copied from the then
active /home/ubuntu/findez-profile-card-20261117/frontend. Five enumerated files
changed; guards preserve all unrelated profile and other concurrent web work.
Backend and database untouched. Existing deployment approval covers this bug fix.
No push or other hosting deployment. deploy.py includes runtime rollback to the
previous web directory and retains old static chunks for existing browser tabs.
Native Windows acceptance of the corrected message requires the user to update
and repeat the action; tests are not represented as an actual Fusion run.

Published and live-checked: documentation and ZIP match 0.5.1 and the digest above.
No production inventory changes were performed.
