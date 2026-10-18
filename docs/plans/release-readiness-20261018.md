# FindEZ submission readiness audit - October 18, 2026

## Reviewed fixes

1. API key UI keeps raw credentials and asynchronous actions bound to the signed-in account. Refresh uses current auth; revoked new keys disappear from the one-time display.
2. Expired web sessions offer a direct sign-in recovery path, preserving the destination.
3. Migration 058 restores organization-key writes after the inventory hierarchy rollout, using the existing live key/workspace authorization helper. It permits quantity/text updates to retain an unchanged private photo only within the same currently writable inventory. It does not grant photo downloads or permit arbitrary photo attachment.
4. Invalid cross-inventory or reference writes return a safe actionable 400 rather than a misleading database-unavailable 503.
5. Existing migration 053 and catalog_service.py close public catalog writes and protect verified barcode identities. Live metadata confirmed the gap; user approved and both fixes are now activated. inventory_scope.py already matches its reviewed RPC allowlist in production.
6. API documentation, OpenAPI, Actions and MCP assets describe current workspace/organization terminology, content permission restrictions, private photos and same-inventory moves.
7. Terms/privacy dated October 18 describe private photo access, account memory, setup drafts, invitations, permissions, deletion prerequisites and key responsibilities. The existing unencrypted photo-processing limitation remains disclosed.
8. Mobile signup records the canonical Terms version. The missing compiled release-configuration test is restored to verify production HTTPS hosts and an anonymous, never service-role, client key.

## Verification completed

- Backend: 1,006 tests; connector suites and packaged extension pass.
- Web: 379 tests, TypeScript pass; lint has no errors (existing warnings remain).
- Mobile baseline: all 631 tests and analysis pass. Focused auth/legal and compiled release configuration checks run for the small final change.
- Composed PostgreSQL fixture through migration 056 passes. Both API regressions reproduce before 058 and pass after it, including denied arbitrary private photos and No access.
- 053 and 058 applied twice to an isolated fresh production restore; 87 tables retain their values, private image storage remains private, service-only helpers remain restricted. No customer QA writes.
- Fresh private backup and rehearsal receipt: /home/ubuntu/findez-api-release-20261018-final.

## Approved activation completed

053 and 058 were applied atomically after a fresh full backup. Only catalog_service.py and api_v1.py were deployed after live hash checks. Health/database health pass; all 93 unrelated Python files were preserved. Catalog client writes are closed, service RPC restrictions and API/photo guards are confirmed.
No customer records, memberships, API keys, photo locators, or feature settings
are rewritten. Existing backend and web source files outside the exact overlay
must be preserved. A fresh backup, old function/source copies and preflight
hashes accompany activation. Keep catalog security restrictions on rollback;
forward-fix rather than reopening public writes.

## Limits before Apple submission

Automated and simulator evidence does not prove physical Apple/Google login,
camera/photo picker, APNs background delivery, fresh recovery email links,
offline interruption/relaunch, or multi-account invitation/revocation on the
exact TestFlight build. Public App Store submission remains held. FIND has a
previously documented unencrypted processing hop; preserve its configuration
under the existing user instruction and do not claim full transport encryption.
Production npm audit reports zero known vulnerabilities. Web build repair vendors the existing Geist fonts locally after Google font loading failed; the webpack production build and five landing-page tests pass. The web release is live; all 294 unrelated source/public files were preserved. Eight candidate routes pass. Live privacy UI shows the new date, and the expired-session link opens sign-in with its return destination. Final mobile analysis and 17 focused auth/legal/compiled configuration tests pass. Signed production build 90 is complete; all 31 archive and 31 exported executables are iOS device code and strict archive signatures pass. Apple validation passed and Apple acknowledged upload of 1.0.8 (90), delivery 0541ba2e-4a4f-4757-adf6-fc00405544b7. Processing/tester availability were not polled. No claim that every possible bug is eliminated or that legal compliance
is certified.

Legal references checked: Apple's App Review Guidelines 5.1.1 and account-deletion
reference, and California Attorney General CCPA privacy-notice guidance.
https://developer.apple.com/app-store/review/guidelines/
https://developer.apple.com/support/offering-account-deletion-in-your-app/
https://oag.ca.gov/privacy/ccpa

Live connector deployment check passes: backend/database health, unissued key rejection (401), API/Actions production destinations, and byte-identical tested Desktop package. No customer inventory writes were used for the live smoke check.

## Coverage and final device gate

The full automated suites cover authentication/eligibility, onboarding and setup handoff, workspace/inventory/Space navigation, capture/review/save, item details and photo privacy, search/Ask/streaming, imports/documents, invitations and content permissions, memory, notifications, profile/settings and account/resource deletion. SQL fixtures exercise actual authorization and storage policies; API and widget tests use controlled fixtures. This is not a claim that every flow was exercised manually against production.

Before submitting build 90, finish one clean-install and one upgrade pass on a physical iPhone: email/Apple/Google sign-in and recovery; camera/photo capture through review and save; search/Ask and item photo display; invitation acceptance and access revocation using two accounts; notification delivery; interruption/offline recovery; and in-app deletion with a disposable reviewer account. Confirm reviewer credentials, privacy answers, support/legal URLs and selected build in App Store Connect. Keep production customer records out of acceptance cleanup.

Apple validation of the signed build 90 IPA passed. The Flutter exporter warned about unused placeholder LaunchImage assets; the active native launch storyboard contains the branded FindEZ label and does not reference those assets. No release error was reported.

Review lanes: [web PR115](https://github.com/tanyasmritivc/main-inventory-app/pull/115), [API PR116](https://github.com/tanyasmritivc/main-inventory-app/pull/116), [mobile PR117](https://github.com/tanyasmritivc/main-inventory-app/pull/117).

## Final delivery and dependency audit

Build90 source: 96b00d3. Signed IPA, archive, strict platform verification, Apple validation and upload acknowledgement are preserved in `/Users/tanyasmritivictorcharles/Documents/FindEZ/AppStore/1.0.8-build90`. Apple delivery: `0541ba2e-4a4f-4757-adf6-fc00405544b7`. Public App Store submission is held; processing and tester availability were not checked.

CI exposed a web-branch generator/artifact mismatch and stale locally installed connector dependencies. The web branch now includes the matching documentation generators; 40 API-document tests pass. Connector dependencies were installed from the lockfile, the SDK updated to 1.32.1 and proxy-addr updated to its patched release. Connector tests, bundle reproducibility and standalone writes pass. The rebuilt download was atomically published. Web and connector **production** dependency audits each report zero known vulnerabilities. Two high-severity development-tool findings remain through MCPB/node-forge (GHSA-86w9-cpqp-85rv), with no upstream fix reported; node-forge is not part of the distributed connector runtime. This is not a claim of zero advisories across development tooling.

Upstream advisory references: https://github.com/advisories/GHSA-6qxp-vccf-f47h , https://github.com/advisories/GHSA-jqcg-44mw-7w3h , https://github.com/advisories/GHSA-86w9-cpqp-85rv .
