# Rounded app icons and tab fade

Mobile-only follow-up to beta 118. Uses the exact standalone light/dark SVGs
provided October 23; both match the `round/` variants in findez-logo-echo.zip.
The app icon exports preserve the supplied full-bleed background, geometry and
padding. iOS applies its own external mask. iOS catalog sizes (including dark),
Android launcher sizes and bundled app-icon PNGs are replaced. Web branding and
in-app wordmarks are outside this request and unchanged.

## Navigation

Each retained page now owns its header and footer actions. Previously these
switched immediately outside the fade, changing the outgoing page's constraints
and making the New space button and header jump. They now dissolve together.
The 340ms ease-out fade begins responding immediately instead of the previous
slow ease-in. Existing pages retain state; rapid taps retarget the current frame,
and outgoing pages cannot receive taps or accessibility focus. Reduce Motion
removes the Flutter dissolve.

Native UIKit UITabBar remains the Liquid Glass control. Its public CALayer clock
runs at 0.7 speed to soften the system selection bubble without delaying its
selection callback or replacing private subviews. Changing timing preserves local
layer time; Reduce Motion restores the system clock. UIKit still controls its
own gesture/spring animation, so an exact duration across iOS versions is not
promised. Non-iOS selection uses the same duration/curve as the page fade.
API reference: https://developer.apple.com/documentation/quartzcore/camediatiming/speed

## Validation and delivery

Full Flutter suite: 822 passed, one optional skip; analysis clean. The first
native/test attempt stopped on disk exhaustion; disposable build caches were
removed and the full suite rerun successfully. Build number 1.1.1 (119).
Native iOS 26.5 simulator built and the full synthetic Ask/Spaces/More shell
was inspected in dark/light appearance, including the Spaces footer and Settings
round trip. Native taps verified page selection; exact timing and physical-device
feel remain acceptance checks. Signed build/upload verification is in progress. Production target remains lib/main.dart;
`tool/native_world_motion_visual.dart` is a debug-only, synthetic API fixture.
No production inventory is touched by the motion audit. Native physical iPhone
acceptance is reported separately from simulator and widget checks.

Manual acceptance:
1. Check home-screen icon in light/dark appearance after updating.
2. Switch Ask -> Spaces -> More -> Ask. Header, page and New space button should
   dissolve without a layout jump, and the native glass selection should settle
   more gently. No added wait before content begins fading.
3. Rapidly change selection midway; return to Ask and check draft retention,
   then Spaces and check scroll position. Only the selected page accepts touches.
4. Repeat in light/dark appearance and with Reduce Motion enabled.
