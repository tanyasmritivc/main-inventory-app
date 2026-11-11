## November 11 - Mac download moved into navigation

Download for Mac now sits beside Sign in on desktop and in the small-screen menu;
removed from the hero. Production build and 1440/1120/1024/390px browser checks pass,
including spacing, no overflow and the Mac-only destination. Live placement verified.
Release: /home/ubuntu/findez-desktop-nav-20261111/frontend.

## November 11 — Plans & access moved to footer

Removed from desktop/mobile marketing navigation; available under Product in the footer. Build and live desktop/mobile link checks passed.

## November 11 — Desktop download link on landing

Added the Mac/Windows download link to the first screen. Production build and three responsive browser checks passed. See docs/releases/DESKTOP_LANDING_LINK.md.

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
