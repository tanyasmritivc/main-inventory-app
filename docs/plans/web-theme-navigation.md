# Persistent navigation theme and monochrome notifications

Page-owned theme providers removed html.dark when a shell unmounted. World routes, account routes and inventory loading boundaries replace shells, exposing the white canvas. The root layout now owns document appearance independently of page providers. Prepaint canvas/theme-color updates preserve initial appearance; public paths remain light. Storage, system preference and blocked-storage behavior are unchanged.

Notifications use neutral grayscale surfaces, text, icons, unread indicators and hover states in both modes. The app remains primarily monochrome; baby blue stays limited to explicitly requested accents such as Upgrade and resource links.

Validation: 632 tests / 88 suites, TypeScript, ESLint (0 errors / 52 existing warnings), all five CI gates on both runtime commits, production builds and 27 staged/live route checks per release. Regression tests replace shells/loading states and check that dark is not removed, and verify public exits. Safari verified world, account, notifications and inventory-scoped navigation, light public pricing, dark return and the deployed neutral notification dropdown. Screenshots show rendered states, not every transient frame.

6079ec8 deployed theme continuity first; 0eb0f12 adds the user's monochrome dropdown correction. Final release is monochrome-notifications-20261026/frontend, build 3y1vHI9CvrzWK2YDbiDKh. Prior compiled releases remain available. Only disposable caches from inactive releases were removed for build space. Backend process unchanged by both web publishes. API stream guard is isolated in PR249.

Receipt: web-theme-navigation-receipt.json. No mobile, schema, pricing or auth changes.
