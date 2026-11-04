# Auto-extract source popup — build178

The main Ask Auto-extract Camera/Library picker now has its own appearance-aware sheet instead of reusing the forced-dark extraction review container. Other extraction review sheets and main Ask behavior are unchanged.

The picker enforces regular native SF Pro locally, including when the surrounding MediaQuery enables OS Bold Text. Its heading is18pt and body/button text is16pt. Copy and spacing are compact. Camera and Library use opaque grey stadium buttons with48pt minimum targets, and stack on narrow screens or with enlarged text. Light/Dark/System appearance changes apply while the picker is open.

The bounded scrollable sheet stays above the keyboard and leaves a dismissible backdrop even on a small screen. SwipeDownSheet provides smooth downward dismissal and the accessibility dismiss action, without adding a close button. Camera still returns true, Library false and dismissal null through the root navigator, preserving the originating chat and its existing photo/extraction pipeline.

## Verification

Focused popup/capture checks, full Flutter tests, analyzer and native iOS screenshots are recorded at delivery. Tests cover nested navigation, both source callbacks, regular SF Pro even without the global typography wrapper, opaque controls, live System appearance changes,320pt width,2.6x text, reduced motion, keyboard insets, downward swipe and backdrop dismissal. Fixtures do not open a real camera or write inventory. Physical iPhone acceptance remains unverified.

No backend/web/schema or public App Store change. TestFlight178 upload is authorized. Private configuration and binaries stay outside the checkout in `projects/findez-popup178-private`.
