# Solutions release, November 11, 2026

Live: https://www.findez.ai/solutions

## Deployment

Replaced the real Next.js `/solutions` page in place. Deployed a scoped source archive over SSH to the active self-hosted service, `findez-web`, in `/home/ubuntu/findez-amazon-csv-help-20261111/frontend`. No Vercel, Render, staging, alternate route, feature flag, or local preview was created.

Backed up the previous compiled release and affected existing source files before deployment. Built on the production server with `npm run build -- --webpack`, using the existing build-only cache helper for authentic Google Fonts files. The first build caught a converted SVG `viewbox` attribute; it was corrected to `viewBox` and the previous release was restored while fixing it. Final production compilation, TypeScript validation, and prerendering passed. Final build: `YC7_goO_VyAqbzcsjPHm8`. Service is active and `/solutions` returns 200.

## Files and shared components

Changed:

- `frontend/src/app/(marketing)/solutions/page.tsx`: renders the replacement while preserving `pageMetadata('solutions')`.
- `frontend/src/components/marketing-dark/home-content.tsx`: optional current-page and CAD-link props on the shared header/footer. Homepage defaults are unchanged.
- `frontend/src/components/marketing-dark/home-motion.tsx`: optional Solutions background-occlusion configuration.
- `frontend/src/components/marketing-dark/home-motion-runtime.js`: supports pages without a tour/marquee and configurable background occluders. Homepage defaults are unchanged.
- `.agents/ACTIVE_WORK.md`: release status.

Added under `frontend/src/components/marketing-dark/`:

- `solutions.tsx`: server composition with shared homepage shell.
- `solutions-content.tsx`: supplied text, tabs, audience rows, links and sample-data disclosures.
- `solutions.css`: route-scoped supplied styles, including local compensation for the site's global reset.
- `solutions-motion.tsx`: separate client effect components.
- `solutions-motion-runtime.js`: supplied `AUD`, `ROWS`, map and spreadsheet drawing code, with cleanup, visibility pausing and reduced-motion behavior.

Added the supplied package under `docs/solutions-v3/` and this report with six live screenshots and link/memory evidence. No files deleted: the old Solutions/founders module is still imported by other marketing routes and contains their shared sections, so it was preserved. `/solutions` no longer renders those old sections.

The homepage redesign was already live. Header, footer, smooth scrolling, headline reveal, background-mark drawing, lifecycle helper and the single browser requestAnimationFrame scheduler are reused. No new package, image asset, backend, mobile, auth, environment or configuration changes. All four solution sub-page sources are untouched.

## Destinations

No route differed from the supplied list. The plan is **Founders Access**.

| Control | Destination |
| --- | --- |
| Logo | `/` |
| Solutions | `/solutions` |
| CAD Intelligence | `/#cad` |
| Founders Access | `/founders` |
| Developers | `/docs/api` |
| Sign in | `/signin` |
| Download | `/desktop` |
| Get Free Founders Access | `/signup` |
| See how it works | `#sm` |
| Robotics map/Explore | `/solutions/robotics` |
| Workshops map/Explore | `/solutions/workshops` |
| Makerspaces map/Explore | `/solutions/makerspaces` |
| Engineering labs map/Explore | `/solutions/engineering-labs` |
| Plans & access | `/pricing` |
| iPhone app | `https://apps.apple.com/us/app/findez-ai/id6760401697` |
| Research | `/research` |
| Contact | `mailto:info@findez.ai` |
| Privacy / Terms | `/privacy`, `/terms` |
| Discord | `https://discord.gg/sKRrWA5wbf` |
| Instagram | `https://www.instagram.com/findezai/` |

Both Community links open in a new tab. All 19 unique HTTP destinations returned 200 after following redirects; see `links.json`. Contact was verified as the mailto destination without sending email.

## Live Safari verification

Compared the supplied screenshots with the live page at 1440×900 and 390×844. Verified map typing, selected-path drawing, audience cycling and selected-audience destinations; the hero anchor; header hiding on downward movement and returning on upward movement; and pinned spreadsheet, intermediate morph and resolved drawer states in both scroll directions. Inspected phone text wrapping and the horizontal tab strip. The static sample data makes no application API calls.

Safari Memory profiling captured 251 samples over 161.74 elapsed seconds, including two full scroll passes and a final sustained interval. Peak measured page memory was 142.78 MiB; the last minute stayed between 134.94 and 135.50 MiB. The trace was briefly paused for an intermediate export. This is page-category memory, not total Safari process RSS. See `memory-summary.json`. The Community dropdown was also verified visibly open with both links.

Reduced-motion branches were reviewed in source: no glide or automatic audience cycling, fully resolved first map and answers, final pinned state. OS-level reduced-motion emulation was not performed.

| View | Desktop | Phone |
| --- | --- | --- |
| Hero | [Desktop hero](desktop-hero.png) | [Phone hero](phone-hero.png) |
| Inventory map | [Desktop map](desktop-map.png) | [Phone map](phone-map.png) |
| Pinned inventory | [Desktop pinned](desktop-pinned.png) | [Phone pinned](phone-pinned.png) |

Screenshots are cropped from the live Safari responsive viewport. Minor font rasterization and scrollbar differences remain between Safari and the supplied capture. The shared header/footer retain the already-deployed homepage layout, as requested. The supplied drawing math, audience data, spreadsheet rows and copy are retained.
