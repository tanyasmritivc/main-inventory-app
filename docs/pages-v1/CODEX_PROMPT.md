# Codex prompt: restyle Product, Solutions, Research and Pricing (web)

Before you run this, put these files into the repo:

| File | Goes to |
| --- | --- |
| `findez-pages.html` | `docs/pages-v1/findez-pages.html` (the reference prototype; open it in Chrome and use the nav) |
| `product.png`, `solutions.png`, `research.png`, `pricing.png` | `docs/pages-v1/` |

Then paste everything below the line into Codex from the repo root.

---

WEB (NEXT.JS) ONLY. Restyle the existing Product, Solutions, Research and Pricing pages so they look and move like `docs/pages-v1/findez-pages.html` and the screenshots next to it.

**The prototype is a UI reference only. Its words are placeholders.** Keep every heading, paragraph, list item, plan name, price, limit and FAQ that our pages already have. Put that existing text into the prototype's card types, layout, colours and animations. Do not copy any text from the prototype.

## Scope (strict)

- Do NOT change the FastAPI backend, Supabase, the Flutter app, env files, CI or deploy config.
- Do not change the landing page, app routes (dashboard, inventory and so on) or auth.
- Do not change routes, links, prices, plan logic, checkout or any data. Only the presentation of these four pages changes.
- **Never invent copy:**
  - If a prototype block has no matching content on our page, leave the block out.
  - If our page has content with no matching block, use the closest card type below.
- Work on a new branch `feat/pages-v1-ui`. Do not push.

## Find the content first

1. Locate the current Product, Solutions, Research and Pricing pages and their components.
2. List each section's existing text and data.
3. Map each section to one of the card types below.
4. Show the mapping in your final summary.

## Visual system

Reuse the landing page's tokens, grain and gradients if they already exist (for example `components/landing-v5/`). Do not duplicate them.

- **Colours:** black and white UI only.
  - Ink `#0B0B0C`, secondary `#55565B`, tertiary `#8C8D92`.
  - Lines `#ECEAE6`, light card `#F5F4F1`, page `#FFFFFF`.
  - Colour appears only inside the grainy gradient cards.
- **Fonts:**
  - Inter 400/500/600 for everything.
  - Plus Jakarta Sans 600 for the "FindEZ" wordmark only.
  - Geist Mono for counts, quantities and confidence scores.
- **Headings:**
  - Weight 400, letter-spacing −0.03em, line-height 1.08.
  - Page hero h1 is `clamp(36px, 4.6vw, 60px)`; section h2 is `clamp(30px, 3.3vw, 44px)`.
- **Body:** 17px/1.55, secondary colour.
- **Buttons:** 46px pill.
  - Black: `#0B0B0C` with white text.
  - White: white with a 1px `#ECEAE6` inner line.
  - Glass, used on dark gradient cards: `rgba(255,255,255,.14)`, a 1px white/40% inner line and an 8px backdrop blur.
- **Layout:**
  - Content sits in a centred 1152px column with 1px `#ECEAE6` hairlines on its left and right.
  - Each section has 110px vertical padding (80px on mobile) and a hairline at the bottom.
  - Small 7px black squares sit on the two bottom corners of each section, where the hairlines meet.
- **Grain:** the inline SVG `feTurbulence` noise from the prototype (`.grain::after`), with overlay blend at 0.55 opacity, on every gradient.
- **Gradients:** copy all eight exactly from the prototype CSS: `.g-sunset`, `.g-dusk`, `.g-dawn`, `.g-ember`, `.g-sage`, `.g-lilac`, `.g-moss` and `.g-plum`.
  - Use the light ones (dawn, sage, lilac) only behind white cards.
  - Use the dark ones (sunset, dusk, ember, moss, plum) wherever white text sits on the gradient.

## Card types

| Card | Look | Use it for |
| --- | --- | --- |
| **Page hero** | No card. Drifting blurred colour blobs (peach, blue, lilac; 26–34s loops) with grain, fading to white at the bottom. The blob colours change per page, as in the prototype. Centred h1, one paragraph, buttons. | The top of each page |
| **Split heading** | Two columns: h2 on the left, paragraph and optional buttons on the right, aligned to the bottom. Stacks on mobile. | The intro of every section |
| **Gradient showcase card** | Radius 26px, a dark grainy gradient, a white product card or chat floating in the middle, and a caption in white at the bottom (small label plus one bold line). | A feature with a visual (Auto Extract, Ask, perception) |
| **Spotlight card** | `#F5F4F1`, radius 22px, padding 22px. A 40px white icon tile at the top, a small grey label and a 16px/500 line at the bottom. | Feature grids, "ways to add", the problems list |
| **Stack card** | White shell, radius 28px, 12px inner padding. Left: a grey panel with a small label, h3 (28px), a list with hairlines and a "Start free" button. Right: a grainy gradient panel with a white Q&A bubble. | Solutions use cases (one card per audience) |
| **Feature list + gradient** | A grey list card with icon rows beside a grainy gradient card holding a white workspace or activity card. | Teams |
| **Strip** | A grey rounded bar with text on the left and a black button on the right. | Organizations or enterprise contact, developer API |
| **Pipeline** | A row of 64px round icon nodes joined by a line, each with a title and a short line underneath. Vertical on mobile. | Step-by-step "how it works" content |
| **Roadmap card** | A dark grainy card with a large heading and four glass tiles (`rgba(255,255,255,.1)`, 10px backdrop blur). The first tile has a pulsing dot and the label "Current focus". | FIND research pillars |
| **Plan cards** | Four columns of grey cards. The highlighted plan uses the `.g-ember` gradient with white text and a "Most popular" glass tag. Each card has the name, a description, a large price (46px, tabular numbers), the billing line, a button and a checklist. | Pricing plans |
| **Compare table** | Hairline rows, a grey header row, black round ticks, and grey dashes for "not included". It scrolls sideways on small phones. | Plan comparison |
| **FAQ** | Hairline rows with a round + button that rotates 45° when open. | Pricing questions |
| **Closing card** | A dark grainy gradient, radius 28px, centred h2, a line of text, and white plus glass buttons. | The last section of each page |

## Motion (match the prototype; one curve: `cubic-bezier(.32,.72,0,1)`)

Only build an animation if the section it belongs to exists on our page.

- **Blur Text:** hero headline words enter one after another (opacity 0 → 1, blur 10 → 0, y 0.35em → 0, 950ms, 85ms apart). The paragraph and buttons follow.
- **Reveal:** every section block enters once when it reaches 92% of the viewport (opacity, y 18 → 0, blur 6 → 0, 800ms), with small staggered delays inside grids.
- **Grainient:** gradient cards drift (`background-size: 170%`, background-position animating over 20s, alternate).
- **Spotlight:** on hover, a 260px soft white light and a faint dark edge follow the pointer (CSS variables `--mx` and `--my`).
- **Rotating Text** (Solutions hero, if the page names several audiences): the audience names cycle every 2.6s inside a grainy gradient pill. Words slide up with blur, the pill's width animates to fit, and the gradient crossfades.
- **Scroll Stack** (Solutions use cases):
  - cards are `position: sticky` at `88px + i × 18px`;
  - each earlier card scales down by 0.035 and darkens slightly as later cards arrive;
  - the effect scrubs with scroll;
  - turn it off below 900px.
- **Animated List** (Auto Extract visual): detection boxes appear on the photo and the matching rows slide in one by one, then the sequence loops.
- **Typed chat** (Ask visual): the question types out, three dots show, then the answer and location chip fade in, and the sequence loops. Use example questions that already exist in our app or landing copy.
- **Scroll Reveal** (the long Research paragraph): words go from 14% opacity and 3px blur to fully sharp as the paragraph scrolls through the viewport.
- **Pipeline fill:** the connecting line fills with scroll, and each node turns black as the line reaches it.
- **Count Up** (Pricing): the Monthly / Yearly toggle has a sliding black knob. Prices count to the new value over 650ms and the billing line crossfades. Only add the toggle if our pricing already has yearly prices.
- **Nav:** a soft grey pill slides under the current page link, the nav turns frosted white after 8px of scroll, and below 900px it becomes a menu button with a dropdown.
- **Performance and accessibility:**
  - Drive all scroll effects from one `requestAnimationFrame` loop that writes styles through refs, with no per-frame React state.
  - Loops only run while their section is on screen.
  - With `prefers-reduced-motion`, everything is static and fully visible.

## How to build it

- Put shared pieces in `frontend/components/pages-ui/` (or the repo's equivalent):
  - `Grain`, `GradientCard`, `SpotlightCard`, `SplitHeading`, `PageHero`, `BlurText`, `RotatingText`, `ScrollStack`, `Pipeline`, `PlanCard`, `CompareTable`, `Faq`, `ClosingCard`;
  - one `useScrollFrame` hook for the rAF loop.
- **React Bits** (reactbits.dev) is the inspiration for Blur Text, Rotating Text, Scroll Stack, Spotlight Card, Animated List, Scroll Reveal, Count Up and Grainient.
  - Write lightweight versions with CSS and the Web Animations API.
  - Use `motion` only if it is already in package.json.
  - Do not add GSAP, three.js or WebGL.
- Scope all styles to these pages, with no global leaks.
- Use `next/image` for photos and the existing brand mark (the black Petals logo).

## Check before you finish

- `npm run lint` and `npm run build` pass.
- Each page renders at 1440px and 390px with no horizontal scroll.
- White text on gradient cards stays readable.
- Every word on the four pages came from our existing pages. List any section you dropped or merged.
- Prices, plan names and limits are unchanged from the current pricing page.
- Reduced motion works.
- Commit on `feat/pages-v1-ui`. In the summary, include:
  - the files changed;
  - the section-to-card mapping for each page;
  - anything from the prototype left out because there was no matching content.
