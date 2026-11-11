# Fusion CAD preview production release

User authorization: deploy the preview first, then let the user test the real
workflow. The user is not required to share a private assembly with a developer.

## Release scope

Implementation `f917c4e7` adds the Fusion exporter/download, authenticated `/cad`
page and read-only inventory comparison endpoint. No database migration,
inventory mutation, mobile change, geometry upload or CAD account OAuth is part
of this release. Native Fusion execution remains a user acceptance gate.

Production is composed from the actual live source, not this older branch.
`production-overlay.patch` records the six shared-file integration changes,
including the CAD entry in the newer organization's Tools screen. New CAD files
are copied byte-for-byte from the implementation commit.

## Verification

- The implementation branch previously passed 1,667 backend and 334 frontend
  tests, production build, and synthetic component browser checks.
- All 42 CAD tests pass against the final production-source backend candidate.
- Final staged frontend: 435 passed and 78 failed. The unchanged live baseline:
  425 passed and the same 78 failures. The failure-name comparison found no new
  failures. All three CAD test suites pass. The full web suite is not green.
- Changed CAD source and the Tools entry passed ESLint. The final production
  webpack build, including TypeScript, passed with the real server environment.
  Intermittent Google Fonts loader failures were resolved by retrying with the
  successful candidate's build cache; no fonts, type checks or configuration
  were replaced with mocks. A concurrent build/test artifact scan was rerun with
  `.next` excluded from Jest's module scan; no tests were excluded.
- Real HTTP acceptance uses two marked disposable accounts and one synthetic
  inventory: eight required units, six covered, two missing, 75% coverage.
  Anonymous, malformed and foreign-account requests are denied. The comparison
  preserves the synthetic stock rows unchanged.
- Staged browser acceptance passed real sign-in, explicit upload, comparison,
  shortage CSV and ZIP download, with no page errors. A local transport proxy
  supplied the synthetic multipart file to the real staged API because the
  localhost preview is outside production's allowed CORS origins. Public HTTPS
  acceptance must run without that proxy after switching.

## Preservation and rollback

Server staging: `/home/ubuntu/findez-cad-release-20261111`.
Release guards detected concurrent Gmail and Connections dashboard rollouts and
stopped before changing production. The final candidate includes both, based on
`/home/ubuntu/findez-connect-dashboard-20261111/frontend` and the current backend.
It preserves 164 unrelated backend and 433 unrelated web source/resource files.

The deployment script checks original and candidate hashes, environment parity,
test failure parity and the built artifact before publication. Only the backend
router and new CAD modules are copied into the live backend. The web service
switch uses a separate `zzz-cad.conf` override; the Gmail/commerce overrides and
earlier releases remain intact. No production package or schema change is needed.

Rollback: restore `deployment-backup/router.py` to the live backend router,
remove only the CAD web override, daemon-reload and restart the affected services.
The newly copied CAD modules can remain unregistered. Verify API/database health,
the restored web working directory and existing commerce callbacks. Do not pull
or reset the production checkout. Private environments, credentials and logs stay
on the server; only sanitized results are committed.

## Deployment receipt

Deployed November 11, 2026 at 06:04:24 UTC (November 10, 22:04 Pacific).
Build ID: `LtL_paVYP-cqQal7EwtC1`. Active web:
`/home/ubuntu/findez-cad-release-20261111/candidate-v2/frontend`.
API and database health passed; anonymous CAD access is denied; web `/cad`
redirects anonymous users to sign-in. Both existing commerce callback pages
remain available with their original app-level headers.

Public HTTPS API acceptance passed the synthetic 8/6/2 comparison, malformed
input rejection, cross-account isolation and unchanged QA stock. The public
add-in ZIP returns 200 and contains the expected 7,094-byte package.
Public browser acceptance passed without interception or mocks: email/password
sign-in, JSON selection without premature upload, explicit comparison, correct
75%/8/6/2 results, evidence, shortage CSV and add-in ZIP downloads, and navigation
from the real Tools inventory selector into CAD with the selected inventory
preserved. No browser page errors occurred. The normal first-sign-in welcome
dialog was dismissed through its Get started button. The existing Connections
entry and dashboard card remained visible.

Both marked QA accounts were deleted and their item rows verified absent. The
temporary staging servers were stopped. No customer account, stock, design or
membership was modified. The deployment receipt is `deployment-receipt.json`.

User entry point: sign in at `https://www.findez.ai`, open Tools, select an
inventory, then CAD Intelligence. Download/install the Fusion add-in there,
export the active assembly, and upload the JSON explicitly to compare.
