## October 24 follow-up (candidate build130)

The user rejected the layered shadow and requested Stop. The loader now retains
only the shadow inside the original SVG, dims the backdrop more strongly, removes
text shadows, and uses a compact progress bar. Stop closes immediately, cancels
client transport, and suppresses late results/errors and the confirmation sheet.
Server computation already underway may continue. Existing endpoint and save
contracts are unchanged. Stop also works during the success hold. The final timed
caption reads Still working; the fabricated step counter is removed.
Space options use the existing Flutter popup instead of UIKit on iOS.
The beta129 record below describes the previous delivered version.

# Pip extraction loader

Reference: open `findez-extract-loader.html`, then **B · Pip, no card**.
The HTML and both mascot SVGs came from the supplied findez-pip-extract-loader.zip.

Flutter-only implementation in `mobile/lib/widgets/pip_extract_loader.dart`.
`runWithCaptureProgress` owns the loader route, retains the existing failure/retry
behavior, and shows the returned item count for 600 ms before existing review UI.
Both Space photo upload and Scan photo capture use it. Spreadsheet uploads use a
separate upload/mapping page, not the old “Extracting items” dialog; that page and
chat's inline activity are unchanged.

The current image endpoint returns one complete result, so floating orange seeds
have no labels, the meta line is a timed step counter, and the bar is indeterminate.
Captions follow the requested timing; they are presentation, not server telemetry.
No invented item names or partial counts appear. Flutter approximates CSS drop-shadow
with a blurred SVG silhouette. One BackdropFilter handles the background.

Reduce Motion stops the bob, seed layer, text slide, success pop and progress motion.
The status remains readable and advances without motion. Assets and fonts are bundled;
no new dependency is needed. The bottom navigation and extraction logic are unchanged.

QA entry point (not included by production main):
`flutter run -d <simulator> -t tool/pip_extract_preview.dart`.
This exercises the real Space photo picker and Confirm Items using a delayed,
network-free two-item API fixture. It does not measure GLM latency or accuracy.

Checks: `flutter analyze`; `flutter test --no-pub --concurrency=1`.
Focused tests cover blocked dismissal, zero/singular/plural success counts, 600 ms
hold, final caption, Reduce Motion, 3.2x text on a small display, early teardown,
retry and exact-route cleanup with nested navigation/another modal.

## Verified behavior

Exact runtime commit: `7fa398c1a4f83fa1c4bdecfc4c2e1e8373365ce8`.
CI run 40155086930 passed all five jobs, including clean Flutter analysis and
868 Flutter tests (one optional skip). Thirteen focused loader/capture tests pass.

On iPhone 17 Pro / iOS 26.5 simulator, a native library photo flowed through the
real Space capture UI with a delayed two-item fixture: blur/dim without a card,
bob/seeds/progress, captions ending at “Almost done...”, found-it pose with the
returned count, and the existing Confirm Items sheet. Nothing was saved.
With the real Settings > Accessibility > Motion > Reduce Motion switch on, Pip
and the bar stayed still, chips were absent, and the text stayed readable. The
switch was restored to its original off state. Native iOS uses
`accessibilityFeatures.reduceMotion`, so the loader observes that flag in addition
to `MediaQuery.disableAnimations`. Physical-device acceptance is unverified.

The timed captions are not measured extraction stages. No speed or accuracy claim
is made by this UI-only change. The CSS shadow is approximated by a blurred SVG
silhouette; native SVG rendering may differ slightly from the browser reference.
The current endpoint has no streamed items or progress, so seed chips and an
indeterminate bar intentionally replace the reference's named chips.

## Files changed

- `mobile/lib/widgets/pip_extract_loader.dart`: shared route, handle and animation.
- `mobile/lib/features/scan/capture_progress.dart`, `scan_page.dart`, and
  `upload_photo_flow.dart`: loader wiring and actual returned item count.
- `mobile/assets/mascot/pip.svg`, `pip-found-it.svg`: supplied artwork.
- `mobile/pubspec.yaml`: asset registration and TestFlight build 129.
- `mobile/test/pip_extract_loader_test.dart`, `capture_progress_test.dart`: lifecycle,
  accessibility, success and existing retry/navigation coverage.
- `mobile/tool/pip_extract_preview.dart`: network-free native QA entry point.
- `docs/extract-loader/findez-extract-loader.html`, this README, and
  `.agents/ACTIVE_WORK.md` / `.agents/CURRENT_STATE.md`: reference and delivery record.

## Delivery

Committed and pushed on `feat/pip-extract-loader`; PR #205.
Apple acknowledged version 1.1.1 (129), delivery
`141bf00a-26cc-419d-b983-e6bc4c70ec03`. Processing and tester availability were not
polled. Device acceptance is unverified. No public App Store submission.

The signed archive and export each passed checks for 32 iOS-device executables;
strict signature, 24 privacy manifests, production HTTPS configuration and Apple
validation passed. IPA SHA256:
`620f9e553caa0a2ed6db98e0a998de05cd33832cb8eb5e05e1ecf9a1f6aeae3a`.
Artifacts, both simulator recordings, CI receipt and Apple acknowledgment are in
`~/Documents/FindEZ/AppStore/1.1.1-build129/`.
