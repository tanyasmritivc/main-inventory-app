# Auto Extract review UI, build 184

Based on the exact App Store restore delivered as build 183 (fc47b0d). Runtime changes are limited to the existing photo review card, photo preview layout/cache, progress panel and build number. No backend, extraction prompts/model, API, schema, dependency, web or other app screen changes.

The selected photo stays visible with a plain white sweep, then shrinks into a fixed review header. Real confidence sorts highest first, stable ties keep scan order, and unknown names or identity confidence below 0.5 form the final section. Missing scores use existing review/missing-field flags. Labels never invent scores. Detail values are displayed verbatim. Rows scroll independently with a bottom fade; controls and footer remain reachable on smaller screens and with the keyboard. Initial visible rows fade in 250ms apart; reduced motion removes the sweep and reveal delays. Existing iOS font and theme inheritance are retained.

## Data and behavior

The current response has item identity confidence, notes/brand, crop URLs and review evidence, but no bounding boxes. Items arrive as a completed capture rather than individual incremental events. Accordingly, the no-box/no-incremental-item fallback is used: no fabricated outlines, object tags, waiting rows or checking steps. Only the existing public progress messages are shown; a numeric progress bar appears only for a real checked/total message. Other messages use indeterminate progress.

Sorting operates on a display list and uses the original row index as its durable protocol ID. It never changes the draft, selection or save ordering. The complete existing mutation, edit, quantity, destination, duplicate and save method region matches build 183 after whitespace normalization. Tests verify exact PATCH IDs and POST save payload, source list identity/order and no network request on row highlight.

## Validation

- Full mobile regression suite: 1,275 passed, one existing skip. Final focused checks: 80 passed. Static analysis clean.
- Final native iPhone simulator: all 11 cases passed, including light/dark review, 320pt and 390pt keyboard layouts at 1x/2.6x text, and stop-with-draft preservation checked. Reduced motion and 35-row scrolling covered by widget tests.
- Three real-photo variants through the actual Ask flow: mixed workbench (8 items, 6 unknowns), parts bin (6 items, 1 unknown), obscured objects (7 items, 4 unknowns). Each completed without mutating the returned draft; crop URLs and existing item fields were used. Two initial server timeouts succeeded on retry. Backend unchanged.
- Disposable account and all 24 test images removed; no inventory writes were made.
- Save parity was checked through exact request assertions and unchanged mutation/save code. A separate old/new live-cloud save comparison and physical-device acceptance were not performed; those are not claimed.
- Signed-package verification and Apple upload receipt follow in the delivery record.

## What to Test

Photo scan: your photo stays on screen while it scans. Review shows the most confident items first with returned details, and unknown items last. Check light/dark/System appearance, long lists, selection/edit/quantity, keyboard, stopping and saving to a Space. UI only; scanning and saving use the existing pipeline. The current API supplies no object boxes, so this build uses the supplied no-outline fallback.
