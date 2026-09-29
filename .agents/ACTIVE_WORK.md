# Active work

Update this file when work starts, changes owner, becomes blocked, or lands. Do not
list ideas as active work.

## Verified active work

| Work | Area | State | Dependencies and handoff |
|---|---|---|---|
| Flutter UIScene lifecycle migration | `mobile/ios` | Local branch `mobile/flutter-uiscene-migration`; commit `30d5a5e` plus uncommitted changes in Podfiles, Xcode project, and `AppDelegate.swift` | Owner and release status are not recorded. Inspect that worktree before editing these files. Run Flutter analysis/tests, an iOS release build, and physical launch checks before release. |
| App Store mobile recovery | `mobile/` | Branch `mobile/app-store-recovery` restores the public `1.0.6 (17)` mobile tree from `0bb4f01`, with release metadata `1.0.7+30`. App Store Connect finished processing build 30 and lists it in the internal TestFlight groups. | Verify an install from TestFlight. Do not mix the Interior v2 rebuild into this recovery lane. |
| Item photo gallery | `backend/` item photo API and recovered `mobile/` item/scan flows | Branch `feat/item-image-gallery` in `/private/tmp/findez-item-images`; implementing add, view, and delete photo controls while preserving FIND-captured images. | Based on recovered App Store mobile source. Reuses the existing `item_events` photo records and `items.image_url` thumbnail contract without a database migration. |

## Known blocked product work

| Work | Blocker |
|---|---|
| Durable Review queue and object gallery | FIND source images, crops or geometry, per-object evidence, status, and correction events are not persisted. FIND jobs are deleted after mapping. |
| Hosted MCP access for remote clients | Current MCP transport is local stdio. A hosted Streamable HTTP service and per-user authentication are not implemented. |

## Handoffs

No task-specific handoff is registered in `.agents/HANDOFFS/` as of 2026-09-22.
