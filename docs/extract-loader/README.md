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
