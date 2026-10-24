# Mobile Blue echo and motion update

Based on beta 117. The user supplied the primary Blue echo kit and requested all
logos/icons and theme applications. Native iOS Liquid Glass controls remain.

- Retained 300ms tab dissolve preserves drafts and scroll positions, retargets
  rapid selections continuously, excludes outgoing hit testing/semantics and
  respects Reduce Motion.
- Native Settings uses the same app text-size factor as Flutter, smaller body and
  detail sizes, and UIFontMetrics for Dynamic Type. Plus Jakarta Sans is bundled
  and registered for native Settings; platform icons and presentation stay native.
- Exact supplied primary vector geometry and opaque light/dark launcher exports.
  Plus Jakarta Sans for interface text; Geist Mono for quantities and data.
- The existing plain chat background is preserved. Accessible status foreground
  colors are retained instead of applying low-contrast brand swatches to small text.

Validation: full Flutter suite 821 passed, one optional skip. Analysis clean.
Native iOS 26.5 simulator built successfully; Settings Default dark/light and
appearance controls verified visually. Tab selection was checked using native
UITabBar; rapid switching/state retention/Reduce Motion covered in widget tests.
Physical-device acceptance is pending. Beta 118 delivery receipt follows upload.

Artwork export source/script live in the sibling web brand branch:
`docs/brand-blue-echo` and `scripts/export-brand-v3.cjs --mobile-root ...`.
Fonts use their bundled SIL Open Font Licenses; no runtime font fetch is needed.

## Delivery receipt

Apple acknowledged 1.1.1 (118), delivery `7ea3cc3c-c89b-4ec3-ab84-a4d1862ce1bb`.
Runtime `28187b5d719bab41ccd52288cd315fcf4a4265c3`, PR181. Exact-commit CI run
40049512512 passed all five jobs. IPA SHA-256:
`3e2fe0c05e9e0543760e840f224a634af9933a298faed10082f8c9d7e7881529`.

All 32 archive and exported Mach-O executables were verified for iOS device
platforms; strict signature and 24 privacy manifests passed. The first local
candidate contained a cached simulator framework, was retained for audit and was
never uploaded. A clean rebuild passed platform checks and Apple validation.
The existing unused LaunchImage placeholder still produces Flutter's advisory;
the native launch storyboard uses a plain background, and Flutter splash/loading
screens use the new wordmark.

Durable signed IPA, zipped archive and private Apple receipts are preserved under
`~/Documents/FindEZ/AppStore/1.1.1-build118`. Apple processing and tester availability
are pending and were not polled. No public App Store submission was made.

Manual acceptance once TestFlight offers 118:
1. Check the home-screen icon and in-app wordmark in light/dark appearance.
2. Switch Ask, Spaces and More repeatedly; the content should dissolve smoothly
   and retain drafts/scroll positions. Reduce Motion should remove the dissolve.
3. Open Settings at Default size, compare to app text, then check Large/Larger.
4. Confirm the native tab bar remains Liquid Glass and chat stays on the plain
   background. Physical-device acceptance remains pending.
