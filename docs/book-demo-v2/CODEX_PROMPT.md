# Codex prompt: replace the live Book a Demo page and deploy it directly (web only)

Unzip this folder into the repo at `docs/book-demo-v2/`. Then paste everything below the line into Codex from the repo root.

---

**REPLACE THE BOOK A DEMO PAGE DIRECTLY ON THE LIVE SELF-HOSTED SITE AND DEPLOY IT. DO NOT MAKE A VERCEL COPY.**

- No Vercel deployment, no Vercel preview, no Render, no local copy, no staging copy.
- The only deploy target is the self-hosted production server for findez.ai.
- If the repo's deploy scripts or config point at Vercel, don't use them: find the self-hosted deploy path. If you can't find it, stop and tell me, and don't deploy anywhere else.

WEB (NEXT.JS) ONLY. BOOK A DEMO PAGE ONLY. Replace the current Book a Demo page on findez.ai (the page the header "Book a Demo" button opens) with the new design in `docs/book-demo-v2/`, then deploy it straight to production.

## HOW TO WORK: REPLACE DIRECTLY. NO COPY.

- **Edit the real Book a Demo page and its components in place.** Keep its current route, metadata and title. Remove the old pieces the new page no longer uses (for example the workbench photo), but only if no other page imports them.
- **Do not make** a copy, a duplicate route, a "v2" page, a preview page, a feature flag, or a separate local test version.
- **Do not set up a local preview** to check the design before deploying.
- Only run what the deploy itself needs (install, lint, build, if the deploy runs them). If the build fails, fix it and continue. Never deploy a broken build.
- **Credentials:** never create, print, log, commit or ask for passwords, keys or tokens. If deploy access or any secret is missing, stop and tell me exactly what is missing.

## SCOPE. READ THIS FIRST.

- **Do not touch:**
  - every other route, including the home page, Solutions, CAD Intelligence, Founders Access, sign in and the signed-in web app;
  - the backend (FastAPI or any Python), Supabase (tables, RLS, SQL, auth), env and config files;
  - the scheduling provider's settings (event types, durations, availability, emails);
  - the mobile app.
- **No new packages.** Plain React and CSS. No animation, form or date libraries.
- **No em or en dashes** in any copy. **No CSS `filter: blur` or `backdrop-filter`.**
- **No numbered lists or step numbers anywhere** (no "01", "02", "Step 1 of 3" and so on). The prototype has none. Don't add any.
- **Use the copy in the prototype exactly.** Don't add or remove lines, except where this prompt says to.
- **Header and footer:** use the site's existing shared header and footer. The header in the prototype is only a copy of the live one for context. Don't rebuild it.

## THE MOST IMPORTANT RULE: KEEP THE REAL BOOKING WORKING

The prototype's calendar, time slots and confirmation use **fake sample dates**. The live page already books real demos. Before changing anything:

1. **Find how the current page books a demo and where the form answers go.** For example, a Calendly link or embed, a scheduler API, or a backend endpoint. Tell me what you found.
2. **Keep that exact integration and data flow.** Keep the same field names, option values, validation and submission the live form uses now. The dropdown options in the prototype are for the layout. If the live form's options differ, keep the live ones.
3. **The "Choose a date and time" step must show real availability** from that integration, styled like the prototype:
   - If the integration can give you real open slots without new secrets or backend changes, render them as the prototype's day and time buttons.
   - If it can't (for example, it's a Calendly embed), show the scheduler **inside the same card** on the second step instead of the fake grid. Theme it dark to match (background `#1B1B1B`, text `#F3F1EA`, accent `#F3F1EA`), hide its own cookie banner and event details if the provider supports it, and prefill the name, email and answers from step one.
   - **Never show made-up dates or times.**
4. **Only show "You're booked." after the provider confirms the booking** (for Calendly, the `calendly.event_scheduled` message). Fill it from the real booking:
   - **When:** the real date and time, in the visitor's timezone.
   - **Where:** the real meeting location from the event. If you can't read it, use "Link in your invite".
   - **Focus:** the "What would you like to explore?" answer.
   - **Buttons:** keep "Add to calendar" and "Reschedule" only if you can link them to the real booking. If you can't, leave that button out and tell me.
5. **The length text** ("20 minutes · Live online" and "20 minutes · Pacific Time") must match the real event length and the visitor's timezone. If the real event isn't 20 minutes, use the real length and tell me. Don't change the event itself.

## What's in this folder

- **`prototype/findez-book-demo.html`:** the finished page, fully clickable. Open it in a browser. It runs on a tiny template runtime at the bottom of the file. **Don't ship that runtime.** Port the CSS (the `<style>` block), the markup (the `<script id="tpl">` template) and the logic (`class Component`, including the search demo data) into React.
- **`screens/`:** the targets.
  - `desktop/01-form.png` is the whole page at 1440 wide.
  - `desktop/02` to `06` show the required-field error, the filled form with the CAD note, picking a day, picking a time, and the confirmation.
  - `mobile/01` and `02` show the phone layout at 390 wide.

## The page

Dark, matching the live site: page `#161616`, card `#1B1B1B`, fields `#121212`, lines `#222222` to `#333333`, text `#F3F1EA`, greys `#C9C7C1`, `#A9A7A1` and `#85837E`. The only colour is amber `#E3B45C` for low stock and "short". Fonts: Inter, Inter Tight and Geist Mono from the site's existing setup.

- **Left column:**
  - The headline "See FindEZ in action." (no eyebrow label above it) and the paragraph under it.
  - **The search demo card,** which replaces the workbench photo. A search types itself, the three result rows fade in with location and count, then it moves to the next search. It loops through three searches. The footer line reads "drivetrain_v4 · Autodesk Fusion" and "7 of 8 ready · 1 short".
    - It's sample data. Keep the "Sample data" tag. It never calls an API.
    - Mark it `aria-hidden` as in the prototype.
    - Pause the loop when it's off screen or the tab is hidden, and clear the timer on unmount.
    - **Reduced motion:** show the first search fully typed, with its results, and don't loop.
  - "What you'll see" with four rows, each with a check mark, separated by thin lines.
  - The "Request an Organization Pilot ↗" link. Keep the link target the live page uses now.
- **Right column:** the booking card, sticky at the top on desktop.
  - **Step one, the form:** labels above the fields, two fields per row on desktop and one per row under 560px. "(optional)" sits in grey next to the label. The CAD note appears only for Onshape, SolidWorks or Other. One error line is shown above the button. The button reads "Choose a date and time →".
  - **Step two, the time:** see the booking rule above. "Back" returns to the form with the answers kept.
  - **Step three, the confirmation:** see the booking rule above.
- Make every input a real `<label>` and field, buttons real `<button>`s, keep visible focus rings, and move focus to each new step's heading when the step changes.

## After deploying

1. Open the live Book a Demo page at 1440×900 and at 390 wide, and compare it with `screens/`.
2. Check that:
   - the search demo loops and pauses off screen;
   - the required-field error shows when the form is empty;
   - the CAD note shows only for Onshape, SolidWorks or Other;
   - the second step shows **real** availability.
3. **Do not complete a real booking** and don't submit the form with fake details if that sends an email or saves a lead. Stop at the point where a real booking or email would happen and tell me, so I can do the final test myself.

## Report back

- How the page books demos (the provider and how you connected it), and anything you couldn't connect.
- How you deployed, and confirmation that nothing went to Vercel or Render.
- The files you changed, added and removed.
- The live URL, with one desktop and one phone screenshot of the form and of the time step.
- Anything you couldn't match exactly, and why.
