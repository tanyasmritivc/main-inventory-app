# MOB-004 Phase C Capture architecture

## Objective and status

Phase C makes Capture the production photo-first way to teach FindEZ about the
physical world. Implementation is complete on `mobile/mob-004-phase-b-integrated`
at application commit `39aeb86e83dcd16ab4646fb30d37c873502e55f6`.

The active path is:

`Capture UI -> CaptureController -> CaptureClient -> ApiClient -> existing FIND / barcode / bulk-create APIs`

No backend route, database table, migration, FIND runtime, or language runtime was
changed. FIND remains the server-side perception boundary and its evidence remains
transient.

## Audit decisions

### Keep

- Existing `image_picker` camera/library acquisition and `mobile_scanner` barcode
  and FindEZ QR support.
- The backend FIND pipeline for segmentation, identification, OCR/barcodes,
  measurement, confidence, and multiple objects.
- `ConfirmScanSheet` as the supported editable review surface.
- Existing bulk inventory creation, verified-catalog enrichment, Space selection,
  QR label offers, spreadsheet import, BOM readiness, and Project Kits.
- Existing shell navigation, Phase A design tokens, and inventory refresh callback.

### Modify

- Make Take a photo the dominant action and move barcode/QR, spreadsheet, BOM, and
  Project Kits into a secondary capture-tool hierarchy.
- Show honest coarse stages: preparing, finding objects, reading/identifying, and
  saving. No fabricated percentage is shown.
- Surface real quantities, brand, part number, barcode, OCR, dimensions, partial
  response state, confidence-derived review cues, and multiple results.
- Put FIND/barcode request state, drafts, errors, cancellation, retry eligibility,
  save failures, and partial-save ownership in `CaptureController`.
- Use Dio cancellation for read-only FIND and barcode requests. Retry FIND only
  after explicit user action. Never automatically retry inventory mutations.
- Aggregate same-name, same-Space capture results before bulk creation. After a
  partial save, remove successful drafts so reviewing the remainder cannot repeat
  successful mutations.
- Add live-region semantics, descriptive labels, 44-point or larger primary
  controls, large-text coverage, and reduced-motion handling.

### Rebuild

- Replace the 2,600-line primary Scan widget's network/orchestration ownership with
  a presentation-focused photo-first page.
- Replace the duplicated in-Space upload implementation with the same Capture
  controller/client and partial-save rules.

### Defer

- FIND-001 and any new perception pipeline behavior.
- Durable source photos, crops, masks, geometry, provenance, correction learning,
  and a durable Review queue. Current FIND jobs are deleted after mapping.
- True server-reported percentage progress, background capture jobs, offline capture
  persistence, and cross-device synchronization. Current APIs are synchronous and
  mobile inventory caching remains memory-only.
- General duplicate resolution beyond the supported barcode lookup and backend
  same-name/Same-Space quantity merge.

## Files changed

- `mobile/lib/core/api_client.dart`
- `mobile/lib/features/scan/capture_client.dart`
- `mobile/lib/features/scan/capture_controller.dart`
- `mobile/lib/features/scan/scan_page.dart`
- `mobile/lib/features/scan/upload_photo_flow.dart`
- `mobile/test/capture_controller_test.dart`
- `mobile/test/capture_page_test.dart`

## State, API, and FIND behavior

`CaptureClient` is the mobile boundary for FIND extraction, barcode lookup, image
preparation, and bulk saving. It delegates authenticated transport to the existing
`ApiClient`; those methods now accept Dio cancellation tokens for safe read
cancellation.

`CaptureController` owns the active read request, coarse stage, long-wait state,
error classification, retry source, extraction summary, editable drafts, save
failures, and partial-save reconciliation. The UI owns only image/source selection,
Space selection, rendering, navigation, and dialogs.

The response shape and backend behavior are unchanged. Real transient
`scan_evidence` is rendered where available. Unknown and low-confidence results are
marked for review. The client does not imply that crops or evidence will survive
the session.

Main Capture and in-Space photo capture both use the same controller/client path.
Spreadsheet import, BOM analysis, Project Kits, barcode lookup, FindEZ QR lookup,
manual fallback, review, and QR label offers remain available.

## Cancellation, retry, errors, and partial saves

- Stop cancels active FIND/barcode HTTP reads through Dio and stale generations are
  ignored. Leaving the active Capture destination also cancels analysis.
- A retained photo can be retried only by the user. Barcode association is retained
  across that read-only retry.
- Bulk inventory writes have no automatic retry or cancel-after-submit behavior.
- Successful partial-save entries are removed from controller state. Only failed or
  locally invalid drafts remain for editing and user-controlled resubmission.
- Ambiguous bulk responses produce an explicit check-Memory warning rather than a
  potentially duplicating retry.
- User-facing errors use existing safe API error mapping and do not expose secrets
  or stack traces. Existing results survive extraction failures where possible.

## Validation

- Focused Capture Flutter tests: 12 passed.
- Full Flutter suite, serial to avoid the existing app-links mock race: 59 passed.
- Isolated ASK widget regression: 1 passed.
- `flutter analyze`: no issues.
- Relevant backend FIND, bulk-create, spreadsheet, and robotics scan tests: 23
  passed plus 6 subtests; one dependency deprecation warning.
- iOS simulator build with the existing local development configuration: passed,
  producing `build/ios/iphonesimulator/Runner.app`.
- `git diff --check`: passed.
- No physical-device validation was performed.
- No retired OpenAI runtime code, dependency, configuration, or environment
  variable was introduced.

The default parallel Flutter run exposed the repository's existing app-links mock
channel race when the splash and ASK widget tests overlap. The isolated ASK test and
the complete serial suite both pass.

## Phase B closure status

Disk pressure was relieved only by deleting regenerable Xcode DerivedData. Phase B
automated tests were rerun successfully and the simulator build passes. The oldest
simulator retained the app container but not authentication; it opens at Sign in.
Therefore the authenticated Phase B smoke is still pending and Phase B must not be
called formally closed yet.

## Remaining work and exact next step

MOB-004 Phase D and later phases have not started. Durable Review/FIND evidence work
remains blocked on a persistence design and is not part of this phase.

Exact next step: authenticate the retained iOS simulator and execute the Phase B
two-question continuity, attachment-history, navigation-action, and Stop smoke.
After that closure, review and merge the Phase C commits. Begin Phase D only under
its separately approved scope.
