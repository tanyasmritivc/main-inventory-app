# Search favicon compatibility (2026-10-18)

The old symbol beside findez.ai in Google results is the website favicon. The
live site advertised only /images/findez-favicon.svg and /favicon.ico returned
404. Google's current supported-format list does not include SVG. The preceding
search-positioning pass missed this separate compatibility issue. The public
App Store artwork already uses the current FindEZ mark.

Export the existing approved native 1024px icon without redesigning it:

- /favicon.png: opaque 96x96 PNG, primary website favicon.
- /favicon.ico: 16x16, 32x32 and 48x48 frames, conventional browser fallback.
- /apple-touch-icon.png: opaque 180x180 PNG, Apple touch icon and public publisher
  logo reference.

Native source: mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/
Icon-App-1024x1024@1x.png in the mobile lane. Source SHA256:
63fcb092600e5fdeae2b32e6bf657fc203b9d14b13f670a0a07bb17dbe6f8213.
PNG exports and ICO frames are checked against their dimensions and previewed.
Keep permanent icon URLs; no query-string rotation or periodic cache busting.
Keep the existing SVG endpoint available for old bookmarks.

Web-only metadata/static-asset change. Preserve search copy, the current landing
renderer, Search Console proof, invitation association file, account changes,
authenticated UI and Dashboard. No native binary, backend or database changes.

Verify normal and Googlebot-Image HTTP responses on both public hostnames:
correct declared icon links/MIME types, exact asset bytes, PNG dimensions and
ICO frames, no authentication/crawler block, plus retained canonical/JSON-LD/
Search Console proof and protected product routes. Run full web tests, types,
scoped lint, actual preserved production build and all five CI gates. Published source f087a84 (PR126) passes all five CI gates (39184358123). Final
both-host HTTP checks pass, with 265 unrelated runtime/public files preserved.
Release: /home/ubuntu/findez-search-icons-20261018/candidate/frontend. The current
PNG/ICO/Apple-touch assets and declared links are live; Google cached result
replacement remains unverified. The existing homepage indexing request is accepted;
Google favicon refresh remains external and is not promised immediately.

Reference: https://developers.google.com/search/docs/appearance/favicon-in-search.
