## Solution detail section cleanup (November 8, 2026)

Deployed on `fix/solution-page-trim` through the existing self-hosted web release
method. Removed the numbered help section and audience carousel from Robotics,
Workshops, Makerspaces and Engineering Labs detail pages. Preserved the main
Solutions grid, landing carousel and Everyday page. Removed the founder quote
and attribution from the marketing data and renderer. Public source/assets and
built browser bundles have no founder-name matches. Production webpack build and
13 live route checks passed; 524 other source/public files and backend unchanged.
Release: `solution-trim-20261108`, build `m_dwDM1_d29I8SobxXlUp`.
Receipt: `docs/plans/solution-page-trim-release.json`. No unfinished work.

# Active work

Update this file when work starts, changes owner, becomes blocked, or lands. Do not
list ideas as active work.

## Verified active work

| Work | Area | State | Dependencies and handoff |
|---|---|---|---|
| Flutter UIScene lifecycle migration | `mobile/ios` | Local branch `mobile/flutter-uiscene-migration`; commit `30d5a5e` plus uncommitted changes in Podfiles, Xcode project, and `AppDelegate.swift` | Owner and release status are not recorded. Inspect that worktree before editing these files. Run Flutter analysis/tests, an iOS release build, and physical launch checks before release. |
| App Store recovery and item-photo release | `mobile/` and deployed item-photo backend routes | The public `1.0.6 (17)` source was recovered, build 30 was processed in its internal groups, and item-photo build `1.0.7 (31)` finished App Store Connect processing with `VALID` status on 2026-09-29. | Verify build 31 group assignment and install it from TestFlight. On a physical iPhone, check retained FIND photos plus camera/library add and delete against production. Do not mix the Interior v2 rebuild into this lane. |

## Known blocked product work

| Work | Blocker |
|---|---|
| Durable Review queue and object evidence | FIND masks, geometry, unresolved object records, review status, and correction events are not persisted after job cleanup. Uploaded source images and available object crops survive as item photos. |
| Hosted MCP access for remote clients | Current MCP transport is local stdio. A hosted Streamable HTTP service and per-user authentication are not implemented. |

## Handoffs

No task-specific handoff is registered in `.agents/HANDOFFS/` as of 2026-09-22.
