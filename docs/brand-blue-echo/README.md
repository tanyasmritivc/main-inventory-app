# Blue echo rollout - October 23, 2026

The supplied `findez-brand-kit.zip` is authoritative. `kit/` preserves its brand
rules, theme tokens and primary SVGs. Runtime vectors preserve all seven primary
assets exactly; only embedded provenance metadata is omitted from runtime SVGs.
`source/` also preserves the original individual SVG handoff.

Shared React logos cover marketing, authentication, app navigation and footers.
The homepage uses the same supplied outlined wordmark. Browser SVG/ICO/96px PNG,
180px touch icon, 512px organization/social logo and legacy public SVG URLs use
the same artwork. Public page titles and route behavior stay intact.

Plus Jakarta Sans is the shared interface font; Geist Mono is the data font.
Primary controls use ink/white; orange and baby blue are accent tokens. Existing
accessible status foreground colors remain for small warning/success/error text.
The kit's voice guidance applies to new copy; this asset rollout does not rewrite
previously approved landing-page copy or change its scroll timelines.

Regenerate exports with `node scripts/export-brand-v3.cjs`. To update native and
Flutter web launcher assets too, pass `--mobile-root /absolute/path/to/mobile`.
PNG app icons are opaque. iOS includes the supplied dark appearance icon.

Google chooses when to recrawl and display a favicon. Publishing crawlable icon
assets and Organization structured data cannot guarantee an immediate search
result update. Public App Store artwork changes with a separately approved public
release; a TestFlight upload is not a public App Store submission.

Validation and deployment receipts are recorded after completion.
