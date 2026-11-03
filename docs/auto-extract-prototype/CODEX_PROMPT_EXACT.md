# Codex prompt: Auto Extract, an exact copy of the prototype (Flutter, nothing else changes)

**Before you run it:** copy the whole `findez-auto-extract-prototype` folder into the repo at `docs/auto-extract-prototype/`. Then paste everything below the line into Codex from the repo root.

This replaces every earlier Auto Extract prompt.

---

MOBILE (FLUTTER) ONLY. Replace the Auto Extract (add items from a photo) UI with an **exact copy** of the prototype at `docs/auto-extract-prototype/findez-auto-extract-prototype.html`. The screens to match are `docs/auto-extract-prototype/screens/02-add-sheet.png` to `07-saved-and-ask.png`. Open the HTML in a browser and click through it first.

Every size, colour, radius, label and animation below comes from the prototype's CSS. Use them as they are: 1 CSS px = 1 logical pixel in Flutter. If this prompt and the HTML ever disagree, the HTML wins.

## Hard rules: what you must NOT change

This is a UI swap for one flow. Change nothing outside it.

- **No backend, API, Supabase, web app, env or config changes.**
- **No logic changes.**
  - Keep the existing extraction call, save call, Space list, create-Space call and delete call exactly as they are, with the same request and response handling.
  - Only change the widgets that display them and the local UI state.
- **No changes to models, services, repositories, API clients or routes.** The same goes for any provider or state logic that other screens use.
- **No new packages,** and no edits to `pubspec.yaml` or `pubspec.lock`.
- **Don't edit the global theme.** Put the colours below in a private constants file inside the Auto Extract folder.
- **Leave the rest of the Ask screen alone:**
  - the top bar, the empty state, the composer's layout, normal chat bubbles and normal chat answers;
  - the one exception is the composer changes in step 3, which happen only while an extraction is running or being reviewed.
- **Leave every other screen alone:** Home, Spaces, the Space detail, Inventory, Settings, onboarding, voice and so on.
- **Remove nothing users can do today.** Extract, retry, select or deselect, edit, choose a Space, create a Space, save and cancel all still work.

## Step 0: find the code first

Before you edit anything:

1. Find every file that renders the current Auto Extract UI:
   - the loading or "Review extraction" card;
   - the results list;
   - the edit sheet;
   - the Space picker;
   - the saved state.
2. Print the list of files.
3. Only edit those files. Put any new widgets in one new folder **next to the existing extraction code** (for example `.../auto_extract/widgets/`).
4. If you think you need to touch a file outside that list, **stop and explain why** instead of doing it.

## Tokens: use exactly these

| Token | Value |
|---|---|
| bg | `#111112` |
| s1 | `#1C1C1E` |
| s2 | `#232325` |
| s3 | `#2C2C2F` |
| sheet | `#1A1A1C` |
| line | white at 8% (`#14FFFFFF`) |
| line2 | white at 13% (`#21FFFFFF`) |
| tx | `#FAFAFA` |
| tx2 | `#9A9AA0` |
| tx3 | `#5F5F64` |
| white pill | `#F2F2F2` |
| ink (text on white) | `#0B0B0C` |
| red | `#E5484D` |
| curve | `Cubic(0.32, 0.72, 0, 1)` |

- **Font:** the iOS system font, the same as the rest of the app.
- **Icons:**
  - stroke 1.9, round caps and joins, 20pt unless stated otherwise;
  - use the icon set the app already uses for: plus, camera, image, pen, check, minus, pin, chevron-down and search.
- **"Hairline"** below means a 1pt inner border in that colour.

## 1. Add sheet (`02-add-sheet.png`)

**When it opens:** from the composer's **+** and from any existing "add photo" entry point.

**Scrim:** black at 55% with a 4pt blur. It fades in over 350ms using the curve, and tapping it closes the sheet.

**Sheet:**
- Inset 8pt from the left, right and bottom. Radius 38, fill `sheet`, a line2 hairline, and the shadow `0 -20 60` black at 60%.
- Padding: 10 top, 18 sides, 26 bottom. Maximum height 80% of the screen; it scrolls inside if needed.
- It slides up from `translateY(110%)` to 0 over 500ms using the curve.
- **Grab handle:** 38×5, radius 3, white at 20%, centred, with 14 below it.

**Contents, top to bottom:**
- **Title:** "Add from a photo", 22pt, weight 700, letter spacing −0.02em.
- **Subtitle:** "Snap a shelf, drawer or bin. FindEZ lists every item, and nothing saves until you approve." 14.5pt, tx2, with 4 above it.
- **Two buttons**, 16 below the subtitle, in a row with a 10pt gap:
  - 52 tall, radius 26, fill s2, weight 600, 15.5pt;
  - **"Camera"** (camera icon, 18pt, with an 8pt gap) and **"Library"**;
  - wire them to the existing camera and gallery pickers.
- **Recent photos:** the prototype's two demo photo cards are only there for the demo. If the app already keeps recent photos, show the last two as cards above the buttons, laid out like this:
  - a 2-column grid with a 10pt gap, 16 below the subtitle;
  - each card has radius 22, fill s2, a 110-tall image and a label area (padding 11/13/13) with the name at 15pt/600 and a second line at 12.5pt tx2;
  - if the app doesn't keep recent photos, leave the grid out.

**While a scan is running,** + doesn't open the sheet. It shows the toast "Still looking at your photo".

**Hidden sheets must never take taps.** Only the open sheet receives touches; use `IgnorePointer` or `Offstage` when closed.

## 2. Toast

- White pill `#F2F2F2` with ink text at 14pt/600. Padding 10/16, radius 20.
- Centred horizontally, 104pt from the top of the screen.
- It fades and slides down 20pt as it appears, over 400ms using the curve, and stays for 1.6s.

## 3. Scanning (`03-scanning.png`)

When a photo is picked, close the sheet and add two chat messages.

**User photo message:**
- Right-aligned, 200 wide, at the photo's aspect ratio, cropped to cover.
- Corner radii: 20, 20, 6 (bottom right), 20. There's 14 above it.

**FindEZ reply:**
- A row with 16 above it and a 10pt gap.
- **Avatar:** 28×28, radius 8, white, with the black clove (15pt) centred.
- **Body:** fills the remaining width. In order:
  1. **Title:** "Looking at your photo" at 15.5pt, line height 1.5, followed by three dots:
     - each dot is 5×5 and tx2, with a 4pt gap and 6pt to the left of the first;
     - they blink from 25% to 100% to 25% opacity over 1.2s, starting 0.15s apart.
  2. **Live line:** "Found " plus the lowercase names found so far, joined with ", ". 13.5pt tx2, 2 above it, minimum height 19.
  3. **Photo:** full width at its **real aspect ratio**, not cropped. Radius 18, black behind it, 12 above it.
     - **Sweep:** a band 45% of the photo's height, a vertical gradient from white at 0% to 22% (at 85% down the band) to 80%;
     - it moves from −45% to 100% of the photo's height every 1.8s on `Cubic(.45, 0, .55, 1)`, looping.
  4. **Progress bar:** 3 tall, radius 2, s2 track, white fill, 12 above it.
     - It starts at 8%, each found item moves it to `found / total × 90%`, and it animates over 500ms using the curve.
  5. **Tile grid:** 2 columns with an 8pt gap, 12 above it. It starts with **2 shimmer tiles**:
     - each is 62 tall, radius 16, fill s1;
     - a soft white sweep (6% opacity) moves across every 1.4s.

**As each item arrives:**
- **Box:** add the item's box on the photo at its position.
  - It starts at 0% opacity and 1.12× scale, then animates to normal (opacity 350ms, scale 450ms, both using the curve).
- **Tile:** add the item's tile in front of the shimmer tiles. Once 2 or more items have arrived, keep only 1 shimmer tile.
- **Messages:** every new chat message fades in and rises 10pt over 450ms using the curve.

**Composer while scanning:**
- The placeholder becomes "FindEZ is looking…".
- The send button becomes a **stop** button: 46 round, white fill, with a 12×12 ink square (radius 3) in the middle.
- **Stop:** cancels the request if the existing client supports cancelling; otherwise ignore the result when it arrives. Then replace the reply's body with "Stopped. Nothing was saved."

**If the API returns all items at once,** keep the sweep and the bar going until the response arrives. Then reveal the boxes and tiles one by one, 120ms apart.

**Box style:**
- 2pt white border, radius 10.
- **Number badge:** 20 round, white, 11pt/700 ink, sitting −9pt from the box's right and top edges.
- **Left out:** the border is dashed at white 50%, and the badge is white at 55%.
- **Highlight:** an outer ring 4pt wide, white at 30%, for 500ms.

**Tile style:**
- Radius 16, fill s1, line hairline, padding 8, 10pt gap.
- **Image:** 46×46, radius 11, cropped to cover.
  - Its badge is 18 round, white, 10pt/700 ink, sitting −5pt from the image's left and top edges.
- **Name:** 13.5pt/600, line height 1.2, maximum 2 lines.
- **Second line:** "×24" at 12pt tx2, with 3 above it. Add " · not sure" for low-confidence items.
- **Pencil:** a 24 round tap target at the top right (6pt inset), with a 14pt pen icon in tx3.
- **Pressed:** scale 0.98.
- **Left out:** 42% opacity, with the name struck through.
- **Highlight:** an inner 1.5pt white border for 500ms.

## 4. Review (`04-review.png`)

When extraction finishes, the same reply changes:

**Removed:** the sweep, the progress bar, the shimmer tiles and the live line.

**Title text:**
- "I found **N items**." with "N items" at weight 600, and "item" when there's only one.
- If any items are low confidence, add " I left out the [names, lowercase, joined with " and "] because I'm not sure."
- If the API has no confidence data, show only the first sentence and select every item.

**Low-confidence items** start **left out**.

**Item names:** sentence case. If the extracted name has a parenthetical, show the part before it as the name. This is display only; don't change the data.

**Tapping a tile or its box** toggles that item in or out and highlights both.

**Row under the tiles,** 12 above it, with an 8pt gap:
- **Space pill:**
  - takes 1 share of the width, 46 tall, radius 23, fill s2;
  - padding 14 left and 12 right, 14pt/600, 6pt gaps;
  - contents: a pin icon (17pt), the Space name (one line, ellipsis, fills the space), and a chevron (16pt, tx2);
  - it defaults to the last Space used on this device.
- **Save button:**
  - takes 1.15 shares of the width, 46 tall, radius 23, white with ink text at 15pt/600;
  - the label is "Save N items" ("Save 1 item" for one);
  - when nothing is selected, the label is "Select items", at 35% opacity and disabled;
  - pressed: scale 0.97.

**Hint,** 12.5pt tx3, 8 above it: "Tap an item or its number to leave it out. Tap ✎ to edit."

**Composer placeholder** during the review: "Or tell me what to change…".

## 5. Edit sheet (`05-edit.png`)

It opens from a tile's pencil and uses the same sheet, scrim and handle as the add sheet.

**Crop:** 150 tall, radius 20, cropped to cover, with 4 below it.

**Fields:**
- Each field has radius 16, fill s2, padding 10/14 and 10 above it.
- Each label is 11.5pt/500 tx2. Each input is 16.5pt/500 tx with 2 above it.
- **Name:** a text field.
- Then a row with a 10pt gap and two equal fields:
  - **Quantity:** a − button, the number and a + button.
    - Each button is 34 round, fill s3, with a 16pt icon.
    - The number is 20pt/600, at least 36 wide, centred, with a 14pt gap and 4 above.
    - The minimum is 1.
  - **Details:** a text field, using whatever field the current edit uses (category, description or notes).

**Buttons,** 16 above them, with a 10pt gap, each 52 tall, radius 26, 15.5pt/600:
- **"Leave out":** fill s2 with red text, 1 share of the width.
- **"Done":** white with ink text, 1.4 shares.

**What they do:**
- "Done" saves the name, quantity and details to that item in local review state, selects it, and closes the sheet.
- "Leave out" deselects it and closes the sheet.

## 6. Fixing things by typing

During the review only, check a message the user types **on the device** before it goes to the chat:

- **Quantity fix:** if the message has a number and a word of 4 or more letters from an item's name (ignoring a trailing "s"), set that item's quantity, select it, and reply "Updated: **Socket head screws** ×30."
- **Leave out:** if it matches an item and contains "remove", "leave out", "not", "skip" or "wrong", deselect that item and reply "Left out **Electrical tape**."
- **Anything else** goes to the existing chat, unchanged.

The user's message shows as a normal user bubble. FindEZ's reply shows with the same avatar.

## 7. Space sheet (`06-space.png`)

It opens from the Space pill and uses the same sheet.

**Title:** "Save N items to…" (22pt/700).

**Search field,** 14 above it:
- 46 tall, radius 23, fill s2, padding 0/14, 8pt gap;
- a search icon (17pt, tx2) and the input (15.5pt), with the placeholder "Search Spaces";
- it filters live as you type.

**List,** 12 above it, grouped by inventory:
- **Group label:** "Season 2026-27 · Hardware" style, 12.5pt/600 tx3, margins 14/10/4/10. Use the real workspace and inventory names.
- **Rows:**
  - full width, padding 11/10, radius 16, 12pt gap;
  - the selected row (and the pressed row) has an s2 fill;
  - **Tile:** 42×42, radius 12, the Space's gradient (see below);
  - **Name:** 15.5pt/600;
  - **Under the name:** "Hardware · 42 items", or "Empty", at 12.5pt tx2;
  - **Selected:** a 24 round white check on the right, with a 13pt ink check icon at stroke 3.

**New Space row** at the end:
- An s3 tile with a plus icon (18pt).
- The label is **"New Space"**, or **New Space "query"** when there's search text. The line under it reads "Create it and save here".
- It uses the existing create flow, selects the new Space straight away, closes the sheet, and shows the toast `Created "name"`.

**Picking a row** closes the sheet and updates the pill. **It doesn't save.**

**Space gradients:** if Spaces already have gradient tiles in the app, reuse them exactly. Otherwise, use these four, picked by a stable hash of the Space name:

| Name | Base gradient | Glows |
|---|---|---|
| slate | 150°: `#B9BEC5`, then `#6E747D` (at 50%), then `#24272C` | `#D9DCE0` top-left, `#2A2D33` bottom-right |
| moss | 160°: `#3E5A4C`, then `#6F8C74` (at 50%), then `#22322C` | `#E3C9A6` top-right, `#24493F` bottom-left |
| dusk | 150°: `#9AA6B2`, then `#4E5878` (at 50%), then `#151729` | `#B7C3CC` top-left, `#1A1C33` bottom-right |
| plum | 160°: `#2B2440`, then `#6B5486` (at 50%), then `#A7808F` | `#E8B9A6` top-right, `#241D3D` bottom-left |

## 8. Saved (`07-saved-and-ask.png`)

**On Save:**
- Call the existing save.
- Fade the reply's body out (250ms), then replace it with the content below and fade it back in.
- If saving fails, keep the review exactly as it was, show the error in a toast with a retry, and keep every edit.

**Saved card,** 4 above it:
- Padding 12, radius 18, fill s1, line hairline, 10pt gap, 14.5pt text.
- A 24 round white check (13pt ink check, stroke 3).
- "Saved **3 items** to Workbench", with "3 items" at 600.
- On the right: up to 4 item crops, each 30×30, radius 8, overlapping by −8pt, with a 2pt s1 ring.

**Action pills,** 10 above them, 8pt gap:
- Each is 38 tall, radius 19, fill s2, padding 0/15, 14pt/600.
- **"Open Workbench":** goes to that Space's existing screen.
- **"Undo":** uses the existing delete for exactly those items, then the body becomes "Undone. Nothing from that photo was saved." and the toast "Undone" appears. If there's no item delete, hide Undo.

**Suggestion chips,** 14 above them, 8pt gap:
- Each is 36 tall, radius 18, fill s1, line hairline, padding 0/15, 13.5pt tx2.
- **"Where is the [first item, lowercase]?"** sends that question through the existing chat.
- **"Add another photo"** opens the add sheet.

**The composer placeholder** goes back to the normal one.

Don't change how normal chat answers look. Questions after saving use the existing chat UI exactly as it is today.

## Motion and accessibility

- Use only the durations and curves listed above.
- With Reduce Motion on: no sweep and no shimmer. Everything else is a fade only.
- Every tappable thing gets a semantics label, including "Edit [item]", "Leave out [item]" and "Stop".
- Every tap target is at least 44×44, with padding around the smaller visuals.

## Check before you finish

1. `flutter analyze` is clean and the app builds for iOS.
2. Do a real extraction with **1 item, 4 items and 10+ items**.
   - Put each step next to the matching prototype screenshot and fix any difference in spacing, size, colour or text.
   - With more than 8 items, the boxes show their number badges only.
3. Test:
   - **stop** in the middle of a scan;
   - a **typed correction**;
   - the **edit sheet**;
   - search and **New Space**;
   - **save**;
   - **Undo**;
   - a **failed save** (airplane mode);
   - that **no hidden sheet catches taps**.
4. Check that the rest of the Ask screen and every other screen look and behave exactly as before.
5. Run `git diff --stat` and show it. Every changed file must be from your step 0 list or the new Auto Extract widget folder. If anything else changed, revert it.
6. In your summary, list:
   - anything you hid because the API doesn't return it (boxes, items arriving one by one, confidence, crops);
   - the files you changed.
7. Commit on a new branch, `feat/auto-extract-exact`. **Don't push.**
