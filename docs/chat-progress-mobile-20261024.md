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

Manual device checks: Auto Extract and ordinary chat progress; expand/collapse;
light/dark; font setting; Reduce Motion; leave/reopen chat; attachment retries.
The shimmer matches the supplied React Bits two-second soft sweep using ShaderMask,
not a web view or new dependency. Public activity only, no model chain of thought.
Physical-device acceptance is unverified until performed on a real iPhone.
