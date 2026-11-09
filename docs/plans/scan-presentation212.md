# Scan tips and composer motion — build 212

Mobile presentation only, based on released build211. The composer now reveals
and erases placeholder text continuously on display frames, retaining settled
text layout and a soft reveal edge. Focus, drafts, busy/voice state, app lifecycle,
TickerMode and accessibility continue to stop decorative typing.

Active scans rotate ten shared product tips every eight seconds. The first tip
retains the overly-crowded timing notice; subsequent tips cover app switching,
Space destinations, saving as-is, uncounted quantities, natural-language search,
spreadsheet formats, restock thresholds, individual crops and photo clarity.
Tips reserve their tallest text height to prevent control movement. VoiceOver /
accessible-navigation keeps the tip stable. Reduce Motion uses immediate text
replacement, with no crossfade. Background/offscreen tips pause.

The UIKit photograph has a soft white horizontal sweep clipped to the visible
aspect-fit photo and its rounded corners. The sweep is decorative, stops with
Reduce Motion/inactivity/detachment, and does not represent detection geometry.
Existing region overlays, real progress, Steps, Stop, draft/edit/save and request
ownership are preserved. No backend, web, API or extraction processing changes.

## Verification

From mobile, run:

```sh
flutter test test/world_composer_test.dart test/scan_tips_test.dart test/native_scan_progress_test.dart test/extraction_image_test.dart test/chat_question_test.dart
flutter test --coverage --no-pub --concurrency=1
flutter analyze --no-pub
flutter test integration_test/native_scan_progress_test.dart -d IOS_DEVICE
flutter test integration_test/scan_polish_test.dart -d IOS_DEVICE
```

Native scan checks include light/dark, normal/2.6x text and compact keyboard
viewports, actual sweep animation, timed tip rotation, stable content height,
Reduce Motion and platform-view disposal. The composer checks fractional frame
progress, unchanged draft/actions, focus and accessibility. Tip checks cover
stable layout, pause/resume, screen-reader behavior and disposal.

Private evidence: projects/findez-scan212-private. Eight native scan cases and
15 focused Flutter checks passed. Full regression, native composer checks, CI and
signed delivery are in progress. Physical-device visual acceptance remains
unverified. This presentation change does not add new background guarantees or
change provider latency.
