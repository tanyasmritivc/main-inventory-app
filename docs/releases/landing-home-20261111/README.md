# Homepage production release, November 11, 2026

Live URL: https://findez.ai/

## Deployment

Replaced the real Next.js home route in place on the existing self-hosted server.
No Vercel, Render, staging site, alternate route, or local preview was used.

- Service: `findez-web`.
- Existing production directory: `/home/ubuntu/findez-cad-guide-theme-20261111/frontend`.
- Production command: `npm run build -- --webpack`.
- Successful final build: `SQji7GlQpaBtfs45ePMyF`.
- The service was stopped for the build, then restarted after success. A source and compiled-output backup with automatic failure rollback protected the deployment.
- Initial font-download failures rolled back. IPv4-first DNS for the build process resolved the fetch; no environment or configuration files were edited.
- Public homepage returns HTTP 200 and the new headline. Only homepage source and supplied assets were overlaid. Shared production sections and unrelated changes were preserved.

## Implementation and files

Modified:

- `frontend/src/app/(marketing)/page.tsx`: renders the new server composition with homepage metadata.
- `frontend/src/components/marketing-dark/page.tsx`: removes the old home composition from the shared renderer.
- `frontend/src/components/marketing-dark/cad-intelligence-motion.ts`: uses the shared frame scheduler. Existing CAD markup, copy, styling, and behavior are retained.

Added under `frontend/src/components/marketing-dark/`:

- `home.tsx`: server composition.
- `home-content.tsx`: server-rendered supplied copy, markup, sample tour, and image components.
- `home.css`: scoped supplied styling and isolation from existing global rules.
- `home-frame.ts`: shared browser animation-frame scheduler.
- `home-life.js`: cleanup of timers, listeners, observers, and frame subscriptions.
- `home-motion-runtime.js`: ported motion controllers.
- `home-motion.tsx`: separate client effect components.

Added unchanged assets under `frontend/public/landing/`: `snap-md.jpg`, `bins-md.jpg`, and `c0.jpg` through `c5.jpg`.

Added supplied archive contents under `docs/landing-v3/`, this release report, six screenshots, and a Safari memory summary. Updated `.agents/ACTIVE_WORK.md`.

No files deleted. The obsolete home sections are no longer rendered; shared legacy helpers remain in their existing module to preserve other marketing routes. No backend, mobile, Supabase, auth, signed-in application, dependency, environment, or configuration changes.

## Destinations and plan

The existing plan name is **Founders Access**. All four checklist capabilities are retained.

| Link | Destination |
| --- | --- |
| Download / Download for iPhone / iPhone footer link | https://apps.apple.com/us/app/findez-ai/id6760401697 |
| Sign in / Open the web app | `/signin` |
| Join Founders Access | `/signup` |
| Solutions | `/solutions` |
| Developers | `/docs/api` |
| CAD Intelligence navigation | `#cad` |
| Explore CAD Intelligence | `/cad` |
| Founders Access navigation | `#x-fa` |
| Logo | `#top` |
| Plans & access | `/pricing` |
| Research | `/research` |
| Privacy / Terms | `/privacy` / `/terms` |
| Contact | `mailto:info@findez.ai` |

## Live verification

Production webpack compilation, TypeScript checking, and prerendering passed. No local preview or test suite was run, as requested.

Safari was inspected at 1440 x 900 and at 390 CSS pixels wide, against the supplied screenshot references:

- Header hides on downward movement and returns upward.
- Tour loops through extraction, choosing Workbench, saving, and the washers answer. Pause, Play, and Escape were exercised.
- Pinned photo transitions through separated parts into the completed list, and reverses when scrolling back.
- Founders pass and dot-field motion render on desktop and narrow layouts.
- Both navigation anchors reach their sections. The existing global CSS smooth-scroll behavior was isolated on the homepage so it cannot compete with the supplied frame-based controller.
- Link destinations were inspected. App Store resolves to the existing app listing.
- Two top-to-bottom Safari scroll passes completed without an obvious hitch. No runtime console errors were observed; existing font preload warnings remain.
- The page uses fictional Alex / A / Team Voltage sample data and makes no application API calls.

Reduced-motion behavior is implemented: native scrolling, no tilt or tour loop, final tour answer and finished pinned list, stopped marquee. This path was reviewed in source but was not manually emulated in Safari. Phone screenshots use Safari Responsive Design Mode, not a physical iPhone.

## Safari memory

The live Web Inspector recording lasted 221.23 seconds. Initial allocation and collection were visible, with a peak of 417.70 MiB. During the final minute, memory stayed between 197.42 and 201.60 MiB, from 199.71 to 200.29 MiB. This supports a stable post-collection plateau in the observed session, not a claim of zero allocation or proof against every leak.

The recording preceded the final CSS isolation fixes; animation code was unchanged. See `safari-memory-summary.json`. Raw Inspector data is not included in the repository.

## Screenshot evidence and differences

| Section | Desktop | Phone |
| --- | --- | --- |
| Hero | [Desktop](desktop-hero.png) | [Phone](phone-hero.png) |
| Pinned list | [Desktop](desktop-pinned.png) | [Phone](phone-pinned.png) |
| Founders Access | [Desktop](desktop-founders.png) | [Phone](phone-founders.png) |

Screenshots are cropped to the actual live viewport. Browser font rasterization and animation phases differ from static targets; no pixel-identical claim is made. Existing CAD presentation is deliberately retained as requested. Lifecycle cleanup and a shared animation scheduler replace the prototype's standalone script setup while preserving its visual timeline and calculations.
