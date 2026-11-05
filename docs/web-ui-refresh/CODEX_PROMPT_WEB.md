# Codex prompt: web app UI refresh (design only)

Unzip this folder into the repo at `docs/web-ui-refresh/`. Then paste everything below the line into Codex from the repo root.

---

WEB APP (NEXT.JS) ONLY. Restyle the existing FindEZ web app to match the approved prototype in `docs/web-ui-refresh/findez-web-app.html`. Screenshots of each page are in `docs/web-ui-refresh/screens/`.

## THIS IS A UI FIX ONLY. READ THIS FIRST.

**Nothing is removed and no feature is added. Every existing feature, page, button, menu, field and action must still be there and still work exactly as it does today. Only how it looks changes, so that it adjusts to the new design.**

- **The prototype is a visual reference, not a feature list.**
  - It is a static mock with fake data. Copy its look: layout, spacing, type, colour, radius and motion.
  - Don't copy its data or its demo behaviour.
- **If the app has something the prototype doesn't show, keep it.**
  - Restyle it to fit the new design.
  - Never delete it because it's missing from the prototype.
- **If the prototype shows something the app doesn't have, don't build it.**
  - The only exceptions are the four approved UI additions listed further down.
  - List anything you skipped in your summary.
- **Don't change anything except the visual layer:**
  - routes, URLs or navigation targets;
  - API calls, endpoints, Supabase queries, auth, permissions or plan logic;
  - what any button or menu item does.
- **Item data stays exactly as stored, however the items were imported** (photo scan, spreadsheet, barcode, manual):
  - Don't change item names, column names, field names, field order, values, units or sorting.
  - The table shows the same columns in the same order as today.
- **Keep all copy as it is today, except:**
  - the filler lines listed under Pages;
  - the new text in the approved additions.
  - No em or en dashes anywhere in new copy.
- **Theme:**
  - Light mode is the default.
  - If the app has dark mode or a theme switch today, keep it working.
  - Restyle dark mode with the same structure, using dark values of the same tokens.
- **Don't touch the backend, the mobile app or the database.**
- **No new packages.** Use the fonts and icon set the app already has: Inter, and Inter Tight for the main headline. If Inter Tight isn't loaded, load it with `next/font`, which is built in.

## Design tokens (light)

| Token | Value |
|---|---|
| Page background | `#FFFFFF` |
| Sidebar background | `#F9F9F8` |
| Surface 2 (segmented control, chips) | `#F3F3F2` |
| Hover | `#F1F1F0` |
| Active nav item | `#ECECEB` |
| Line | `#E8E8E6` |
| Line strong | `#DCDCDA` |
| Text | `#0B0B0C` |
| Text secondary | `#55565B` |
| Text tertiary | `#8A8A8F` |
| Running low text | `#8A6418` |
| Running low dot | `#B08A3E` |
| Motion easing | `cubic-bezier(.32,.72,0,1)` |

- **Accent:** black and white only. Colour appears only in artwork (card covers, tiles, the banner).
- **Primary buttons:** black (`#0B0B0C`) with white text. Secondary buttons are white with a 1px line.
- **Cards:** white, 1px `#E8E8E6` border, radius 16. On hover: lift 2px and a soft shadow.

## Artwork: smooth, not risograph

- Remove all grain and noise textures from the web app.
- Artwork uses the four existing palettes as smooth gradients. Copy these exactly; they're also in the prototype CSS.

```css
/* plum */  background: radial-gradient(90% 80% at 100% 0%, rgba(182,157,159,.9) 0%, transparent 88%), radial-gradient(90% 90% at 0% 100%, #453349 0%, transparent 88%), radial-gradient(70% 70% at 55% 55%, rgba(153,96,80,.85) 0%, transparent 90%), linear-gradient(150deg, #8E5A55 0%, #773F42 50%, #553846 100%);
/* sage */  background: radial-gradient(90% 80% at 100% 0%, rgba(170,179,169,.95) 0%, transparent 88%), radial-gradient(90% 90% at 0% 100%, #576B5B 0%, transparent 88%), radial-gradient(70% 70% at 50% 55%, rgba(132,148,127,.9) 0%, transparent 90%), linear-gradient(150deg, #94A291 0%, #76887A 50%, #5E7262 100%);
/* slate */ background: radial-gradient(90% 80% at 10% 0%, rgba(151,166,177,.95) 0%, transparent 88%), radial-gradient(80% 90% at 100% 100%, #222236 0%, transparent 88%), radial-gradient(70% 70% at 55% 55%, rgba(116,129,147,.9) 0%, transparent 90%), linear-gradient(150deg, #7D8A99 0%, #5B6680 48%, #3A4260 100%);
/* terracotta */ background: radial-gradient(90% 80% at 0% 10%, rgba(211,177,158,.95) 0%, transparent 88%), radial-gradient(80% 90% at 100% 100%, #757067 0%, transparent 88%), radial-gradient(70% 70% at 50% 60%, rgba(171,93,68,.9) 0%, transparent 90%), linear-gradient(150deg, #C08A6E 0%, #AB6A4C 50%, #8C735C 100%);
```

- **Which palette a Space or workspace gets:**
  - If the app already assigns one, keep that assignment.
  - Otherwise use a stable hash of the name, so it never changes between visits.
- Items without a photo show a small slate tile with a white line icon. Items with a photo stay exactly as they are.

## Shell (every page)

- **Sidebar:** same items, same order, same targets as today. Only the styling changes:
  - width 266px, background `#F9F9F8`, a 1px line on the right;
  - logo row with the collapse button;
  - the organisation switcher as a white rounded card;
  - section labels at 12.5px;
  - nav items 36px tall, radius 10, active item `#ECECEB`;
  - Upgrade as a white bordered button with ↗;
  - profile row, then Sign out.
- **Organisation menu:** same items and actions as today, restyled as a white floating menu.
- **Top bar:**
  - 66px tall, no bottom border;
  - breadcrumb on the left at 13.5px;
  - on the right: "Go to... ⌘K", the bell and the avatar.
  - Keep every control that's there today.

## Pages

**New chat (home)**
- Headline "What’s in your world?" in Inter Tight 400, 52px, letter spacing −0.025em, with a slow shine animation across the text. Keep the subtitle under it.
- **Composer:**
  - white, radius 20, a 1px `#DCDCDA` ring and a soft shadow;
  - + on the left, which opens the existing add menu;
  - send on the right, which turns black when there's text.
  - A very faint light slowly moves around its edge and stops while the composer is focused.
- Keep "Check AI answers before making changes." under it. Keep the history and new chat buttons.
- **Chat answers and follow-ups:** same behaviour, restyled. User messages go in a right-aligned bubble; item results are shown as rows.

**Spaces**
- **Remove these filler lines:** the "Superpowered Jalapenos" label above the title and the line under the title. Keep the title.
- **Keep the existing controls** (refresh, New Space, search) and the existing groups by workspace and inventory.
- **Space cards:**
  - a smooth art cover with a frosted item-count badge;
  - below it, the location icon and the name;
  - then one quiet info line (see approved addition 4).
- **Browse inventories:** the same cards as today, restyled with a small palette tile, the name, "All items" and a chevron.

**Space detail (for example Fastener DB)**
- **Header:**
  - a palette tile, "← My Spaces" (the existing back link), the Space name;
  - the info line, for example "298 items · 7,583 units · 2 running low · Added 2 days ago" (see approved addition 4).
- **Actions:** keep every existing action and what it does (Upload Image, Import Spreadsheet, Scan Barcode, + Add Item, Export CSV).
  - Export CSV is a secondary button.
  - The four add actions may sit under one black "Add items ▾" button with a menu.
  - Every action keeps its current behaviour and permissions.
- **Search and the category filter:** same behaviour, restyled. The filter becomes a segmented control.
- **Table:**
  - same columns, same order, same names, same values, same row actions ("...");
  - white card, 13px tertiary uppercase headers, 56px rows, thumbnail tiles.
  - Quantities that are already flagged as low by the app's existing logic show in `#8A6418`. If the web app has no low logic today, leave quantities unchanged.
- **The floating "Ask FindEZ" button:** same behaviour, restyled.
- **Item details:** if the app already opens a view or panel for an item, restyle it as a right-side panel that shows the item's existing fields and existing actions. Don't add a panel if there isn't one today.

**Tools**
- Remove the line under the title.
- Keep the inventory selector, Earlier chats, and every tool card with its current title, description and action.
- Cards: a white bordered card with a small icon tile, the title and the description.

**Workspaces**
- Remove the line under the title, and the "Inventories, people, tasks and files" line on the card.
- Keep refresh, Manage workspaces and every workspace card. Each card has a smooth art cover and the workspace name.

**Every other page** (People, Organization settings, Profile, plans, sign-in, and anything not listed above): apply the same tokens, cards, buttons and type. Change nothing else.

## Approved UI additions (only these four)

These are the only new things on screen. Each one uses features and data the app already has. **None of them may add an API call, endpoint, table or new logic.** If something they need isn't available on the client today, leave that part out and say so in your summary.

**1. Founding Access banner**
- A 40px strip across the top of the main column, above the top bar.
- Background is the smooth plum gradient with no grain, drifting slowly. White text, centred:
  - a small frosted "Founding Access" label;
  - "You're in early, and FindEZ is free while we get ready to launch.";
  - an underlined "See what is included" link;
  - × on the right.
- **"See what is included"** opens the existing Founding Access popup. If there isn't one, it opens the existing plans or upgrade page.
- **×** collapses the banner smoothly and remembers that choice in `localStorage` (wrapped in try/catch).
- Show the banner only where the app already treats the user as being on Founding Access, or on the free early plan, if that state exists. If it doesn't exist, show it to everyone.

**2. Quick start (home only, below the composer)**
- A small "Quick start" label, then four equal cards in one row (two per row under 860px wide).
- Each card has a 38px palette tile with a white icon, a title and a short hint.

| Card | Hint | What it does (existing actions only) |
|---|---|---|
| Scan a photo | Add a whole shelf | Opens the existing image upload / photo scan flow |
| Import a sheet | CSV or Excel | Opens the existing spreadsheet import |
| Find an item | Where and how many | Puts "Where are the " into the composer and focuses it |
| Running low | What to restock | Sends "What is running low?" to the existing chat |

**3. Typing placeholder (home composer only)**
- The placeholder types and deletes these examples, then rests on "Ask about your inventory...":
  - "Where are the M5 screws?"
  - "What is running low in Fastener DB?"
  - "Add 24 M4 screws to Fastener DB"
  - "Which Space has the spare batteries?"
- It stops as soon as the user focuses the composer or types.
- It's off when the user's system has reduced motion turned on.

**4. Space info line**
- One line of tertiary 12.5px text on Space cards and under the Space detail title, joined by "·":
  - units;
  - "N running low" with an amber dot;
  - "Added X ago" (or "Created X ago" when the Space is empty).
- Use only values the page already loads or can compute from data already on the client.
- Hide "running low" when its count is 0, or when the app has no low logic.
- If a value isn't available without a new request, leave that part out.

## Motion

- **On load:** headline, subtitle, composer and Quick start fade up in sequence (14px, 0.9s, the easing above).
- **Hover:** cards lift 2px. On the composer, the + rotates 90° and the send arrow nudges up and to the right.
- **Banner:** collapses on close.
- Respect `prefers-reduced-motion`: no animation at all when it's on.

## Git

- Work on a new branch, `feat/web-ui-refresh`. Commit, and push the branch to `origin`.
- Don't merge into main and don't deploy. findez.ai is self-hosted and is deployed separately.

## Check before you finish

1. `npm run lint` and `npm run build` pass.
2. Run the app locally and check, in light mode (and dark mode if it exists):
   - every sidebar item, the organisation menu and the top bar controls;
   - New chat: send a message, the + menu, history, new chat, the four Quick start cards and the banner (link and close);
   - Spaces: search, New Space, refresh, open a Space, Browse inventories;
   - Space detail: every add action, Export CSV, search, filter, a row's "..." menu, Ask FindEZ;
   - Tools: every card and the inventory selector;
   - Workspaces: refresh, Manage workspaces, open a workspace;
   - People, Organization settings, Profile, Upgrade, Sign out.
3. **Make a list of every button, link and menu item before you start, and check it again after.** The two lists must match, plus only the four approved additions.
4. Open a Space that was imported from a spreadsheet and one that was made from a photo scan. The column names, order and values must be identical to before.
5. Take screenshots of every page listed above.
6. Run `git diff --stat`. Only web UI files (components, styles, layout) should change, plus the four additions. Nothing in the API, backend, mobile or database.

## Report

- the branch and commit hash;
- the files you changed;
- for each approved addition, which existing action or data it uses, and any part you left out because it wasn't available;
- anything in the prototype you skipped because the app doesn't have it;
- confirmation that the before and after lists of controls match;
- the screenshots.
