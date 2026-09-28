# Active work

Update this file when work starts, changes owner, becomes blocked, or lands. Do not
list ideas as active work.

## Verified active work

| Work | Area | State | Dependencies and handoff |
|---|---|---|---|
| Interior v2 complete mobile rebuild | `backend/`, `mobile/` | Active on `mobile/interior-v2-full-rebuild` | Wave 1 and Wave 2 are merged. The optional first-capture onboarding and signed-in More navigation now work in the simulator. Photo persistence and public Storage URL fixes are separately merged to main and deployed as PRs #21 and #22. No backend migration is deployed from the rebuild branch. |

## Open release gates

| Work | Required proof before deployment |
|---|---|
| Workspace migrations 036, 037 and 038 | These migrations have never been executed against a database. Do not deploy them until the Phase 1 acceptance test passes: two accounts in one workspace see the same objects, and a third account in another workspace sees none, proven by direct SELECT with each user's own token. The backend uses the service-role client and bypasses RLS, so an API-level test does not prove these policies. Local Docker is corrupted and could not start PostgreSQL. |
| Wave 3 object and photo acceptance | A real personal-space multi-object scan returned visible source and crop images. Four objects saved, and More > Places > Cabinet > Object displayed the saved image and item data on the deployed backend. The legacy database has no durable source-frame event, so the object sheet hides that panel when unavailable. Shared-workspace relationships, history, and paper still need live checks after workspace migration acceptance. |
| Wave 4 capture acceptance | Photo, Scan and See have light and dark simulator screenshots, and the signed preview was installed on an iPhone. Verify camera permission denied, live viewfinder, Photo save and Scan save on the device. The shared workspace barcode route has a focused unit test, but a live same-record save needs the workspace backend and database acceptance above. |
| Wave 5 manual add acceptance | The grouped form and match path have simulator screenshots and unit tests. Verify a live new save and a live matched count update after the workspace backend and database acceptance above. Legacy shared spaces retain their prior add flow until a co-member update route is available. |
| Wave 6 Find acceptance | Find has light and dark simulator screenshots and a test showing two paths and counts for the same object name. Verify real API search results and navigation to Scan and See after the workspace backend and database acceptance above. |
| Wave 7 See acceptance | Live See is gated because the backend has no frame inference service and p50 latency could not be measured. The simulator shows an explicit unavailable state and Photo fallback in both themes. Real shelf recognition and a visual camera permission denied check on the connected iPhone remain open. |
| Wave 8 onboarding acceptance | Signed-out users now see account entry first. New accounts can open inventory immediately or choose a first photo, then review and save without a required tour. Light and dark widget tests cover the signup fields. A fresh-account run on a physical phone remains open. |
| Wave 9 your world acceptance | The six screens have light and dark simulator fixture screenshots. More > Places > Cabinet > Object now opens with real data and a saved photo against the deployed backend. Bin, document, label, and shared-workspace data still need live checks. The paged inventory read in `bebbfd4` must deploy with the mobile build to show more than 1,000 objects. |
| Wave 10 remaining screens and states | The ten rebuilt screens have light and dark simulator fixture screenshots. The signed preview is installed separately from TestFlight, but the user reports it does not open for them. Camera permission denial and the native photo picker were checked on the preview before that report. A real offline capture, app kill and reopen, and a fresh-account onboarding run remain unverified. Partial saves now keep unsaved objects in the phone queue. |
| Missing workspace schema acceptance | The signed-in simulator opens personal inventory against the deployed backend without `/workspaces`. Workspace switching is disabled. Home hides unavailable low-stock, kit, and checkout counts; identity review uses the Wave 2 heuristic when `identity_confirmed` is absent. Object detail uses list data if its newer detail route is missing, and hides missing relationships, reorder data, and source frame. Widget tests and a simulator build pass. Migrations 036 to 038 remain undeployed. |
| Interior v2 release audit | All 29 prototype screens have light and dark iPhone simulator screenshots in `mobile/screenshots/interior-v2/README.md`. Flutter analyze and 49 tests pass. The palette contrast test covers used token and surface pairs, with dark `text3` on `s2` the lowest body pair at about 4.53:1. Legacy ancillary screens still contain hardcoded colours and icons, so the requested full interior sweep is incomplete. Physical camera and offline checks and fresh-account onboarding remain open. |

## Known blocked product work

| Work | Blocker |
|---|---|
| Durable Review queue | Source frames and available object crops now survive FIND job cleanup, but unresolved review status and correction events are not durable yet. |
| Hosted MCP access for remote clients | Current MCP transport is local stdio. A hosted Streamable HTTP service and per-user authentication are not implemented. |

## Handoffs

No task-specific handoff is registered in `.agents/HANDOFFS/` as of 2026-09-22.
