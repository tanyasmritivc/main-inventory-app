# Codex prompt: replace the live Research page on findez.ai directly

Unzip this folder into the repo at `docs/research-page/`. Then paste everything below the line into Codex from the repo root.

---

WEB (NEXT.JS) ONLY. ONE PUBLIC MARKETING PAGE ONLY. Replace the **current Research page** on the self-hosted findez.ai with the new FIND research page in this folder, then deploy it straight to production.

## HOW TO WORK: REPLACE DIRECTLY. NO COPY.

- **Edit the real Research page in place.** Change the existing Research page file and the components it uses.
- **Don't make any of these:**
  - a copy or a duplicate route;
  - a "v2", preview or staging page;
  - a feature flag;
  - a separate local test version.
- **Don't run a local preview** to check the design before deploying.
- **Only run what the deploy itself needs:** install, lint and build if the deploy runs them. If the build fails, fix the error and continue. Never deploy a broken build.
- **Don't use Vercel or Render.**
  - findez.ai is self-hosted.
  - Don't create, link or deploy to a Vercel or Render project.
  - Don't change any Vercel or Render setting, even if config files for them exist in the repo.
- After deploying, check the page on the live site (see "After deploying").

## What is in this folder

- **`prototype/findez-research.html`:** the finished page. Open it in a browser to see the design and every animation. It opens on Research.
- **`source/site.html`:** the readable source: markup, CSS, data and animation code. **Port from the source, not the built file.** `source/chat.part.html` has the logo mark (`FZ_MARK`) for reference only. Use the site's existing logo component.
- **`assets/`:** put these in `public/research/` and load the photos with `next/image`.
  - `photo-parts-boxes.jpg` = `PH.parts`.
  - `photo-pulley-bins.jpg` = `PH.bins`.
  - `find-hero-points.json` = `FRPTS`: the dot positions for the hero animation. Import it as static JSON; don't fetch it.
- **`screens/`:** the targets.
  - `desktop/` (1440x900) and `mobile/` (390x844), numbered top to bottom.
  - `03-pipeline-1` to `-6` are the six scroll steps of the pipeline section.
  - `motion/` shows the hero animation over its first 4 seconds.

## Exactly which code is the page

`source/site.html` holds the whole marketing site. **Use only the Research page parts:**

- **The page** (`P.research`), in this order:
  1. `FRHERO()`: the large silver "FIND" headline, "FindEZ Intelligent Recognition & Detection", the intro (ending "Currently in development."), and the dot animation on the right with four labels.
  2. `FRWHY()`: "Not one model. A pipeline.", two paragraphs and five plain chips.
  3. `FRPIPE()`: "Research & Development", a sticky scroll section with the parts photo on the left and the six steps on the right. The photo is tagged "Concept illustration". Each step shows its own overlay:
     - instance segmentation: coloured outlines on each object;
     - barcode recognition: a scan across the package label;
     - optical character recognition: "Read: PN-F258";
     - visual embeddings: the match card;
     - confidence-based routing: Resolved and Escalated tags, plus the two-path card;
     - inventory integration: the review card.
  4. `FRDATA()`: "Trained on real robotics benches." with four photo tiles.
  5. `FRLOOP()`: "Every correction teaches FIND." with the orbit ring.
  6. `FRGOAL()`: "A perception pipeline built for real inventory." on the left and three points with thin dividers on the right. **No boxes here.**
  7. `FRSTAT()`: "In development, not yet in production" and its text.
  8. `FREND()`: "Help shape what FIND becomes." with a "Get in touch" button and the address under it.
- **Data:** `FRO`, `FRSTEPS`, `FRPTS`, `PH`.
- **Animation code:**
  - `frHero`: the dots gather into the parts outlines, a scan line passes and the labels appear.
  - `frFrame`: the pipeline scroll steps.
  - `frInit`: starts the above and the tile reveals.
  - `split` / `splitAll`: the word reveal.
  - `.rv`: the reveal on scroll.
  - `.chrome`: the silver headlines, keeping the bottom padding so letters like g and y aren't cut off.
- **Styling:**
  - the CSS block headed `Research page: FIND`, including `.fr-gg` and `.fr-pts`;
  - the `.v4c` and `.dotbg` styles that `FREND()` uses;
  - the base tokens at the top of the file (`--bg`, `--tx`, `--tx2`, `--tx3`, `--line`, `--line2`, `--card`, `--soft`, `--e`, `.wrap`, `.btn`, `.rv`).

Ignore everything else in `source/site.html`. It belongs to other pages that already exist on the live site.

## Content rules

- **Use the prototype's text exactly.** **No em or en dashes** anywhere: copy, code comments or commit messages.
- **Development status must stay clear:**
  - keep "Currently in development." in the intro;
  - keep the "Concept illustration" tag on the pipeline photo;
  - keep the status section saying FIND is not part of the FindEZ app yet;
  - don't add any performance numbers, accuracy claims or launch dates.
- **No glowing or coloured dots next to words or headings.** No status pills or badges with dots. The only dots on the page are the hero animation and the moving dot on the orbit ring.
- **Contact:**
  - "Get in touch" is a `mailto:info@findez.ai?subject=FIND` link;
  - the address `info@findez.ai` is shown under it as plain text.
- The item names, quantities and match bar in the pipeline overlays are illustrative sample visuals. Keep them as static content.

## Scope. Do not touch anything else.

- **Only the Research page changes**, plus shared marketing components it needs.
- **Don't change:**
  - the landing page, Solutions, Founders Access, Plans or any other page;
  - the site nav or the footer. The prototype shows a Research link in both; if the live site already has those links, leave them. If it doesn't, don't add them, and mention it in the report.
  - sign in, sign up and every signed-in app page;
  - the FastAPI backend (any Python), Supabase (tables, migrations, RLS, SQL);
  - API routes, server actions, middleware, auth, data fetching, types;
  - env or config files, and `package.json` dependencies;
  - the mobile app.
- **Keep the existing Research page URL** so current links keep working.
- **Page title:** "FIND Research | FindEZ AI", with a matching meta description taken from the intro text.
- **No new packages.**
  - Use Inter the way the site already loads it.
  - Draw the hero with a plain `<canvas>`.
- **No network requests** from this page apart from its own static files. Nothing calls the backend, OpenAI or any model.
- **Logo:** use the site's existing FindEZ logo component.
- **Old code:** delete the old Research page sections only when nothing else imports them.

## Motion rules

- **Pipeline section:**
  - updates in the scroll handler in the same frame;
  - each step appears the moment its part of the scroll is reached.
- **Hero canvas:**
  - runs only while it's on screen;
  - caps its pixel ratio at 1.5;
  - stops when the page unmounts.
- **Only animate `transform` and `opacity`.** No CSS `filter: blur()` and no `backdrop-filter`.
- **Respect `prefers-reduced-motion`:**
  - the hero shows the finished dot outline with labels;
  - the ring doesn't spin;
  - everything shows in its final state.
- Clear every interval, observer, listener and animation frame on unmount and on route change.

## Git and deploy (straight to production on the self-hosted site)

1. Create a branch `feat/research-find` from the branch production deploys from (usually `main`). Don't include other unmerged branches.
2. Make the changes in place. Commit with a detailed changelog, and push the branch to `origin`.
3. **Deploy to production the way this repo or its docs already deploy the self-hosted web app.**
   - Use the existing method: CI workflows, deploy scripts, a Dockerfile or compose file, or deploy docs. Don't set up a new one.
   - **If production deploys from `main`:** merge the branch into `main` (a normal merge, no force push) and push.
   - **If you can't find a deploy method you can run:** stop after pushing and tell me exactly what step is needed.
   - Don't SSH into any server or run anything on infrastructure that isn't already configured in this repo or on this machine.
   - Never use Vercel or Render.
4. **Credentials:** never create, print, log or ask for passwords, tokens, keys or secrets. If something is missing, stop and tell me exactly what.

## After deploying (on the live site)

1. Open https://www.findez.ai, go to the Research page and compare it with `screens/` at desktop and phone widths, top to bottom. Check:
   - the hero dots gathering and the labels appearing (`motion/`);
   - all six pipeline steps while scrolling;
   - the photo tiles, the orbit ring, the two-column objective section, the status section and the contact button.
2. Check:
   - there are no console errors and no requests besides static files;
   - "Get in touch" opens an email to info@findez.ai;
   - the landing page, Solutions, Founders Access, sign in and the signed-in app look and work exactly as before.
3. **If the page is broken or anything else on the site changed:** roll back with the repo's existing method (revert the merge commit and redeploy), then tell me what went wrong.

## Report

- the live Research page URL;
- the branch, the commit hash, and the merge commit;
- the deploy method you used, and whether it succeeded;
- the output of `git diff --name-only main...feat/research-find`, confirming no backend, API, auth, app, config or other page files changed;
- the old files you deleted;
- whether the nav and footer already link to Research;
- screenshots of the live page on desktop and phone.
