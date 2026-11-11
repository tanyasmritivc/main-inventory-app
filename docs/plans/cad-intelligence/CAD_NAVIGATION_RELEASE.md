# CAD navigation release — November 10, 2026

CAD Intelligence is available from the web profile menu, Profile and Settings
page and account sidebar, and organization navigation. Inventory-scoped menu
links preserve the selected inventory. Account entry opens an authorized inventory
chooser; organization links retain the organization through sign-in and directory
loading. Stale directory responses and unavailable organizations are rejected.
No backend, database, inventory quantity, mobile, or deployment configuration in
the repository was changed.

## Validation

- Final production-source candidate: 18 tests passed across six CAD/account suites.
- Local final new entry, route and navigation tests: eight passed.
- CAD source and new tests pass ESLint; production webpack and TypeScript build pass.
- The profile regression suite has the same nine failures as the unchanged live
  baseline, compared by failure name. The complete existing web suite is not green;
  this focused navigation release does not claim to fix its historical failures.
- Public HTTPS browser acceptance passed real sign-in, inventory chooser, profile
  menu, Profile and Settings card, account sidebar and organization navigation,
  inventory preservation, existing Connections card and add-in download. No page
  errors. Anonymous organization entry redirects to sign-in with its destination.
- Two marked disposable accounts were removed; no QA inventory items remain.
  No private customer assemblies or inventory were used.

## Publication and preservation

Build `0pox6Msgm8YJ9C1Oeesk9` published at 2026-11-11 06:23:04 UTC.
Active web: `/home/ubuntu/findez-cad-navigation-20261111/candidate-v2/frontend`.
The release was rebased onto the concurrent Settings Connections publication,
preserving 582 unrelated source/resource files. `navigation-overlay.patch` records
shared integration changes against that actual live source. The local branch
predates the live world-navigation helper, so its context-navigation integration
is accompanied by the exact production overlay rather than replacing newer code.
Build retries used real fonts; no mocks or disabled checks were deployed.

Deployment guard verified source hashes, environment parity, test failure parity,
working directory and build output before switching the web service. Backend was
not restarted. Sanitized metadata is in `navigation-receipt.json`.

Rollback: remove only
`/etc/systemd/system/findez-web.service.d/zzzz-cad-navigation.conf`, run systemd
daemon-reload and restart `findez-web`. Prior Settings Connections source remains
at `/home/ubuntu/findez-settings-connections-20261111/frontend`. Do not reset or
pull the production checkout. Recheck service working directory and HTTPS health.

Native Fusion execution remains a separate user acceptance test from the original
preview release.

## Hover styling follow-up

Download links and the native Choose File control now underline on hover and
keyboard focus. Filename status remains plain. Browser computed-style checks
and the production build passed. Published CSS-only build
`FbnIQsJwJlPGjJEf6lzk7`, preserving 590 other files, from
`/home/ubuntu/findez-cad-hover-20261111/candidate-v2/frontend`.
Rollback removes only `zzzzz-cad-hover.conf` from the web systemd overrides and
reloads/restarts the web service to return to the navigation release.
The BOM importer still accepts Fusion JSON only; CSV/XLSX column mapping and
parsing have not been implemented.
