# Codex prompt: replace the live Book a Demo page and deploy it directly (web only)

Unzip this folder into the repo at `docs/book-demo-v3/`. Then paste everything below the line into Codex from the repo root.

This replaces the earlier `docs/book-demo-v2/` prompt. Don't run that one.

---

**REPLACE THE BOOK A DEMO PAGE DIRECTLY ON THE LIVE SELF-HOSTED SITE AND DEPLOY IT. DO NOT MAKE A VERCEL COPY.**

- No Vercel deployment, no Vercel preview, no Render, no local copy, no staging copy.
- The only deploy target is the self-hosted production server for findez.ai.
- If the repo's deploy scripts or config point at Vercel, don't use them: find the self-hosted deploy path. If you can't find it, stop and tell me, and don't deploy anywhere else.

WEB (NEXT.JS) ONLY. BOOK A DEMO PAGE ONLY. Replace the current Book a Demo page on findez.ai (the page the header "Book a Demo" button opens, currently titled "Request a demo") with the new design in `docs/book-demo-v3/`, then deploy it straight to production.

## HOW TO WORK: REPLACE DIRECTLY. NO COPY.

- **Edit the real Book a Demo page and its components in place.** Keep its current route, metadata and title. Remove the old pieces the new page no longer uses (the old left column, the search demo card and the "What you'll see" list), but only if no other page imports them.
- **Do not make** a copy, a duplicate route, a "v3" page, a preview page, a feature flag, or a separate local test version.
- **Do not set up a local preview** to check the design before deploying.
- Only run what the deploy itself needs (install, lint, build, if the deploy runs them). If the build fails, fix it and continue. Never deploy a broken build.
- **Credentials:** never create, print, log, commit or ask for passwords, keys or tokens. If deploy access or any secret is missing, stop and tell me exactly what is missing.

## HEADER AND FOOTER: USE THE SITE'S REAL ONES

- **The page must show the site's existing shared header and footer,** exactly as every other findez.ai page does. Import the real components.
- **The header and footer inside the prototype are only a picture of the live ones, for context. Do not copy, rebuild or port them.** Port only the content between them (the framed two-panel section).
- If the current Book a Demo page doesn't use the shared header and footer, switch it to them. Don't change the header or footer components themselves.

## SCOPE. READ THIS FIRST.

- **Do not touch:**
  - every other route and the shared header and footer components;
  - the backend (FastAPI or any Python), Supabase (tables, RLS, SQL, auth), env and config files;
  - the mobile app.
- **No new packages.** Plain React and CSS, with inline SVG for the drawings. No carousel, animation or form libraries.
- **No em or en dashes** in any copy. **No CSS `filter: blur` or `backdrop-filter`.**
- **No numbered lists or step numbers anywhere** ("01", "Step 1" and so on).
- **Use the copy in the prototype exactly.** Don't add or remove lines, labels or tags.

## KEEP THE REAL REQUEST FLOW

The live page today is a request form: the visitor fills it in and Tanya follows up. The new page keeps that flow. There is **no calendar or time picker.**

1. **Find how the current form submits and where the answers go.** For example, an API route, an email, a database insert or a third-party form. Tell me what you found.
2. **Keep that exact submission, field names, option values and validation.**
   - Fields: Full name (required), Work email (required), Company or organization (required), and "What would you like to explore?" (optional, multi-select).
   - Choices: AI inventory search, Robotics inventory, Fusion and STEP models, BOM comparison. If the live values differ, keep the live ones.
   - Don't add fields such as phone.
3. **Show "Thanks, <first name>." only after the submission succeeds.** If it fails, keep the form filled in and show one short error line above the button.

## What's in this folder

- **`prototype/findez-book-demo.html`:** the finished page, fully clickable, with fonts embedded. Open it in a browser.
  - It runs on a tiny template runtime at the bottom of the file. **Don't ship that runtime.**
  - Port the CSS (the `<style>` block), the markup between the header and the footer (inside the `<script id="tpl">` template) and the logic (`class Component`, including the `SLIDES` data and the timer) into React.
- **`screens/`:** the targets.
  - `desktop/01-full-page.png` is the whole page at 1440 wide. Your header and footer replace the ones you see there.
  - `desktop/02` to `05` show the four example cards: Robotics, Hardware, Labs, Workshops.
  - `desktop/06` to `08` show the required-field error, the filled form with two choices picked, and the thank-you state.
  - `mobile/01` and `02` show the phone layout at 390 wide.

## The page

**Colours:** dark, matching the live site.

| Role | Value |
|---|---|
| Page | `#161616` |
| Frame | `#1A1A1A`, 1px `#262626` line, 24px radius |
| Right panel | `#141414` |
| Card | `#1B1B1B`, 1px `#2A2A2A` line |
| Fields | `#121212` with a `#2F2F2F` line |
| Text | `#F3F1EA` |
| Greys | `#C9C7C1`, `#A9A7A1`, `#85837E`, `#6E6D69` |
| Primary button and selected chip or tab | `#F3F1EA` with `#111111` text |
| Required asterisk | amber `#E3B45C` |
| Error text | `#F29B85` |

**Type:** use the site's existing fonts.

- **Headings:** Inter Tight 400, letter-spacing −0.024em. This covers "See FindEZ in action.", "How teams like yours use FindEZ", the card number, the card question and "Thanks, …".
- **Body and fields:** Inter.
- **Small uppercase labels:** Geist Mono.

**Layout:** a centred frame, max 1376px wide, split into two columns (left a little wider). It stacks into one column under 1000px.

- **Left column:**
  - The headline and paragraph, a divider, then the form.
  - Labels sit above the fields. Name and email share a row on desktop, one per row under 560px.
  - The choices are pill buttons that toggle (`aria-pressed`), showing "+" off and "✓" on.
  - The button reads "Request a demo →".
- **Right column:**
  - The heading "How teams like yours use FindEZ", then one card, then four tabs below it: Robotics, Hardware, Labs, Workshops.
  - The card has three parts:
    - a top row with the big number and the mono label;
    - "<team> ASKS", the question in quotes, and the one-line answer;
    - a drawing panel. Port the four inline SVG drawings and the gear and pulley paths from the prototype's `<defs>`.

    | Card | Drawing | Panel colour | Line colour |
    |---|---|---|---|
    | Robotics | bearing | blush `#F4CFD6` | ink |
    | Hardware | gear | maroon `#5C1A27` | blush |
    | Labs | pulley | slate `#26272B` | cream |
    | Workshops | bolt | ink with amber and sky glow corners | white |
- **Behaviour of the cards:**
  - **They change on their own every 4 seconds,** in order, and loop.
  - Clicking a tab shows that card and restarts the 4-second timer.
  - The timer pauses while the browser tab is hidden and while the section is off screen. Clear it on unmount.
  - The tabs are a `role="tablist"` with `aria-selected`.
  - The drawing fades in on change.
  - **Reduced motion:** don't auto-advance; tabs still work.
  - These cards are illustrative examples, not customer data. Keep the copy exactly as it is and don't call any API for them.
- Keep visible focus rings on every field, chip, tab and button.

## After deploying

1. Open the live Book a Demo page at 1440×900 and at 390 wide, and compare it with `screens/`.
2. Check that:
   - the real site header and footer show, with no second header or footer from the prototype;
   - the cards change by themselves every 4 seconds, and the tabs work;
   - the required-field error shows when the form is empty;
   - choices toggle on and off.
3. **Do not submit the form with fake details** if that sends an email or saves a lead. Stop there and tell me, so I can do the final test myself.

## Report back

- How the form submits (where the answers go), and confirmation that it still works the same way.
- How you deployed, and confirmation that nothing went to Vercel or Render.
- The files you changed, added and removed, and which shared header and footer components the page uses.
- The live URL, with one desktop and one phone screenshot.
- Anything you couldn't match exactly, and why.
