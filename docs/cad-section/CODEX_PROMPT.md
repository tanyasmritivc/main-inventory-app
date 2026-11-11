# Codex prompt: add the CAD Intelligence section to the live landing page (web only)

Unzip this folder into the repo at `docs/cad-section/`. Then paste everything below the line into Codex from the repo root.

---

**ADD THIS DIRECTLY TO THE LIVE SELF-HOSTED SITE. DO NOT MAKE A VERCEL COPY.** No Vercel deployment, no Vercel preview, no Render, no local copy and no staging copy. The only deploy target is the self-hosted production server for findez.ai. If the repo's deploy scripts or config point at Vercel, don't use them: find the self-hosted deploy path. If you can't find it, stop and tell me, and don't deploy anywhere else.

WEB (NEXT.JS) ONLY. LANDING PAGE ONLY. Add the new **CAD Intelligence** section to the home page of the self-hosted findez.ai, **directly below the first screen** (the hero with the chat box and the Download and Sign in buttons). Then deploy it straight to production.

## HOW TO WORK: CHANGE THE LIVE PAGE DIRECTLY. NO COPY.

- **Edit the real home page in place** and add the section as a new component.
- **Do not make** a copy, a duplicate route, a "v2" page, a preview page, a feature flag, or a separate local test version.
- **Do not set up a local preview** to check the design before deploying.
- **Deploy to the live self-hosted site** the way this repo already deploys to it. **Never use Vercel or Render**, not even for a preview.
- Only run what the deploy itself needs (install, lint, build, if the deploy runs them). If the build fails, fix it and continue. Never deploy a broken build.
- **Credentials:** never create, print, log, commit or ask for passwords, keys or tokens. If deploy access or any secret is missing, stop and tell me what is missing.

## SCOPE. READ THIS FIRST.

- **Add one section. Change nothing else.**
  - Don't change the first screen: its headline, chat box, Download and Sign in buttons, or spacing.
  - Don't move, restyle or remove any section that comes after it. The new section slots in between.
  - Don't change the navigation in this task.
- **Do not touch:** the backend (FastAPI or any Python), Supabase, auth, env and config files, dependencies (no new packages), or the mobile app.
- **No em or en dashes** in any copy. **No CSS `filter: blur` or `backdrop-filter`** (it caused memory problems in Safari).
- **Copy:** use the exact wording in the prototype. Don't add or remove lines.
- **The comparison window is sample data.** Keep the "Sample data" tag in the window and the note under it. The data is hard-coded for display only and must not call any API.

## What's in this folder

- **`prototype/findez-cad-section.html`:** the finished section. A plain placeholder at the top stands in for the first screen; **don't port the placeholder**.
- **`source/cad-section-readable.html`:** the same file without embedded fonts. **Port from this file**: the CSS, the markup and the script.
- **`screens/`:** the targets.
  - `desktop/1-section-1440x900.png`: the finished state.
  - `desktop/2-button-hover.png`: the button hover.
  - `desktop/3-reduced-motion.png`: how it looks with Reduce Motion on.
  - `mobile/1-section-390.png`: the stacked phone layout.
  - `motion/1-uploading.png` to `5-finished.png`: the animation in order.

## The design

Match the site's existing tokens: black background, text `#F5F5F6`, secondary `#A3A3A8`, tertiary `#6C6C71`, lines `#232325` and `#323235`, amber `#E3B45C` (the same amber the site uses for low stock). Use the site's existing Inter and Geist Mono fonts. Don't add font files.

### Layout

- Section padding: 140px top and bottom (96px and 88px under 980px). Content max width 1240px, side padding 40px (16px on phones).
- A faint dot grid sits behind the section: 1px dots every 28px, white at 16% opacity, masked by a radial gradient centred to the right so it fades out toward the edges. Use CSS only.
- **Two columns** (about 0.9 : 1.1, gap 72px), vertically centred. **Below 980px:** one column, copy first, window below (gap 44px).

### Left: copy

- "Design it. / Find it. / Build it." on three lines. Inter 400, 64px, line height 1.02, letter spacing -0.045em (44px on phones).
- "Can you build it with what you already own?" Inter 400, 26px, text colour, 22px below (21px on phones).
- "Bring your Autodesk Fusion assembly into FindEZ. Compare its parts with your inventory, see what's available, and find what's missing." 17px, line height 1.55, secondary, max width 470px, 18px below.
- **Button** 34px below: "Explore CAD Intelligence →". 46px tall pill, background `#F5F5F6`, black text 15px weight 500. Hover: background white and the arrow nudges 3px right.
  - **Link:** if the repo already has a CAD Intelligence page, link to it. If not, link to the existing sign-up page with `?ref=cad` for now. Don't create a new page. Tell me which you used.
- "Available for **Autodesk Fusion** · Preview" 16px below the button: 13px tertiary, with "Autodesk Fusion" in secondary weight 500.
- Don't use any Autodesk logo. The name is text only.

### Right: the comparison window

- Card: radius 18px, background `#0F0F10`, 1px ring `#232325`, a deep soft drop shadow.
- **Title bar** (44px): three small grey circles, "CAD Intelligence", and a "Sample data" tag on the right (pill, 1px ring `#323235`, 12px secondary).
- **File row:** a cube icon tile, "drivetrain_v4" and "Exported from Fusion with the FindEZ add-in". On the right, a thin upload progress bar that becomes "Uploaded · 8 components" when done (the text is hidden on phones).
- **Model panel** (176px tall): a slowly turning drivetrain drawn as dots on a `<canvas>`. Each group of dots belongs to one component in the table. Port the point generation and drawing code exactly from the source.
  - Dots are dim grey before they're compared.
  - The component being matched pulses bright white.
  - Matched components stay white. Short or missing components turn amber.
  - A small label at the bottom left reads "Reading assembly", then "Matching: <component>", then "Shortages shown in amber".
- **Table:** Component (name, plus a small location line under it, hidden on phones), Needed, In stock, Status. Numbers in Geist Mono. Rows are 52px with a 1px top line.
  - Status chips: "Ready" (outlined, secondary), "Short N" (amber fill, dark text), "Missing" (amber outline and amber text). Short and missing rows get a faint amber row tint. Chips never wrap.
  - Use the eight rows from the source exactly, including their numbers and locations.
- **Summary row:** "5 of 8 ready", a split bar (white for ready, amber for short), and "3 short or missing".
- **Note** under the window, right-aligned, 12.5px tertiary: "Sample data. Component names and counts are for illustration."

### Animation (port the timings from the source)

1. Starts once, when the window is 35% visible (IntersectionObserver).
2. The upload bar fills over 1.5s, then the file row shows "Uploaded".
3. Every 0.34s the next row slides up and fades in. A soft light band moves to that row. Its stock count ticks up, and its status chip appears about 0.43s later.
4. When all rows are done, the summary bar fills. The finished state holds for about 6.5 seconds, then the sequence replays.

Also:

- **Reduce Motion:** show the finished state straight away, with no loop and a still model.
- Pause the canvas when it's off screen (IntersectionObserver on the canvas). Cap the canvas pixel ratio at 2 and resize it with the window.
- Put the animation in a client component (`"use client"`) with `useEffect`. Clean up timers, `requestAnimationFrame` and observers on unmount.

## After deploying

1. Open the live home page at 1440 wide and on a phone width (390). The new section sits directly below the first screen, and the first screen looks exactly as before.
2. Compare the section with `screens/`. Let the animation play through once and check it replays.
3. Check Safari: smooth scrolling, and memory stays flat over a minute.

## Report back

- How you deployed, and confirmation that nothing was deployed to Vercel or Render.
- The files you changed or added.
- Where the button links to.
- The live URL you checked, with a desktop and a phone screenshot of the new section.
- Anything you could not match exactly, and why.
