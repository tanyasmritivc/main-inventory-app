# Hero morph implementation report

This report records the initial local delivery. The later user-authorized live
publication and preservation of newer live landing behavior are documented in
[PUBLISH.md](PUBLISH.md).

Completed locally on branch `hero-morph`, based on `e9c3e27`, in
`/Users/tanyasmritivictorcharles/dev/findez-hero-morph`.
Preview: `http://127.0.0.1:3214/` while the local dev process is running.
Nothing was pushed or deployed. No backend, mobile, database, environment,
CI, DNS or deployment configuration files were modified.

## Audit and replacement

`AUDIT.md` was written before changing application code. It identifies the route,
all 13 original sections in order, and the exact replacement boundaries.

The homepage now has one `#hero` with a 1300px sticky scroll track. The original
hero and `#stmt` are removed from the homepage. The old `#see` headline, body and
counters are removed. Its later SVG detection overlay and Capture phone screenshot
remain together immediately afterward. That overlay retains its original photo
as its coordinate backdrop; there is no second capture intro copy block.

The full original component is retained in the clearly named legacy file below.
It continues to serve `/lab`, whose route file was not changed. No original
component, engine, stylesheet or image was deleted.

The existing header markup, navigation, auth initialization and scroll/fade engine
are unchanged. All markup from `#graph` through the footer is byte-for-byte
unchanged. All other routes are unchanged.

## Changed and added files

Paths in this table are relative to `frontend/`.

| File | Change |
| --- | --- |
| `src/components/site/hero-morph.tsx` | New hero, capture end state, exact copy, actions, card, six detection boxes and chip. |
| `src/components/site/hero-morph-engine.ts` | New `init(root)` engine with teardown, reference formulas, runtime header measurement, rAF DOM painting, hover/drift, reversible counters and Ask cycle. |
| `src/components/site/hero-morph.css` | Reference styles scoped under `.fzh`, prefixed keyframes and static narrow/reduced-motion layout. |
| `src/components/site/landing-lab.tsx` | Homepage composition uses the new hero and retains the subsequent detection beat. Non-homepage preview uses the legacy component. |
| `src/components/site/legacy/landing-lab-before-hero-morph.tsx` | Complete original component, with only its export name and relative import paths adjusted. |
| `public/images/landing/hero-workbench.jpg` | Byte-identical copy of the supplied 1600x1200 reference image. |
| `src/__tests__/landing-page.test.tsx` | Updates composition expectations, verifies removed statement/duplicate intro, retained capture beats and exact hero destinations. Existing header/session tests remain. |
| `eslint.config.mjs` | Allows Node `require()` imports specifically in CommonJS `.cjs` tooling so the existing compile helper and local browser checker pass full ESLint. No application TypeScript rules changed. |
| `design/hero-morph/README.md`, `SPEC.md`, `PROMPT.md`, `reference/index.html`, `reference/assets/*` | Original supplied handoff, retained unchanged. |
| `design/hero-morph/AUDIT.md` | Pre-change route and section audit. |
| `design/hero-morph/check-browser.cjs` | Reproducible local Chrome screenshot and interaction checks. All remote network requests are blocked or fulfilled locally. |
| `design/hero-morph/local-fonts.cjs` | Local-only Next font fixture using existing bundled Geist files read-only. Used only by validation process variables, without changing environment files or font imports. |
| `design/hero-morph/compare/*` | 12 full-resolution comparison pairs, 24 individual screenshots, a reduced-motion screenshot, gallery, browser results and local check logs. |
| `design/hero-morph/IMPLEMENTATION.md` | This report. |

Image SHA-256:
`ba9365e2403a700dc4f9ad962fd1f9f8e15cfb6e2cdd07bbd3c9263b9dc39fb8`.

## Validation

| Check | Result |
| --- | --- |
| `tsc --noEmit` | Pass, no diagnostics. |
| `npm run lint` | Pass, zero errors. 54 existing source warnings and one warning in generated coverage output. |
| `npm run test:ci -- --runInBand` | Pass, 324 tests in 45 suites, with coverage. |
| `next build --webpack` | Pass with synthetic local auth settings and local font fixtures. This compile output is not a deployment artifact. |
| `git diff --check` | Pass. |
| Chrome screenshots | Pass at 1440x900, 1280x720 and 390x844, each at document scroll 0, 500, 900 and 1400px. |
| Pointer lens and idle drift | Pass, including pointer tracking in the narrow static layout. |
| Six-box reveal and counters | Pass: all counts 0 through 6 appear at the staggered thresholds. Needs a look changes to 1 with the gearbox housing. |
| Reverse scroll | Pass: counts return 6, 5, 4, 3, 2, 1, 0. |
| Ask cycle | Pass: all four exact questions/answers, their corresponding highlighted boxes, and observed full intervals of about 4.2 seconds. |
| 1280x720 fit | Pass: headline/actions and card remain inside the viewport without collision. Intentional card/photo/chip layering matches the reference. |
| Narrow layout | Pass: text, photo, card, capture copy; final counts 6 and 1; no sticky stage or horizontal overflow. |
| Reduced motion | Pass: static layout, final counts, stopped drift/caret/row animation; live restoration of normal motion also passes. |
| Browser runtime errors | None in the final interaction run. |
| Original `/lab` | Pass: retains its old statement and scanning canvas. |
| Scope and preservation | All changes under `frontend/`; original legacy component and `#graph` through footer verified against the base source. |

Open `compare/index.html` to browse the pairs. Reference is on the left and the
site is on the right. `compare/browser-results.json` records all 13 browser checks
and measured states. Logs are in the same folder. Screenshots accept the existing
cookie notice and hide the development badge in the test browser only.

The validation browser uses installed Chrome and an already installed Playwright
package. Example command from `frontend/` on this machine:

```sh
NODE_PATH=/Users/tanyasmritivictorcharles/.npm/_npx/e41f203b7505f1fb/node_modules node design/hero-morph/check-browser.cjs
```

The local dev and compile checks use these process-only variables:

```sh
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:9
NEXT_PUBLIC_SUPABASE_ANON_KEY=synthetic-local-only
NEXT_FONT_GOOGLE_MOCKED_RESPONSES=/Users/tanyasmritivictorcharles/dev/findez-hero-morph/frontend/design/hero-morph/local-fonts.cjs
NEXT_TELEMETRY_DISABLED=1
```

## Reference match and limits

All specified constants, curves, timing thresholds, image coordinates, strings
and colors are ported. No unimplemented SPEC requirement is known.

The existing header is intentionally retained, as requested. Its measured height
is 66px in the tested site viewports, whereas the reference uses a different
stand-in header. That causes expected initial vertical offsets and a larger
mobile offset when comparing the same document scroll position. The hero engine
uses the real header height; no 82px fallback is hardcoded.

Idle lens and Ask states depend on elapsed time, so separately captured reference
and site screenshots can show different lens locations or questions. The runtime
interaction checks verify both behaviors. The reference ends in a placeholder;
the site continues into the preserved landing content. These expected differences
are visible in the paired screenshots.

The implementation additionally handles live viewport and motion-preference
changes and cleans up listeners, observers and animation frames on unmount.
The supplied reference chooses reduced motion only once at initial load.
