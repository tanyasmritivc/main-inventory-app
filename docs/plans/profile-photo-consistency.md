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

Validation: 1,032 Python tests plus10 subtests. Member tests cover authorized IDs,
foreign/malformed paths, missing photos, signing errors and allowed presentation
fields. Web365 tests/types pass, including pointer pan/pinch, matching export,
explicit acceptance, cancel/failure/retry and replacement/removal. Scoped lint
and preserved actual-runtime compilation remain release gates. Native crop pixel
checks, real touch gestures, Settings replacement/removal, People and task refresh
pass in both themes; final complete native/CI and signed build91 are in progress.

Chat action migration057 remains unapproved/unapplied; the combined release is
not activated. Build90 already exists and remains preserved; the new release is91
and includes90's 96b00d3 terms/configuration source fixes. No customer QA writes.
