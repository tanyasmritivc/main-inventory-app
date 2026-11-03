# Codex prompt: Auto Extract in chat (Flutter), built from the working prototype

Before you run this, copy the whole `findez-auto-extract-prototype` folder into the repo at `docs/auto-extract-prototype/` (the HTML, `overview.png` and `screens/`). Then paste everything below the line into Codex from the repo root.

This replaces the earlier Auto Extract prompts (the full-screen type A, type B and loader option C). If any of those were already started, keep what matches this prompt and drop the rest.

---

MOBILE (FLUTTER) ONLY. Rebuild the Auto Extract (add items from a photo) flow so it works exactly like the prototype in `docs/auto-extract-prototype/findez-auto-extract-prototype.html`. Open that file in a browser and click through it before you start. The step-by-step screens are in `docs/auto-extract-prototype/screens/01-empty.png` to `07-saved-and-ask.png`.

## Rules

- **Mobile only.** Don't change the backend, API, Supabase, the web app, env or config. Use the endpoints and models the app already calls for extraction, saving items, Spaces, delete and chat.
- **Nothing is removed.** Every action that works today (extract, retry, select or deselect, edit, choose a Space, create a Space, save, cancel) still works.
- **Hide what the API doesn't return.** If something in the prototype needs data the API doesn't give you, hide that part and list it in your summary. Check in particular: detection boxes, items arriving one by one, a confidence or "not sure" flag, and item crops.
- **Spaces** are the unique `location` values on items (there's no Spaces table). Use however the app already builds that list.
- Use the existing dark theme tokens: background `#111112`, surfaces `#1C1C1E` / `#232325` / `#2C2C2F`, hairlines white at 8% and 13%, secondary text `#9A9AA0`, tertiary `#5F5F64`, white primary pill `#F2F2F2` with near-black text. Use the iOS system font and the curve `Cubic(.32, .72, 0, 1)`.
- Work on a new branch, `feat/auto-extract-chat`. Commit, but don't push.

## Where it lives

All of it happens **inside the Ask chat**. There's no separate full-screen page and no small card squeezed above the composer. The photo is the user's message, and FindEZ replies right under it. The review happens inside that reply.

## 1. Empty chat (`01-empty.png`)

- When the chat has no messages, centre this in the middle:
  - "What's in your world?" (28pt, weight 700);
  - "Snap a shelf, drawer or bin and FindEZ lists every item. Or just tell it what you have." in secondary text;
  - two chips: "Snap a shelf" (camera icon, opens the add sheet) and "Where did I put my drill?" (sends that question).
- It fades out as soon as the first message is added.
- **Top bar:** back on the left, "Ask" in the middle, and new chat on the right (this clears the conversation).
- **Composer:** + on the left, the text field ("Ask FindEZ…"), mic, and a round send button that turns white once there's text.

## 2. Add sheet (`02-add-sheet.png`)

- Opens from + or "Snap a shelf". It's a bottom sheet inset 8pt with radius 38, over a dark blurred scrim.
- **Contents:**
  - the title "Add from a photo";
  - "Snap a shelf, drawer or bin. FindEZ lists every item, and nothing saves until you approve.";
  - two buttons: **Camera** and **Library**, wired to the existing image picker.
- The two demo photos in the prototype are only there for the demo. Don't build them. Instead, if the app keeps recent photos, show the last two as quick picks; if it doesn't, leave that space out.
- If a scan is already running, + shows the toast "Still looking at your photo" instead of opening the sheet.
- **A hidden sheet must never catch taps.** Only the open sheet takes touches.

## 3. Scanning (`03-scanning.png`)

As soon as a photo is picked:

1. Add the photo as the **user's message**: a right-aligned rounded thumbnail (about 210×126, radius 20 with a 6pt bottom-right corner).
2. Add a **FindEZ reply** under it, with the white clove avatar on the left. It contains:
   - "Looking at your photo" with three pulsing dots;
   - one live line in secondary text: "Found battery charger, socket head screws…" (the lowercase names found so far);
   - the photo at its **real aspect ratio**, not cropped, radius 18, with a soft white sweep moving down it;
   - a thin 3pt progress bar under the photo;
   - a two-column tile grid with shimmer placeholder tiles.
3. As each item comes in, add its **numbered box** on the photo (white, 2pt, radius 10, with a white number badge on the top-right corner) and its **tile** before the placeholders. Boxes and tiles fade in and rise 8pt.
4. **Stop:** while scanning, the send button becomes a white **stop** button and the field's placeholder reads "FindEZ is looking…".
   - Tapping stop cancels the request, if the client can cancel it, and replaces the reply with "Stopped. Nothing was saved."

If the API returns everything at once instead of item by item, keep the sweep and progress bar running until the response arrives. Then reveal the boxes and tiles one after another, about 120ms apart.

## 4. Review: the reply becomes the review (`04-review.png`)

When extraction finishes, remove the sweep, the progress bar and the placeholders. The same reply then shows:

- **Text:**
  - "I found **N items**." in bold;
  - if any items are low confidence, add "I left out the [names] because I'm not sure.";
  - if there's no confidence data, show only the first sentence.
- **The photo** with numbered boxes. Items that are left out get a **dashed**, faded box.
- **Tiles**, two per row:
  - a 46pt crop with the number badge, the name (13.5pt / 600), and "×24" underneath, plus " · not sure" for low-confidence items;
  - a small pencil at the top right;
  - tapping a tile (or its box on the photo) toggles it in or out, and both get a short highlight;
  - a left-out tile is at 42% opacity with its name struck through;
  - low-confidence items start **left out**.
- **Item names:** sentence case and short. If the extracted name has a parenthetical, show the part before it as the name and use the rest as the details line in the edit sheet. This is display only.
- **One row underneath:**
  - a Space pill (pin icon, Space name, chevron), defaulting to the last Space used on this device;
  - the white **"Save N items"** button, which reads "Select items" and is disabled when nothing is selected.
- **Hint** in tertiary text: "Tap an item or its number to leave it out. Tap ✎ to edit."
- **Composer placeholder:** "Or tell me what to change…".

## 5. Edit sheet (`05-edit.png`)

- Opens from a tile's pencil. Same sheet style.
- **Contents:**
  - a large crop of the item;
  - **Name** (text field);
  - **Quantity** with − and + (minimum 1);
  - **Details** (text field, using whichever field the current edit already uses: category, description or notes);
  - **"Leave out"** (red text, secondary) and **"Done"** (white primary).
- "Done" updates the tile and makes sure the item is selected. "Leave out" deselects it. Both close the sheet.

## 6. Fixing things by typing

While a review is open, a message the user types is checked **on the device first**:

- **A number plus a word from an item's name** (for example "it's 30 screws") sets that item's quantity. FindEZ replies "Updated: **Socket head screws** ×30."
- **"Remove", "leave out", "skip", "not" or "wrong" plus a word from an item's name** deselects it. FindEZ replies "Left out **Electrical tape**."
- **Anything else** goes to the normal chat as usual.

This is a small local parser in the Flutter code. Don't add a backend endpoint for it.

## 7. Space sheet (`06-space.png`)

- Opens from the Space pill. The title is "Save N items to…".
- **Search field** ("Search Spaces"), which filters as you type.
- **Spaces grouped by inventory**, under a label like "Season 2026-27 · Hardware".
  - Each row has the Space's grainy gradient tile, the name, and "Hardware · 42 items" (or "Empty").
  - The current Space shows a check.
- **"+ New Space"** sits at the bottom. If there's search text, it reads **New Space "query"** and uses that name.
  - It uses the existing create flow, selects the new Space straight away, and shows the toast "Created "name"".
- Picking a Space closes the sheet and updates the pill. **It doesn't save.**

## 8. Saved (`07-saved-and-ask.png`)

- Tapping Save calls the existing save. The review content then fades out and in its place the same reply shows:
  - a card with a white check, "Saved **3 items** to Workbench", and the item crops overlapping on the right (up to 4);
  - **"Open Workbench"** and **"Undo"** as secondary pills;
  - two suggestion chips: "Where is the [first item]?" and "Add another photo".
- **Undo** uses the existing delete for exactly those items, then the reply changes to "Undone. Nothing from that photo was saved." If there's no delete for items, hide Undo.
- **Open** goes to that Space's screen.
- The composer goes back to "Ask FindEZ…".
- If saving fails, keep the review open and show the error with a retry. Never lose the user's edits.

## 9. Asking afterwards

- Questions after saving go through the **existing** chat as they do today.
- If the chat response already includes item references, show a single matching item as a card:
  - the crop, the name, a pin with "Inventory › Space", and the quantity on the right;
  - under it, "I used one" (lowers the quantity by 1 through the existing update) and "Move" (opens the Space sheet and moves the item through the existing update).
- If the response doesn't include item data, show plain text only. Don't invent answers on the device.

## Motion

- New messages fade in and rise 8pt.
- Sheets slide up over about 500ms with the curve above, and the scrim fades in at the same time.
- The sweep loops every 1.6s.
- With Reduce Motion on: no sweep, and fades only.

## Check before you finish

- `flutter analyze` is clean and the app builds for iOS.
- Do a real extraction with **1 item, 4 items and 10+ items**.
  - With more than 8 items, keep the boxes readable: number badges only, with no labels on the photo.
  - The tile grid scrolls with the chat.
- Test **stop** in the middle of a scan, a **typed correction**, the **edit sheet**, **New Space**, **save**, **undo**, and a **failed save** (airplane mode).
- **No hidden sheet catches taps.**
- Every existing action still works.
- In your summary, list:
  - anything you hid because the API doesn't return it;
  - the files you changed;
  - the commit on `feat/auto-extract-chat`.
