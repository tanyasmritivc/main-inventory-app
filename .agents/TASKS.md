# Prioritized tasks

This list contains work supported by current source or verified deployment notes.
Task IDs remain stable when priority or ownership changes. Reprioritize when
production state changes, and do not add speculative roadmap items.

## P0 critical

- **INFRA-001**: Replace FIND's public plain-HTTP connection with TLS or a reachable
  private route, then remove `FIND_API_ALLOW_INSECURE_HTTP` from production.
- **INFRA-002**: Review and merge the locally committed transactional-email
  preservation branch, then back up and reconcile the dirty production VM checkout
  before returning to normal pull-based deploys. Verify every migration before
  restarting services.
- **MOB-001**: Complete the documented physical iPhone release gates: Google auth,
  Apple auth, fresh-link password recovery, and background APNs delivery.

## P1 important

- **MOB-002**: Finish and review the Flutter UIScene lifecycle migration. Validate
  the signed iOS build and record its TestFlight status.
- **FIND-001**: Persist capture source images and per-object crops or geometry, FIND
  evidence, review status, and user corrections. Define retention and deletion
  behavior before storing training-quality data. Then build the durable Review flow
  on mobile first and mirror it on web.
- **FIND-002**: Instrument FIND queue and job duration, then reproduce and resolve
  photo scans that time out or remain in a loading state.
- **BILLING-001**: Resolve the duplicate Stripe route families and choose a
  StoreKit-compliant iOS payment path before changing paid access.
- **INFRA-003**: Add encrypted off-machine database and configuration backups and
  test restoration.
- **DOCS-001**: Reconcile stale top-level documentation that still describes retired
  hosting or a mobile-only web product surface.

## P2 later

- **MOB-003**: Add real offline inventory persistence and conflict behavior for poor
  network conditions.
- **DATA-001**: Move low-stock thresholds from device-local preferences to an
  account or shared workspace model if team-wide thresholds are required.
- **INFRA-004**: Build a hosted MCP transport with per-user authorization if remote
  agent clients need FindEZ tools. Keep the existing local stdio connector for
  desktop use.
- **API-001**: Re-test chat streaming without legacy response padding before
  removing it.
