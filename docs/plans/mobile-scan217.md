# Mobile scan and camera polish, build 217

Native UIKit photo-source sheets are shared by Ask and Spaces. iPhone uses a
compact content-sized slide-up sheet with camera, library and cancel actions;
older supported iOS falls back to system medium/large detents. Native sheets
support swipe/outside dismissal and keep their presentation lifecycle token.

During preview scanning, only Back remains in the chat header. Scan cards omit
the review title, use monochrome shimmer and a subtle material edge/background.
The result photo scrolls inside the same list as the extracted items. Bulk
selection supports all rows and unknown rows separately through revisioned draft
updates. More links are quieter. Profile editing has one header. Settings includes
Community with https://discord.gg/vN2qfhMzs.

Chat and preview scanning own independent streams, generations and progress.
Text/voice questions are enabled after the server establishes the scan conversation.
Stopping either request does not cancel the other; reset/dispose cancels both.
Attachments remain unavailable during a scan. This proves client isolation, not a
promise of identical provider latency under every concurrent load.

The native photo camera now detects common linear and 2D barcodes locally. A
separate tap confirms lookup, so incidental labels never hijack a photo. Photo
capture normalizes orientation and retains Photos, cancellation and permissions.
FindEZ item labels resolve to authorized saved items without a duplicate draft.
Public catalog misses stay unknown. Backend deployment has a separate lane and
receipt, with no schema changes.

Validation: full Flutter suite 1,382 passed, one existing skip; additional photo
scroll regression passed in the 84-case final focused suite. Analysis clean.
Backend baseline suite 1,583 passed plus two additional provider fallback cases.
Native simulator checks cover dark/light scan cards and sheets, large scan text,
photo-source selection and outside dismissal. Native compilation passed after
adding iOS 15 compatibility for custom sheet detents. Final release packaging and
Apple receipt are recorded separately. Physical camera focus, real barcode
recognition and latency with simultaneous live requests remain device acceptance.
