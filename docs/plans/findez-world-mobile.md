# FindEZ World mobile

Adds an Ask-header World entry and full-screen WebView at
https://www.findez.ai/world?embed=1 using the existing webview_flutter dependency.
Navigation is restricted to HTTPS www.findez.ai World paths; other web/mail links
open externally. Only the exact /world?embed=1 main page receives the existing
Supabase session through window.postMessage after FindEZApp ready and on refresh.
The bridge rechecks URL, account and view generation before sending credentials.
Account changes, errors and timeout show a bounded retry/close state.

The screen uses platform-default audio/scale, safe-area close control and keyboard
insets. World allows portrait and both landscapes; app startup and close prefer
portrait. Closing calls the existing inventory reload/revision mechanism. No new
backend, inventory/auth provider, dependency, or Info.plist edits in this lane.

## Validation

- flutter analyze --no-pub: clean.
- flutter test --no-pub --reporter failures-only: 1,398 passed, one existing skip.
- New bridge tests cover trusted URLs, ready/refresh handoff, account changes,
  offline timeout/retry, keyboard insets, and orientation restoration.
- Existing large-text header tests exposed and verified the responsive entry fix.
- Four stale organization-removal assertions now reflect the existing delete-only
  behavior. No resource-removal implementation change was made.
- Safari live checks: existing selected-account Spaces, Saved layout, tour Skip,
  Add item form and 390x900 portrait rendering. No item was created/moved/deleted.
- Native signed-in, portrait/landscape keyboard, create/return, offline, and
  physical-device acceptance and requested simulator screenshots remain pending.

## Delivery

Apple Transporter acknowledged delivery of **1.1.5 (223)** on November 15, 2026
at 22:30 Pacific. Final package source `c04427c4`; World implementation commit
`699bddc6` (message `FindEZ World screen`), branch `feat/organisation-spaces-mobile`.
No push: the standing user instruction prohibits Vercel previews.

The first signed 1.1.4 (223) passed local checks but Apple rejected its closed
release train (90186/90062). The next marketing version was rebuilt and verified:
33 iOS device executables in archive and export, strict signatures, 27 privacy
manifests, production defines, bundle ID, app/share-extension versions and anon
Supabase configuration. Final IPA SHA-256:
`b46549b9c27fbb62ff4183f9bd7464ba379c050e978ba1057d9d2374385cf02e`.
Apple delivery passed. Processing was pending at acknowledgment; tester
availability and native acceptance remain unverified. No App Store submission.

The exact testing note is prepared below. API lookups for note publication had no build
record yet, so the note is not published. No processing/group-availability poll.
Receipt: [findez-world-mobile-release.json](findez-world-mobile-release.json).

`git diff --name-only` after committing runtime/version changes was empty.
Changed implementation files, including new files, were:

- mobile/lib/features/world/findez_world_page.dart
- mobile/lib/features/world/world_shell.dart
- mobile/lib/main.dart
- mobile/pubspec.yaml (version only)
- mobile/test/findez_world_page_test.dart
- mobile/test/workspace_deletion_test.dart (stale expectations only)

Shared state, decisions and these release records also changed. No other runtime
files changed in this mobile lane. Full native simulator screenshots/checks listed
above remain unfulfilled; browser responsiveness and host mocks are not substitutes.

What to Test: New World button at the top: your spaces as a pixel art world.
Follow Bolt's tour, add an item, finish a quest, play Count it, and try room styles
in Build. Rotate to landscape too.
