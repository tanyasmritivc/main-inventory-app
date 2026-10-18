# Public search positioning (October 18, 2026)

The supplied Google AI Overview calls FindEZ a workshop inventory assistant and
cites Apple. Direct App Store Connect and Apple's public US lookup now report
version 1.0.7, released October 12, with the memory-focused description. The
Google source snapshot still shows 1.0.6 and its older workshop copy. A TestFlight
upload does not update Google's cached sources or publish an App Store version.

The editable 1.0.8 draft also retained a conflicting name, "FindEZ: AI Inventory",
and an item-recognition subtitle. Its name is now saved as "FindEZ AI", subtitle
"AI memory for your things", with the description below. Live 1.0.7 promotional
text is refreshed; its approved description and all historical versions remain.
No version was submitted or released, and no build selection changed.

## Published-source candidate

- Title: FindEZ AI | AI memory for the physical world
- Description: Turn the physical world into memory. Scan photos and barcodes,
  save items in Spaces, and ask FindEZ AI what you have and where it is.
- Root, homepage, Open Graph and Twitter use the same positioning.
- Homepage JSON-LD describes only public WebSite, SoftwareApplication and
  publisher identities, with implemented features. It includes no customer data,
  fabricated ratings, prices, SearchAction or promised Google placement.
- Keep the current independently changed landing renderer, local fonts, theme,
  authentication and Dashboard. The mobile download page gets matching copy.
- The sitemap advertises the homepage's actual October 18 update and omits unknown
  modification dates on other routes. It never invents a new date on every crawl.

Implementation: frontend/src/lib/public-positioning.ts, app/layout.tsx,
app/page.tsx, app/sitemap.ts and app/mobile-app/page.tsx. No backend, schema,
native code or product permission changes.

## App Store draft description

FindEZ AI gives the physical world a memory. Capture the things you own or manage,
remember where they belong, and ask about them in your own words.

At home, at work, or with a team, FindEZ keeps your items, locations, photos and
context together so you can find what you need.

SCAN AND REMEMBER

- Take or upload a photo to identify multiple items, or scan a barcode.
- Review suggested details and uncertain identifications before saving.
- Keep the item crop and original scan photo together for new captures.
- Import a spreadsheet to bring existing records into FindEZ.

FIND THINGS IN SPACES

- Organize items by the real places they belong, such as a drawer, garage,
  office or lab.
- Keep quantities, notes and photos with each saved item.
- Search what you have and check where it was recorded.

ASK FINDEZ AI

- Ask questions about your saved items, quantities, locations and context.
- Attach a photo to give a question more context.
- Review and confirm proposed item additions or deletions before they happen.
- Follow responses as they appear in a focused conversation.

USE IT YOURSELF OR WITH YOUR TEAM

- Keep personal belongings together or choose an organization to work in.
- Collaborate within workspaces and inventories with clear roles and permissions.
- Share access through invitations and work together on tasks and files.
- Use your saved profile photo across People and shared work.

Your saved records are the source for questions about what you own. Photo
identifications and AI answers can be uncertain; check important details before
acting. Built by AI Robots Inc.

Live promotional text: FindEZ AI gives the physical world a memory. Scan your
things, save where they belong, and ask what you have and where to find it.

## Verification and delivery

365 branch web tests across 48 suites, TypeScript, scoped ESLint and the actual
preserved production-configured webpack build pass. Isolated browser/Googlebot
HTML checks verify exact title, description, canonical, social previews and valid
public JSON-LD. Sitemap dates/route allowlist, robots.txt, mobile download copy,
sign-in/legal routes and protected Scan/Items/Ask routes pass. The release
preserves 261 unrelated runtime/public files, including the actual landing
renderer. No customer QA writes or signed-in content is used.

Server receipts: /home/ubuntu/findez-search-positioning-20261018. App Store
before/prepared/confirmed metadata is retained privately under
Documents/FindEZ/AppStore/search-positioning-20261018. Exact-source CI and web
activation remain pending. Google recrawl/indexing and generated AI Overview
wording are external; never claim a reindex request or changed results without
the corresponding Search Console receipt.

Google guidance: https://developers.google.com/search/docs/appearance/ai-features
and https://developers.google.com/search/docs/crawling-indexing/ask-google-to-recrawl.
Apple guidance: https://developer.apple.com/app-store/product-page/.
