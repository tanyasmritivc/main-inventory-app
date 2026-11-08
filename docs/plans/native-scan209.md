# iOS scan presentation and navigation timing — build 209

The Ask/Spaces native tab indicator now selects first, with the retained page
following after 220 ms. Rapid retaps, Add, world changes and disposal cancel any
obsolete pending navigation. Reduce Motion/accessibility navigation bypasses
that delay.

Active Auto Extract progress in main chat and Space extraction uses UIKit:
a native scroll view, system labels/spinner/progress indicator, SF Symbols and
native Stop/Steps controls. The original image is displayed with the same region
boxes and evidence. A bounded display copy is sent to UIKit once; the uploaded
photo, extraction API calls, timeouts and resulting crops are unchanged.

Completed drafts keep the existing review/edit/save implementation. Space
binding and cancellation stay owned by their original Flutter controllers.
No backend, web, chat response or extraction-model changes are included.

## Validation

- Full Flutter suite: 1,363 passed, one existing skip. Analyzer: no issues.
- Native UIKit tests: light/dark, normal/2.6x text/compact 320x260, updates,
  complete scroll-content geometry and disposal into the existing review route.
- Manual simulator fixture: native photo and region overlays, Steps expansion,
  appearance switching, Stop callback once and completed-state transition.
- Physical TestFlight scrolling, VoiceOver, real keyboard, actual scan and
  review/edit/save acceptance remain pending. Desktop gesture automation did not
  conclusively prove reaching the footer, so that is not claimed as a device pass.
- This UI-only release did not rerun provider latency benchmarks. Previous live
  response/scan timings are not a promise of constant provider speed.

Apple acknowledged TestFlight 1.1.2 (209), delivery `9282a1de-61c3-4219-ba0e-d9f5b71e820c`.
All five CI jobs passed for runtime `bfa12c13774fb7035b4dc0d56282d9fa9b0bf0b2` (run42535411676).
Processing/tester availability was not polled. See `mobile209-release.json`.
