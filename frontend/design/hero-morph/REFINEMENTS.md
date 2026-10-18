# Landing refinements

Published on 2026-10-18 at https://findez.ai/.
Build: `7TbDSICsTgfD5NyLfPiBN`. Local branch: `hero-morph`.
No Git push was performed.

This is the follow-up to [AUDIT.md](AUDIT.md) and [PUBLISH.md](PUBLISH.md).
The user's subsequent screenshot feedback replaces the earlier instruction to
retain the separate detection and Capture phone scene. The changes affect only
the web landing page. All other routes keep their existing behavior.

## Current landing order and transitions

| ID | Headline | File | Scroll behavior |
| --- | --- | --- | --- |
| `hero` | FindEZ gives the physical world a memory. | `src/components/site/hero-morph.tsx` | Existing 1300px pinned morph into Take a picture. That is it. |
| `graph` | Knowing what it is is useful. Knowing everything around it is memory. | `src/components/site/landing-lab.tsx` | Existing rounded dark surface, letter reveal and pinned memory graph |
| `zoom` | Not just "Workshop". Exactly where. | `src/components/site/landing-lab.tsx` | New rounded surface entry and reversible letter reveal, followed by the existing pinned location zoom |
| `ask` | Ask the memory, not a chatbot. | `src/components/site/landing-lab.tsx` | Existing scroll reveal and context card |
| `who` | One memory for anyone who owns, shares or manages things. | `src/components/site/landing-lab.tsx` | Existing expanding dark surface and scrolling audience rows |
| `find` | Making our model better, day by day. | `src/components/site/landing-learning.tsx` | New expanding rounded surface, copy rise and scroll-driven FIND orbit |
| `app` | Capture. Ask. Find. | `src/components/site/landing-lab.tsx` | New rounded surface transition around the existing screenshot fan |
| `waitlist` | Be first on the iPhone app. | `src/components/site/landing-lab.tsx` | Existing card reveal |
| `end` | Take a picture. FindEZ remembers. | `src/components/site/landing-lab.tsx` | Existing final letter animation and footer |

New per-frame scene updates live in `landing-scenes-engine.ts`, write styles
inside requestAnimationFrame, and return a complete teardown. They do not use
React state. Geometry follows the actual scroll position in both directions.
Animating a pseudo-element keeps the new model section's layout height stable.
The existing Lab engine retains ownership of its pinned stories.

## Files and preservation

Changed runtime files:

- `src/components/site/hero-morph.tsx`: removed the top Capture / Ask / Find eyebrow.
- `src/components/site/hero-morph-engine.ts`: fluid hero geometry and detection label containment.
- `src/components/site/hero-morph.css`: responsive typography and short-screen fallback.
- `src/components/site/landing-lab.tsx`: removed `#see`, replaced the pipeline, and connected scene surfaces and location letters.
- `src/components/site/landing-lab-engine.ts`: added reversible location letter opacity.

Added runtime files:

- `src/components/site/landing-learning.tsx`
- `src/components/site/landing-scenes-engine.ts`
- `src/components/site/landing-scenes.css`

The business inquiry button uses the existing public contact address,
`mailto:info@findez.ai?subject=FindEZ%20business%20inquiry`. It opens the visitor's
email application with a subject filled in. No contact backend was added.

The removed Capture phone scene and pipeline remain available in
`src/components/site/legacy/landing-lab-before-hero-morph.tsx`; that file is
unchanged. `/lab` continues to use the legacy component. No old assets were
deleted. Header, footer, authentication destinations and other routes are
preserved.

The two updated Jest files cover homepage composition, the inquiry destination,
accessible location text, and ordered/reversible letter opacity. The browser
checker is `check-refinements.cjs`. Screenshots, results, check logs and release
receipts are in `refinements/`. Candidate and live screenshots show the final
implementation; local screenshots record the earlier local review.

## Requested changes to the original SPEC

The screenshot feedback intentionally changes the original hero geometry: the
content now uses fluid gutters and a 1920px maximum instead of the 1160px cap,
scales typography to both viewport dimensions, and fits the photo, card, chip
and copy inside desktop screens. Screens shorter than 600px use the stacked
static layout as well as narrow screens and reduced motion. Detection label
positions are constrained inside the photo, and the pointer hint is hidden on
small phones. The supplied photo, detection coordinates, 1300px pin, morph
curves, counters, question timing and pointer lens remain unchanged.

The separate phone scene and pipeline are intentionally removed from the
homepage according to the later request. There are no known unmatched items
within the updated scope.

## Verification and publication

- TypeScript `--noEmit` passes without diagnostics.
- ESLint passes with zero errors and 55 existing/generated warnings.
- All 325 Jest tests pass in 45 suites.
- The real production Next.js build passes using the existing configuration and fonts.
- Headless Chrome passes on the isolated production candidate and public site at
  2560x1440, 2048x1152, 1920x1080, 1440x900, 1280x720, 1280x600, 1024x768,
  980x600, 768x1024, 390x844, 375x667 and 1440x540.
- The browser checks confirm no hero copy/card collision or viewport clipping,
  no horizontal overflow, contained detection labels, a continuous one-pixel
  pin release directly into memory, reversible location letters and model
  motion, stable model section height, reduced motion, and no runtime errors.

The candidate's eight runtime source hashes match the local files. Publication
changed five existing frontend source files and added three. The remaining 288
original frontend files were verified unchanged by hash, including the
environment file. All 142 previous static build assets were retained for
already open browser tabs.

Only `findez-web` was restarted. Backend, mobile, database, environment values,
CI, DNS, proxy and service configuration were not changed. The previous frontend
build `ocvFkneLLa0EzDFA14ToX` remains intact at
`/home/ubuntu/findez-web-releases/landing-refinements-20261018/frontend` for
rollback. The private preview process and tunnel were stopped after validation.

`refinements/deployment.json`, `refinements/candidate.json` and
`refinements/live/results.json` record the publication and checks.
