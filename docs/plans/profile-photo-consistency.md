# Settings photo consistency and crop adjustment (2026-10-18)

The user's saved Settings photo is the common identity image. Organization,
workspace and inventory People responses now include optional signed avatar URLs
and color from authorized member profiles. Only parent-authorized IDs are read;
raw storage paths and unrelated profile fields are never returned. Missing or
unavailable photos use initials without hiding the roster. Private profile
storage and all inventory-photo permissions remain unchanged. No migration.

Web/mobile People, task assignees/creators, file upload attribution and activity
use saved member photos. Existing roster refresh handles replacements/removal;
the web also refreshes on the existing profile-change event. No public-profile
lookup or inventory access grant is introduced.

Before upload, a circular preview supports dragging, pinch zoom, zoom controls
and Reset. The accepted square is exported at512px as PNG; the same square source
coordinates drive preview/export. Cancel performs no upload. The original
account/late-response guards and profile form drafts remain. Dashboard unchanged.

Validation: 1,032 Python tests plus 10 subtests. Member tests cover authorized IDs,
foreign/malformed paths, missing photos, signing errors and allowed presentation
fields. Web365 tests/types pass, including pointer pan/pinch, matching export,
explicit acceptance, cancel/failure/retry and replacement/removal. Scoped lint
and actual preserved-runtime build/types/route smoke pass. Native 651 tests,
coverage/analysis and the separately enabled production-config gate pass. Crop
pixel checks, touch gestures, Settings replacement/removal, People and task refresh
pass in both themes. All five CI gates pass for final API `65c90d4`/web `bee5088`/
mobile `79b9abe`. Preserved-runtime unrelated fixture failures are documented in
chat-item-actions.md; no unrelated product changes were made.

The user approved "Apply 057 and publish build 91." Migration 057 and combined
backend/web fixes are live. Apple validated and acknowledged signed 1.0.8 (91),
delivery c6cab1f6-1254-4395-87f7-9e449ad60d18. Build90 artifacts remain preserved, and 91 includes 90's
96b00d3 terms/config source fixes. No customer QA writes. Processing/tester
availability and physical-device acceptance remain unverified; no Apple polling
or public App Store submission. See CURRENT_STATE.md for receipts and hashes.
