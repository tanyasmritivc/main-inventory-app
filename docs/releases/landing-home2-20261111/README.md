# Homepage package 2 release, November 11, 2026

Live target: https://findez.ai/

## Scope and source

Applied `findez-landing-codex-2.zip` to the real homepage in place. Updated the supplied documents and reference screenshots in `docs/landing-v3/`. Compared both archives: every animation script and image is unchanged.

Runtime files changed:

- `frontend/src/components/marketing-dark/home-content.tsx`: Community menu and footer column, updated destinations, footer Solutions link, removed pinned step numbers.
- `frontend/src/components/marketing-dark/home.css`: supplied Community menu styling and four-column desktop footer, scoped to the homepage.

Added this report and six live screenshots. Updated `.agents/ACTIVE_WORK.md`. No runtime files added or deleted. Existing CAD content and motion code are unchanged. No backend, mobile, signed-in app, auth, dependency, environment-file or configuration-file changes.

## Routes

Plan name remains **Founders Access**. All four checklist items remain.

| Control | Destination |
| --- | --- |
| Logo | `/` |
| Solutions | `/solutions` |
| Founders Access navigation and footer | `/founders` |
| Developers | `/docs/api` |
| Sign in / Open the web app | `/signin` |
| Header Download | `/desktop` |
| Download for iPhone / iPhone app | `https://apps.apple.com/us/app/findez-ai/id6760401697` |
| Join Founders Access | `/signup` |
| CAD Intelligence navigation and footer | `#cad` |
| Explore CAD Intelligence | `/cad` |
| Discord, new tab | `https://discord.gg/sKRrWA5wbf` |
| Instagram, new tab | `https://www.instagram.com/findezai/` |
| Plans & access | `/pricing` |
| Research | `/research` |
| Contact | `mailto:info@findez.ai` |
| Privacy / Terms | `/privacy` / `/terms` |

No route substitutions were necessary. The same-page CAD footer anchor uses `#cad`, as requested, to preserve the smooth-scroll handler.

## Deployment

Deployed directly to the existing self-hosted production `findez-web` service in `/home/ubuntu/findez-tab-icon-20261111/frontend`, preserving the more recent site-icon release. No Vercel, Render, preview, alternate route, local server or staging site.

The build command is `npm run build -- --webpack`. Existing dependencies are reused. The service is stopped for the build, then restarted after success. A backup of the prior compiled page and affected files restores the working page on failure.

The first attempts failed in the existing Google Fonts loader and automatically restored the previous page. The final attempt uses a temporary build-only cache helper that downloads authentic Google Fonts CSS and font bytes through curl, verifies the WOFF signatures, and supplies those files through Next's font response hook. Font declarations and app configuration remain unchanged. This is not a fallback typeface or fabricated font response.

## Screenshots

| Section | Desktop | 390px phone layout |
| --- | --- | --- |
| Hero | [Desktop](desktop-hero.png) | [Phone](phone-hero.png) |
| Pinned section | [Desktop](desktop-pinned.png) | [Phone](phone-pinned.png) |
| Founders Access | [Desktop](desktop-founders.png) | [Phone](phone-founders.png) |

## Verification

Production build `hzTuddxupGo8jRJZAez5I` passed compilation, TypeScript and all 65 static pages. The source manifest comparison shows exactly the two intended runtime files changed. Public `/desktop`, `/founders`, `/signin` and `/signup` return HTTP 200.

Live Safari checks covered 1440 x 900 and 390 x 844: Community menu, four-column desktop and wrapped phone footer, updated link destinations, the tour loop and Pause/Play, header hide/reveal, pinned list and reverse scrolling. Six fresh viewport screenshots are included. The animation scripts and image assets match the previous package exactly.

No local preview, test suite, or additional package installation was run. Mobile evidence is Safari Responsive Design Mode, not a physical iPhone. Reduced-motion implementation is unchanged and was source-reviewed previously; manual reduced-motion emulation is not claimed. Font rasterization and animation capture phases can differ from static reference images; no intentional design differences were introduced.

## Safari memory limitation

Two top-to-bottom scroll passes were completed during profiling. The extended recording lasted 153.23 seconds and peaked at 275.03 MiB. Its final minute ranged from 197.45 to 208.1 MiB. However, Safari switched to another tab during observation, and the recording was stopped and resumed once. Background throttling affects this trace. An uninterrupted foreground one-minute flat-memory result is **not verified** for this update. The prior release's observation is documented separately, and no animation code changed in this package. See `safari-memory-summary.json`. Raw browser profiling data is not committed.
