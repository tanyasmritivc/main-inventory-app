# Codex prompt: redesign the photo scan screen in place, then ship to TestFlight

Unzip this folder into the repo at `docs/photo-scan/`. Then paste everything below the line into Codex from the repo root on your Mac.

---

MOBILE (FLUTTER) ONLY. Redesign the **existing** photo scanning card in the Ask chat: the one that says "Scanning photo… / Checking shapes and visual features." with the photo, the progress bar and "Nothing is saved until you review and approve." Then build the app and upload it to TestFlight.

## Change it in place. Don't make a copy

- **Edit the existing scanning widget and its files directly.** Don't create a second version, a "v2" file, a new screen, or a feature flag that keeps the old card around.
  - When you're done, the old card's layout code should be gone, replaced by the new one in the same place.
  - The card still appears in the same spot in the Ask chat, driven by the same scan state.
- **Reuse what's already in the app:**
  - the risograph palettes (`RisoPalette` or similar);
  - the grain texture (`assets/textures/grain.png`) and the grainy-art painter from the Founding Access work;
  - Inter Tight, the theme colours, the clove logo, the toast.
  - If one of these is missing, add it once in the shared place, using the files in `docs/photo-scan/assets/`. Never duplicate it.
- **Same logic, new look:**
  - **Don't change** the scan request, the API, the backend, Supabase, the web app, how items are parsed or saved, or the review screen.
  - Stop, the note field, Retake and Review keep calling exactly what they call today.

## Reference (only to check against; don't embed the HTML)

- **`docs/photo-scan/findez-photo-scan.html`** is the approved design. Open it in a browser: it plays the whole scan on its own.
- **`docs/photo-scan/screens/`**:
  - `01-scanning.png`
  - `02-items-arriving.png`
  - `03-done.png`
  - `04-leave-one-out.png`
  - `05-stopped.png`

## Step 0: look before you build

Find and list:

1. The scanning card widget and the state behind it: progress, found items, done, stopped and error.
2. What the scan API gives back:
   - item names;
   - bounding boxes (and in what units);
   - whether items arrive one by one or all at once;
   - crops or thumbnails;
   - real progress.
3. How "Review" opens today, and whether the review already has a selected / not selected state per item.
4. The existing pieces for riso palettes, grain, fonts and the toast.

## Tokens

| Token | Value |
|---|---|
| Card background | vertical gradient `#161618` → `#121214`, a 1pt ring of white at 8%, a 1pt top highlight of white at 4.5% |
| Soft fill | `#1B1B1E` |
| Text | `#F4F4F5` |
| Secondary text | `#A1A1A6` |
| Tertiary text | `#6B6B70` |
| Hairline | white at 7% |
| Ring | white at 12% |
| Curve | `Cubic(.32,.72,0,1)` |

- No orange or amber in the interface. Colour appears only in the art.

## The card

- **Outer card:** radius 28, the card background, padding 8. It fades in and rises 10pt over 500ms when it appears.

### 1. Stage (`01`, `02`)

A box **300pt tall**, full width, radius 22, clipped so **all four corners are rounded**.

- **Background:**
  - the **Plum / Rust** risograph art with grain, the same gradient and grain as the Founding Access sheet (grain in two passes: overlay at 95% and soft-light at 80%);
  - over it, the captured photo blurred by 30, in greyscale, at 28% opacity, blended with luminosity.
  - This replaces the black letterbox bars.
- **Photo:**
  - centred, 14pt from the top and bottom, at its **real aspect ratio** (contain, never stretched or cropped);
  - radius 14, clipped;
  - a 1pt ring of white at 12% and the shadow `0 18 50` black at 45%.
- **Veil:** while scanning, a black layer at 18% sits over the photo. It fades away when the scan is done.
- **Sweep** (while scanning only):
  - a band 42% of the photo's height, filled with the same Plum / Rust art and grain, blended with `screen` at 95%;
  - its top and bottom edges fade out;
  - it has a 2pt white leading line near its bottom edge, with a soft white glow;
  - it moves from above the photo to below it every 2.4s, on a loop, with `Cubic(.45,0,.55,1)`.
- **Item boxes:** only if the API returns boxes.
  - **Size and fade-in:** each box is placed and sized as a fraction of the photo. It fades in and settles from 1.06× scale (400 to 500ms) as its item arrives.
  - **Frame:** radius 12, a 1.5pt inner white border at 90%.
  - **Label,** 4pt in from the top-left corner (top-right when the box touches the right edge and is narrow):
    - 22 tall, radius 11, near-black at 55% over a 12pt blur, a 1pt ring of white at 20%;
    - a 16pt white circle holding the number (10.5pt weight 700, ink), then the name at 11pt weight 500, white.
  - **Left-out boxes:** the border drops to white at 45% and the label to 60% opacity with a strike-through.
  - **Tapping a box** does the same as tapping its tile (see "Done" below).
- **Status chip** at the top left, 12pt in:
  - 30 tall, radius 15, near-black at 50% over a 14pt blur, a 1pt ring of white at 18%;
  - a pulsing 8pt white dot, then "Scanning", which becomes "Done".
- **Count chip** at the top right, in the same style:
  - "N found" while scanning;
  - "N of M selected" when done (if selecting is supported).

### 2. Text

Padding 16 on top, 10 on the sides.

- **Title:** Inter Tight 400, 26pt, −0.02em. It reads "Looking at your photo", then "N items found" when done.
- **Live line,** 6pt below the title: 14.5pt, secondary.
  - Before anything is found: "Checking shapes and labels…".
  - Then: "Found headphones so far", "Found headphones and a Mac mini so far", "Found headphones, a Mac mini and keyboard so far", using the real item names in lowercase.
  - When done: "Tap an item to leave it out, then review and save." If leaving items out isn't supported, use "Review and save when you're ready."

### 3. Progress bar (while scanning only)

- 3pt tall, radius 2, a track of white at 8%, a `#F4F4F5` fill. It sits 14pt below the text with 10pt side padding.
- **If the API reports real progress, use it.** Otherwise start at 14%, step up as each item arrives (14% plus a share of 76%), ease towards 90% if nothing arrives, and fill to 100% on done. Each change animates over 700ms.

### 4. Tiles

A row that scrolls sideways, with an 8pt gap and padding 14 / 10 / 2.

- **Tile:** 76×76, radius 16, a 1pt hairline ring.
  - It shows the item's crop. If the API gives a box, crop the photo to that box. If it gives a thumbnail, use that. Otherwise show a small riso art tile with a line icon.
  - A 18pt white number badge sits 5pt from the top-left corner.
  - The name sits under it: 12pt weight 500, one line with an ellipsis.
- **Arriving:** tiles slide in from 16pt to the right and fade in (450ms).
- **Placeholders:** while scanning, keep **one shimmer placeholder tile** at the end. Start with 3 placeholders and drop to 1 once two items have arrived.
- **All at once:** if the API returns every item in one go, reveal the boxes and tiles one by one, 120ms apart.

### 5. Done (`03`, `04`)

When the scan finishes:

- the sweep and the bar go away and the veil fades;
- the status chip says "Done";
- the chat **scrolls smoothly** so the buttons are visible above the composer.

**Leaving items out (only if the review screen already has a selected state):**

- Tapping a tile or a box toggles that item.
- A left-out tile drops to 40% opacity.
- **This must use the same selection state the review uses**, so the review opens with those items already left out. If the review has no such state, don't make tiles or boxes tappable.

**Buttons,** 16pt above them, with an 8pt gap. Each is 50 tall, radius 25, 15.5pt weight 600, and scales to 0.98 when pressed.

- **"Review N items"** (takes 1.6 shares of the width):
  - a vertical gradient from `#F4F4F5` to `#D4D4D8` with ink text, a white top highlight at 60%, and the shadow `0 8 24` black at 35%;
  - it reads "Select items" and is disabled at 40% when nothing is selected;
  - it opens the **existing** review.
- **"Retake"** (takes 1 share): transparent with a 1pt ring of white at 12%. It opens the existing camera flow.

### 6. Footer

- A 14pt lock icon and "Nothing is saved until you review and approve.", 12.5pt tertiary, with padding 12 / 10 / 8.

### 7. Stopped (`05`)

- When stop is tapped, the card becomes a short card, centred, with 22pt vertical padding:
  - "Scan stopped" in Inter Tight 400 at 22pt;
  - "Nothing was saved." at 14pt secondary;
  - a "Scan again" outline pill (44 tall).
- "Scan again" reruns the scan using the existing retry.

### 8. Errors

- If the scan fails, use the stopped layout with "Couldn't read this photo", the existing error text as the line under it, and "Try again".

## Composer

- **Keep the existing composer** and its note field.
  - While scanning: the placeholder is "Add a note while scanning…" and the white stop button (a 46pt circle with a 13pt ink square) stops the scan.
  - When done: the placeholder becomes "Ask about these items…" and the button goes back to the normal send button.
- **Don't change** what the note or the send button do.

## Accessibility and motion

- The stage has the semantics label "Scanning your photo", which becomes "4 items found" when done.
- Each tile and box reads its number, its name, and whether it's included.
- Stop says "Stop scan".
- Tap targets are at least 44pt.
- With Reduce Motion on: no sweep, no pulse and no slide. Use fades only.

## Check before uploading

1. `flutter analyze` is clean, and `flutter test` passes if there are tests.
2. Run real scans on a simulator or device:
   - a portrait photo, a landscape photo, a photo with 1 item, and one with 10+ items;
   - stop in the middle of a scan;
   - a failed scan (airplane mode);
   - leave one item out and check the review opens with it already left out (if supported).
3. Check:
   - **no black letterbox bars**;
   - the art and the photo have rounded corners;
   - nothing sits under the composer when done;
   - it fits on the smallest supported iPhone.
4. Take screenshots of scanning, done and stopped.
5. Run `git diff --stat`. **The old scanning card's layout is replaced, not duplicated.** Only the scanning widget files, shared riso/grain files (if they had to be added) and the build number should change.

## Build and upload to TestFlight

1. Work on a new branch, `feat/photo-scan-riso`. Commit the change.
2. Bump the **build number** by 1 in `pubspec.yaml`, commit, and push the branch to `origin`. **Don't merge into main.**
3. Upload to TestFlight **the way this repo already releases iOS:**
   - **fastlane:** the existing beta or TestFlight lane;
   - **Xcode Cloud or Codemagic:** trigger it from the pushed branch;
   - **otherwise:** `flutter build ipa --release` with the existing signing, then `xcrun altool --upload-app --type ios` using the App Store Connect API key **already set up on this Mac**.
4. **Credentials:** never create, print, log or ask for passwords, keys, certificates or profiles. If something is missing, stop and tell me exactly what.
5. Set the TestFlight "What to Test" note to: "New photo scan screen: risograph art instead of black bars, items boxed and listed as they're found, tap to leave items out, then Review. Try a portrait and a landscape photo, and stop mid-scan."
6. **Report:**
   - the version and build number;
   - the commit hash and branch;
   - whether the upload succeeded, and its processing status if you can see it;
   - what the API did or didn't provide (boxes, items one by one, progress, crops) and what you fell back to;
   - the files you changed;
   - the screenshots.
