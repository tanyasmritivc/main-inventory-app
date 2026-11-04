# Codex prompt: Space screen polish (4 fixes, in place), then TestFlight

Unzip this folder into the repo at `docs/space-polish/`. Then paste everything below the line into Codex from the repo root on your Mac.

---

MOBILE (FLUTTER) ONLY. Make four small visual fixes to the **existing** Space detail screen (for example "Fastener DB"), shown in `docs/space-polish/screens/current-space.png`. Then upload a build to TestFlight.

## Rules

- **Change the existing widgets in place.** Don't create a copy, a "v2" file, a new screen or a feature flag.
- **This is a visual change only:**
  - Don't change item names, fields, column names, values, sorting logic, the review logic or the low-stock logic.
  - Don't touch the backend, the API, Supabase or the web app.
  - Every button and action on this screen keeps working exactly as it does now.
- **Reuse the shared pieces added earlier:** the `RisoPalette` colours, the grain texture (`assets/textures/grain.png`), the grainy-art painter, and the Inter Tight font. If the grain asset is missing, use `docs/space-polish/grain.png`. **Don't duplicate any of them.**
- **No new packages.**
- **Git:** work on a new branch, `feat/space-polish`. Commit, and push the branch to `origin`. Don't merge into main.

## Fix 1: risograph tiles for items without a photo

The grey metallic tiles with an archive-box icon get replaced. **Items that have a photo stay exactly as they are.**

**The tile:**
- Same size and position as today (about 52 to 56pt square), radius 13, clipped so the corners are rounded, with a 1pt inner ring of white at 8%.
- **Fill:** risograph art with grain, the same gradient and grain style as the Founding Access sheet and the photo scan. Grain is drawn twice: overlay at 95% and soft-light at 80%.

**Which palette:**
- Pick it with a **stable hash of the item's category** (fall back to the Space name if there's no category), so every item in "Supplies" shares one palette and it never changes between visits.

| Palette | Colours |
|---|---|
| Blue / Slate | `#97A6B1`, `#748193`, `#4B556F`, `#222236` |
| Terracotta / Ochre | `#AB5D44`, `#AC7A52`, `#757067`, `#D3B19E` |
| Plum / Rust | `#453349`, `#773F42`, `#996050`, `#B69D9F` |
| Sage / Olive | `#576B5B`, `#6C7F6D`, `#84947F`, `#AAB3A9` |

**Icon:**
- A white line icon at 22pt, 90% opacity, with a soft shadow of black at 25%.
- If the app already maps categories to icons, use that.
- Otherwise use a small keyword map on the item name or category (display only):

| Keywords | Icon |
|---|---|
| belt, chain | link |
| screw, bolt, nut, washer, standoff | hex nut |
| wire, cable | cable |
| battery | battery |
| motor, servo, gear | gear |
| tool | wrench |
| anything else | the simple box icon |

**Performance (required):** a Space can hold hundreds of items.
- Draw each palette's art **once**: cache it as a `ui.Image` or `Picture`, or use a `RepaintBoundary` keyed by palette, and reuse it for every tile.
- Scrolling 300 items must stay smooth. Check in profile mode.

## Fix 2: the Review card shows a count

- Change "Items to finish" to **"N to finish"**, using the existing review count, so it matches Low quantity ("2 items").
- **If a count is 0, hide that card.** The other card then takes the full width. If both are 0, hide the whole row.
- Keep tapping (and long-pressing, if supported) exactly as it is today.
- If the review count isn't available on this screen without a new API call, keep the current text and say so in your summary. **Don't add an API call.**

## Fix 3: the title font

- Set the large Space name ("Fastener DB") in **Inter Tight Regular (400)**, 34pt, letter spacing −0.02em, line height 1.1, colour `#F4F4F5`.
- Leave its size, position, the breadcrumb and the stats line ("298 items · 7,583 units") unchanged.
- The small title that appears in the top bar on scroll stays in the current font.

## Fix 4: sort label and row text

- **Sort label:** right-align the sort name in the row above the list ("Part # / Item A → Z") to the **same right edge as the quantity numbers**. Keep its text and its 12.5pt tertiary style.
- **Row names:** reduce the item name from about 17pt to **15.5pt**, weight 600, line height 1.25, still **at most 2 lines**. The name text stays exactly as stored.
- **Second line** ("Supplies"): 13pt, secondary colour.
- **Quantity column:** unchanged.

## Check before uploading

1. `flutter analyze` is clean, and `flutter test` passes if there are tests.
2. On a simulator, check:
   - Fastener DB (298 items), a small Space, and a Space where items have photos (photos unchanged);
   - a Space with 0 to review and 0 low (cards hidden);
   - scrolling stays smooth;
   - search, sort, filters, item tap, Ask and + all still work.
3. Take screenshots of Fastener DB at the top, Fastener DB scrolled, and a Space with photos.
4. Run `git diff --stat`. Only the existing Space screen and row widgets, and any shared riso helper that truly had to be extended, should change. Nothing should be duplicated.

## Build and upload to TestFlight

1. Bump the build number by 1 in `pubspec.yaml`. Commit on `feat/space-polish`, then push the branch to `origin`.
2. Upload **the way this repo already releases iOS:**
   - **fastlane:** the beta lane;
   - **Xcode Cloud or Codemagic:** trigger it from the branch;
   - **otherwise:** `flutter build ipa --release` with the existing signing, then `xcrun altool --upload-app --type ios` using the API key already set up on this Mac.
3. **Credentials:** never create, print, log or ask for passwords, keys, certificates or profiles. If something is missing, stop and tell me exactly what.
4. Set the TestFlight "What to Test" note to: "Space screen polish: risograph tiles for items without photos, Review count, new title font, tidier rows. Check Fastener DB scrolls smoothly."
5. **Report:**
   - the version and build number;
   - the commit hash;
   - whether the upload succeeded;
   - whether the review count was available;
   - the files you changed;
   - the screenshots.
