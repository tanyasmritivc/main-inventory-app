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

Final checks: 1,232 full-suite tests passed with one existing skip, plus the
separately added rapid add-menu reversal test. All 12 final native iOS simulator
checks passed, including UIKit preference reads and cancelled/completed edge-back.
Dark/light pending and scrolled screens reviewed. Build161 delivery pending.
Physical smoothness is unverified.
No web, backend, permissions, data contracts or customer data changes.
