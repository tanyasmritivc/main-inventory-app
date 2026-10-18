# Landing audit before implementation

This is the original local audit. During the later authorized publication, the
running frontend was audited again. Its newer memory headline reveal and existing
homepage omission of the Own and Vision screens were preserved. See
[PUBLISH.md](PUBLISH.md) and the pre-publication source snapshots in `publish/`.

Date: 2026-10-17. Branch: `hero-morph`. Base: `e9c3e27`.
Worktree: `/Users/tanyasmritivictorcharles/dev/findez-hero-morph`.

This audit inspects the locally available implementation identified in the project
release notes as the published Lab homepage. No production site, server, API or
database was accessed. All implementation changes are restricted to `frontend/`.
The original checkout and its unrelated active work are preserved.

## Route and composition

`frontend/src/app/page.tsx` renders `LandingLab` from
`frontend/src/components/site/landing-lab.tsx` with `siteNavigation` enabled.
The route loads Geist and Geist Mono and initializes the existing session-aware
header. `landing-lab-engine.ts` updates the DOM using animation frames;
`landing-lab.css` scopes the existing landing styles under `.fzLab`.

Every section below is in `frontend/src/components/site/landing-lab.tsx`.

| Order | ID | Headline or primary text | File |
| --- | --- | --- | --- |
| 1 | `hero` | FindEZ gives the physical world a memory. | `frontend/src/components/site/landing-lab.tsx` |
| 2 | `stmt` | You don't organize your physical world for FindEZ. FindEZ organizes it for you. | `frontend/src/components/site/landing-lab.tsx` |
| 3 | `see` | Take a picture. That is it. | `frontend/src/components/site/landing-lab.tsx` |
| 4 | `graph` | Knowing what it is is useful. Knowing everything around it is memory. | `frontend/src/components/site/landing-lab.tsx` |
| 5 | `zoom` | Not just "Workshop". Exactly where. | `frontend/src/components/site/landing-lab.tsx` |
| 6 | `ask` | Ask the memory, not a chatbot. | `frontend/src/components/site/landing-lab.tsx` |
| 7 | `own` | Point. Check. Don't buy it twice. | `frontend/src/components/site/landing-lab.tsx` |
| 8 | `who` | One memory for anyone who owns, shares or manages things. | `frontend/src/components/site/landing-lab.tsx` |
| 9 | `find` | Not one giant model. A pipeline. | `frontend/src/components/site/landing-lab.tsx` |
| 10 | `vision` | From inventory to action. | `frontend/src/components/site/landing-lab.tsx` |
| 11 | `app` | Capture. Ask. Find. | `frontend/src/components/site/landing-lab.tsx` |
| 12 | `waitlist` | Be first on the iPhone app. | `frontend/src/components/site/landing-lab.tsx` |
| 13 | `end` (footer) | Take a picture. FindEZ remembers. | `frontend/src/components/site/landing-lab.tsx` |

## Exact replacement boundaries

1. HERO: `#hero`, originally lines 42 to 56. Dark full-bleed workbench
   canvas `#fzField`, scanning lens, white headline and two old actions.
2. STATEMENT: `#stmt`, originally lines 58 to 65. Animated statement words
   beside `app-home.jpg` in a phone frame.
3. CAPTURE INTRO: `#see`, originally lines 67 to 95. The left column contains
   the headline, description and Objects found / Need a look counters. The right
   column contains `bench.jpg`, its SVG detection overlay and labels, and the
   `app-capture.jpg` phone screenshot.

The new `#hero` replaces HERO and STATEMENT and supplies the complete CAPTURE
INTRO through its end state. The old intro headline, body, counters and standalone
intro presentation are removed from the homepage. The existing annotated photo
and Capture screenshot remain together as a subsequent detection beat in `#see`:
the photo is required as the coordinate surface for that existing SVG overlay.
There will be no second unannotated intro photo or second intro copy block.

## Preservation plan

Keep the full original landing component in
`frontend/src/components/site/legacy/landing-lab-before-hero-morph.tsx`.
Keep its original engine and CSS in place. Preserve the original `/lab` route
using that legacy component. Only the homepage composition receives the new hero.
Keep `#graph` through `#end`, the existing header and its engine behavior, all
other routes, assets and destinations unchanged.

The new component uses scoped `.fzh` styles and a separate engine exporting
`init(root)` with complete teardown. Port reference formulas directly, measure
the existing real header, and use the supplied 4:3 workbench asset without edits.
