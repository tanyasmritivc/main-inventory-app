# Public pages v1

## Scope and source

Web presentation only, branch `feat/pages-v1-ui`; do not push. Reference prototype and screenshots are retained beside this report. `content-baseline.json` records the exact original Product, Solutions, Pricing, public landing Research and plan catalog sources for the automated preservation audit.

Research is the only new route, explicitly approved by Tanya. Its entire page copy is taken from the already-published `landing-v5/Research.tsx`. No internal documentation, endpoints, infrastructure details, model internals or nonpublic performance claims were used. The existing current-focus/research distinction and development disclaimer remain. Footer Research now points to `/research`; sitemap includes it.

Developers (`/docs/api`, its public landing section, navigation destination and content), app/auth routes, mobile, backend, data, plan catalog, checkout and deployment configuration source are unchanged. Landing tokens/grain/gradients were extracted verbatim into one shared stylesheet; landing presentation remains the same.

## Section-to-card mapping

| Page | Original section/content | Presentation |
|---|---|---|
| Product | The product; A place for your things; introduction and both links | Blob hero, word entrance, original actions |
| Product | Capture & organize introduction | Split heading |
| Product | Existing workshop photo and caption; Example review with Battery charger, quantity 1, Robotics bench, Back center; review caveat | Sunset showcase plus grey record card, detection box and sequential field reveal |
| Product | Capture / Review / Save / Find, all four descriptions | Four-node scroll-fill pipeline, vertical on phones |
| Product | Ask your inventory, both paragraphs and illustrative charger conversation, photo and caveat | Split heading plus dusk showcase with typed question, waiting dots, answer/location reveal |
| Product | Share & manage; Spaces & access, Equipment & projects, Changes & stock; account/access note | Split heading, three spotlight cards, retained note |
| Product | Make it work for your world; original copy/link | Ember closing card |
| Solutions | Existing introduction, two links and three audience anchors | Blob hero and decorative audience rotation using existing names |
| Solutions | Home: description, three workflow steps, Hall closet example, three questions and caveat | Sticky stack card, grey workflow and sunset/white example |
| Solutions | Workshops & robotics: description, three steps, Robotics bench example, questions and caveat | Sticky stack card, grey workflow and dusk/white example |
| Solutions | Teams: description, three steps, Equipment room example, questions and caveat | Sticky stack card, grey workflow and sage/white example |
| Solutions | Start small. Keep it useful; original copy and links | Moss closing card |
| Research | Building FIND and Partner with us | Blob hero and original contact link |
| Research | Public FIND description | Scroll word reveal, full static text with reduced motion |
| Research | Robots that learn. Not just robots that follow; public evidence labels; Perception, Learning, Adaptation, Robot-agnostic | Ember roadmap with four glass tiles and current-focus marker |
| Research | Active-development/research-goals caveat | Unchanged note below roadmap |
| Pricing | Existing heading, description and pre-launch notice | Blob hero |
| Pricing | Free, Plus, Team, exact catalog descriptions/prices/allowances/actions | Three plan cards; Team ember; existing Monthly/Yearly switch with count-up |
| Pricing | How the planned limits work: all four definitions | Grey information cards |
| Pricing | Existing larger-organization contact text/link | Contact strip |
| Pricing | Before you choose: all five questions and answers | Native expandable FAQ with rotating plus |
| Pricing | Existing payment/availability footnote | Retained footnote |

## Content deliberately not added

No original content was removed or merged away. The prototype's fourth plan, enterprise prices, Most popular assertion, comparison table, additional examples, testimonials, statistics, standalone research pipeline/closing sales copy and extra feature/developer sections were omitted because the current pages have no corresponding content. Teams uses its existing solution workflow rather than invented activity records. Auto Extract animates the existing single review record; it does not fabricate additional detected items.

## Files

- Four route entries under `frontend/src/app/{product,solutions,pricing,research}/page.tsx`.
- Shared page shell, cards, motion hook, plan presentation and scoped stylesheet under `frontend/src/components/pages-ui/`.
- `site/pricing-client.tsx` presentation adapter; shared authenticated plan components untouched.
- `landing-v5/tokens.css`, token extraction in `landing.css`, and the approved Research link in `Footer.tsx`.
- Sitemap, navigation/preservation tests and reference/report documents.

## Validation

- 643 web tests in 89 suites passed. Five preservation checks compare original/current visible words and link destinations, Research against public landing copy, and annual plan data/actions.
- TypeScript passes; lint has zero errors and 52 pre-existing warnings.
- Chrome responsive inspection: all four pages at 1440px and 390px; document width matches viewport in each. Mobile navigation, Solutions sticky/phone-static layouts, annual prices, FAQ and Research footer route verified.
- Inter computed font verified after correcting a global inheritance conflict. Team gradient/white-text contrast corrected and visually checked.
- Reduced motion: no running animations, all Research words fully visible and sharp. CSS also forces full question text and the first audience label without motion.
- Production webpack build passed; all 32 staged and live route/asset checks passed. Published directly to the existing self-hosted service from runtime `95d7c945650bc5568bcdb58d40b8cb38cd4553d1`, build `m6h3XZXrsPhx9gaUQkOwN`. Public HTTPS Product/Research markup and the live Research browser rendering were verified. See `deployment-receipt.json`.
- Developers and billing catalog file hashes match the prior release; the backend process and previous compiled release are preserved. No branch push.
- Live Chrome reported a stylesheet-preload warning; no JavaScript or hydration error was observed. Existing lint warnings remain outside this presentation scope.

Motion uses one rAF scheduler, DOM styles/refs rather than per-frame React state, IntersectionObserver, CSS and WAAPI. No animation dependency added. CSS loops pause offscreen; the scheduler pauses when the tab is hidden. All text remains available to assistive technology and server rendering.

## October 27 follow-up: labels and Developers header

The user approved removal of the small grey eyebrow headings after reviewing the release. Product and Solutions no longer render hero, numbered-section or example eyebrow labels; main headings, body text, navigation links, examples and pricing remain. The section grid now starts the main heading in the first row, reclaiming the removed-label spacing. Research and Pricing have no matching eyebrow headings. Existing preservation checks exclude only the intentionally removed labels.

A separate explicit follow-up authorizes the Developers header theme only: white background, neutral link/focus color and a subtle divider. Its JSX, content, sidebar, layout and destinations remain unchanged. This supersedes the earlier Developers exclusion for header CSS only.

Validation: five content-preservation/plan tests and four existing API documentation tests pass; TypeScript and changed-file ESLint pass. Product capture spacing inspected at 1440px and 390px. Developers header computed white with neutral links and no horizontal overflow at 390px. Production build and all 32 staged/live route checks passed after an unchanged retry for a transient Google-font response. Live browser confirms the white Developers header and 390px fit. Runtime `bf8fa9d9` is published in `labels-header-20261027/frontend`, build `TJhn0LDHD621dTKAVn-fj`. Previous release and backend preserved; no push. Receipt: `labels-header-deployment.json`.
