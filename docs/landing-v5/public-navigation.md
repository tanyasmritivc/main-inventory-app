# Public navigation and explainer pages

October 27, 2026. Web-only follow-up to landing v5.

- Centered navigation in a 1200px maximum container; 64px header, 13px links. Product and Solutions open compact click/touch/keyboard disclosures. Mobile gets a Menu control, with outside-click, Escape and focus-leave dismissal.
- Product explains capture/review/save/find, Spaces, Ask and shared management. Solutions covers home, workshops/robotics and teams. Examples are explicitly illustrative; no customer records or fabricated testimonials.
- Removed only the root `/product` redirect so visitors can read the public page. Existing feature subroutes retain their application destinations.
- Pricing reuses the unmodified shared catalog and comparison controls, plus a billing FAQ. Free pre-launch access, disabled subscriptions, USD prices and Team ten-person allowance stay unchanged.
- Developers link remains `/docs/api`; its page and homepage section are untouched. Research is linked in the footer. iOS remains in the footer and Product page.
- Decorative grid markers reduced from 7px to 3px. Other landing sections and animation behavior are unchanged.

Validation: 638 tests / 88 suites pass, TypeScript passes, lint zero errors / 52 existing warnings. Safari desktop Product, disclosure and section navigation verified; 390px responsive checks and release validation recorded below when complete. No Git push/CI under the existing handoff restriction.
