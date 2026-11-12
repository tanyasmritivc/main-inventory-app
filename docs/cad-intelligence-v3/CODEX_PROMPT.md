# Codex prompt: replace the live CAD Intelligence page and deploy it directly (web only)

Unzip this folder into the repo at `docs/cad-intelligence-v3/`. Then paste everything below the line into Codex from the repo root.

---

**REPLACE THE CAD INTELLIGENCE PAGE DIRECTLY ON THE LIVE SELF-HOSTED SITE AND DEPLOY IT. DO NOT MAKE A VERCEL COPY.**

- No Vercel deployment, no Vercel preview, no Render, no local copy, no staging copy.
- The only deploy target is the self-hosted production server for findez.ai.
- If the repo's deploy scripts or config point at Vercel, don't use them: find the self-hosted deploy path. If you can't find it, stop and tell me, and don't deploy anywhere else.

WEB (NEXT.JS) ONLY. This is the **public CAD Intelligence page**: the page that explains the feature to visitors. Build it from the design in `docs/cad-intelligence-v3/` and deploy it straight to production.

## WHICH ROUTE

- **If the repo already has a public CAD Intelligence marketing page,** replace that page in place.
- **If not,** create it at `/cad-intelligence`.
- **Do not replace or change** these two existing pages:
  - **`/cad`:** the signed-in comparison tool. The page links to it.
  - **`/docs/cad`:** the setup guide. The page links to it.
- **Point every "CAD Intelligence" link at the public page.** Update only the link targets (`href`), nothing else:
  - the "CAD Intelligence" link in the shared header and footer;
  - the "Explore CAD Intelligence →" button on the home page.
- Tell me which route you used and every link you changed.

## HOW TO WORK: REPLACE DIRECTLY. NO COPY.

- **Edit the real page in place,** or create the one new route above.
- **Do not make** a copy, a duplicate route, a "v2" or "v3" page, a preview page, a feature flag, or a separate local test version.
- **Do not set up a local preview** to check the design before deploying.
- Only run what the deploy itself needs (install, lint, build, if the deploy runs them). If the build fails, fix it and continue. Never deploy a broken build.
- **Credentials:** never create, print, log, commit or ask for passwords, keys or tokens. If deploy access or any secret is missing, stop and tell me what is missing.

## SCOPE. READ THIS FIRST.

- **Do not touch:**
  - the backend (FastAPI or any Python), Supabase and auth;
  - the CAD comparison logic, the Fusion add-in files in `/downloads`, the setup guide;
  - env and config files;
  - the mobile app.
- **Other pages:** only the link changes listed above. Nothing else on any other page.
- **No new packages.** Everything is plain React, CSS, SVG and `<canvas>`. No animation or smooth-scroll libraries.
- **No em or en dashes** in any copy. **No CSS `filter: blur` or `backdrop-filter`** (it caused memory problems in Safari).
- **No numbered lists or step numbers anywhere** (no "01", "02", "1." and so on). The prototype has none. Don't add any.
- **No "Autodesk Fusion · Preview" tag** above the hero headline. It was removed on purpose.
- **Use the copy in the prototype exactly.** Don't add or remove lines.
- **Sample data:** everything in the comparison, results panel, file previews and matching card is sample data. Keep the "Sample data" tag. Nothing on this page calls an API.
- **Facts must match the product.** The wording on statuses, file limits, privacy and limitations comes from `/docs/cad`. If anything there has changed in the repo, use the repo's current wording and tell me.
- **Shared parts:** if the home page and Solutions redesigns (`docs/landing-v3/`, `docs/solutions-v3/`) are already deployed, reuse their header, footer, smooth-scroll and background-mark components. If not, build them as shared components. Tell me which case it was.

## Links (already in the prototype, keep them)

- **Hero:**
  - "Download the Fusion add-in": `/downloads/findez-fusion-preview.zip`.
  - "Open CAD Intelligence": `/cad`.
- **Results panel:** "Export shortages" goes to `/cad`.
- **Supported files:** "Download the CSV template" goes to `/downloads/findez-bom-template.csv`.
- **Get started:**
  - "Download add-in": `/downloads/findez-fusion-preview.zip`.
  - "Read the setup guide": `/docs/cad`.
  - "Open CAD Intelligence": `/cad`.
- **Header and footer:** the same routes as the other redesigned pages, with "CAD Intelligence" shown as the current page.

## What's in this folder

- **`prototype/findez-cad-intelligence.html`:** the finished page, with fonts embedded. Open it in a browser to see the motion.
- **`source/cad-readable.html`:** the same page without embedded fonts. **Port from this file**: the CSS, the markup, the privacy SVG and every script, including the `BOM`, `RS` and `FL` data.
- **`screens/`:** the targets.
  - `desktop/01` to `13` go top to bottom through the page, including four states of the pinned section and the Short tab of the results panel.
  - `mobile/01` to `04` cover the phone layout.

## The page, top to bottom

Monochrome throughout: black `#000`, text `#F5F5F6`, greys `#A1A1A6` and `#6E6E73`, lines `#1C1C1E` and `#2C2C2E`. The only colour is amber `#E3B45C`, for Short and Missing. Fonts: Inter, Inter Tight and Geist Mono from the site's existing setup.

1. **Hero.**
   - Two-tone headline: "Can you build it with what you already own?" in white, then "CAD Intelligence compares a Fusion assembly's parts list with your FindEZ inventory." in grey.
   - Two buttons, then "Free through Founders Access. Setup takes a few minutes."
2. **What it does** (`#cm`, 340vh tall with a sticky 100vh inside, one `<canvas>`; port `drawCm()` exactly). Scroll drives it forwards and backwards:
   - 0.06 to 0.26: a drivetrain point cloud (8 part groups) rotates and explodes apart.
   - 0.2 to 0.44: lines run from each part group to its BOM row.
   - 0.44 to 0.66: the assembly dims and inventory rows appear. Match lines carry an evidence tag (PART NO, BARCODE, or a dashed NAME line). The servo row shows "NO MATCH".
   - 0.68 to 0.9: status chips land on each row (Covered, Short N, Needs review, Missing). The point cloud recolours to match, and a summary with a split bar appears.
   - **Left column:** "Read the parts list", "Match it to your inventory", "See what to buy". The active step is white with its description, and there are no numbers.
3. **What you learn** (`#rs`): a results panel with four tabs (Covered 4, Short 2, Missing 1, Needs review 1).
   - It cycles every 4.6s while visible, and clicking a tab plays it.
   - Rows fade in one by one. A side panel shows that status's definition.
4. **How to use it** (`#pl`): four steps along a line (Export from Fusion, Upload the BOM, Select an inventory, Compare).
   - A white dot travels along the line (CSS animation), and the active step's icon turns white.
   - On phones the steps stack and the line is hidden.
5. **Supported files:** tabs for Fusion JSON, CSV and Excel, cycling every 5.2s. The window on the right writes out a sample of each file type line by line (code for JSON and CSV, a grid for Excel). Under the tabs: the file limits note and the template link.
6. **Matching accuracy** (`#ev`): copy on the left. On the right, a card for "M4 nylock nut" with three evidence bars that fill when 40% visible: exact barcode and supplier part number strong, name only weak.
7. **Privacy:** the inline SVG diagram.
   - The Fusion box holds a slowly rotating wireframe, captioned "Assembly geometry stays here".
   - "name", "part no." and "qty" pills travel along the path to the FindEZ box (SVG `animateMotion`).
   - A dashed label in the middle reads "geometry is never uploaded".
   - Two text columns sit below. On phones the SVG is hidden and only the text shows.
8. **Current limitations:** four rows split by dashed lines, each with a slashed-circle icon, a title and one line.
9. **Get started** (`#start`): three action rows (add-in, setup guide, comparison tool). Next to them, a folder layout writes itself out line by line with the inner `FindEZ/` folder highlighted, plus a one-line install hint.
10. **Footer.**

## Motion system

- **Smooth scrolling on desktop only** (`pointer: fine`):
  - Intercept wheel, arrow keys, Page Up and Down, Space, Home, End and in-page anchor clicks.
  - Ease `window.scrollTo` toward the target at **0.16 per frame**.
  - Don't intercept pinch-zoom (ctrl + wheel) or horizontal scroll.
  - Leave touch devices on native momentum scrolling.
- **The header** hides on scroll down (after 24px) and returns on any small scroll up (12px). It always shows near the top and on keyboard focus. The Community dropdown opens on hover and focus.
- **One `requestAnimationFrame` loop** redraws the scroll-driven pieces only when the scroll position changes or on resize.
- **Background mark** (`#x-bg`, fixed):
  - full strength in the hero;
  - half strength further down;
  - hidden while the pinned section is in the middle of the screen.
- **Headlines** reveal word by word when 40% visible.
- **Canvas sizes:** cap device pixel ratio at 1.5 for the pinned canvas and 1 for the background.
- **Pausing:** pause auto-cycling and canvases when off screen, and clean up every timer, observer and rAF on unmount.
- **Reduced motion:**
  - no smooth scrolling and no auto-cycling;
  - the pinned section shows its final state and the evidence bars show filled;
  - the file preview and folder layout show in full;
  - the pipeline dot and the SVG motion stop.
- Put each animated piece in its own client component (`"use client"`, `useEffect`). Keep the server-rendered text in the markup for SEO. Title: "CAD Intelligence | FindEZ AI".

## After deploying

1. Open the live page at 1440×900 and at 390 wide. Scroll the whole page and compare it with `screens/`.
2. Check that:
   - the pinned comparison scrubs forwards and backwards with scroll;
   - the results tabs and the file tabs cycle and respond to clicks;
   - the add-in download actually downloads the ZIP;
   - "Open CAD Intelligence" reaches `/cad` (sign-in first is fine);
   - the setup guide link works;
   - every "CAD Intelligence" link on the site now points at the public page.
3. In Safari, scroll top to bottom twice: it should be smooth, and memory should stay flat over a minute.

## Report back

- How you deployed, and confirmation that nothing went to Vercel or Render.
- The route you used and every link you changed on other pages.
- The files you changed, added and removed, and whether the header, footer and motion are shared with the other pages.
- Any wording you changed to match the repo's current `/docs/cad`.
- The live URL, with one desktop and one phone screenshot of the hero, the pinned comparison and the results panel.
- Anything you couldn't match exactly, and why.
