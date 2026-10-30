# Spaces interaction and navigation motion

Build161 first fixes delayed navigation before access resolution, restores normal
edge-back from Space details, reduces scroll edge blur from 24 to 8 passes per
edge, removes per-frame add-menu animation allocations and animates the add menu
instead of snapping its controller to the end. No skeletons or artificial waits.
That first phase passed 63 focused host checks and 10 native iOS simulator checks.

A separate second phase adds the requested 160ms stationary crossfade shared by
primary tabs and pushed routes. Outgoing subtle dim starts first; incoming blends
on top after a short stagger. Opaque per-tab surfaces prevent stacked text from
showing through. No scaling or automatic translation. Rapid retargeting retains
tab state and permits only destination input. Interactive edge-back uses Flutter's
Cupertino gesture driver rather than a competing timeline.

UIKit exposes Reduce Motion and Prefer Cross-Fade through a read-only channel at
startup and notifies changes/resume. Reduce Motion without explicit Cross-Fade
switches immediately; explicit Cross-Fade permits the non-spatial dissolve.
Native sheets remain UIKit-owned. Apple API reference:
https://developer.apple.com/documentation/uikit/uiaccessibility/preferscrossfadetransitions

Final checks: 1,233 full-suite tests passed with one existing skip, including the
rapid add-menu reversal test. All 12 final native iOS simulator
checks passed, including UIKit preference reads and cancelled/completed edge-back.
Dark/light pending and scrolled screens reviewed; analysis clean. All five CI
gates passed for runtime `0ff52f02acaf8305cbc0c583d5ca39e4b2dfe011`
(run 41016601351). CI caught an opaque ColoredBox obscuring list ink feedback;
the corrected surface uses Material and passed the full local/CI suites.
Apple acknowledged build161 upload, delivery `bc9b127a-7053-4804-b1a5-7465619c5fde`. Processing was not polled; tester availability is pending. See `mobile-navigation-controls-receipt.json`. The source is preserved in
`/Users/tanyasmritivictorcharles/Projects/findez-navigation-controls` after the
temporary checkout lost older files at midnight. Build outside synced Documents
to avoid file-provider metadata on signed frameworks.
Physical smoothness is unverified.
No web, backend, permissions, data contracts or customer data changes.
