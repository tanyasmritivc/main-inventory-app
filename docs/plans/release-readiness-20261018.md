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
Production npm audit reports zero known vulnerabilities. Web build repair vendors the existing Geist fonts locally after Google font loading failed; candidate validation is in progress. Final mobile analysis and 17 focused auth/legal/compiled configuration tests pass. Build 90 packaging/upload is in progress. No claim that every possible bug is eliminated or that legal compliance
is certified.

Legal references checked: Apple's App Review Guidelines 5.1.1 and account-deletion
reference, and California Attorney General CCPA privacy-notice guidance.
https://developer.apple.com/app-store/review/guidelines/
https://developer.apple.com/support/offering-account-deletion-in-your-app/
https://oag.ca.gov/privacy/ccpa
