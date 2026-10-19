# Web launch audit - 2026-10-19

Scope: website, public landing, API documentation and downloadable connectors.
No mobile or database changes. The user approved a separate, narrowly scoped API metadata correction, deployed and verified in PR130.

## Baseline

Branch fix/web-launch-audit-20261019 starts from b58d615 and commit b37ab12
captures the actual running website overlays. The running service is
/home/ubuntu/findez-search-icons-20261018/candidate/frontend. Keep unrelated
production source and environment files intact. Imported release regression
fixtures match deployed onboarding, API-key sessions and legal content.

## Findings and fixes in progress

- Public homepage waitlist claimed success without sending or storing the email.
  Replaced with the existing App Store destination. Retired the obsolete /lab
  prototype route with a redirect to the public homepage.
- Capture copy overstated detection and skipped the required review/save step.
  Updated to match actual review and Space selection. Context diagrams and
  location paths are identified as illustrative saved context.
- Signup sent web users to the mobile app in its copy despite web onboarding.
- API-key requests lacked a timeout and trusted revocation/count responses.
  Added 30-second timeout, redirect rejection, uncertain-write guidance and
  validation before claiming revocation or connection success.
- Item create/edit controls had visible labels without programmatic association.
  Connect labels to fields for screen readers and reliable keyboard interaction.
- API connector source/generator dependencies diverged from the deployed public
  reference. Restored released contract sources and regenerated/tested the bundle.
- Documentation clarifies legacy Team IDs versus current workspace terminology,
  organization-key coverage and exclusion of personal inventories.

## Acceptance matrix (in progress; do not treat as completed)

- Public: homepage, responsive layout, navigation, metadata, legal and App Store links.
- Account: sign-in, redirects, onboarding, settings, profile and session isolation.
- Inventory: directory, create Space/item, edit, search, quantities, export/import.
- Capture/review: photo, barcode, manual entry, errors and save boundaries.
- Ask/documents: grounded answers, source links, uploads/notes and isolation.
- Collaboration: invite preview, permissions, sharing links and revoke behavior.
- Integration: key create/read-only/write limits/revoke, MCP handshake/tools,
  ChatGPT Actions schema and downloadable package.
- Security: dependencies, authentication guards, private images, XSS/redirects,
  account/inventory boundaries and production response headers.

## Evidence so far

- npm production dependency audit: zero reported vulnerabilities.
- Initial source tests surfaced baseline/dependency/test drift; these initial
  failures are not counted as product regressions or successful final validation.
- Connector unit suite passed after release-source alignment; packaged MCPB
  launches standalone and passes its protocol/write safety fixture.
- Authorized Safari sign-in succeeded using the user's alternate account.
- Created only Web Launch QA 2026-10-19 inventory
  (11a7ac84-baad-4411-9b5c-8c69d685c198), QA Shelf and a synthetic washer item.
- Desktop empty dashboard, required-name validation, Space creation, item create
  and quantity persistence verified in Safari. More acceptance is pending.

## External launch gates

Previously documented GPU processing transport and infrastructure concerns must
be rechecked and reported separately. This web-only lane does not alter mobile,
provider nonce configuration, GPU ingress or production database permissions.

## Verified October 19

- 51 web suites / 407 tests pass, including failed-save draft retention and labelled item controls.
- Production-configured isolated candidate: TypeScript, scoped ESLint (existing warnings only), webpack production build pass. Candidate remains inactive pending final acceptance.
- 29 connector tests, deterministic bundle check and standalone bundle protocol fixture pass. Live packaged MCP handshake exposes eight tools; connection, list, query, locations and summary succeed. Read-only write rejected.
- Live API: key creation, read/write scope separation, item create and quantity patch, foreign-workspace denial, key-management denial, revocation and revoked-key 401 pass. Temporary keys revoked.
- Safari: directory, isolated inventory/Space creation, manual item required-field validation/create/edit/reopen, Brand/Part persistence, grounded Ask answer/source, document create/reopen/link pass.
- Photo upload of a public workbench asset returned 21 candidates. Explicit save created 16 clear records and queued five uncertain records. Explicit correction/approval moved one review item into inventory. No customer objects used.
- QA sharing: creation, authenticated preview and web invitation landing passed; owner opens the shared inventory without creating another membership. Revocation acceptance pending.
- Public pages, legal pages, downloadable Actions/MCPB, association JSON, security headers, private-image traversal/anonymous denial, founder proxy anonymous denial, API anonymous denial and untrusted CORS exclusion pass.
- API fix separately passed 1,100 tests plus 10 subtests and is deployed; no migration.

## Dependency audit limits

Production web dependency audit reports zero vulnerabilities. Development dependency findings remain in braces and sprintf-js (unpatched upstream advisories GHSA-vfj7-8cjw-p6xm and GHSA-hp3w-g68c-fv3c); MCP packaging has a development-only node-forge advisory GHSA-86w9-cpqp-85rv. Do not apply npm's proposed major-version downgrades as a blind fix. Production connector audit and actual distributed dependency list must be checked separately. These checks are not a proof that no vulnerability exists.
