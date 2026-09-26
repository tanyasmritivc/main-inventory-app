# Active work

Update this file when work starts, changes owner, becomes blocked, or lands. Do not
list ideas as active work.

## Verified active work

| Work | Area | State | Dependencies and handoff |
|---|---|---|---|
| Flutter UIScene lifecycle migration | `mobile/ios` | Local branch `mobile/flutter-uiscene-migration`; commit `30d5a5e` plus uncommitted changes in Podfiles, Xcode project, and `AppDelegate.swift` | Owner and release status are not recorded. Inspect that worktree before editing these files. Run Flutter analysis/tests, an iOS release build, and physical launch checks before release. |

## Known blocked product work

| Work | Blocker |
|---|---|
| Durable Review queue and object gallery | FIND source images, crops or geometry, per-object evidence, status, and correction events are not persisted. FIND jobs are deleted after mapping. |
| Hosted MCP access for remote clients | Current MCP transport is local stdio. A hosted Streamable HTTP service and per-user authentication are not implemented. |

## Handoffs

- MOB-004 Phase B ASK architecture is complete on
  `mobile/mob-004-phase-b-integrated` at `7f3bb1f`; see
  `.agents/HANDOFFS/MOB-004-PHASE-B.md` for validation and the pre-merge smoke test.
