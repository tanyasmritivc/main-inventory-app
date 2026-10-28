# Public navigation and explainer pages

October 27, 2026. Web-only follow-up to landing v5.

- Centered navigation in a 1200px maximum container; 64px header, 13px links. Product and Solutions open compact click/touch/keyboard disclosures. Mobile gets a Menu control, with outside-click, Escape and focus-leave dismissal.
- Product explains capture/review/save/find, Spaces, Ask and shared management. Solutions covers home, workshops/robotics and teams. Examples are explicitly illustrative; no customer records or fabricated testimonials.
- Removed only the root `/product` redirect so visitors can read the public page. Existing feature subroutes retain their application destinations.
- Pricing reuses the unmodified shared catalog and comparison controls, plus a billing FAQ. Free pre-launch access, disabled subscriptions, USD prices and Team ten-person allowance stay unchanged.
- Developers link remains `/docs/api`; its page and homepage section are untouched. Research is linked in the footer. iOS remains in the footer and Product page.
- Decorative grid markers reduced from 7px to 3px. Other landing sections and animation behavior are unchanged.

Validation: 638 tests / 88 suites pass, TypeScript passes, lint zero errors / 52 existing warnings. Safari desktop Product, disclosure and section navigation verified. At 390px, Product and Solutions layouts, mobile navigation, section links, monthly/yearly prices and FAQ expansion were checked. No Git push/CI under the existing handoff restriction.


Published directly to the self-hosted `public-pages-20261027/frontend` release from runtime `0fd6c40180b8967ecb12441f386847892c3f589c`, build `JhcaFxY6cvqGF_OIeECPJ`. Production compilation/TypeScript and all 30 staged and live route/asset checks passed. Public HTTPS content checks passed for Product, Solutions and Pricing; live Safari Product menu navigation and layout passed. Developers and shared plan catalog hashes were unchanged. Backend process and prior compiled release were preserved. Receipt: `public-navigation-deployment.json`.

Build operations: removed only the previous release's disposable webpack compiler cache to recover space. The first isolated build stalled on a Google font TLS connection; a retry with build-only `NODE_OPTIONS=--tls-max-v1.2` completed. Runtime configuration was not changed. Safari retained an older permanent `/product` redirect for direct address-bar navigation; a fresh query loaded the new page and the live Product menu then navigated correctly to canonical `/product`. No browser data was cleared.
