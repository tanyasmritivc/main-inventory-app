# Authoritative FindEZ artwork - October 24, 2026

The user explicitly reselected findez-logo-svg.zip and the seven individually
named SVGs. This supersedes the later findez-logo-echo.zip / app-icon-*-2.svg
launcher artwork from build 119. Preserve the exact supplied geometry, spacing,
orange, blue echo, dark/light ink and outlined lettering.

source/ preserves the complete original SVGs, including provenance metadata.
source-manifest.json maps canonical names to the user's exact filenames and
SHA256 checksums. Every individual SVG matches its corresponding ZIP member's
geometry and attributes. Runtime SVGs omit embedded provenance metadata only.

Audit found the web shared mark/wordmark, all seven public SVGs, legacy public
URLs, favicon SVG/ICO/PNG, Apple touch icon, social/Organization logo and theme
colors already correct. Fifteen assets from the live self-hosted HTTPS site match
the local authoritative exports byte-for-byte (live-web-asset-audit.json). The
live homepage links to those browser/touch/social assets. No web deployment is
needed or claimed. Public page title, prompt demo and auth remain unchanged.
Search engines control their own cached display; this audit verifies the site's
published assets, not Google's search result rendering.

Mobile auth, onboarding, splash, loading and welcome already share the matching
wordmark and theme. The light/dark launcher source SVGs and derived iOS/Android
icons were the differing assets and are replaced. The existing shared exporter
scripts/export-brand-v3.cjs in the web branding lane regenerated all platform
sizes; macOS, Windows and Flutter web already matched and remained unchanged.
Bundled PNGs and both legacy assets/icon/icon.png and
assets/Icon-App-1024x1024@1x.png now match too. iOS icons retain
opaque square backgrounds so the OS applies its own mask. Raster previews were
visually inspected against the supplied paths. No AI image generation was used.

Build 1.1.1 (123) includes all build 122 fixes. Navigation, page fades, UI layout,
chat behavior, backend and database are unchanged. Public App Store publishing is
separate from TestFlight delivery; no public release is implied.

Validation: 847 Flutter tests passed (one optional skip), analysis clean, and
46 raster icon exports exactly match the supplied SVG pixels/dimensions/opacity.
All mobile Dart/native behavior source and tests are byte-for-byte unchanged from
build 122. The signed IPA launcher icon was decoded and compared against the corrected source
pixels with an exact match. Both archive/export passed 32 iOS executable checks,
strict signing, 24 privacy manifests and production HTTPS configuration.
All five CI jobs passed on runtime 1ddc102 (run 40075508703; PR 189).

Apple validated and acknowledged 1.1.1 (123), delivery `cc77bb73-b867-44c6-b7d7-8add63508fd8`.
IPA SHA256: `29773e4d7b367af0c3b28f7d8a111cb76542f49f59cdf6b77aa6a36a441389ed`.
Private artifacts: Documents/FindEZ/AppStore/1.1.1-build123. Processing/tester
availability was not polled. Public App Store publishing and physical home-screen
acceptance remain separate.

Manual verification: install TestFlight 1.1.1 (123) when available, then compare
the launcher in light/dark appearance against source/findez-app-icon-*.svg. Check
FindEZ's auth/welcome wordmark. On the web, reload findez.ai and inspect the header
and browser tab; the existing assets already match. Search-engine cache refresh
and public App Store artwork are not implied by a beta upload.
