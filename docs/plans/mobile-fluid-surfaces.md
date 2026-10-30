# Mobile fluid surfaces, October 29

Mobile-only follow-up to TestFlight157, branch `fix/mobile-fluid-surfaces`.
Build158 is pending signed export, CI and upload. Main, web, APIs and database unchanged.

- App-owned Flutter and UIKit text uses regular SF Pro. Top Spaces and More
  headings retain their previous size/weight. Existing text scaling remains.
- Shared diagonal shimmer appears during page/tab arrivals using their existing
  transition time and while page data loads. No timer delays data or responses.
  Reduce Motion skips arrival animation and renders static loading placeholders.
  Opening a Space presents its loading route immediately with error/retry support.
- New-chat chips offer recent-item and low-stock questions, filling a draft for
  review before sending. No stock changes are triggered by a suggestion.
- Lower item-info fields use one surface instead of inherited nested outlines;
  sentence-case labels and consistent spacing preserve all actions and autosaves.
- Space thumbnails sample clean regions of the user's unchanged four-texture
  atlas. A stable UUID hash distributes choices across the four variants, so
  rename, rebuild and another device keep the same appearance. No API metadata.
- Chat and Scan share the compact gray glass photo-source sheet.
- Tap-to-speak shows a centered dimmed recording overlay; actual native microphone
  levels drive its bars. A final transcript submits once. Hold/release, Cancel,
  permission failures and late callback isolation remain covered.
- Conversation content scrolls behind bounded progressive blur at the top/bottom;
  measured control heights preserve first/last message reachability. Extraction
  retains its existing constrained layout for keyboard/accessibility safety.
  Space lists scroll beneath the same header treatment.

Verification covers regular typography, gesture cancellation/final-result
submission, retained drafts, placeholder reduced motion, stable textures,
item writes/dismissal, large text, keyboard and light/dark iOS rendering.
Native camera/microphone acceptance on a physical device remains unverified.

Host validation: 1,222 tests passed with one existing skip; Flutter analysis is clean.
Native component checks cover light/dark recording (including 2.6× text), photo
menus/textures and reduced-motion placeholders (8 cases), plus both item-info
themes (2 cases). Ten Ask layout checks passed with native UIKit controls.
Automated navigation uses the Flutter control fallback because the test driver
cannot tap embedded UIKit views; this is not physical-device acceptance.

Six native navigation/scroll checks pass with those fallback controls. The
conversation test now checks an empty usable composer instead of assuming the
rotating placeholder remains on its first frame.
