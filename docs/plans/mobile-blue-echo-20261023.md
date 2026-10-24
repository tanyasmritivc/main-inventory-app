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
