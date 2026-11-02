# Workbench hero

Branch: `feat/hero-workbench`, based on web research commit `268fcc5`. Initially completed locally per `CODEX_PROMPT.md`; the user subsequently clarified "please deploy." Runtime `0c0d41c` is now pushed and live at https://findez.ai after all five CI gates and staged/live checks. See `../plans/hero-workbench-receipt.json`.

The homepage now uses the supplied Workbench photo, headline, white composer, announcement band and dark navigation treatment. Object boxes use the reference cover geometry, clipping and center exclusion, 900ms initial delay, 1500ms cadence and 2900ms display time. Placeholder examples type at 28ms per character, hold for 2400ms and delete at 10ms per character. Focus permanently stops typing. Reduced motion disables photo zoom, placeholder typing and box scaling. Visibility and intersection observers pause active time and photo motion off screen; observers and frames are cleaned up on unmount.

The existing bounded signup prompt, recent draft restoration, IME handling and Back recovery are preserved. Add, Speak and Scan keep their existing signup destinations. These are public landing controls; they do not record audio or scan a visitor's photo before signup. The current Solutions/Developers/Pricing destinations are retained, respecting the prior removal of Product. Phone navigation matches the reference over the hero; the existing menu is available farther down the page. Other pages retain the original header. All sections below the hero remain unchanged.

## Changed files

- `frontend/src/components/landing-v5/HeroWorkbench.tsx`: hero and existing prompt handoff.
- `frontend/src/components/landing-v5/workbench-motion.ts`: decorative box placement, typing and lifecycle.
- `frontend/src/components/landing-v5/workbench.css`: scoped reference styles.
- `frontend/src/components/landing-v5/workbench-fonts.ts`: self-hosted Inter Tight 400 and Geist Mono 500 through next/font/google; existing Inter and Jakarta remain.
- `frontend/src/components/landing-v5/Header.tsx`: optional homepage announcement and hero appearance.
- `frontend/src/components/landing-v5/LandingV5.tsx`, `frontend/src/app/page.tsx`: homepage wiring.
- `frontend/public/images/landing/workbench-wide.jpg`: supplied photograph, one request.
- `frontend/src/__tests__/landing-page.test.tsx`: updated requested copy and font mock.
- `docs/hero-workbench/`: supplied prompt, HTML, walkthrough and reference screenshots; implementation notes and browser QA evidence.
- `.agents/ACTIVE_WORK.md`, `.agents/CURRENT_STATE.md`: local task state.

## Validation

- 649 tests across 90 suites passed; 10 focused landing/navigation checks also passed after final React changes.
- `npm run lint` passed with 52 pre-existing warnings and no errors.
- `npx tsc --noEmit` passed; the final standard `npm run build` also passed compilation, TypeScript and prerendering.
- This checkout originally linked node_modules outside the Turbopack root. The link was detached without removing its target and `npm ci` installed the locked dependencies locally. No package, environment or deployment configuration changed. The final build uses the normal command, not a font/configuration substitute.
- Chrome verified 1440x900, 390x844 and 320x844: two-line desktop headline, no horizontal overflow, focus permanently stops typing, off-screen pause/resume, collapsing band, lower-page phone menu and encoded Enter-to-signup handoff. No browser page errors.
- Reduced motion: no photo animation, no typing, no box transforms.
- Full box-cycle sampling at desktop/phone: no clipped labels or overlap with the center block; exactly one photo request. See `qa/animation-checks.json`.
- Reviewed desktop/phone screenshots against the supplied screenshots and extracted walkthrough frames. Existing cookie notice remains; it was dismissed through its normal control for the final visual comparison.

Live: https://findez.ai. Local preview: `http://localhost:3038` while its process remains running. Local screenshots and browser results are in `qa/`; staged/public verification is recorded in the deployment receipt. Publication applied only the eight runtime hero files over the current live release, preserving newer privacy content and other pages.
