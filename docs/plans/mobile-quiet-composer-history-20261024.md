# Quiet composer and history typography

Mobile-only follow-up to beta119, based on the supplied FindEZ/Lovable screenshots.

- History uses the existing native toolbar control in plain mode: a 20pt clock
  inside its 44pt hit area, without the glass circle. Other platforms use a plain
  20pt Cupertino clock.
- Composer uses a scoped, flatter frosted surface, 20pt corners, uniform translucent
  cool-neutral fill and a subtle hairline. The old highlight/bevel and shadow are
  removed here without changing shared surfaces. High contrast uses an opaque fill.
- Microphone becomes a plain 21pt glyph while preserving its full tap area, pointer
  lifecycle, release-to-send, cancellation and accessibility action.
- Native history now receives the current app text-size factor on initial load and
  every refresh/error/delete update. UIKit applies OS Dynamic Type once. Titles
  use the app's 15pt body base, dates 13pt, and search/empty states scale consistently.
  Existing sheet presentation, search, selection and deletion confirmation remain.

The current page backgrounds, native Liquid Glass bottom tabs, tab motion and
all backend/web/database behavior are unchanged. The debug-only native fixture
contains synthetic history rows and applies the production appearance scaler.

## Verification

Full Flutter suite: 826 passed, one optional skip; analysis clean. Native visual
audit and production packaging pending. No upload yet.

## Manual acceptance

1. On Ask, check the small plain history clock and flatter composer in light/dark.
2. Open history, search for a chat, clear search and select a saved conversation.
3. Settings > Appearance: try Small, Default, Large and Larger; reopen history
   after each. Titles, dates and search text should follow the preference.
4. Repeat with iOS Larger Text; verify wrapping/scrolling and no double scaling.
5. Type a multi-line draft, open Attach, and hold/release voice to send. Confirm
   release sends once and cancellation does not send. Check the compact composer
   inside a conversation, keyboard open, and source chips.

Physical-device acceptance is separate from synthetic simulator verification.
