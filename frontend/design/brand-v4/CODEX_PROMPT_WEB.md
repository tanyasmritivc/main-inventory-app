# Codex prompt: switch the web app to the Petals logo

Before you run this, copy the whole `findez-brand-kit-v4` folder into the repo at `frontend/design/brand-v4/`.

Then paste everything below the line into Codex from the repo root.

---

WEB FRONTEND ONLY. Replace every FindEZ logo in the Next.js app with the new Petals logo, and make sure the theme tokens match. The source is `frontend/design/brand-v4/`. Read `BRAND.md` there first.

## Scope (strict)

- Do NOT touch backend/, mobile/, the Supabase schema, RLS, env files, CI or deploy config.
- Change only logos, icons and theme tokens. Do not change layouts, copy, routes or logic.
- Work on a new local branch `web-brand-v4`. Do not push or deploy.

## Logo

1. Copy `frontend/design/brand-v4/logo/` to `frontend/public/brand/`, replacing what is there. Remove older logo files from `public/brand/` only if nothing still imports them after the swap.
2. Replace every logo with the new files:
   - landing nav and footer, app sidebar and header, auth pages, onboarding;
   - empty states;
   - OG and Twitter images that live in this frontend;
   - the 404 page.

   Rules:
   - Where the logo appears with the name, use `findez-wordmark.svg`, or `findez-wordmark-white.svg` on dark backgrounds.
   - Where it appears alone, use `findez-mark.svg`. On orange backgrounds, use `findez-mark-white.svg`.
   - Below 32px, use `findez-mark-small.svg`.
   - Remove any separate "FindEZ" text that sat next to an old logo when the wordmark now includes the name.
3. Remove every old logo, including inline SVG copies. Search for:
   - Blue echo paths: `A4.5 4.5` and `A2 2 0 0 1 27.25`;
   - the colour `#A9D6F5` used inside a logo component;
   - "Item ring" or "ring" logo components;
   - files named `echo` or `findez-mark` that are older versions.
4. Favicon and icons in the Next.js metadata:
   - `icon`: `findez-favicon.svg`, with `findez-favicon-32.png` and `findez-favicon-16.png` as fallbacks;
   - `apple-icon`: `findez-app-icon-180.png`.

   Use `app/icon.*` and `app/apple-icon.*`, or the `icons` metadata field, whichever the app already uses.
5. `docs/landing-v3` and older prompts mention other logos. This prompt overrides them.

## Theme

- Compare the CSS variables and the Tailwind config against `theme/tokens.json`, `theme/findez-theme.css` and `theme/tailwind.findez.js`, and make the values match:
  - orange #E8590C
  - orange-ink #C2410C
  - orange-tint #FFE8DA
  - ink #111112
  - baby blue #A9D6F5
  - blue-tint #EEF6FD
  - night #0B0B0D
- Fonts: Plus Jakarta Sans (400, 500, 600) and Geist Mono (400, 500), loaded through `next/font/google`.
- Do not restyle components beyond swapping token values.

## Check before you finish

- `npm run lint` and `npm run build` pass with no new warnings.
- At 1440×900 and 390×844, the new logo shows everywhere and no old logo remains.
- The browser tab shows the orange favicon.
- `git grep -n "A4.5 4.5"`, `git grep -n "27.25 35.25"` and `git grep -in "item ring"` return nothing in app code.
- Commit on `web-brand-v4`. List the files changed and anything you could not match.
