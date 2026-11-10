# Mobile surface corrections, build 219

Replace the native organization popover with a bounded Flutter popup menu. It keeps 44pt minimum touch targets, full wrapping labels, selected marks, outside dismissal and the existing organization, Personal, create and invitation actions. Width is bounded to 300pt and height to 55 percent of the viewport with scrolling.

The system tab highlight moves first at UIKit's original speed. Dart waits 300ms before changing the retained page; World tabs do not crossfade overlapping transparent text. Rapid return, Add and disposal cancel pending changes. Reduced-motion preferences still skip the lead delay.

Chat keeps the continuous ambient canvas. Spaces uses plain black in dark mode and white in light mode. Native Settings, Add to chat and chat history use their original system backgrounds. Light scan cards gain a fine outline and soft shadow; shared floating surfaces gain slightly clearer light shadows.

Camera appearance only: remove the oversized panel, use a 70pt shutter, 48pt Photos control, 44pt top close control, short hint and a bottom gradient for contrast. Photo capture, barcode detection, permission handling and lifecycle logic are unchanged. A simulator-only static camera preview is excluded from device binaries. The synthetic Dart target is separate from lib/main.dart.

Validation: full mobile suite 1,383 passed with one existing skip. Final focused menu, tab, retained-page and native scan regressions: 13 passed. Analyzer clean. Native simulator visual checks passed for both menu themes, long names, selection, dismissal, navigation ordering, plain Spaces, native sheets, camera controls and light scan card separation. Camera capture and physical-device acceptance remain pending; no live scan or customer data writes were performed.

Production 1.1.3+219 packaging and TestFlight delivery pending. Public App Store submission unchanged.
