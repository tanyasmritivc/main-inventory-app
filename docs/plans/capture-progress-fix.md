# Extraction progress dialog ownership, October 16

## Verified failure and implementation

The in-Space upload flow used showDialog with its default root navigator, then
Navigator.of(context).pop on the nested caller navigator. This could pop the
Space beneath the dialog while leaving Extracting items on top of the already
returned Confirm Items sheet. The screenshot is consistent with this route bug,
not evidence that the backend repeatedly analyzed the same photo.

runWithCaptureProgress now owns a specific DialogRoute on the root navigator.
Its finally block removes that route only, before results/error handling proceeds.
It does not pop the Space or whichever unrelated modal happens to be on top.
Post-request work checks both mounted context and the originating route's current
state, avoiding confirmation on a departed-but-still-mounted Space. Existing
network deadlines (two-minute send/receive), explicit confirmation, uncertain
Review handling and save APIs remain unchanged. No automatic retry or duplicate
extraction is added. Existing shared-Space and barcode fallback uploads reuse
this corrected helper.

## Validation

Four new real Flutter navigation tests exercise nested success into the actual
ConfirmScanSheet, timeout/failure followed by retry, unrelated root-modal
preservation and leaving the source Space before completion. The first attempt
at the departure test exposed that a popped route may remain mounted while its
animation is suspended behind a root modal; current-route checks were added.
Focused tests pass, the full Flutter suite passes 466 tests and analysis is clean.
The signed beta75 delivery receipt will follow.
This stage changes mobile only; reuse the preceding 814 backend/six subtest and
329 web passes, with no repeated regression checks after push/build.

## Release and manual acceptance

TestFlight 74 was acknowledged from 0ebf355, delivery
9106117d-0272-4d90-a140-687db472ee06. It includes the earlier crop fix and Review/
Space notification bells. Beta75 will add this dialog fix; processing is not
polled. No backend/web/schema/production-data change is needed in this stage.
Physical iPhone acceptance, background push display and fresh email verification
remain unverified. Signed IPA/archive/Apple receipts are preserved privately in
Documents/FindEZ/AppStore/1.0.8-build74 and build75.

1. Install beta75. Open an inventory Space, Upload Photo and select a photo.
2. Extraction should appear once and disappear before Confirm Items is usable.
   Check the close-ups, then Cancel; the original Space should remain open.
3. Repeat and explicitly save clear items/uncertain reviews. Refresh the same
   inventory and verify actual saved results without a leftover extraction modal.
4. Interrupt the request with airplane mode; once the existing network timeout
   resolves, an error should replace progress and leave the Space available.
   Reconnect and retry, confirming one extraction request per attempt.
5. Repeat from a shared Space and barcode-label photo fallback. Exercise app
   background/resume and account/context changes with a pending request.

## Files changed in this stage

- mobile/lib/features/scan/capture_progress.dart
- mobile/lib/features/scan/upload_photo_flow.dart
- mobile/test/capture_progress_test.dart
- mobile/pubspec.yaml
- .agents/ACTIVE_WORK.md, .agents/CURRENT_STATE.md, .agents/DECISIONS.md
- TESTING.md
- docs/plans/capture-progress-fix.md
- docs/plans/capture-crop-fix.md (build74 delivery receipt)

Rollback only this mobile helper/caller change if necessary; retain the crop,
notification and authorization fixes. No migration or data rollback exists.
