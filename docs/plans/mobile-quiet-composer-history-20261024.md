# Quiet composer and history typography

Mobile-only follow-up to beta119, based on the supplied FindEZ/Lovable screenshots.

- History uses the existing native toolbar control in plain mode: a 18pt clock
  inside its 44pt hit area, without the glass circle. Other platforms use a plain
  18pt Cupertino clock.
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

Full Flutter suite: 826 passed, one optional skip; analysis clean. Final focused controls/history/voice/composer checks: 19 passed. Native iOS26.5
simulator verified Default dark history, search/filter/clear, Larger light history
with wrapped titles, and composer/header presentation. Physical-device appearance
and voice acceptance remain pending. Signed production build120 passed verification of 32 device executables in both
archive and export, strict code signing, 24 privacy manifests and production HTTPS
configuration. All five CI jobs passed on e70bdc43b397cc9b9cb3f1ee669ba90c4dc3f85f
(run40068444703). Apple validation and upload succeeded.

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

## Delivery receipt

Build120 acknowledged by Apple: `71ce9f9d-276c-4610-8897-690b2b3b208c`.
Runtime `e70bdc43b397cc9b9cb3f1ee669ba90c4dc3f85f`; PR185; CI40068444703 passed all five jobs.
IPA SHA-256: `01da9c7d41f5cb2d3465da13adec8300cd6aa13a8343ae69af1de50fce036cfe`.
Archive, IPA and receipts preserved privately under
`~/Documents/FindEZ/AppStore/1.1.1-build120`.
The existing unused LaunchImage placeholder emits Flutter's advisory; the
production launch storyboard is unchanged. Processing/tester availability were
not polled. No public App Store submission. Physical iPhone acceptance pending.
