# Native iOS navigation and restored chat background

Build 1.1.1 (116), PR #178, stacked on the mobile fluid-shell release.

The chat background is restored to beta 114: black in dark mode and the original
warm light landing surface. Beta 115's history sheet, settings, Space layout,
manual Space creation, compact menus and release-to-send voice behavior remain.

On iOS the bottom navigation now hosts UIKit's UITabBar, using SF Symbols
and the system material, selected lens, drag motion and tab labels. With the iOS 26
SDK this is native Liquid Glass; older iOS uses its standard system tab appearance.
Flutter retains the page state, scope, navigation and non-iOS fallback. No package,
backend, database or account changes are needed. The existing compact width remains.
The native container reserves 83 points so the system bar fits its touch bounds.

The native bar uses default platform-view gesture arbitration. The app-wide
keyboard-dismiss tap recognizer is enabled only when the software keyboard is
visible; the shell hides bottom tabs in that state. Keeping an always-active
ancestor tap recognizer consumes native tab taps. The runtime audit mirrors this
production wrapper. No private UIKit APIs or custom gesture simulation are used.

## Verification

- Full host suite: 812 passed, one optional skip.
- Flutter analysis: clean (see release receipt for final delivery).
- Native iPhone 17 Pro / iOS 26.5: compiled and ran the actual UIKit view. Verified
  Ask → Spaces → More → Ask with single taps, sliding Ask → More, and live light/
  dark appearance changes with the production-style keyboard-dismiss wrapper using the app UI and observing the Flutter page label.
- Exploratory WidgetTester-driven native touch runs timed out intermittently even
  with forwarded device events. These are not counted as passing native tests.
  Use the normal runtime harness below for native gestures, not WidgetTester.tap.
- Physical iPhone, older iOS appearance, VoiceOver and Reduce Motion acceptance
  remain manual device checks. Simulator evidence does not establish those results.

## Manual verification

1. Run `flutter run -t tool/native_tabs_visual.dart -d <ios-device-id> --no-pub`.
   This debug-only harness uses no APIs or customer data. Tap each tab once and
   verify the large page label matches. Drag the selected lens across tabs.
2. Use Switch appearance and repeat. Ensure the existing selection survives the
   theme change. Production builds must target `lib/main.dart`.
3. In TestFlight 116, check the restored Chat background in both themes; navigate
   Ask / Spaces / More; open and dismiss history and settings. Verify the selected
   tab remains correct after returning from a pushed Space page.
4. Focus the composer and dismiss the keyboard. The bar should hide and return
   without losing selection. Check New space above the bar on an editable scope.
5. On a physical iPhone, repeat with VoiceOver and Reduce Motion, and check the
   system tab labels, focus order and touch targets. Check an older supported iOS
   device for its standard UIKit fallback before public release.

Google and unfinished connectors stay hidden. This is a TestFlight release only.

## Delivery receipt

Apple acknowledged 1.1.1 (116), delivery 2a1a948f-cfde-47a8-9f5e-4f519f5ff8a2.
Runtime `d4ccc0d`; all five CI gates passed (run 40029940276).
Signed archive/export, privacy/device-platform checks and Apple validation passed.
Processing and tester availability were not polled; no public App Store submission.
Earlier candidates were never uploaded.

IPA SHA-256: `c526cd4fe1eda922d4f0eb27f11f0f34bbd4b3bdbe4404f7e28233d054066b53`.
Durable archive, IPA and receipts: `Documents/FindEZ/AppStore/1.1.1-build116`.
Physical-device, VoiceOver, Reduce Motion and older-iOS acceptance remain pending.
