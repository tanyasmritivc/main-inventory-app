# Workbench headline intro

Scope: three existing hero runtime files only. The full headline is split into masked words at render time, with one accessible h1 name. The existing ember gradient remains on intelligence. A mount class starts the 1050ms word animations at 150ms + index * 70ms. Composer and hint rise over 900ms at 950ms and 1100ms. Photo fades over 1600ms at 100ms while retaining the existing zoom; detection starts at 1200ms, matching the existing placeholder delay. Reduced motion immediately displays final states, including before hydration.

The later user instruction authorizes pushing and deploying this change to the existing self-hosted site. The original prompt's local-only restriction is superseded.

Local validation: 649 tests/90 suites; lint zero errors and 52 existing warnings; TypeScript; standard npm run build. The initial sandbox-restricted build failed to create its worker port; a clean permitted build passed. Browser checks at 1440x900 and 390x844 confirm final word/layout positions within 0.05px of the prior build, unchanged wrapping, preserved gradient and descenders, stagger order, one-time animation through resize/scroll, signup handoff, and no page errors. Both pre-hydration states and reduced-motion immediate rendering passed.

Runtime files changed:
- frontend/src/components/landing-v5/HeroWorkbench.tsx
- frontend/src/components/landing-v5/workbench.css
- frontend/src/components/landing-v5/workbench-motion.ts

Published at https://findez.ai from runtime `29cefa2` after five CI gates (41391173955), isolated production build, 33 staged/live route checks and public desktop/phone browser verification. Build `k7mpOiTNubm6SFT6ghlmr`. The server build reused the previous successful font/build cache after font-fetch parsing failures; no source/configuration workaround was introduced. Safari desktop visually verified. Other pages, backend and the prior compiled release are preserved. See `docs/plans/hero-intro-receipt.json`.
