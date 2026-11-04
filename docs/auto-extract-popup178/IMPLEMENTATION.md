# Auto-extract source popup — build 178

The main Ask Auto-extract Camera/Library picker now has its own appearance-aware sheet instead of reusing the forced-dark extraction review container. Other extraction review sheets and main Ask behavior are unchanged.

The picker enforces regular native SF Pro locally, including when the surrounding MediaQuery enables OS Bold Text. Its heading is 18pt and body/button text is 16pt. Copy and spacing are compact. Camera and Library use opaque grey stadium buttons with 48pt minimum targets, and stack on narrow screens or with enlarged text. Light/Dark/System appearance changes apply while the picker is open.

The bounded scrollable sheet stays above the keyboard and leaves a dismissible backdrop even on a small screen. SwipeDownSheet provides smooth downward dismissal and the accessibility dismiss action, without adding a close button. Camera still returns true, Library false and dismissal null through the root navigator, preserving the originating chat and its existing photo/extraction pipeline.

## Verification

30 focused checks and all 1,366 Flutter tests passed (one existing skip); analyzer clean. All six native iOS popup cases passed, with screenshots in verification/. Tests cover nested navigation, both source callbacks, regular SF Pro even without the global typography wrapper, opaque controls, live System appearance changes, 320pt width, 2.6x text, reduced motion, keyboard insets, downward swipe and backdrop dismissal. Fixtures do not open a real camera or write inventory. Physical iPhone acceptance remains unverified.

No backend/web/schema or public App Store change. TestFlight 178 upload is authorized. Private configuration and binaries stay outside the checkout in `projects/findez-popup178-private`.

Apple acknowledged TestFlight 1.1.2 (178), delivery 22381432-74f8-441a-b8ae-55477d3b6aa4. Processing/tester availability pending and unpolled. All five exact-source CI gates passed (run 41786025561). Signed archive/export passed platform, strict-signature, privacy, production-configuration and font-packaging checks; Apple validation passed. Source ab3ca194b1cbce7475da8fcf49edb29abfa9ce02. See testflight178-receipt.json.
