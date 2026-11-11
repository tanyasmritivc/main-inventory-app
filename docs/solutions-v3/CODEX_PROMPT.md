# Codex prompt: replace the live findez.ai Solutions page and deploy it directly (web only)

Unzip this folder into the repo at `docs/solutions-v3/`. Then paste everything below the line into Codex from the repo root.

---

**REPLACE THE SOLUTIONS PAGE DIRECTLY ON THE LIVE SELF-HOSTED SITE AND DEPLOY IT. DO NOT MAKE A VERCEL COPY.**

- No Vercel deployment, no Vercel preview, no Render, no local copy, no staging copy.
- The only deploy target is the self-hosted production server for findez.ai.
- If the repo's deploy scripts or config point at Vercel, don't use them: find the self-hosted deploy path. If you can't find it, stop and tell me, and don't deploy anywhere else.

WEB (NEXT.JS) ONLY. `/solutions` ONLY. Replace the current Solutions page at `/solutions` on findez.ai with the new design in `docs/solutions-v3/`, then deploy it straight to production.

## HOW TO WORK: REPLACE DIRECTLY. NO COPY.

- **Edit the real `/solutions` page and its components in place.** Remove the old Solutions sections the new page no longer uses, but only if no other page imports them.
- **Do not make** a copy, a duplicate route, a "v2" or "v3" page, a preview page, a feature flag, or a separate local test version.
- **Do not set up a local preview** to check the design before deploying.
- Only run what the deploy itself needs (install, lint, build, if the deploy runs them). If the build fails, fix it and continue. Never deploy a broken build.
- **Credentials:** never create, print, log, commit or ask for passwords, keys or tokens. If deploy access or any secret is missing, stop and tell me what is missing.

## SCOPE. READ THIS FIRST.

- **Do not touch:**
  - the four solution sub-pages (`/solutions/robotics`, `/solutions/workshops`, `/solutions/makerspaces`, `/solutions/engineering-labs`);
  - the home page, the sign-in page, the signed-in web app and every other route;
  - the backend (FastAPI or any Python), Supabase, auth, env and config files;
  - the mobile app.
- **No new packages.** Everything is plain React, CSS and `<canvas>`. No animation or smooth-scroll libraries.
- **No em or en dashes** in any copy. **No CSS `filter: blur` or `backdrop-filter`** (it caused memory problems in Safari).
- **No numbered lists or step numbers anywhere** (no "01", "02", and so on). The prototype has none. Don't add any.
- **Use the copy in the prototype exactly.** Don't add or remove lines.
- **Sample data:** all questions, answers, counts and spreadsheet rows are sample data. Keep the "Sample data" tag and the note under the audience rows. Nothing on this page calls an API.
- **Shared header and footer:** if the home page redesign (`docs/landing-v3/`) has already been deployed, reuse its header, footer, smooth-scroll and background-mark components instead of making new copies. If it hasn't, build them here as shared components so the home page can reuse them. Tell me which case it was.

## Links (already in the prototype, keep them)

- **Header:**
  - Logo `/`, Solutions `/solutions` (shown as the current page), CAD Intelligence `/#cad`, Founders Access `/founders`, Developers `/docs/api`, Sign in `/signin`, Download `/desktop`.
  - The Community dropdown has Discord `https://discord.gg/sKRrWA5wbf` and Instagram `https://www.instagram.com/findezai/`, both opening in a new tab.
- **Hero:** "Get Free Founders Access" goes to `/signup`; "See how it works" scrolls to `#sm`.
- **Inventory map:** the white button in the bottom-right corner always links to the current tab's page and shows its name:
  - Robotics teams `/solutions/robotics`
  - Workshops `/solutions/workshops`
  - Makerspaces `/solutions/makerspaces`
  - Engineering labs `/solutions/engineering-labs`
- **Audience rows:** each row ends with an "Explore …" button that goes to the same four pages, in the same order.
- **Footer:**
  - Product: Founders Access `/founders`, CAD Intelligence `/#cad`, Solutions `/solutions`, Plans & access `/pricing`, iPhone app `https://apps.apple.com/us/app/findez-ai/id6760401697`, Developers `/docs/api`.
  - Company: Research `/research`, Contact `mailto:info@findez.ai`, Privacy `/privacy`, Terms `/terms`.
  - Community: Discord and Instagram.
- If any of these routes are different in the repo, use the repo's current route and tell me.

## What's in this folder

- **`prototype/findez-solutions.html`:** the finished page, with fonts embedded. Open it in a browser to see the motion.
- **`source/solutions-readable.html`:** the same page without embedded fonts. **Port from this file**: the CSS, the markup and every script, including the `AUD` and `ROWS` data.
- **`screens/`:** the targets.
  - `desktop/01` to `10` go top to bottom: hero, map typing, map path and answer, the Workshops tab, audience rows, the three pinned states, the Community menu and the footer.
  - `mobile/01` to `03` cover the phone layout.

## The page, top to bottom

Monochrome throughout: black `#000`, text `#F5F5F6`, greys `#A1A1A6` and `#6E6E73`, lines `#1C1C1E`, `#232326` and `#2C2C2E`. No accent colour on this page. Fonts: Inter, Inter Tight and Geist Mono from the site's existing setup.

1. **Header.**
   - It turns solid black after 10px of scroll.
   - It **fades and slides up when scrolling down** (after 24px of downward movement) and **comes back on any small scroll up** (12px). It always shows near the top of the page and when it receives keyboard focus.
   - The Community dropdown opens on hover and on keyboard focus.
2. **Hero.**
   - Two-tone headline: "A better way to find what you already have." in white, then "Parts, tools, equipment and supplies, for teams that build things." in grey.
   - Two buttons, then the inventory map.
3. **Inventory map** (`#s-ins`).
   - A panel with four tabs (Robotics teams, Workshops, Makerspaces, Engineering labs) that auto-cycles about every 6 seconds. Clicking a tab plays that one.
   - **Left column:** the question types out. Then the "Resolved path" rows (Space, Storage, Bin, Item) light up one by one, and the answer appears in a white card.
   - **Right side** (`<canvas>`, port `drawGraph()` exactly):
     - a map of 3 Spaces → 9 storage spots → 27 bins → 54 items, drawn as faint dots and curved lines;
     - the selected path draws in white, with a label at each stop and a pulse on the item.
   - **Footer bar:** "inventory map · <audience>", "Sample data", and the white link button described above.
   - It starts when 20% visible and pauses when off screen.
4. **Audience rows.**
   - Headline: "Built around the places where things get lost. / Four kinds of teams. One way to find things."
   - Four rows split by dashed lines. On the left of each: the audience name, the tags in Geist Mono, a headline, the body copy and the "Explore …" button.
   - On the right of each, a small chat: the question types itself when the row is 60% visible, then the answer and the location chips appear.
5. **Pinned "One inventory." section** (`#sm`, 300vh tall with a sticky 100vh inside). Scroll position drives it forwards and backwards:
   - **Left:** the headline and three steps (no numbers): "Bring what you already have", "See it as places", "Ask FindEZ". The active step is white and shows its one-line description.
   - **Right** (`<canvas>`, port `drawSm()` and `ROWS` exactly):
     - 0 to 0.3: the `inventory.xlsx` table with 12 rows;
     - 0.24 to 0.56: each row's rectangle morphs into a drawer tile in a 4×3 wall (3 columns on phones), and the table text crossfades to bin label, name and count;
     - 0.62 to 0.9: a query box types "Where are the 24 tooth HTD pulleys?", a line draws down to the PN-F260 drawer, that drawer turns white while the others dim, and the "18 in bin PN-F260" pill appears.
6. **Footer** with Product, Company and Community columns. There is **no Founders Access panel** on this page.

## Motion system

- **Smooth scrolling on desktop only** (`pointer: fine`):
  - Intercept wheel, arrow keys, Page Up and Down, Space, Home, End and in-page anchor clicks.
  - Ease `window.scrollTo` toward the target at **0.16 per frame**.
  - Don't intercept pinch-zoom (ctrl + wheel) or horizontal scroll.
  - Leave touch devices on native momentum scrolling.
- **One `requestAnimationFrame` loop.** It only redraws the scroll-driven pieces (background mark, pinned canvas) when the scroll position changes or on resize.
- **Background mark** (`#x-bg`, fixed, behind everything): a faint silver FindEZ mark whose petals pull apart into a 2×2 grid of bins and come back together as the page scrolls. It fades out while the inventory map or the pinned section is in the middle of the screen.
- **Headlines** reveal word by word when 40% visible.
- **Canvas sizes:** cap device pixel ratio at 2 for the map, 1.5 for the pinned canvas and 1 for the background.
- **Pausing:** pause canvases when off screen, and clean up every timer, observer and rAF on unmount.
- **Reduced motion:** no smooth scrolling, no auto-cycling, the map shows its first audience fully resolved, the rows show their answers, and the pinned section shows its final state.
- Put each animated piece in its own client component (`"use client"`, `useEffect`). Keep the server-rendered text in the markup for SEO, and keep the page's existing metadata and title.

## After deploying

1. Open the live `/solutions` at 1440×900 and at 390 wide. Scroll the whole page and compare it with `screens/`.
2. Check that:
   - the header hides on scroll down and returns on scroll up;
   - the map cycles and its link button changes with the tab;
   - all four "Explore …" buttons open the right solution pages;
   - the pinned section scrubs forwards and backwards with scroll;
   - every header and footer link works.
3. In Safari, scroll top to bottom twice: it should be smooth, and memory should stay flat over a minute.

## Report back

- How you deployed, and confirmation that nothing went to Vercel or Render.
- The files you changed, added and removed, and whether the header, footer and motion are shared with the home page.
- Any route that differed from the list above.
- The live URL, with one desktop and one phone screenshot of the hero, the inventory map and the pinned section.
- Anything you couldn't match exactly, and why.
