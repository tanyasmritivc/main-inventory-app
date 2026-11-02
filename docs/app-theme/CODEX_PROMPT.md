# Codex prompt: restyle the signed-in web app (dark and light)

Before you run this, put `findez-app-theme.html` and the `dark/` and `light/` screenshot folders into `docs/app-theme/` in the repo. Then paste everything below the line into Codex from the repo root.

---

WEB (NEXT.JS) ONLY. Restyle the whole signed-in web app (every page after sign-in) to match `docs/app-theme/findez-app-theme.html` and the screenshots in `docs/app-theme/dark/` and `docs/app-theme/light/`. It must work in both dark and light mode.

**The six screenshots are examples of the theme, not the full list.** Apply the same tokens and components to every signed-in route, modal, drawer, menu, toast and empty state, as described in "Apply it everywhere" below.

## Scope (strict)

- **This is a visual change only. Do not add, remove or rename any feature, page, route, menu item, button or field.** Every screen keeps the same items, in the same order, doing the same thing. The prototype uses placeholder names ("Alex Morgan"); keep the real data.
- Do not change the backend, API calls, Supabase, auth, the Flutter app, the landing page, env files or deploy config.
- Dark and light follow the existing Appearance setting and theme logic. Do not add a new toggle.
- Work on a new branch `feat/app-theme`. Do not push.

## Design tokens

Put these in one place (CSS variables on `[data-theme]` or the existing theme provider) and use them everywhere in the app shell.

| Token | Dark | Light |
| --- | --- | --- |
| page `--bg` | `#0D0D0F` | `#FFFFFF` |
| sidebar `--side` | `#0D0D0F` | `#FAFAF9` |
| card `--surf` | `#141416` | `#FFFFFF` |
| soft fill `--surf2` | `#1B1B1E` | `#F5F4F1` |
| hover | `#1A1A1D` | `#F2F1EE` |
| active nav | `#1F1F23` | `#EDECE8` |
| line | `rgba(255,255,255,.07)` | `#ECEAE6` |
| strong line | `rgba(255,255,255,.12)` | `#E2E0DB` |
| text | `#F4F4F5` | `#0B0B0C` |
| secondary text | `#A1A1A6` | `#5E5F64` |
| tertiary text | `#6B6B70` | `#9A9BA0` |
| primary button | graphite pill: `linear-gradient(180deg,#2E2E33,#1F1F23)`, `#F4F4F5` text, `inset 0 1px 0 rgba(255,255,255,.14)` top highlight plus a 1px `rgba(255,255,255,.10)` ring | `linear-gradient(180deg,#26262A,#0B0B0C)`, white text, the same top highlight |

- **Dark mode page light:** add a very faint radial light at the top of the main area: `radial-gradient(900px 420px at 50% -120px, rgba(255,255,255,.035), transparent 70%)`.
- **⌘K badge:** a 1px ring and tertiary text, with no fill.
- **Fonts:**
  - Inter for the UI.
  - Inter Tight 400 for page titles (36px, letter-spacing −0.02em) and the Ask headline (46px).
  - Plus Jakarta Sans 600 for the "FindEZ" wordmark.
- **The accent is black and white, not orange.** Remove every orange or orange-red UI colour from the signed-in app: buttons, links, focus rings, badges, glows, active states and avatars. "New Space", "New inventory" and "Save changes" become the primary pill above.
- **Upgrade button:** soft-fill background (`--surf2`), 1px line, primary text, sparkle icon and ↗. On hover it uses the active-nav colour.
- **Default avatar and organization initial:** `#3A3A40` with white text.
- **Grainy gradients** are the only colour in the app, and only on Space, inventory and workspace art. Copy `.g-sand`, `.g-dusk`, `.g-slate`, `.g-moss` and `.g-plum` plus the `.grain` overlay from the prototype. There are no orange gradients. Pick one per item by a stable hash of its id, so the colour never changes between visits.

## Components

- **Sidebar** (256px, 1px line on the right):
  - logo and collapse button;
  - organization switcher as a bordered 44px row with a rounded-square initial;
  - section labels at 12px tertiary;
  - nav items 36px tall, 10px radius, secondary text with tertiary icons;
  - hover uses the hover token; the active item uses the active-nav token with primary text and icon.
  - **Footer:** Upgrade (soft fill, as above), then the profile row (avatar, name, "Profile and settings"), then Sign out. Same items as today.
- **Top bar** (64px): breadcrumb (current item in primary text, ancestors secondary, "/" tertiary), then the "Go to… ⌘K" field with a 1px line, the bell and the avatar.
- **Buttons:**
  - all buttons are 38px pills;
  - primary uses the primary-button token;
  - secondary is transparent with a 1px strong-line ring;
  - refresh and "more" are 38px round icon buttons.
- **Fields** (search, select, inputs): 42px tall (40px in forms), 12px radius, card background, 1px line, and the strong line on hover.
- **Cards:** card background, 16px radius, 1px line. In dark mode, cards and panels use `linear-gradient(180deg,#161618,#121214)` with a faint `inset 0 1px 0 rgba(255,255,255,.045)` top highlight, and form inputs sit on `#0F0F11`. On hover, the strong line, a 2px lift and a soft light that follows the pointer (`--mx`/`--my` radial, very faint).
  - **Spaces, workspace and inventory cards:** a 110px grainy gradient top with a small frosted chip (for example "298 items"), then the icon and name below.
  - **"Browse inventories" cards:** a 46px gradient tile on the left, with name and subtitle.
  - **Tool cards:** a 36px soft-fill icon tile, then the title and subtitle. Use one simple line icon per tool, as in the prototype.

## Apply it everywhere (not just the six screens)

Build the theme as shared tokens and shared components first. Then migrate every signed-in page to them, so the look is consistent across the whole app.

1. **Find every signed-in surface.**
   - List every route under the authenticated layout. This includes, but is not limited to:
     - chat and conversation threads, and History;
     - Spaces and Space detail;
     - item lists and item detail;
     - Tools, and each tool page: Capture / Import, Documents, Review, Activity, Restock, Check-outs, Project kits, Collections, Labels, Inventory settings;
     - Workspaces, and each workspace tab: Overview, People, Locations, Tasks, Files, Activity, Settings;
     - People and Organization settings;
     - every account settings page: Organizations, Profile, Appearance, AI memory, Plans & usage, Developer, Help and information, Account.
   - Also list every shared piece of UI:
     - modals, dialogs, drawers, popovers, dropdowns and context menus;
     - tables, tabs, toasts, tooltips;
     - empty, loading, skeleton and error states;
     - the organization switcher menu, the "Go to… ⌘K" command palette and notifications.
2. **Shared tokens.** Put every colour, radius, border and shadow in the one token file or theme provider. Replace hard-coded colours in components with the tokens. Search the app code for hex and rgb values, and for orange-red classes and values (for example `orange`, `red-5`, `#E`, `#F9`), and remove them.
3. **Shared components.** Use one implementation each, styled exactly as in "Components" above, and use it on every page:
   - Button: primary, secondary, icon and destructive;
   - Input, Select, Textarea, Search;
   - Card;
   - PageHeader: small label, Inter Tight title, subtitle and actions;
   - Breadcrumb;
   - Tabs, Table;
   - Modal/Dialog, Dropdown/Menu, Toast;
   - Badge/Chip, Avatar, EmptyState, Skeleton.
4. **How the common patterns should look:**
   - **Page headers:** always the PageHeader component, with the title in Inter Tight 400 at 36px. One primary action at most per page; the other actions are secondary or icon buttons.
   - **Chat threads:**
     - user messages sit in a soft-fill bubble (`--surf2`, radius 18/18/6/18);
     - assistant messages are plain text in primary colour, with no bubble;
     - item results, location chips and tables inside answers use the Card and Chip styles;
     - the composer in a thread is the same glass (dark) or white (light) composer as on the Ask screen, docked at the bottom.
   - **Tables and lists:**
     - rows separated by hairlines (the line token), with no zebra stripes;
     - header text at 12px tertiary;
     - row hover uses the hover token;
     - numbers right-aligned in tabular figures.
   - **Tabs:** text tabs with a 2px primary-colour underline on the active tab, or a segmented pill on a soft fill. Pick one and use it everywhere.
   - **Modals and drawers:**
     - card background (the dark-mode gradient card in dark), 18px radius;
     - a 1px line and a deep shadow;
     - an overlay of `rgba(0,0,0,.55)` in dark and `rgba(11,11,12,.25)` in light, with a 4px blur;
     - the title in Inter 500 at 17px;
     - actions bottom-right: secondary, then primary.
   - **Menus, dropdowns and popovers:** card background, 12px radius, 1px line and a shadow; 34px items with the hover token.
   - **Toasts:** card style, bottom-centre, with a small line icon and no coloured background.
   - **Badges and status chips:** neutral by default (soft fill with secondary text). For status, use small muted dots rather than coloured backgrounds: green `#3E8E5E`, amber `#B08A3E`, red `#B5483E`. Do not use orange.
   - **Destructive actions** (delete, remove, revoke): a secondary button with text in `#E5484D` (dark) or `#CD2B31` (light) and a red-tinted ring on hover. Only these use red.
   - **Empty states:** a 46px grainy-gradient tile, a one-line title, one line of secondary text and one action. No illustrations.
   - **Loading:** skeletons in the soft-fill colour with a slow shimmer. Spinners only inside buttons.
   - **Focus rings:** `0 0 0 2px var(--bg), 0 0 0 4px` primary text colour at 40%. Never blue or orange.
   - **Links in text:** primary colour with an underline at 30% opacity, rising to 100% on hover.
   - **Scrollbars:** thin and neutral.
5. **Shiny headline.** Use the shiny text only for the Ask screen headline, so it stays special. Every other title stays solid.
6. **Grainy gradients.** These are the only colour, and only on art for Spaces, workspaces, inventories, collections and empty-state tiles. Never on buttons or text.
7. **Same features.** Every page keeps exactly the same features, fields, buttons and data as today. This is a visual migration only.

## Screen by screen (layout matches the screenshots)

1. **New chat / Ask:**
   - "History" and "New conversation" become secondary pills at the top;
   - the subtitle is unchanged.
   - **Shiny headline:** "What's in your world?" is centred, Inter Tight 400, 48px, with a slow shine that sweeps across it.
     - Text fill: `linear-gradient(110deg, A 0%, A 38%, B 50%, A 62%, A 100%)` with `background-size: 250% 100%`, clipped to the text.
     - Dark mode: A = `#8E8E94`, B = `#FFFFFF`. Light mode: A = `#2A2A2E`, B = `#A9A9B0`.
     - Animate `background-position` from 100% to 0% over 5.5s with `cubic-bezier(.45,0,.55,1)`, holding still for the last 40% of each loop.
     - Reduce Motion: a static solid colour, `#E4E4E7` in dark mode and `#0B0B0C` in light mode.
   - **Composer** (radius 22px), with the placeholder "Ask about your inventory...", the + button and the "Ask" pill. Same actions as today.
     - **Light mode:** a white card with a soft shadow; "Ask" is the graphite-to-black pill.
     - **Dark mode:** never a white box on the dark page.
       - Card: `linear-gradient(180deg,#19191C,#131315)` with light text, a 1px `rgba(255,255,255,.09)` ring, `inset 0 1px 0 rgba(255,255,255,.06)` and a deep shadow (`0 30px 70px rgba(0,0,0,.55)`).
       - A gradient hairline border: brighter at the top (`rgba(255,255,255,.22)`), fading by the middle.
       - Placeholder `#6E6E74`, the + button with a 1px `rgba(255,255,255,.12)` ring, and "Ask" as a light pill (`linear-gradient(180deg,#F4F4F5,#D4D4D8)` with ink text). That pill is the only bright element.
   - The note "Check AI answers before making changes." sits under it.
2. **Spaces:**
   - title, subtitle, refresh and "New Space" (primary);
   - full-width search;
   - group labels as "Workspace / **Inventory**" (inventory name in secondary text);
   - Space cards with gradient tops;
   - the "Browse inventories" row.
3. **Tools:**
   - title, subtitle and refresh;
   - the "Inventory" label with the select and an "Earlier chats" secondary pill;
   - 10 tool cards in a 3-column grid, same order.
4. **Workspaces:** title, subtitle, refresh and "Manage workspaces"; workspace cards with gradient tops and "Inventories, people, tasks and files".
5. **Workspace detail:**
   - the small "Workspace" label above the Inter Tight title;
   - "…" and "New inventory" (primary);
   - search;
   - inventory cards with gradient tops and the "…" menu on the art.
   - The sidebar shows the extra "Workspace" section, same items as today.
6. **Profile:**
   - account sidebar, same items;
   - the "Personal details" panel with hairline rows (180px label column);
   - inputs as above;
   - "Change" as a secondary pill and "Remove" as a tertiary text link;
   - avatar colours become a muted, non-orange set: `#3A3A40, #6B6B70, #8C7B6B, #4E5878, #46565F, #3E5A4C, #6B5486, #A7808F`, with the selected one ringed;
   - "Save changes" as the primary pill.

## Motion

- Pages fade in and rise 8px (500ms, `cubic-bezier(.32,.72,0,1)`).
- The Ask headline shine loops as described above.
- Cards lift on hover (300ms).
- Primary buttons brighten slightly on hover.
- Nothing else animates.
- Respect Reduce Motion.

## Check before you finish

- `npm run lint` and `npm run build` pass.
- Compare each of the 6 screens in dark and light with the screenshots.
- **Open every other signed-in route,** plus at least one modal, one dropdown, one toast, one table and one empty state, in both modes. They all use the same tokens and components, and none look like the old style.
- **Search the app code** for leftover hard-coded colours and orange or orange-red values, and list any that remain, with the reason.
- Every button, link, field and menu item that existed before still exists and works.
- No orange or orange-red remains anywhere in the signed-in app.
- Text contrast passes WCAG AA in both modes.
- No layout breaks at 1280px width.
- Commit on `feat/app-theme`. List the files changed, every route you restyled, and anything you could not match exactly.
