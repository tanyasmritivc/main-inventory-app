# FindEZ landing page (prototype "C · Lab"): handoff for Codex

This folder is everything Codex needs to rebuild the approved landing page prototype in the Next.js frontend, pixel for pixel.

## What is in here

| Path | What it is |
| --- | --- |
| `reference/index.html` | The approved prototype as a standalone page. Open it in Chrome. This is the source of truth for how everything looks and moves. |
| `reference/assets/` | Every image the page uses (photos already cleaned of third party logos, app screenshots, wordmark). |
| `source/Lab.dc.html` | The prototype source. All markup, CSS and every animation formula, with exact numbers. |
| `tools/compare.mjs` | Screenshots the reference and the new page at the same scroll positions (desktop and mobile) so they can be compared side by side. |

## Setup (Tanya)

1. Copy this whole folder into the repo at `frontend/design/landing-lab/`.
2. Open Codex in the repo and paste the prompt below.
3. When Codex finishes, open `http://localhost:3000/lab` next to `reference/index.html` and compare. The current homepage is not touched until you approve.

## How to read `source/Lab.dc.html`

The prototype was built in a design tool with a tiny template syntax. Mapping to React:

| Prototype | Meaning in React |
| --- | --- |
| `<helmet>` | Global CSS and font links. Move into a scoped stylesheet. |
| `style="{{name}}"`, `{{name}}` | A value computed in `renderVals()` from scroll state. Same formula, same numbers. |
| `<sc-for list="{{x}}" as="y">` | `x.map(y => ...)` |
| `<sc-if value="{{x}}">` | `{x && (...)}` |
| `class Component extends DCLogic` | The page logic: `onScroll()` computes progress values per section, `renderVals()` turns them into styles. |
| `assets/...` | Files in `reference/assets/`. |

Prototype only, do not port: the `H >= 2000` "still" branch in `onScroll()` (it exists only for the design canvas preview) and the `data-props` / `$preview` attribute. Use `prefers-reduced-motion` for the finished, motionless state instead.

---

## Paste this into Codex

```
Task: Rebuild the approved FindEZ landing page prototype in the Next.js frontend, matching it exactly. Web frontend only.

Source of truth (read all of it first):
- frontend/design/landing-lab/reference/index.html  (open in Chrome, scroll through it)
- frontend/design/landing-lab/source/Lab.dc.html    (markup, CSS, every animation formula)
- frontend/design/landing-lab/README.md             (syntax mapping, what not to port)

Where to build:
- New route: frontend/src/app/lab/page.tsx, with metadata robots noindex. Do NOT change frontend/src/app/page.tsx or the current landing components. Tanya will approve before it replaces the homepage.
- Follow the same pattern as the existing landing-morph files:
  - frontend/src/components/site/landing-lab.tsx         markup only ('use client')
  - frontend/src/components/site/landing-lab-engine.ts   all scroll, canvas and per-frame behavior; export initLandingLab(root): () => void (teardown)
  - frontend/src/components/site/landing-lab.css         every rule scoped under .fzLab, keyframes prefixed fzl-
- Copy images from design/landing-lab/reference/assets/ to frontend/public/images/landing-lab/ and reference them from there.

Exactness rules:
- Port every formula in renderVals() and onScroll() with the same constants (ss() smoothstep, c() clamp, L() lerp, section heights pinH + 2300 and pinH + 2900, multipliers, delays). Do not "simplify" timings.
- The engine must write styles directly to elements (refs or data attributes) inside requestAnimationFrame. Do NOT drive per-frame animation through React state.
- Keep the same section ids: hero, stmt, see, graph, zoom, ask, own, who, find, vision, app, waitlist, end. The compare tool depends on them.
- Fonts: Geist and Geist Mono via next/font/google, applied only inside .fzLab.
- Colors exactly as in the source: #000, #FFF, #111112, #EAEAEA, #8C8C8C, #6B6B6B, brand orange #E8590C, dark orange text #C2410C, plum #79648C.
- Header logo: inline the SVG wordmark from reference/assets/findez-wordmark.svg (mark plus "Find" in #111112 and "EZ" in #E8590C). Footer wordmark uses the same glyph paths without the mark, as in the source.
- Labels that change during scroll (photo detection tags, memory graph nodes, location names, pipeline steps, the 92% figure) are HTML positioned over the images, not SVG <text>. Keep it that way.
- Hero: canvas that draws the photo darkened, with the scanning lens (cursor follow, idle drift) and the OBJ list of boxes and labels exactly as in startField().
- Eased wheel scrolling (onWheel and glide in the source, factor 0.8, easing 0.09) on desktop only. Touch scrolling stays native.
- Phone frames use the fz-phone, fz-bezel, fz-screen structure with container query units, exactly as in the source.
- No em dashes or en dashes anywhere in copy, code comments or commit messages.

Links:
- "Log in" -> /signin. "Get started" and "Try FindEZ on the web" -> /signup. "Join the iPhone waitlist" -> #waitlist.

Waitlist form:
- Keep the exact UI and validation from the source. Submit handler is a clearly marked TODO that does nothing but show the confirmation state. Do NOT add a backend endpoint or call the API.

Reduced motion:
- With prefers-reduced-motion, show every section in its finished state (the same values the source uses in its "still" branch), no pinned scroll lengths, no canvas animation loop, no eased scrolling.

DO NOT:
- Do not touch backend/, mobile/, the app shell, globals.css tokens, or any other route.
- Do not add dependencies (no GSAP, Framer Motion, Lenis). Everything is plain TypeScript and CSS, as in the source.
- Do not change copy, colors, spacing, images or timings to "improve" them.
- Do not use em dashes or en dashes.

Acceptance criteria:
1. npm run build, tsc --noEmit and eslint pass; existing jest tests still pass.
2. Run: node design/landing-lab/tools/compare.mjs http://localhost:3000/lab
   For every pair in design/landing-lab/compare-out/desktop and /mobile, the -new.png matches the -ref.png in layout, sizes, colors, text and animation progress. Only font anti-aliasing and the hero lens position (it drifts over time) may differ. Fix any other difference and re-run until clean.
3. No console errors. No horizontal scroll at 390px wide.
4. List every file you created or changed, and paste 3 compare pairs (hero, zoom at 50%, vision at 60%) in your final message.
```

---

## Notes

- App screenshots in `reference/assets/app-*.jpg` are 460px wide, a little soft on high resolution screens. For launch, swap in raw iPhone screenshots (1179px wide) with the same names.
- The memory graph values (March, $49, Drivetrain rebuild) are placeholders. Edit them in the engine data when the real values are known.
