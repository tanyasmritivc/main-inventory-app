# Codex prompt: Founding Access modal (web app), then a Vercel preview

Unzip this folder into the repo at `docs/founding-access-web/`. Then paste everything below the line into Codex from the repo root.

---

WEB (NEXT.JS) ONLY. Build a "Founding Access" modal in the signed-in web app.

- **After sign up:** a new account sees it once, right after signing up.
- **After sign in:** an existing account sees it once, the first time it signs in after this ships.
- **When it's done:** push a branch so Vercel builds a preview.

## Reference

- **`docs/founding-access-web/findez-web-founding-access.html`** is the approved design. Open it in a browser and use the **Demo** bar (bottom left) to switch between After sign up / After sign in and Dark / Light.
- **`screens/`** shows each state:
  - `01-dark-after-sign-up.png`
  - `02-dark-whats-included.png`
  - `03-light-after-sign-in.png`
  - `04-light-your-plan.png`
  - `05-small-screen.png`
- **Build it as a real React component** in the app's own style system: CSS modules, Tailwind, or whatever the repo already uses. You can take the CSS values straight from the prototype.
- **Don't ship the prototype.** Its app shell, demo bar, sidebar button and avatar trigger are there to show context only.

## Rules

- **Web only.** Don't change the backend, the API, the Supabase schema or RLS, the Flutter app, the landing page, env files or Vercel settings.
- **Text only, no billing logic.** Don't touch plans, billing, entitlements, item data or how items are stored.
- **No new packages.** Use the existing modal or dialog component if it can match this design; otherwise build a small one.
- **Use the app theme tokens** from the app theme work (`--bg`, `--surf2`, `--line`, `--tx`, `--tx2` and so on), in both dark and light mode. No orange anywhere in the interface. The only colour is the risograph art.
- **Leave existing buttons and menus alone,** including the sidebar Upgrade button and the avatar menu.
- **Git:** work on a new branch, `feat/founding-access-web`. Commit, and push the branch to `origin`. **Don't merge into main and don't deploy to production.**

## Step 0: look before you build

Find and list:

1. Where sign-up and sign-in finish, and the first signed-in page a user lands on.
2. How the current user is read on the client: their id and their `created_at`.
3. The Plans & usage settings page.
4. The theme tokens, the fonts (Inter, Inter Tight and Plus Jakarta Sans should already be loaded), any existing Dialog component, and any existing analytics.

New code goes in one folder, for example `components/founding-access/`.

## When it shows

1. **Once per user, per browser.**
   - After the user lands in the signed-in app, check `localStorage` for `findez_founding_seen_<userId>`. If it's missing, open the modal about 600ms after the page settles.
   - Closing it in any way sets the key: the ✕, Esc, clicking outside, "Get started" or "Got it".
   - Wrap every `localStorage` read and write in try/catch, and never let a storage error block the app.
2. **Which version:**
   - If the account's `created_at` is less than 15 minutes old, show **After sign up**.
   - Otherwise show **After sign in**.
3. **Never on public pages:** not on the landing page, the auth pages, or on top of another open modal.
4. **Plans & usage:** add one card at the top of that page, without moving anything else on it.
   - **Card contents:** a small art tile, "Founding Access", "Your plan right now", a "Free" chip, and a "See what's included" secondary button.
   - **The button** opens the modal straight on the details view, titled "Your plan", with no Back link.
5. **Analytics:** if the app already has analytics, log `founding_modal_shown` (with the version), `founding_modal_details` and `founding_modal_closed`. Otherwise skip this.

## Design

### Overlay and window

- **Overlay:** `rgba(0,0,0,.55)` in dark mode and `rgba(11,11,12,.25)` in light, with a 4px backdrop blur. It fades in over 350ms.
- **Window:**
  - fixed in the centre, `width: min(820px, 100vw − 48px)`, radius 18px;
  - **dark mode background:** `linear-gradient(180deg,#161618,#121214)` with `inset 0 1px 0 rgba(255,255,255,.045)`;
  - **light mode background:** `#FFFFFF`;
  - a 1px `--line2` ring and a deep shadow (`0 40px 100px rgba(0,0,0,.6)` in dark, `0 30px 80px rgba(11,11,12,.18)` in light);
  - **entrance:** from `translate(-50%,-46%) scale(.98)` and opacity 0, to its place over 500ms on `cubic-bezier(.32,.72,0,1)`.
- **Layout:** a two-column grid, a 320px art column and the content column.

### Art column (Plum / Rust risograph)

- **The panel:** 8px margin, radius 12px, at least 440px tall.
  - Clip it with `clip-path: inset(0 round 12px)` so the colour has **rounded corners in every browser, including Safari**.
  - It has a 1px inner edge of `rgba(255,255,255,.1)`.
- **The art layer:**
  - 12% larger than the panel on every side;
  - it drifts to `translate(5%,-4%) scale(1.06)` and back over 14s, alternating;
  - the background is Plum / Rust, the same as the prototype's `.rp-plum`:

```css
background:
  radial-gradient(50% 60% at 12% 70%, #453349 0%, transparent 75%),
  radial-gradient(55% 55% at 55% 60%, #773F42 0%, transparent 72%),
  radial-gradient(40% 45% at 92% 10%, #996050 0%, transparent 72%),
  radial-gradient(35% 35% at 25% 5%, #B69D9F 0%, transparent 70%),
  linear-gradient(150deg, #453349, #773F42 55%, #996050);
```

- **Grain:** two layers of the SVG fractal-noise texture from the prototype's `.riso::before` and `.riso::after`:
  - `mix-blend-mode: overlay` at 0.95 opacity, tiled at 180px;
  - `mix-blend-mode: soft-light` at 0.8 opacity, tiled at 120px.
  - The grain must be clearly visible.
- **Put the four palettes in one shared place,** so Spaces and other art can reuse them later. The modal uses Plum / Rust.

| Palette | Colours |
|---|---|
| Blue / Slate | `#97A6B1`, `#748193`, `#4B556F`, `#222236` |
| Terracotta / Ochre | `#AB5D44`, `#AC7A52`, `#757067`, `#D3B19E` |
| Plum / Rust | `#453349`, `#773F42`, `#996050`, `#B69D9F` |
| Sage / Olive | `#576B5B`, `#6C7F6D`, `#84947F`, `#AAB3A9` |

- **Chip,** 16px from the top and left:
  - "Founding Access";
  - 28px tall, radius 14, `rgba(255,255,255,.14)` over a 12px blur, a 1px ring of `rgba(255,255,255,.22)`;
  - 12.5px, weight 500, white.
- **Logo tile,** centred:
  - 72px, radius 20, `rgba(255,255,255,.12)` over a 14px blur;
  - rings `rgba(255,255,255,.24)`, a top highlight of `rgba(255,255,255,.3)`, and the shadow `0 14px 40px rgba(0,0,0,.25)`;
  - the white clove at 34px;
  - it pops in from 0.75× scale over 800ms.
- **Caption,** 18px in from the sides and 16px from the bottom: "Your inventory stays yours, whatever plan you're on." 12.5px, `rgba(255,255,255,.82)`.

### Content column

- **Padding:** 28px top, 32px right, 24px bottom, 24px left.
- **Close button (✕):** absolute, 14px from the top and right, 38px round, `--tx2` colour, the hover token on hover, `z-index` above the views.

**View 1: welcome**

| Part | After sign up | After sign in |
|---|---|---|
| Small label (12px, weight 500, `--tx3`) | Welcome to FindEZ | Welcome back |
| Title (Inter Tight 400, 36px, −0.02em, line height 1.1) | You're in early. | You're a Founding member. |
| Lead (15px, `--tx2`, line height 1.5, max 420px wide) | FindEZ is free while we get ready for launch. Here's how it works. | FindEZ is free while we get ready for launch. Here is what that means for your inventory. |

- **Three points,** 22px above them, 16px apart.
  - Each has a 36px icon tile (radius 10, `--surf2`, a 1px `--line` ring) and an 18px line icon.
  - The title is 14.5px weight 500, and the body is 13.5px `--tx2` with line height 1.45.
  - They rise 8px in turn (0, 80 and 160ms).

| Icon | Title | Body |
|---|---|---|
| Shield with a check | Your inventory stays yours | Everything you save stays in your account, even if you never subscribe. |
| Magnifier | Always find what you saved | Opening, searching and exporting your items stays free. |
| Plus | Adding more will need a plan later | When paid plans launch, you'll get a small free allowance. Adding more will need a subscription. |

- **Fine print,** 20px above it: "We'll tell you before anything changes. You can find this anytime in Plans & usage." 12.5px `--tx3`.
- **Actions,** bottom-right with an 8px gap, as 38px pills using the app's Button component:
  - **"See what's included":** secondary, with a 1px `--line2` ring;
  - **"Get started":** primary. That's the graphite pill in dark mode and the graphite-to-black pill in light, both with the top highlight.
  - "Get started" closes the modal and shows the app's toast: "Ask anything, or add your first items with +".

**View 2: what's included**

- **Header:**
  - a "‹ Back" text button (13px `--tx2`, hidden when opened from Plans & usage);
  - the title "What's included" (or "Your plan" from Plans & usage) in Inter Tight 400 at 28px.
- **Plan card,** 16px above it:
  - radius 14, the dark gradient card or white, with a 1px `--line` ring;
  - a 40px Plum / Rust art tile (radius 10, clipped, with an 18px white clove);
  - "Founding Access" at 14.5px weight 500 and "Your plan right now" at 12.5px `--tx2`;
  - a "Free" chip (24px, radius 12, `--surf2`, 12px `--tx2`).
- **Table card,** 10px above it, same card style:
  - columns: label, then "Now" (70px), then "Free plan" (96px), both centred;
  - the header row is 12px `--tx3`;
  - rows are 14px with a 1px `--line` on top and padding 10/16;
  - checks are 16px line icons with stroke 2.2;
  - the "Limited" chip is 22px tall, `--surf2`, 12px `--tx2`;
  - the "Plan" chip is 22px tall with a 1px `--line2` ring and 12px `--tx`.

| Row | Now | Free plan |
|---|---|---|
| Open and search items | ✓ | ✓ |
| See item details | ✓ | ✓ |
| Export your inventory | ✓ | ✓ |
| Ask FindEZ | ✓ | Limited |
| Add new items | ✓ | Limited |
| Add from a photo | ✓ | Limited |
| Import a spreadsheet | ✓ | Plan |

- **Fine print:** "**Free plan** is what you keep without subscribing once paid plans launch. Prices and the date aren't set yet. We'll tell you before anything changes, and nothing you've saved is ever deleted." 12.5px `--tx3`, with "Free plan" in `--tx2`.
- **"Got it"** (primary) at the bottom right closes the modal.
- **Switching views:** the incoming view fades in and slides 16px over 400ms.

### Small screens (under 820px)

- It becomes a bottom sheet: 8px from the sides and bottom, radius 28, one column.
- The art is on top at 150px tall, radius 22, clipped, with no caption.
- Actions stack full width, 46px tall, with the primary on top.
- The sheet scrolls inside if it's taller than the screen.

### Accessibility

- `role="dialog"`, `aria-modal="true"`, and `aria-labelledby` pointing at the title.
- When it opens, move focus to the dialog container (`tabindex="-1"`), **not** onto a button, so no focus ring shows on open.
- Keep Tab inside the modal. Esc closes it, and focus returns to wherever it was before.
- Focus rings use the app's ring style (`0 0 0 2px var(--bg), 0 0 0 4px` text colour at 40%), shown only with `:focus-visible`.
- Prevent the page behind from scrolling while the modal is open.
- `prefers-reduced-motion` turns off the drift, the pop and the rise, leaving only fades.

## Check before you push

1. `npm run lint` and `npm run build` pass.
2. **Locally,** check:
   - a fresh account shows **After sign up** once;
   - an older account shows **After sign in** once;
   - reloading doesn't show it again;
   - Plans & usage › See what's included opens **Your plan**.
3. Check dark and light mode at 1440, 1280 and 390px widths, in **Chrome and Safari**. The art must have rounded corners in Safari too.
4. `git diff --stat` shows only:
   - the new component folder;
   - the hook where the signed-in app mounts it;
   - the Plans & usage card;
   - the shared palette file;
   - `docs/founding-access-web/`.
5. Commit on `feat/founding-access-web`, then push the branch to `origin`.
6. **Report:**
   - the commit hash;
   - the Vercel **preview** URL, from the GitHub checks or `vercel` if it's already linked (don't link or log in to anything new);
   - screenshots of both versions in dark and light, and the 390px sheet;
   - the files you changed.
