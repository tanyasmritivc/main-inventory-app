# Mobile background and organization menu, build 218

The organization picker now uses a contained 280pt native popover, compact rows with at least 44pt touch targets, and a bounded scrollable height. Long names and Dynamic Type retain their available space. The Dart fallback uses the same width bound.

A stationary, opaque page canvas provides subtle warm and cool radial glows in light and dark themes. It covers the full World shell including safe areas. Retained tabs and the Spaces header no longer paint solid strips over it. Cards and navigation remain floating surfaces. Profile, shared utility pages, and native grouped Settings lists use the matching canvas. High Contrast removes the decorative glows.

No API, permission, scan, storage, or chat behavior changes. The debug-only synthetic preview is separate from the production lib/main.dart target.

Validation: full mobile suite 1,383 passed with one existing skip; 103 focused checks passed after the canvas fixes; analyzer clean. Native simulator checks cover both themes, compact menu selection and dismissal, long labels, larger preferred text, Settings, Profile and the Spaces header. Physical-device acceptance remains pending. The synthetic fixture does not validate live inventory loading.

Release: signed production 1.1.3+218 packaging and TestFlight delivery pending. Public App Store submission unchanged.
