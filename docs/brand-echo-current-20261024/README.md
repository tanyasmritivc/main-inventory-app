# Current echo artwork — October 24, 2026

The latest user selection is findez-logo-echo.zip plus findez-app-icon-dark-2.svg
and findez-app-icon-light-2.svg. The standalone SVGs exactly match the ZIP round/
variant, so that variant is used throughout. This supersedes the prior
brand-authoritative-20261024 selection; historical delivery records remain historical.
The wordmark and isolated mark geometry already matched. App-icon and favicon
scaling is now the supplied 1.42, without additional padding or recoloring.
Source checksums are preserved here. Both light/dark app icons stay opaque and
square for native OS masking. The existing theme colors and navigation are unchanged.

Mobile platform exports, bundled legacy icons, browser SVG/ICO/PNG, touch and
Organization/social logos are regenerated from these sources. Browser metadata
uses a new version key. Search engines control when their cached icon refreshes.
Public App Store artwork is not published by a TestFlight upload.

## October 24 — Chat activity and current echo icons delivered (beta125; PR197)

Apple acknowledged 1.1.1 (125), delivery `e5f4a8f8-2426-4a60-8d99-4a86a23beffb`.
Runtime 52a82725900e32c2021d71a48d9ac55d58d7d94f includes actual activity with a two-second
left-to-right soft shine, expandable steps, text scaling and Reduce Motion. Text
drafts are labeled Inventory draft. Native navigation and its motion are untouched.
The latest findez-logo-echo.zip round/ artwork and matching app-icon-*-2.svg are now
canonical; native launchers, bundled/legacy and other platform exports match.

849 Flutter tests (one optional skip), clean analysis, focused progress checks and
13 brand checks passed. All 46 raster exports match the supplied SVG pixels/sizes/
opacity, and the launcher decoded from the signed IPA matches exactly. All five
runtime CI jobs passed (40143399990). Archive/export each passed 32 device-executable
checks, strict signing, 24 privacy manifests and production HTTPS configuration.
Apple validation passed. IPA SHA256: `de441e88902c521203d63db8581d06d95c0314d194ad2e37cbc8570ed4504f9e`.

Artifacts: Documents/FindEZ/AppStore/1.1.1-build125. Processing/tester availability
was not polled; physical-device acceptance remains unverified. No public App Store
submission. Build124's earlier upload is superseded by this build with the latest
artwork and reversed shine. Web/API were deployed through their separate lanes.
