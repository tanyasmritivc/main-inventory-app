# Landing v3

Homepage-only React port of the supplied `landing-prototype.html`. The archived
prototype is unchanged. Its workbench image is served from
`frontend/public/images/landing-v3/bench.jpg`.

## Implementation

- `frontend/src/app/page.tsx` retains the existing metadata and structured data,
  loads Plus Jakarta Sans and Geist Mono through Next fonts, and renders LandingV3.
- `frontend/src/components/landing-v3/` owns all sections, scoped CSS, prototype
  geometry/data, navigation, scroll painting and the Three.js tool scene.
- One requestAnimationFrame loop paints styles through refs and renders visible
  tools. Reduced motion disables typing, idle rotation and progress smoothing.
- Three.js uses the existing npm dependency and a dynamic client-only component.
  Unavailable WebGL hides the canvas. Resources and listeners are disposed on exit.
- Removed the old, unreferenced homepage component/animation variants. Shared
  navigation, cookie notice and all interior routes remain unchanged.

## Validation on October 23, 2026

- Full web coverage suite: 60 suites, 469 tests passed.
- Additional WebGL fallback suite: 3 tests passed.
- `npm run lint`: zero errors; the same 52 pre-existing warnings as the base.
- `npx tsc --noEmit`: passed.
- `npm run build`: passed using non-secret public Supabase build placeholders.
  The first unconfigured build failed in unrelated authentication prerendering;
  no application changes were made to work around that requirement.
- Chrome responsive inspection: full scroll story at 1440×900 and 390×844;
  document widths measured 1440 and 390 respectively. No hydration warnings or
  application errors observed. Tools render on the first and closing screens,
  the item count changes from 18 to 19, and reduced-motion emulation keeps the
  hero placeholder and tool rotations static.

## Manual verification

1. Run `npm ci` and `npm run dev` in `frontend/`; open `/` at the two sizes above.
2. Check the chat-only opening copy, typing placeholder and retained cookie notice.
3. Scroll slowly through photo scan/tags/review, black memory graph, PN-F40 cabinet
   zoom/breadcrumb, Ask, audience rows, fanning/merged team cards, four phones,
   phone-to-laptop item transfer, closing tools and footer. Reverse scrolling too.
4. Submit `Add screws & batteries` and verify the encoded `/signup?prompt=...`
   destination. Attach, camera and microphone all open `/signup`.
5. Hover tools for name/location, click for bounce, and verify they leave/return
   with scrolling. Emulate reduced motion and verify typing/spinning stop.
6. Verify the console stays free of hydration errors, and `/pricing`, `/signin`,
   `/signup`, `/docs/api`, `/privacy`, `/terms` retain their existing interfaces.

## Fidelity and limits

Timeline values, morph rectangles, text choreography and scene styling come from
the prototype. The requested 820px breakpoint is used consistently (the supplied
CSS used 760px while its JavaScript used 820px). Fonts are self-hosted by Next and
Three.js is the existing npm version rather than the prototype's CDN import map.
Random tool orientations vary on each load, as in the prototype.

The prototype's mobile photo review panel extends below the viewport during its
pinned scene; comparison at 390×844 confirmed the same crop in the reference and
the port. That geometry is retained rather than silently redesigning the source.
Physical iPhone/Safari acceptance remains unverified. No backend, database or
mobile changes are included.


## Self-hosted deployment — October 23, 2026

User explicitly authorized self-hosted deployment. Implementation `cf29d1f`
(PR #180, branch `feat/landing-v3`) is live at https://findez.ai from:
`/home/ubuntu/findez-web-releases/landing-v3-20261023/frontend`.
Next build ID: `8xw5tjSXdVhKej4STQ101`.

The isolated release copies the previously running connector release and applies
only the frontend patch. SHA-256 comparison preserved 366 unrelated files,
including existing production environment/configuration. The existing installed
node_modules is reused without modification. Production `npm run build --
--webpack` passed with the real self-hosted configuration. All five repository CI
jobs passed on the implementation commit.

Before activation, eight route responses matched the previous runtime (including
its existing `/dashboard` 404). After activation, public HTTPS checks passed for
`/`, `/signup`, `/signin`, `/pricing`, `/docs/api`, `/privacy`, `/terms`, 19 referenced
assets, exact homepage title/copy and the workbench image hash. Chrome verified
live rendering, typing and 3D tools; no hydration/application errors were seen.
Chrome did report an unused-preloaded-CSS advisory. Full desktop/mobile scroll
inspection was performed locally before release, as documented above.

Only the `findez-web` WorkingDirectory drop-in changed, followed by service restart.
The backend PID remained unchanged. Previous runtime and drop-in are preserved:
`/home/ubuntu/findez-web-releases/connectors-20261022/frontend` and
`/home/ubuntu/findez-web-releases/landing-v3-20261023/previous-web-rebuild.conf`.
To roll back, restore that drop-in to
`/etc/systemd/system/findez-web.service.d/web-rebuild.conf`, run systemd daemon-reload
and restart `findez-web`. The server-side private deployment receipt records
source hashes and verification results. The temporary candidate server was stopped.

Disk preparation removed only rebuildable `.next/cache` directories in four
inactive October 16–17 web releases, freeing about 3.6 GB; their runnable builds
and all source data remain intact. No Vercel deployment was used for activation.
