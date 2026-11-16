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

Version 1.1.4 (223); branch feat/organisation-spaces-mobile. Initial archive failed
for lack of disk; safe compiler-cache cleanup and rebuild are in progress.
No upload acknowledged yet. Preserve the public App Store submission. No push
because the standing user instruction prohibits Vercel previews.

What to Test: New World button at the top: your spaces as a pixel art world.
Follow Bolt's tour, add an item, finish a quest, play Count it, and try room styles
in Build. Rotate to landscape too.
