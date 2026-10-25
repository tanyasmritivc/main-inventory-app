# Mobile audit - October 24, 2026

Scope: Flutter mobile, based on beta131. No web, API, database or extraction
model changes. Candidate beta132 uses the existing production entry point.

## Reproduced and fixed

- Muted hints failed 4.5:1 contrast on light surfaces and raised dark surfaces.
  Resolve the shared hint token to theme-specific colors; lift dark muted labels.
- A failed Review refresh was invisible when cached items existed. Keep the rows
  and show the public error with a retry action and live-region announcement.
- Back, scrim and sheet dismissal could lose Review edits, including during a
  pending save. Guard dismissal, preserve failed drafts, and require explicit
  discard. The sheet handle uses the same guard. Successful saves still close.
- Large text on short screens could overflow Review's fixed heading. Instructions
  scroll; the heading joins the scrollable content when space is constrained.
  The close button remains available.
- Quantity stepper buttons lacked accessibility labels. They now identify
  Increase/Decrease quantity. Unfinished quantity text is also a protected draft.

Unknown captures still belong to the selected Space's Review section. Nothing
changes extraction, quantity inference, API calls, save destinations or stock
promotion rules. Pip cancellation and the Flutter Space menu remain intact.

## Validation

- Baseline: 879 host tests passed, one optional skip; clean analysis.
- Full post-fix host run: 885 passed, one optional skip. A subsequent seventh
  regression covers unfinished quantity edits. Final focused set: 27 passed.
- Extended iPhone 17 Pro/iOS 26.5 audit: 149 initially passed, one optional skip.
  Twelve failures were stale Flutter-only assertions against UIKit controls.
  The harness now explicitly exercises Flutter account/confirmation fallbacks
  for those assertions; native bottom-tab callbacks are selected on iOS.
  Corrected affected cases and six new regressions passed in focused native runs
  (167 distinct passing native-hosted cases across the runs, one optional skip).
- Actual native accessibility/visual inspection: light and dark Review editor,
  quantity labels, edit/discard/keep-editing, UIKit Settings opening, live native
  appearance changes, and Memory's native confirmation/cancel.
- Utility layout matrix covers notifications, destinations, connections, items,
  spaces, documents, projects and Memory in both themes at 1x, 2x and 3.2x text.
- The broader host/native suites cover documents, onboarding, organization and
  inventory navigation, permissions, restock, notifications, memory, scan/review,
  imported fields, profile, invitations, session recovery, chat, and cancellation.

`tool/mobile_audit_preview.dart` is a guarded debug-only synthetic preview. It
does not use customer records and is never a production build target.

## Limits and delivery

Simulator and synthetic tests do not prove physical camera accuracy, crowded-photo
latency, background APNs, live OAuth or physical-device acceptance. No claim that
every possible mobile bug is eliminated. Exact-runtime CI, signed archive checks
and Apple's upload acknowledgment are recorded in the delivery receipt when done.
