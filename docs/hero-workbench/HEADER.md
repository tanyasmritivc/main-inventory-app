# Workbench header refinement

Implemented from header-before-after.png and findez-hero-workbench-2.html. The homepage announcement and nav are transparent above the reference photo gradient. A thin announcement divider remains. Scrolling adds rgba(13,13,15,.72) with 14px backdrop blur. White brand/links and the dark mobile menu remain readable over lower sections. Existing route choices and menu keyboard handling are preserved.

Detection boxes now have 28px edge margins, top >= 196px and a 60px-expanded exclusion above the headline. Existing label clipping protections, timings, photo zoom, text input and intro remain. Other pages use the unchanged standard header variant.

Validation: 649 tests/90 suites; lint zero errors and 52 existing warnings; TypeScript; standard production build; Chrome desktop/390px/320px top and scrolled header, mobile menu/Escape, box bounds, no hex-screw box above the desktop headline, preserved intro, reduced motion, signup handoff and no browser errors. The prefixed backdrop-filter declaration precedes the standard declaration because reversing them caused the production optimizer to omit Chrome's override.

Runtime files: Header.tsx, workbench.css, workbench-motion.ts under frontend/src/components/landing-v5. Self-hosted deployment explicitly authorized by the user.

Published at https://findez.ai from `1ff488a`, build `HaLAIldkJzsUJ54SyaSsf`, after five CI gates (41392829552), server build, 33 staged/live checks and public browser checks at 1440/390/320. Safari top/scroll visually verified. Source/configuration guards preserved all other pages and the backend. Previous compiled release retained. See `docs/plans/hero-header-receipt.json`.
