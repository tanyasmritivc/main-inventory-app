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

Public Ask alignment, 2026-11-08: in progress on production main. Remove inherited
textarea focus chrome inside marketing Ask bars and balance text/button alignment.
Preserve existing Enter/Send authentication and suggestion-demo behavior.

Marketing Ask submission, 2026-11-08: deployed from main commit `bfe9a707` in
`ask-submit-20261108`. Typing/paste stays on-page; nonempty Enter/Send opens signup.
Production build and 13 route checks passed. Live Safari checks confirmed typing,
paste, empty Enter, Shift+Enter, suggestion demos, Enter redirect, and Send redirect.
One shared public component changed; 531 other source/public files were preserved.

Solutions hero entrance, 2026-11-08: deployed from production web main, commit
`70ed1745`. The four detail heroes fade in their first rendered scene and stagger
the heading/control entrance, reserve dynamic-load space, and honor reduced motion.
Self-hosted release: `solutions-entrance-20261108`; production build and 13 route
checks passed. All 529 other source/public files and 93 existing font faces were
preserved. Build-only font cache reused live fonts after a Google font loader
failure; temporary build output used memory and the final artifact is on disk.
Production disk remains low (about 480 MB free); old releases were not deleted.

No task-specific handoff is registered in `.agents/HANDOFFS/` as of 2026-09-22.
