# Active work

Update this file when work starts, changes owner, becomes blocked, or lands. Do not
list ideas as active work.

## Verified active work

| Work | Area | State | Dependencies and handoff |
|---|---|---|---|
| Interior v2 complete mobile rebuild | `backend/`, `mobile/` | Active on `mobile/interior-v2-full-rebuild` | Wave 1 and Wave 2 are merged. Backend B1, B2, B3, B5 and B4 precede the remaining screen waves. No backend migration is deployed from this branch. |

## Open release gates

| Work | Required proof before deployment |
|---|---|
| Workspace migrations 036, 037 and 038 | These migrations have never been executed against a database. Do not deploy them until the Phase 1 acceptance test passes: two accounts in one workspace see the same objects, and a third account in another workspace sees none, proven by direct SELECT with each user's own token. The backend uses the service-role client and bypasses RLS, so an API-level test does not prove these policies. Local Docker is corrupted and could not start PostgreSQL. |
| Wave 3 object and photo acceptance | The object sheet has simulator fixture screenshots in both themes. A real workspace item, persisted crop and source frame, relationship, history, and paper flow still need a live check after the workspace migrations pass. |
| Wave 4 capture acceptance | Photo, Scan and See have light and dark simulator screenshots, and the signed preview was installed on an iPhone. Verify camera permission denied, live viewfinder, Photo save and Scan save on the device. The shared workspace barcode route has a focused unit test, but a live same-record save needs the workspace backend and database acceptance above. |
| Wave 5 manual add acceptance | The grouped form and match path have simulator screenshots and unit tests. Verify a live new save and a live matched count update after the workspace backend and database acceptance above. Legacy shared spaces retain their prior add flow until a co-member update route is available. |
| Wave 6 Find acceptance | Find has light and dark simulator screenshots and a test showing two paths and counts for the same object name. Verify real API search results and navigation to Scan and See after the workspace backend and database acceptance above. |

## Known blocked product work

| Work | Blocker |
|---|---|
| Durable Review queue | Source frames and available object crops now survive FIND job cleanup, but unresolved review status and correction events are not durable yet. |
| Hosted MCP access for remote clients | Current MCP transport is local stdio. A hosted Streamable HTTP service and per-user authentication are not implemented. |

## Handoffs

No task-specific handoff is registered in `.agents/HANDOFFS/` as of 2026-09-22.
