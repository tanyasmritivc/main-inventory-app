# Developer documentation and policies - November 7, 2026

The Developers guide now includes scoped key verification, read-only checks by permission, rotation and revocation verification, safe support details, and links to the policies. The deployed API key-authentication and integration route files are byte-identical to the November 1 audited source; the public 20-operation reference remains current and unchanged.

Privacy and Terms are effective November 7, 2026. They describe current notification preferences, announcement receipts, feed visibility rather than a universal 14-day retention promise, credential handling and revocation limits, and Founders Access without automatic purchase authorization. Existing AI/provider, photo transport, data rights, liability, and human deletion-review disclosures are retained. Drafting follows actual deployed behavior and the FTC privacy-promises guidance at https://www.ftc.gov/business-guidance/privacy-security; this is not a legal compliance certification.

Validation:
- 31 real HTTPS checks with the dedicated review account: credential rejection, issuance, expiry-date validation, user-session/API-key separation, secret-free metadata, authenticated item/query/directory/member reads, write-scope denial, revocation, and rejection after revocation. Also verified notification preferences are available. Temporary key revoked and empty synthetic organization removed. No customer inventory changed. See the sanitized live-check receipt.
- 72 authentication, organization-management and OpenAPI tests pass against the prior isolated audit source; current deployed key-auth and integration routes match that snapshot. No backend behavior or schema changes.
- 38 focused web tests pass, including key creation, confirmation/revocation, copy failures, organization scoping, legal version acknowledgment, docs navigation and example syntax. Updated stale test mocks for account identity and organization discovery.
- Full web suite: 553 pass, 52 fail; unchanged parent ce6d35df: 539 pass, 65 fail. No new failing test names; 13 existing failures fixed. Remaining unrelated regressions are not claimed green.
- Changed runtime files pass ESLint. Production webpack build (including TypeScript) and 14 staged routes pass. Chrome visual review covers all three pages and the new verification anchor. Browser connector could not start due to a missing runtime dependency; Computer Use provided the review.

Production writes and actual expiry after waiting were not exercised by the live smoke. A successful read against an empty audit organization proves authenticated routing, not populated inventory or third-party assistant installation. Full-suite failures remain outside this documentation update.

Publication is a guarded four-file overlay on founders-demo-20261107. The previous release, configuration, 515 unrelated web files, API process, schemas and connector package are preserved. The separate publication receipt records activation.
