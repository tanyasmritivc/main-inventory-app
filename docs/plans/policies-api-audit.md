# Terms, privacy and integration API audit — November 1, 2026

Updated the public policies and integration reference against deployed behavior. Terms and privacy retain existing consumer protections and disclose voice transcription, default personalization, integration/member data, action receipts and human deletion confirmation. No new data-use permission or model-training consent is introduced.

The API guide and generated OpenAPI/Actions/desktop connector annotations distinguish workspace, organization-bound and legacy all-owned keys, current content permissions, duplicate Space-name handling, private photo access and string-form management errors. Added a named-organization key example and organization navigation. No backend behavior or production schema changes.

Source baseline: 305e3e0 already matches the deployed 20-operation OpenAPI contract and both API guide components. The newer legal copy was recovered from the actual hero-descender-20261101 release; newer voice/personalization disclosures are preserved. Publication must overlay only the reviewed files on that live release, preserving the homepage, latest logo, fonts, app and server configuration.

Validation completed before publication:
- 108 focused tests against a private copy of the actual live backend source.
- 1,145 full backend tests and 10 subtests; final generator contract changes pass 43 documentation tests.
- 509 PostgreSQL permission/behavior assertions, including write-only keys, cross-account boundaries, imports, queries, organization management and reviewed deletion, using a disposable local PostgreSQL 17 instance. Missing historical migration files were supplied from the committed contract baseline. No production SQL or migrations executed.
- Concurrent action retries produce one receipt; concurrent deletion produces one effect; a key-revocation race is denied.
- 24 real HTTPS checks with the dedicated review account: service/database health, issuance, authenticated inventory/query/directory/member reads, invalid request and insufficient-scope denials, revocation and rejection of the revoked key. An empty synthetic organization was created solely for these checks and removed; no inventory records or existing membership data were changed. Details: policies-api-live-check.json.
- 473 web tests (472 initially passed; the remaining signup assertion was updated for the new Terms date and its 11-test suite passed), 36 connector tests and the standalone packaged-extension test. Lint has no errors and 51 pre-existing warnings. Build/type and release receipts are recorded separately when complete.

Limits: production integration writes/deletion were intentionally not exercised on customer inventory; their route/SQL/permission/concurrency behavior was tested with isolated fixtures. Empty-organization live reads prove the authenticated production path, not the accuracy of populated customer inventory. A generated contract and tests are not a guarantee of future availability or legal compliance.

Privacy drafting reference: https://www.ftc.gov/business-guidance/privacy-security — describe actual practices and honor privacy promises. Mandatory rights remain conditional on applicable law; no new compliance certification or retention guarantee was added.

Publication completed: 27def05, PR293, CI41400739188 all five jobs green. Local webpack/type checks and isolated server build pass; 38 staged/live routes and public apex/www updated content pass. Chrome reviewed all three staged pages and the published API guide. Production source/configuration and backend PID preserved. See policies-api-receipt.json.
