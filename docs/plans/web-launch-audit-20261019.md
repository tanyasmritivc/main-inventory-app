# Website launch audit — October 19, 2026

Status: website fixes are deployed and verified. The remaining unencrypted GPU
processing connection prevents an unconditional public-launch security signoff.

Scope: web app, landing page, API documentation, API-key management and downloadable
connectors. Mobile source, binaries and App Store submission were untouched. The
user separately approved the shared API metadata and bounded checkout-query fixes
in PR130. No production database migrations or permission changes were made during this web audit.

## Delivery

- Website: [PR131](https://github.com/tanyasmritivc/main-inventory-app/pull/131),
  runtime commit `54ed135`, deployed to findez.ai and www.findez.ai.
- Shared API fixes: [PR130](https://github.com/tanyasmritivc/main-inventory-app/pull/130),
  metadata implementation `9eb444c`, checkout repair `11f79c9`; both narrow deployments verified healthy.
- Preceding runtime `b7d5a13` passed all five CI gates in
  [run 39332332200](https://github.com/tanyasmritivc/main-inventory-app/actions/runs/39332332200).
  Final compact Review runtime `54ed135` also passed all five gates in
  [run 39333092847](https://github.com/tanyasmritivc/main-inventory-app/actions/runs/39333092847).
- Active website directory: `/home/ubuntu/findez-web-review-compact-20261019/candidate/frontend`.
  The initial releases preserved 259 and 269 unrelated runtime files. The final
  totals refinement preserved 272. All used source-hash guards, isolated builds,
  retained cached chunks, configuration backups and health-checked rollback.
- Private server receipts: `/home/ubuntu/findez-web-launch-20261019`,
  `/home/ubuntu/findez-web-search-20261019`, and
  `/home/ubuntu/findez-web-item-fields-20261019`.

The branch baseline `b37ab12` captures the actual live website overlays on top of
`b58d615`. It is preserved deployed work, not a new feature release. Neither the
production root checkout nor unrelated ongoing work was reset or overwritten.

## Bugs corrected

1. Brand, Part number, Subcategory and Tags were silently discarded by manual
   item request schemas. The approved API correction accepts bounded metadata;
   omitted fields still preserve existing values and blank values can clear them.
2. Failed edits closed their dialog and lost the visible draft. They now retain
   the form and error until a confirmed save. Create/edit labels now identify
   their inputs programmatically.
3. Space searches kept a filtered list after the search was cleared. Local Space
   filtering is now immediate, includes part number/brand and restores all rows
   when cleared. Stale asynchronous global-search responses are ignored.
4. Spreadsheet “View Items” only closed the dialog. It now opens the destination
   Space in the same inventory. Partial failures and malformed import receipts
   no longer claim full success. Interrupted imports explain duplicate risk.
5. CSV export quoted separators but allowed formula-like inventory text. Dangerous
   text prefixes, control characters and full-width variants now receive a literal
   marker. Numeric quantities stay numeric data; quotes/newlines are escaped.
   CSV applications vary, especially after editing and resaving; this is an export
   mitigation, not a guarantee about downstream spreadsheet behavior. See
   [OWASP guidance](https://community.owasp.org/attacks/CSV_Injection).
6. API-key requests lacked a timeout and trusted malformed success responses.
   Added bounded requests, redirect rejection, uncertain-write guidance, and
   validated revocation/connection receipts before showing success.
7. Landing waitlist claimed success without storing or submitting the email.
   Replaced it with the real iPhone destination. Retired the obsolete `/lab`
   prototype with a redirect. Capture copy describes review, destination selection
   and saving; illustrative location/context examples are identified as examples.
8. Signup copy now reflects web onboarding. API docs clarify legacy Team IDs,
   workspace scope, organization-key coverage and personal-inventory exclusions.
   Released MCP/Actions contract sources and downloadable package are synchronized.
9. Capture destination-load failures now surface an error; save progress no longer
   says it is detecting objects again.
10. A further UI pass removed category-button clutter, duplicate headings and
    background loading flicker, made Capture methods and totals visible on small
    screens, improved document/review copy and fixed the large-inventory checkout
    failure under separate approval. Review now uses compact, paginated rows with
    one expandable correction panel instead of full-width expanded cards. See [UI release evidence](web-ui-polish-20261019.md).

## Validation completed

| Area | Evidence and result |
| --- | --- |
| Website regressions | 54 suites / 431 tests passed. |
| API documentation | 40 contract/example tests passed; published schema matches executable models. Test compatibility restored for current FastAPI fields. |
| Approved server fix | 1,103 backend tests plus 10 subtests passed, including metadata create/update/clear/validation, legacy quantity updates and large-inventory checkout queries. |
| Connectors | 29 tests, deterministic bundle check and standalone packaged protocol fixture passed. Eight tools exposed; no deletion tool. |
| Production build | TypeScript, scoped ESLint and webpack production builds passed. Existing lint warnings remain; no lint errors. |
| Live API keys | QA key creation, read/write separation, item create/patch, scope rejection, key-management rejection, revocation and revoked-key 401 passed. |
| Live MCP | Packaged stdio handshake, connection, item listing, locations, workspace summary and aggregate query passed against the live QA workspace. Read-only write returned 403. |
| Published connectors | Production health, API/Actions destinations and exact downloaded Desktop package bytes passed deployment verification. |
| Account/navigation | Authorized Safari login, workspace/personal directory, scoped navigation, Settings drawer/profile, support/legal destinations and API-key status list verified. |
| Inventory | Isolated inventory/Space creation, required-name validation, manual create/edit/reopen, metadata persistence, immediate part-number search and clear-search restoration verified. |
| Capture/Review | Public workbench photo produced 21 candidates. Explicit save created 16 clear records and queued five uncertain records. Explicit correction/approval added one review record. |
| Ask/documents | Ask returned the saved QA washer quantity/location with its source; note creation/reopening and linking to the item passed. |
| Import/export | Two synthetic CSV imports preserved metadata/quantities. Fixed View Items navigation verified after deployment. Final export contained 21 QA rows and escaped the harmless `=1+1` name as text. |
| Sharing | View-only Space link creation, authenticated preview, owner open, shared contents and revocation passed. Revoked URL displayed unavailable and disabled saving the invitation. |
| Responsive UI | Desktop product view and Safari 390px/820px layouts inspected; landing, API keys, connector documentation, import and settings navigation checked. Normal Safari view restored. |
| Public/security | Legal/docs/download/association endpoints, response security headers, private-image path validation/anonymous denial, founder-proxy denial, anonymous API denial and untrusted CORS rejection passed. |

The final runtime CI run succeeded across all five gates.
CI's automated Flutter checks do not constitute a new mobile build or submission.
No mobile source was changed in this branch.

## Cleanup

Only synthetic QA data was written. The QA Space sharing link and both temporary
API keys were revoked and rejection verified. Both named QA inventories and the
connector QA workspace were deleted using exact ID/name guards and deletion
receipts. Original customer workspaces, items and existing API keys were untouched.
The local cleanup receipt is `/private/tmp/findez-web-launch-private/cleanup-receipt.json`.
Account deletion was not exercised against the user's real account.

## Security findings and launch gates

### Owner GPU/infrastructure work — required before public launch

The running API configuration was rechecked without exposing its address or key:
FIND is configured with `http`, the insecure-HTTP override is enabled, and a
credential is present. App-to-API HTTPS does not encrypt this onward connection.
The privacy notice already discloses that photo processing is not encrypted on
all connections; disclosure does not fix the transport exposure.

1. Put FIND behind valid-certificate HTTPS or a private authenticated encrypted
   tunnel. Restrict the inference listener to that proxy/private network and the
   authorized API host, including submit/status/result/image endpoints.
2. Switch the backend FIND URL to the protected endpoint, disable insecure HTTP,
   retain certificate/hostname checks, and rotate the inference credential after
   protecting the path.
3. Retest scan submit/poll/results/private crops/originals/Review/save, failure
   recovery, cleanup, concurrent requests and load. Monitor queue latency, GPU
   memory, error rates and disk/job retention; keep customer content and keys out
   of logs. Verify production API/firewall exposure separately.
4. Investigate inference latency: one direct natural-language search exceeded the
   45-second QA client deadline. Space text search now avoids that inference path;
   this does not establish acceptable global Ask/search performance under load.

No GPU configuration or provider-auth compatibility settings were changed.

### Dependency findings

Both web and MCP production dependency audits reported zero known vulnerabilities.
Development-only findings remain: braces and sprintf-js advisories
[GHSA-vfj7-8cjw-p6xm](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm) and
[GHSA-hp3w-g68c-fv3c](https://github.com/advisories/GHSA-hp3w-g68c-fv3c), plus MCP
packager node-forge [GHSA-86w9-cpqp-85rv](https://github.com/advisories/GHSA-86w9-cpqp-85rv).
No patched versions were identified in the checked audit. The distributed MCP
bundle's dependency notices do not include node-forge. Monitor upstream fixes;
blind major downgrades of Jest/Next lint tooling are not a safe audit remedy.

### Acceptance limits

This was a code, regression, live API and Safari audit, not an exhaustive external
penetration test or a load-test certification. Camera hardware/browser permission
paths, a fresh OAuth/signup cycle, email delivery, paid transactions, every project
BOM/checkout variation, and every browser/device combination were not separately
replayed live. Relevant automated coverage remains part of the suite; paid web
plans explicitly remain coming soon. Claude Desktop/ChatGPT host installation UI
was not exercised with the user's external accounts: packaged MCP and live API
behavior plus the Actions schema/download were verified directly. A final host
acceptance check is appropriate before advertising a particular host/version as
certified. Existing Terms/Privacy content and links were verified; no new legal
compliance certification is implied.
