# Active work

Update this file when work starts, changes owner, becomes blocked, or lands. Do not
list ideas as active work. Use task IDs from `TASKS.md` and verify worktree state
before changing an existing lane.

## Active lanes

| Task ID | Agent | Worktree or branch | Status | Dependency | Files or area | Handoff |
|---|---|---|---|---|---|---|
| MOB-002 | Unrecorded | `mobile/flutter-uiscene-migration` at `30d5a5e`, plus uncommitted changes | In progress, release status unknown | Signed iOS build and physical launch checks | `mobile/ios/Podfile`, `mobile/ios/Podfile.lock`, Xcode project, `AppDelegate.swift` | None registered |
| INFRA-002 | Codex (implementation), Claude (review, fixes, backup, schema check, alignment, smoke test) | Production `/home/ubuntu/findez` at `main` `f392c45`; `findez` restarted 2026-09-24 03:01:46 UTC | Deployed; Space-invite smoke test passed (one `sent` row; waiting on owner's inbox confirmation) | Separate approvals for removing the stale untracked `014_transactional_email.sql`, redeploying `delete-user`, and the grant-revoke migration | Backend email routes, services, sharing, migration, `delete-user` source | `.agents/HANDOFFS/INFRA-002.md` |

## Blocked lanes

| Task ID | Agent | Worktree or branch | Status | Dependency | Files or area | Handoff |
|---|---|---|---|---|---|---|
| FIND-001 | Unassigned | None | Blocked | Durable source images, crops or geometry, evidence, review status, correction events, and retention policy | FIND persistence, mobile review, web review | None registered |
| INFRA-004 | Unassigned | None | Blocked | Hosted Streamable HTTP transport and per-user authentication | `integrations/findez-mcp`, integration API, hosting | None registered |

## Handoff registration

When a handoff exists, replace `None registered` with its repository path. Remove a
lane after it has landed and its material result is reflected in `CURRENT_STATE.md`,
`DECISIONS.md`, or `TASKS.md` as appropriate.
