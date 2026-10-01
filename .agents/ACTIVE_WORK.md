# Active work

Update this file when work starts, changes owner, becomes blocked, or lands. Do not
list ideas as active work.

## Verified active work

| Work | Area | State | Dependencies and handoff |
|---|---|---|---|
| Flutter UIScene lifecycle migration | `mobile/ios` | Local branch `mobile/flutter-uiscene-migration`; commit `30d5a5e` plus uncommitted changes in Podfiles, Xcode project, and `AppDelegate.swift` | Owner and release status are not recorded. Inspect that worktree before editing these files. Run Flutter analysis/tests, an iOS release build, and physical launch checks before release. |
| App Store recovery and item-photo release | `mobile/` and deployed item-photo backend routes | The public `1.0.6 (17)` source was recovered, build 30 was processed in its internal groups, and item-photo build `1.0.7 (31)` finished App Store Connect processing with `VALID` status on 2026-09-29. | Verify build 31 group assignment and install it from TestFlight. On a physical iPhone, check retained FIND photos plus camera/library add and delete against production. Do not mix the Interior v2 rebuild into this lane. |
| Physical-memory home and durable review | `backend/`, `mobile/`, and matching authenticated web review/home behavior | Branch `feat/physical-memory-home-review` in `/private/tmp/findez-physical-memory`, PR #27; migration `036` and backend/web are deployed. Reference-matching Home and the requested previous rounded four-tab pill are available as build 35 in both internal TestFlight groups. Analysis, all 34 Flutter tests, five CI jobs, Apple validation/processing, and native physical install/launch passed. | Preserve the recovered App Store baseline and separate UIScene worktree. TestFlight-app install and physical capture/photo/auth/revocation checklist remain before calling this production-ready. |
| Reference-matching grounded Ask | Mobile Ask presentation and its additive public answer context | Branch `feat/ask-grounded-reference` in `/private/tmp/findez-ask-reference`, PR #28 stacked on #27. Migration `037` and the selectively deployed backend are live. Build 36 is `VALID` and in both internal TestFlight groups; Apple validation and exact archived physical install/launch passed. All 46 Flutter and 292 backend tests, analysis, and PostgreSQL ownership checks pass. | Home and the previous four-tab pill are unchanged. Hands-on TestFlight install, keyboard/voice, source navigation, ambiguous-project and account-switch acceptance remain unverified. This step does not implement the future memory graph, document retrieval, purchase intelligence, or offline system. |

## Ask follow-up in progress

- `feat/ask-fast-photo-questions` in `/private/tmp/findez-ask-reference`, based on
  the completed build 36 lane. The user now requests only photo attachments for identification/ownership
  questions. Scope: mobile Ask and its authorized read-only backend. Keep Home,
  Capture, web, existing inventory mutations, and the restored pill unchanged.
  Do not promise instant image recognition or silently add an attached object.
  The user withdrew the speed request; all unshipped text-speed edits are removed.

## Known blocked product work

| Work | Blocker |
|---|---|
| FIND geometry and training corrections | Unresolved object records, public evidence, review status, uploaded source images, and available crops persist. Masks, geometry, and training-quality correction events still do not persist after FIND job cleanup. |
| Hosted MCP access for remote clients | Current MCP transport is local stdio. A hosted Streamable HTTP service and per-user authentication are not implemented. |

## Handoffs

No task-specific handoff is registered in `.agents/HANDOFFS/` as of 2026-09-22.
