# Prioritized tasks

This list contains work supported by current source or verified deployment notes.
Reprioritize it when production state changes.

## P0 critical

- Finish the November 1 core launch gates in
  `HANDOFFS/2026-10-14-launch-readiness.md`: release the tested capture receipt
  candidate, validate real capture -> save -> reopen -> find, measure FIND quality
  and latency, and exercise ambiguous/unknown/recorded-location answers. Image
  similarity is deferred by the user; Shopify stays disabled.
- Before charging, implement account-bound Stripe subscriptions and StoreKit
  purchase/restore with verified provider lifecycle and shared backend
  entitlements. The new five-tier pricing UI is planned copy, not paid access or
  new quota enforcement. Configure products, test failures/refunds/renewals and
  reconcile the legacy one-time billing route before activation.

- Finish physical/filtered release acceptance after the approved Space cache fix.
  On October 4, owner-scoped rename/delete invalidation and six regressions passed
  all 349 backend/API-doc tests; the reviewed file was selectively deployed with
  a private rollback copy. Live QA and build-46 simulator renames now immediately
  retain all five entries. Broader physical acceptance remains outstanding.
- Reconcile and back up the dirty production VM checkout before returning to normal
  pull-based deploys. Preserve unrelated server work and verify every migration
  before restarting services.
- Complete the documented physical iPhone release gates: Google auth, Apple auth,
  fresh-link password recovery, and background APNs delivery.

## P1 important

- FIND transport security follow-up is deferred by the user's explicit October 4
  instruction to preserve the existing connection. Current server-to-FIND HTTP
  is unencrypted, but no URL, allowance, key or proxy changes are authorized.
  Obtain new authorization before starting any TLS/private-route migration;
  do not treat it as active work or a completed security correction.

- Verify production uses the reviewed Next.js security update. This candidate's
  lockfile is already on 16.3.8; do not repeat the stale 16.3.4 -> 16.3.6 source
  task. Preserve VM dependencies/output during any authorized deployment.
- Finish and review the Flutter UIScene lifecycle migration. Validate the signed iOS
  build and record its TestFlight status.
- Define retention and deletion behavior before persisting masks, geometry,
  and training-quality correction events beyond the source/crop images, evidence,
  and Review state now in the release candidate.
- Instrument FIND queue and job duration, then reproduce and resolve photo scans that
  time out or remain in a loading state.
- Resolve the duplicate Stripe route families and choose a StoreKit-compliant iOS
  payment path before changing paid access.
- Add encrypted off-machine database and configuration backups and test restoration.
- Reconcile stale top-level documentation that still describes retired hosting or a
  mobile-only web product surface.

## P2 later

- Add real offline inventory persistence and conflict behavior for poor network
  conditions.
- Move low-stock thresholds from device-local preferences to an account or shared
  workspace model if team-wide thresholds are required.
- Build a hosted MCP transport with per-user authorization if remote agent clients
  need FindEZ tools. Keep the existing local stdio connector for desktop use.
- Re-test chat streaming without legacy response padding before removing it.
