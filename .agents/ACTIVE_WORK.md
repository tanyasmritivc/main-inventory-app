# Active work

Update this file when work starts, changes owner, becomes blocked, or lands. Do not
list ideas as active work.

## Verified active work

| Work | Area | State | Dependencies and handoff |
|---|---|---|---|
| Interior v2 complete mobile rebuild | `backend/`, `mobile/` | Active on `mobile/interior-v2-full-rebuild` | Wave 1 and Wave 2 are merged. Backend B1, B2, B3, B5 and B4 precede the remaining screen waves. No backend migration is deployed from this branch. |

## Known blocked product work

| Work | Blocker |
|---|---|
| Durable Review queue and object gallery | FIND source images, crops or geometry, per-object evidence, status, and correction events are not persisted. FIND jobs are deleted after mapping. |
| Hosted MCP access for remote clients | Current MCP transport is local stdio. A hosted Streamable HTTP service and per-user authentication are not implemented. |

## Handoffs

No task-specific handoff is registered in `.agents/HANDOFFS/` as of 2026-09-22.
