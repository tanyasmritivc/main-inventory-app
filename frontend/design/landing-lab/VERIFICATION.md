# Lab preview verification

October 15, 2026. Branch `feat/landing-lab-20261015`, based on `2d8d3f7`.

The supplied prototype is implemented at `/lab` with noindex metadata. The
homepage, existing landing components, app shell, global tokens, dependencies,
backend and mobile are unchanged. The waitlist intentionally validates and shows
confirmation only; its submit handler has a TODO and makes no API request.

## Validation

- Production Next.js build passed using `npm run build -- --webpack`.
- TypeScript `tsc --noEmit --incremental false` passed.
- Full ESLint passed with zero errors and 55 existing warnings. New files lint cleanly.
- All 39 Jest suites and 287 tests passed, including 11 new prototype formula tests.
- `node design/landing-lab/tools/compare.mjs http://localhost:3000/lab` produced
  46 reference/new pairs: 23 scroll positions at desktop and mobile widths.
- All section heights and scroll progress match. Nonhero screenshots have no
  pixel differences above 16 channel levels except 3 to 44 phone-frame corner
  pixels in the app fan captures. Hero differences include the permitted moving
  scan lens. This is visual parity, not a claim of universal byte-identical pixels.
- Both 1440px and 390px widths have no horizontal overflow or console errors.
- Invalid email, valid Enter submission, confirmation and zero fetch/XHR verified.
- Reduced motion removes pinned travel, uses finished states, pauses SVG motion
  and disables the canvas animation loop and eased scrolling.
- Original reference, source, README and all supplied assets are byte-identical
  to the ZIP. Public image copies are also byte-identical.

The comparison tool additionally waits for fonts, synchronizes ambient CSS/SVG
animation time, dismisses the existing site cookie banner, and writes geometry,
console and behavior receipts. It does not alter scroll animation progress.
It uses the existing cached Playwright installation through an ignored local
`tools/node_modules` symlink; no dependency was added. Generated `compare-out/`
files are ignored. `pairs/hero.png`, `pairs/zoom-50.png` and `pairs/vision-60.png`
show reference on the left and Next.js on the right.

## Preview hosting

A private isolated production build is running at loopback port 3109 in
`/home/ubuntu/findez-lab-preview-20261015/frontend` on the existing VM, forwarded
to `http://localhost:3000/lab` by an SSH tunnel. Build ID:
`AGr4hX4jIMVogJBxSQx4h`. The tunnel must remain open to use that URL.
No live deployment or homepage replacement occurred. The production service,
configuration and database were not changed. Local screenshot receipts include
`source-sha256.json` for the verified runtime and assets.

## Files

New frontend implementation:

- `src/app/lab/page.tsx`
- `src/components/site/landing-lab.tsx`
- `src/components/site/landing-lab-engine.ts`
- `src/components/site/landing-lab.css`
- `src/__tests__/landing-lab.test.ts`

New design handoff and verification:

- `design/landing-lab/.gitignore`
- `design/landing-lab/README.md`
- `design/landing-lab/VERIFICATION.md`
- `design/landing-lab/source/Lab.dc.html`
- `design/landing-lab/reference/index.html`
- `design/landing-lab/tools/compare.mjs`

Each of these eight assets exists in both `design/landing-lab/reference/assets/`
and `public/images/landing-lab/`:

- `app-home.jpg`
- `app-capture.jpg`
- `app-review.jpg`
- `app-ask.jpg`
- `bench.jpg`
- `bench-zoom.jpg`
- `hero.jpg`
- `findez-wordmark.svg`

Repository context updated: `.agents/ACTIVE_WORK.md`.

The supplied soft app screenshots and placeholder graph values are deliberately
preserved. Replacing the homepage or connecting a real waitlist is separate work.
