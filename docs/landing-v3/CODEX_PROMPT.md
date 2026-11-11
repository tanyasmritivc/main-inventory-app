# Codex prompt: replace the live findez.ai landing page and deploy it directly (web only)

Unzip this folder into the repo at `docs/landing-v3/`. Then paste everything below the line into Codex from the repo root.

---

**REPLACE THE LANDING PAGE DIRECTLY ON THE LIVE SELF-HOSTED SITE AND DEPLOY IT. DO NOT MAKE A VERCEL COPY.**

- No Vercel deployment, no Vercel preview, no Render, no local copy, no staging copy.
- The only deploy target is the self-hosted production server for findez.ai.
- If the repo's deploy scripts or config point at Vercel, don't use them: find the self-hosted deploy path. If you can't find it, stop and tell me, and don't deploy anywhere else.

WEB (NEXT.JS) ONLY. HOME PAGE ONLY. Replace the current home page (`/`) on findez.ai with the new design in `docs/landing-v3/`, then deploy it straight to production.

## HOW TO WORK: REPLACE DIRECTLY. NO COPY.

- **Edit the real home page and its components in place.** Remove the old landing sections the new page no longer uses.
- **Do not make** a copy, a duplicate route, a "v2" or "v3" page, a preview page, a feature flag, or a separate local test version.
- **Do not set up a local preview** to check the design before deploying.
- Only run what the deploy itself needs (install, lint, build, if the deploy runs them). If the build fails, fix it and continue. Never deploy a broken build.
- **Credentials:** never create, print, log, commit or ask for passwords, keys or tokens. If deploy access or any secret is missing, stop and tell me what is missing.

## SCOPE. READ THIS FIRST.

- **Do not touch:**
  - the backend (FastAPI or any Python) and Supabase (tables, RLS, SQL, auth);
  - the signed-in web app, the sign-in page and other routes;
  - env and config files;
  - the mobile app.
- **No new packages.** Everything is plain React, CSS and `<canvas>`. No animation or smooth-scroll libraries, no three.js.
- **No em or en dashes** in any copy. **No CSS `filter: blur` or `backdrop-filter`** (it caused memory problems in Safari).
- **Use the copy in the prototype exactly.** Don't add or remove lines.
- **All app data shown is sample data.** Keep the "Sample data" tags and the "Example questions and answers." note. Nothing on this page calls an API.
- **Privacy:** the tour uses "Alex", an "A" avatar and "Team Voltage". Never put a real user name, photo or team on this page.
- **Links:** the prototype already uses the live site's routes. Keep them:
  - Logo `/`, Solutions `/solutions`, Founders Access `/founders`, Developers `/docs/api`, Sign in `/signin`, header Download `/desktop`.
  - Community menu: Discord `https://discord.gg/sKRrWA5wbf` and Instagram `https://www.instagram.com/findezai/` (new tab).
  - "Download for iPhone": `https://apps.apple.com/us/app/findez-ai/id6760401697`. "Open the web app": `/signin`. "Join Founders Access": `/signup`.
  - "CAD Intelligence" scrolls to `#cad` on this page (`/#cad` from other pages).
  - Footer: Plans & access `/pricing`, Research `/research`, Contact `mailto:info@findez.ai`, Privacy `/privacy`, Terms `/terms`, plus the Community column.
  - If any of these routes changed in the repo, use the repo's current route and tell me.
- **Plan name:** if the app calls it "Founding Access" instead of "Founders Access", use the app's name everywhere and tell me.

## What's in this folder

- **`prototype/findez-landing.html`:** the finished page with everything embedded. Open it in a browser to see the motion.
- **`source/landing-readable.html`:** the same page with images as `images/...` paths and no embedded fonts. **Port from this file**: CSS, markup and every script. It also contains the CAD Intelligence section (`section.cad`), which must match what is live now.
- **`assets/`:** put these in `public/landing/` and load them with `next/image` where they're plain images.
  - `snap-md.jpg`: the bench photo, brand logos already blurred.
  - `bins-md.jpg`: the top-down bins photo, brand label already blurred.
  - `c0.jpg` to `c5.jpg`: part thumbnails.
  - Keep them exactly as they are. Never use an unblurred version.
- **`screens/`:** the targets. `desktop/01` to `12` go top to bottom through the page and the tour; `mobile/01` to `04` cover the phone layout.

## The page, top to bottom

Monochrome throughout: black `#000`, text `#F5F5F6`, greys `#A1A1A6` and `#6E6E73`, lines `#1F1F21` and `#2C2C2E`. The only colour is amber `#E3B45C` for "Needs review" tags and for the CAD shortage chips. Fonts: Inter, Inter Tight and Geist Mono from the site's existing setup.

1. **Header.**
   - Logo left, links centred, "Sign in" and a white "Download" pill on the right.
   - It turns solid black after 10px of scroll.
   - It **fades and slides up when scrolling down** (after 24px of downward movement) and **comes back on any small scroll up** (12px). It always shows near the top of the page and when it receives keyboard focus.
2. **Hero.**
   - Two-tone headline: "The AI inventory for people who build things." in white, then "Snap a shelf. Ask where anything is. Get the exact bin." in grey.
   - Two buttons, then "Free through Founders Access".
   - Below: the **product tour window**.
3. **Product tour** (`#x-stage`). A 1160×720 replica of the FindEZ web app, scaled to the column width:
   - The window is shown in the app's real layout: sidebar, top bar, ask box, and the Review extraction panel.
   - A cursor plays this loop (port the `tour()` timeline exactly):
     1. Attach a photo and type "Add everything on this bench".
     2. Review extraction opens, a scan sweeps the photo, numbered pins drop, and six items fill in.
     3. Open "Choose a Space", pick Workbench, then "Save 6 items to Workbench".
     4. A saved toast shows.
     5. Ask "Where are the washers?" and show the answer with its item card.
     6. Wait, then loop.
   - Pause / Play button under the window. Escape also pauses.
   - Starts when 30% visible.
   - **Scroll tilt:** the window starts tilted back (rotateX 16deg, scale 0.93) and flattens over the first 520px of scroll.
4. **CAD Intelligence** (`#cad`): keep it exactly as it is live now.
5. **Pinned photo-to-list section** (`#pm`, 320vh tall, sticky 100vh inside). Scroll position drives it forwards and backwards:
   - Left: "From a photo to a parts list. / Scroll to watch FindEZ work." and three steps: "See every bin", "Pick out every part", "Turn it into a list". The active step is white and shows its one-line description. **No progress bars.**
   - Right, on a `<canvas>`, the bins photo is rebuilt as a grid of squares in the **photo's real colours** (60×80 samples):
     - 0 to 0.2: a scan line sweeps down.
     - 0.18 to 0.42: the background squares fade and drift, and labelled boxes appear on the six parts.
     - 0.45 to 0.78: each part's squares fly into a thumbnail in a list.
     - 0.72 to 0.92: names fade in and counts tick up.
   - Port `BOX`, the sampling and `drawPm()` exactly.
   - On phones the steps sit in a row at the top and the canvas sits below.
6. **Examples.** Headline "Built for people who manage a lot of physical things / and need answers fast.", a slow sideways row of dashed question cards (CSS animation, 70s loop, duplicated for a seamless loop), then the note "Example questions and answers."
7. **Founders Access** (`#x-fa`), a standout panel:
   - A large rounded card with a soft glow and a canvas dot field that ripples outward.
   - Copy: the "FOUNDERS ACCESS" label, "Get in early.", the subline, and a 2-column checklist (Ask FindEZ anything / Snap a shelf, get a parts list / Add new items / Import a spreadsheet).
   - Two buttons and the fine print.
   - On the right, a 3D brushed-silver pass:
     - It shows the black FindEZ mark, "Founders Access", "Early member" and "Free until launch".
     - It turns to face the viewer as it scrolls into view and tilts slightly with the pointer.
     - A sheen sweeps across it.
   - If the app's Founders Access plan doesn't include one of the four checklist items, remove that line and tell me.
8. **Footer:** as in the prototype.

## Motion system (port from the "v2 motion layer" script)

- **Smooth scrolling on desktop only** (`pointer: fine`):
  - Intercept wheel, arrow keys, Page Up and Down, Space, Home, End and in-page anchor clicks.
  - Ease `window.scrollTo` toward the target at **0.16 per frame**, so it follows immediately and glides about a third of a second.
  - Don't intercept pinch-zoom (ctrl + wheel) or horizontal scroll.
  - Leave touch devices on native momentum scrolling.
- **One `requestAnimationFrame` loop.** It only redraws the scroll-driven pieces when the scroll position changes or on resize: the hero tilt, the background mark and the pinned canvas.
- **Background mark** (`#x-bg`, fixed, behind everything):
  - A faint silver FindEZ mark whose four petals pull apart into a 2×2 grid of bins and come back together as the page scrolls.
  - It fades out while the pinned section or the Founders Access panel is on screen.
- **Headlines** reveal word by word when 40% visible.
- **Canvas sizes:** cap device pixel ratio at 1.5 for the pinned canvas and 1 for the background canvas.
- **Pausing:** pause canvases when off screen, and clean up every timer, observer and rAF on unmount.
- **Reduced motion:** no smooth scrolling, no tilt, no tour loop (show its final answer state), the pinned section shows its finished list, and the marquee stops.
- Put each animated piece in its own client component (`"use client"`, `useEffect`). Keep the server-rendered text in the markup for SEO.

## After deploying

1. Open the live findez.ai at 1440×900 and at 390 wide. Scroll the whole page and compare it with `screens/`.
2. Check that:
   - the header hides on scroll down and returns on scroll up;
   - the tour loops and Pause works;
   - the pinned section scrubs forwards and backwards with scroll;
   - Founders Access, Download and Sign in all go to the right places.
3. In Safari, scroll top to bottom twice: it should be smooth, and memory should stay flat over a minute.

## Report back

- How you deployed, and confirmation that nothing went to Vercel or Render.
- The files you changed, added and removed.
- The routes each button uses, and whether the plan is called Founders or Founding Access.
- The live URL, with one desktop and one phone screenshot of the hero, the pinned section and Founders Access.
- Anything you couldn't match exactly, and why.
