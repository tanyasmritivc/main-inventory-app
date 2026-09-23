# Prioritized tasks

This list contains work supported by current source or verified deployment notes.
Reprioritize it when production state changes.

## P0 critical

- Replace FIND's public plain-HTTP connection with TLS or a reachable private route,
  then remove `FIND_API_ALLOW_INSECURE_HTTP` from production.
- Reconcile and back up the dirty production VM checkout before returning to normal
  pull-based deploys. Preserve unrelated server work and verify every migration
  before restarting services.
- Complete the documented physical iPhone release gates: Google auth, Apple auth,
  fresh-link password recovery, and background APNs delivery.

## P1 important

- Finish and review the Flutter UIScene lifecycle migration. Validate the signed iOS
  build and record its TestFlight status.
- Persist capture source images and per-object crops or geometry, FIND evidence,
  review status, and user corrections. Define retention and deletion behavior before
  storing training-quality data. Then build the durable Review flow on mobile first
  and mirror it on web.
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

