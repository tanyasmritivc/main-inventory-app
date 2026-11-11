# Codex prompt: replace the live sign-in page with the dark split design (web only)

Unzip this folder into the repo at `docs/auth-split/`. Then paste everything below the line into Codex from the repo root.

---

WEB (NEXT.JS) ONLY. SIGN-IN PAGE DESIGN ONLY. Replace the **current sign-in page** on the self-hosted findez.ai with the new dark split design in `docs/auth-split/`, then deploy it straight to production.

## HOW TO WORK: REPLACE DIRECTLY. NO COPY.

- **Edit the real sign-in page and its components in place.**
- **Do not make** a copy, a duplicate route, a "v2" page, a preview page, a feature flag, or a separate local test version.
- **Do not set up a local preview** to check the design before deploying.
- **Deploy to the live self-hosted site** the way this repo already deploys to it. **Never use Vercel or Render.**
- Only run what the deploy itself needs (install, lint, build, if the deploy runs them). If the build fails, fix it and continue. Never deploy a broken build.
- **Credentials:** never create, print, log, commit or ask for passwords, keys or tokens. If deploy access or any secret is missing, stop and tell me what is missing.

## THIS IS A DESIGN CHANGE ONLY. READ THIS FIRST.

- **Do not touch:**
  - the backend (FastAPI or any Python) and Supabase (tables, RLS, SQL, auth settings);
  - auth logic: the sign-in call, Google and Apple OAuth, redirects, session handling, validation, error messages, rate limits, "Resend confirmation email" behaviour, "Forgot password?" flow;
  - env and config files, and dependencies (no new packages);
  - the mobile app.
- **Nothing removed, nothing added on the form.** Keep every element the page has today, in the same order:
  1. FindEZ logo and wordmark;
  2. "A product of AI Robots Inc";
  3. "Welcome back" and "Sign in to manage your FindEZ account.";
  4. "Continue with Google", "Continue with Apple";
  5. the "or" divider;
  6. Email field, "Forgot password?" link, Password field;
  7. "Sign in" button;
  8. "Resend confirmation email";
  9. the legal text with its Terms of Service and Privacy Policy links;
  10. "Don't have an account? Sign up".
- Keep all existing error, loading and disabled states. Restyle them to fit the dark design (same colours as the fields), but keep their wording and logic.
- **No em or en dashes** in any copy. **No CSS `filter: blur` or `backdrop-filter`** anywhere on this page (it caused memory problems in Safari).
- **Other auth pages:** if Sign up, Forgot password or Reset password share the same layout component as Sign in, they get the same split layout and right panel automatically. Don't change their form content. If they don't share it, leave them alone. Tell me which case it was.
- **Theme:** this is the dark design. If the site has a light/dark theme setting, use this design for dark mode and leave light mode exactly as it is today. If the site has no theme setting, use this design. Tell me which case it was.

## What's in this folder

- **`prototype/findez-auth-dark.html`:** the finished page. Open it in a browser and resize it to see desktop, tablet and phone.
- **`source/auth-readable.html`:** the same page without the embedded fonts. **Port from this file**: the CSS, the markup and the canvas script.
- **`screens/`:** the targets.
  - `desktop/1-sign-in-1440x900.png`: the main target.
  - `desktop/2-email-focused.png`, `3-google-hover.png`: focus and hover states.
  - `desktop/4-reduced-motion.png`: how it looks with Reduce Motion on.
  - `tablet/1-sign-in-860.png`, `mobile/1-sign-in-390.png`: the stacked layout.
  - `motion/art-1.png` to `art-4.png`: the right panel a few seconds apart, showing the light sweep and slow tilt.

## The design

### Layout

- **Two equal columns** (`1fr 1fr`), full viewport height. Form on the **left**, art panel on the **right**.
- The art panel is **full-bleed**: no padding around it, no rounded corners, no border.
- **Below 960px wide:** one column. The art panel becomes a 300px banner across the **top** (full width, square corners), and the form sits below it.

### Left: the form

- Page background `#0A0809`. Form column centred in its half, **max width 380px**, padding 56px 40px (36px 16px 48px on phones).
- **Text is left-aligned** (not centred).
- Colours: text `#F4F0F0`; secondary `rgba(244,240,240,.64)`; tertiary `rgba(244,240,240,.42)`; lines `rgba(255,255,255,.08)` and `rgba(255,255,255,.14)`.
- **Logo row:** the FindEZ mark at 32px in `#F4F0F0`, gap 11px, "FindEZ" in Inter Tight 500, 24px, letter spacing -0.02em.
- "A product of AI Robots Inc": 12.5px, tertiary, 8px below.
- "Welcome back": Inter **400**, 38px, line height 1.08, letter spacing -0.035em, 44px below the logo block (30px on phones).
- Lead line: 15px, secondary, 10px below.
- **Google and Apple buttons:** 32px below the lead, 10px apart. Height 50px, **pill** (radius 25px), transparent with a 1px inset ring of `rgba(255,255,255,.14)`, text 15px weight 500. Hover: background `rgba(255,255,255,.04)`. Press: scale 0.985.
- **"or" divider:** 13px tertiary, with 1px lines either side; 26px above, 22px below.
- **Fields:** height 50px, radius 14px, background `#141113`, 1px inset ring `rgba(255,255,255,.08)`, text 15px, placeholder tertiary. **Focus:** ring becomes `rgba(201,138,147,.75)` (dusty rose). No glow.
- "Forgot password?": 13px secondary, right-aligned, 12px above and 10px below. Hover: text colour.
- **Sign in:** 20px below, full width, height 50px, pill, background `#F2EEEE`, text `#151012`, 15px weight 500. Hover `#fff`.
- "Resend confirmation email": 13.5px weight 500, secondary, centred, 20px below.
- Legal text: 12.5px, line height 1.6, tertiary, 28px below; its links in secondary, underlined.
- "Don't have an account? Sign up": 14px secondary, centred, 22px below; "Sign up" in text colour, weight 500, underlined (offset 3px).

### Right: the art panel

- Background `#120D0F`. Everything in it is drawn on one `<canvas>` behind the text, sized to the panel at `devicePixelRatio` capped at 2, redrawn on resize.
- **The mark:** the FindEZ clove mark, drawn huge and cropped by the panel's bottom-right corner.
  - Size: `max(panelHeight × 1.15, panelWidth × 1.25)`, centred at 84% across and 74% down, rotated about -0.2 rad with a very slow ±0.025 rad sway.
  - Fill: a diagonal gradient `#EDBFC4` → `#C48A91` → `#7C4850` → `#2E1C21` → `#160F11`, with a dark shade from the bottom-right inside the shape.
  - Light sweep: a soft pale band that crosses the shape every ~18 seconds, clipped to the shape.
  - Rim light: a thin pale stroke on the top-left edges.
  - Glow: eight soft strokes around the shape at low opacity. **Not a blur filter.**
- Two soft radial washes in `rgb(142,90,93)` and `rgb(94,58,64)` behind it, a dark fade at the top behind the headline and at the bottom, and a very light film grain from a small tiled noise canvas.
- **Copy** (left 56px, top 56px; 24px on phones):
  - "The AI that knows where every part is." Inter Tight 500, 42px, line height 1.08, letter spacing -0.035em, `#F6F0F1`, max width 520px (26px on phones).
  - "Snap a shelf, ask a question, get the exact bin. Built for teams that build things." 16px, line height 1.5, `rgba(246,240,241,.66)`, max width 420px, 16px below. Hidden on phones.
- **Bottom line** (left 56px, bottom 48px, hidden on phones): "**Founders Access** is open. Free while we get ready for launch." 14px, `rgba(246,240,241,.6)`, with "Founders Access" in `#F6F0F1` weight 500.
  - If the app calls the plan "Founding Access" instead, use the app's name and tell me.
- The whole panel is decorative: `aria-hidden="true"`, no pointer events needed.
- **Reduce Motion:** draw one still frame and don't start the animation loop.
- Pause the animation loop when the tab is hidden (`document.visibilitychange`) to save battery.

## Implementation notes

- Use the site's existing Inter and Inter Tight fonts. Don't add font files.
- Use the existing FindEZ mark path from the codebase if there is one. Otherwise, use the path in `source/auth-readable.html`.
- Put the canvas logic in a small client component (`"use client"`) with `useEffect`. Clean up `requestAnimationFrame` and listeners on unmount.
- Keep the page's existing metadata and title.

## After deploying

1. Open the live sign-in page on desktop (1440 wide), at about 860 wide, and on a phone width (390). Compare each with `screens/`.
2. Check that Google, Apple, email sign-in, "Forgot password?", "Resend confirmation email" and "Sign up" all still work exactly as before.
3. Check Safari: the animation runs smoothly and memory stays flat over a minute.

## Report back

- The files you changed.
- Whether other auth pages share the layout, and which theme case applied.
- The live URL you checked, with a desktop and a phone screenshot of the live page.
- Anything you could not match exactly, and why.
