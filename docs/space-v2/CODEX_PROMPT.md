# Codex prompt: Space screen, item quick view and scoped Ask (Flutter). UI only, item data untouched

**Setup:** unzip this folder into the repo at `docs/space-v2/`. Then paste everything below the line into Codex from the repo root.

This replaces the earlier `CODEX_SPACE_ASK_MOBILE` prompt.

---

MOBILE (FLUTTER) ONLY. Redesign the **Space detail screen**, its **item quick view**, and the **"Ask FindEZ" popup** opened from a Space. Copy them exactly from the working prototype at `docs/space-v2/findez-space-prototype.html`, and match the screenshots in `docs/space-v2/screens/01-top.png` to `15-back.png`. `docs/space-v2/before-after.png` shows the current app next to the new design.

Open the HTML in a browser and click through it before you start. Every size, colour and radius below comes from its CSS, and 1 CSS px = 1 logical pixel. If this prompt and the HTML disagree on **look**, the HTML wins. If they disagree on **data**, the rules below win.

## Rule 1, the most important one: don't touch item data

**This is a UI and design change only.** Item information, and every setting attached to it, stays exactly as it is today, however the item got into the app (Auto Extract, spreadsheet import, typed in chat, added by hand or anything else).

- **Field names stay the same.** Keep the original column names from spreadsheet imports and every custom field, exactly as they're stored and shown today.
  - Don't rename, translate, reformat or "clean up" a label. For example, "Part Number" stays "Part Number" and "Tooth Count" stays "Tooth Count".
  - Don't merge or split fields, and don't hide any.
- **Values stay the same.**
  - No title-casing, no shortening, no parsing out sizes, and no moving parts of a name into another field.
  - Show the item **name exactly as stored** (for example `PN-F105` or `5mm Timing Belts - Tooth Count 120.0`). Long names wrap to 2 lines; they're never rewritten.
- **Field order stays the same.** Wherever item details are shown, use the fields, labels and order the current item detail screen uses.
- **Item settings stay the same:**
  - categories, location or Space, quantity, units;
  - low-stock thresholds, review or "items to finish" flags;
  - photos, import mappings, and any per-item or per-Space settings.
- **Don't change models, parsing, import code, Auto Extract output, the spreadsheet column mapping or how fields are saved.**
- **The edit flow stays the same.** "Edit" opens the **existing** item detail or edit screen, unchanged.
- **Same field rule everywhere item info appears:** the row's second line, the quick view and the Ask item cards. If the prototype shows something different from today's real data, **today's data wins.**
  - The prototype's sample labels (Description, Category, Location) are only placeholders for "whatever the item has today".

## Rule 2: what else must NOT change

- **No backend, API, Supabase, web app, env or config changes.**
- **No new packages,** and no edits to `pubspec.yaml` or `pubspec.lock`.
- **No changes to models, services, repositories, API clients or routes.** The same goes for any provider logic other screens use.
- **Every action that's reachable today stays reachable:**
  - back, search, notifications, the more menu;
  - Review, Low quantity, sort, category filters;
  - add, item detail, edit, history, new chat, close.
- **Actions use the existing calls:** changing a quantity uses the existing item update, Move uses the existing location edit, add uses the existing add flows, and Ask uses the existing chat with its current scoping.
- **Hide what isn't supported.** If a piece of the prototype needs data or an action the app doesn't have, hide that piece and list it in your summary. Don't invent a backend for it.
- **Don't build the prototype's notes.** Its annotation line in the item sheet ("Same fields and names…") and the side panel are notes for you, not UI.
- **Leave every other screen alone:** Home, Ask home, the Spaces list, Settings, onboarding and Auto Extract.
- Work on a new branch, `feat/space-v2-ui`. Commit, but **don't push**.

## Step 0: find the code first

1. Find every file that renders:
   - the Space detail screen;
   - its rows;
   - the Review and Low quantity cards;
   - the "Ask FindEZ →" button and the scoped Ask sheet;
   - the floating + button;
   - the sort and filter controls;
   - the item info (i) entry point.
2. **Print the list.** Only edit those files. New widgets go in one new folder next to them (for example `.../space/widgets/`).
3. Read how the current item detail screen builds its field list (labels, order, custom and imported columns). The quick view must reuse that same source.
4. If you think you need to touch any other file, **stop and explain why** instead of doing it.

## Tokens

| Token | Value |
|---|---|
| bg | `#0B0B0C` |
| s1 | `#1C1C1E` |
| s2 | `#252527` |
| s3 | `#2E2E31` |
| sheet | `#19191B` |
| ask sheet | `#141415` |
| menu | `#242426` |
| line | white at 8% |
| line2 | white at 12% |
| tx | `#FAFAFA` |
| tx2 | `#9A9AA0` |
| tx3 | `#626268` |
| white pill | `#F2F2F2` |
| ink | `#0B0B0C` |
| amber | `#D6A84E` |
| red | `#E5484D` |
| curve | `Cubic(.32, .72, 0, 1)` |

- **Font:** the system font.
- **Icons:** stroke 1.8, round caps and joins, 20pt unless stated otherwise. Use the icon set the app already has.
- **"Hairline"** means a 1pt inner border.
- **Put these tokens in a private constants file** in the new widgets folder. Don't edit the global theme.

## 1. Space screen (`01-top.png`, `02-scrolled.png`)

**Top bar** (fixed, 104 tall including the status bar, bg colour):
- On the left, back. On the right, notifications and more.
- Each is a 42 circle in s1 with a line2 hairline. Notifications shows a 7pt amber dot when there's something unread.
- The centre title "[Space name]" (17pt/600) is hidden at the top.
- Once the page has scrolled more than 70pt, the title fades in and rises 6pt, and a 1pt line appears under the bar.

**Header** (scrolls with the page, padding 6 top and 20 sides):
- **Breadcrumb:** "[Workspace] · [Inventory]", 13.5pt/500 tx2.
- **Space name:** 34pt/700, letter spacing −0.03em.
- **Stats:** "**298** items · **7,583** units", 15pt tx2 with the numbers in tx/600. Use the same counts the screen shows today, with thousands separators.

**Status cards** (16 above them, two equal cards with an 8pt gap):
- Each card is 60 tall, radius 18, s1 with a line hairline, padding 0/14, 11pt gap.
- A 34 icon tile (radius 11, s3, 18pt icon), then a title (14.5pt/600) and a count line (12.5pt tx2) with a 6pt amber dot.
- The cards are **"Review"** ("N to finish", the existing review count) and **"Low quantity"** ("N items", the existing low-stock count).
- **Tapping a card filters the list in place** to those items. It doesn't open another screen. The active card has an s2 fill and a 1.5pt white inner border. Tap it again to clear the filter.
- If the existing Review screen has actions the list can't do, keep it reachable: long-pressing the Review card opens it.

**Pinned search row** (sticky at the top of the scroll view, bg colour, padding 14/20/10, 8pt gap):
- **Search field:**
  - 44 tall, radius 22, s1 with a line hairline (white at 22% when focused), padding 0/8/0/14;
  - a search icon (18pt), then the input at 15.5pt with the placeholder "Search N items";
  - a 24 round clear button (s3, 12pt ×) appears once there's text;
  - it searches the item **name and the fields the row already shows**. Use the existing search if there is one; otherwise filter the loaded items.
- **Sort button:** a 44 circle, s1 with a hairline. It opens the sort sheet.

**Meta row** (padding 4/20/6, 12.5pt/500 tx3):
- On the left: "N items", or "N results" while searching. When a filter is on, this becomes a white removable chip instead (28 tall, radius 14, ink 12.5pt/600, "Low quantity ×").
- On the right: the current sort name.

**Category filter chips:** keep the existing ones, but only show them when the Space has 2 or more categories. Put them under the meta row, in the prototype's chip style.

**List rows** (list padding 0/8):
- Each row: padding 9/12, radius 16, 13pt gap. Pressed: s1 fill. A 1pt line hairline is inset 77pt from the left, with none on the last row.
- **Thumbnail:** 52×52, radius 13, cropped to cover, line hairline.
  - If the item has no photo, show a grainy gradient tile with a 22pt icon. Use these two prototype gradients, picked by a stable hash of the category:
    - green: 160°: `#3E5A4C`, then `#6F8C74` (at 50%), then `#22322C`, with a `#E3C9A6` glow at the top right;
    - grey: 150°: `#B9BEC5`, then `#6E747D` (at 50%), then `#24272C`, with a `#D9DCE0` glow at the top left.
- **Title:** the **item name exactly as stored**, 15.5pt/600, line height 1.25, letter spacing −0.01em, **maximum 2 lines**. If the item is flagged for review, put a 6pt amber dot in front.
- **Second line:** **exactly what the current row shows** (for example "M8x1.0 Nut · Supplies"), 13pt tx2, 1 line with an ellipsis.
- **Right side:** the quantity at 17pt/600 with tabular figures, and a tiny label under it (11pt tx3): "qty", or "low" when the item is low.
  - Low items show their number in amber.
- **The whole row is tappable** and opens the quick view. **This replaces the (i) button.**
- **Paging:** render 60 rows at first and add 60 more as you near the bottom, or keep the existing pagination. Show "Showing X of Y · keep scrolling" at the end of each loaded batch.
- **No results:** "No "query" in [Space]" (17pt/600), then "Try a size like M5, or ask FindEZ to look everywhere." (15pt tx2), then an "Ask FindEZ" pill that opens Ask with that question.

**Bottom dock** (it **replaces the floating + button and the "Ask FindEZ →" bar**):
- **Fade:** a 150pt gradient behind it, from transparent to bg.
- **Position:** 12 from each side and 28 from the bottom, with an 8pt gap between the two parts.
- **Ask bar:**
  - 58 tall, radius 29, s1 with a line2 hairline, shadow `0 10 30` black at 50%;
  - contents: a 38 white circle with the black clove, "Ask about [Space name]" (16pt tx2, one line), and a 42 mic button on the right;
  - tapping it opens the Ask popup; the mic uses the existing voice input.
- **Add button:** a 58 white circle with a 24pt ink + (stroke 2.2). It opens the add sheet.

**Sheets** (scrim black at 55% with a 4pt blur, fading in over 350ms using the curve):
- **Style:** inset 8, radius 38, sheet fill, line2 hairline, padding 10/12/22. They slide up over 500ms using the curve. Grab handle: 38×5, white at 20%.
- **Hidden sheets never catch taps.**
- **Add sheet** (`09-add.png`):
  - title "Add to [Space name]" (20pt/700);
  - rows (44 icon tile with radius 14 in s2, a 16pt/600 title and a 13pt tx2 subtitle):
    - Take a photo;
    - Choose photos;
    - Import a spreadsheet ("CSV or Excel, keeps your column names");
    - Type it in (opens Ask with "Add " filled in);
  - each row opens the **existing** flow. Hide a row if that flow doesn't exist.
- **Sort sheet** (`07-sort.png`): the sorts the app supports today, plus any that can be done on the device with fields that already exist (Name, Quantity lowest first, Recently added). The selected one shows a 24 round white check.
- **More menu** (`08-menu.png`):
  - a popover at the top right, 230 wide, radius 22, menu fill, line2 hairline, padding 6;
  - it scales from 0.85 at the top right over 350ms;
  - each row is 44 tall, 15.5pt, with an icon on the right;
  - it holds whatever the current more menu has, in the same order. Destructive items are red, under a divider.

## 2. Item quick view (`05-item.png`, `14-item-from-ask.png`)

A bottom sheet (same style as above, maximum height 86%) that opens when you tap a row or an Ask item card.

- **Photo:** 190 tall, radius 26, cropped to cover. With no photo, use the gradient tile with a 44pt icon.
- **Name:** the **item name exactly as stored**, 24pt/700, line height 1.15, letter spacing −0.025em.
  - Under it, the **same second line as the row**, at 15pt tx2.
- **Quantity box:**
  - radius 22, s1 with a line hairline, padding 12/12/12/18;
  - the label "Quantity" (12.5pt/500 tx2), plus "● Low" in amber when the item is low;
  - the number at 32pt/700;
  - on the right, − and + as 48 circles in s3;
  - each tap updates through the **existing** item update. After 500ms with no more taps, show the toast "Saved · N left".
  - If the item uses a units field, keep showing it exactly as today.
- **Details card:**
  - radius 22, s1 with a line hairline, padding 4/16;
  - rows are 14.5pt: the label in tx2 on the left, the value in tx/500 on the right, with 1pt line dividers between them;
  - **The rows are exactly the fields the current item detail screen shows, with the same labels and values in the same order, including every imported spreadsheet column and custom field.**
  - Read-only.
- **Three buttons** (14 above them, 8pt gap, each 52 tall, radius 26, 15pt/600, with an 18pt icon):
  - **Move** (s2): opens the move sheet;
  - **Edit** (s2): opens the **existing** item detail or edit screen, unchanged;
  - **Ask** (white, with the clove): opens Ask with "How many [item name] do we have?".
- **Move sheet** (`06-move.png`): titled "Move [item name]". It lists the Spaces (the unique location values the app already uses) with their gradient tile, name and "Inventory · N items". The current Space has a check.
  - Picking one uses the **existing** location update and shows the toast "Moved to [Space]".

## 3. Ask FindEZ popup (`10-ask.png` to `13-scope.png`, `15-back.png`)

**Sheet:**
- Top at 56pt, radius 32 on the top corners, ask-sheet fill, a line2 hairline on top.
- It slides up from 105% over 550ms using the curve, with a grab handle.

**Header** (padding 4/14/10/20, 8pt gap):
- "Ask FindEZ" (19pt/700).
- Under it, the **scope chip**:
  - 26 tall, radius 13, s2, 12.5pt/500 tx2, one line;
  - contents: an 18 rounded thumbnail of the Space's first photo, "Only in [Space] · N items", and a chevron;
  - tapping it opens a small popover (250 wide, radius 22, menu fill) with the scopes the **existing** chat supports (for example "Only in [Space]", "All of [Inventory]", "Everything"), each with its item count and a check on the current one;
  - **If the existing chat only supports one scope, show the chip without the chevron or popover.**
- On the right, 40 circles for **history**, **new chat** and **close**, using the existing actions.

**Empty state:**
- **Headline,** 28pt/700, letter spacing −0.03em, line height 1.15: "Ask about [Space]." followed by "Find, count or change anything in it." in tx3.
- **Suggestion card,** 20 above it:
  - radius 22, s1 with a line hairline, rows with 1pt dividers;
  - each row: padding 12/14, a 34 tile (radius 10, an item photo or an icon), the text at 15.5pt, and a chevron on the right;
  - build the suggestions from the Space's real data: "What is running low?", "How many [common item] do we have?", "Do we have [another item]?", "What did I add recently?".
  - Tapping a row sends it.

**Messages:**
- **User:** a right-aligned bubble in s3, radii 20/20/6/20, padding 11/15, 15.5pt.
- **FindEZ:** the 28 white avatar (radius 8, black clove) and text at 15.5pt, line height 1.5, with bold where the response uses it.
- **Typing:** three 5pt dots blinking in turn.
- **New messages** fade in and rise 10pt over 450ms.

**Item results** (only when the **existing** chat response already includes item references; never invent answers on the device):
- **One item:** an item card.
  - Radius 18, s1 with a hairline, padding 10.
  - A 56 thumbnail, the **item name exactly as stored** (15pt/600), and a small line with its existing second line plus "📍 [Space]". The quantity sits on the right at 22pt/700 (amber if low).
  - Tapping it opens the quick view on top of the chat.
  - Under it, two pills (38 tall, radius 19, s2, 14pt/600):
    - "− I used one": the existing update, quantity minus 1;
    - "Move": the move sheet.
- **Several items:** a compact list card (radius 18, s1), with rows made of a 38 thumbnail, the name, the second line and the quantity on the right. Show up to 4.
  - When there are more, add a "See all N in the list" pill. It closes the popup and fills the Space search.
- **Low-stock answers** add a "Show in list" pill. It closes the popup and turns on the Low quantity filter.
- **Follow-up chips:** outline pills, 36 tall, radius 18, a line2 hairline, 13.5pt tx2, scrolling sideways.

**Composer** (bottom padding 8/12/28):
- 56 tall, radius 28, s1 with a line2 hairline.
- Contents: + (opens the add sheet), the input (16pt, placeholder "Ask about [Space]", then "Ask a follow-up" after the first message), mic, and a 44 send circle (s3 and dim when empty, white with an ink arrow when there's text).

**Closing:** tapping the scrim or close shuts the popup. When the quick view is open on top of Ask, closing it returns you to the chat.

## Motion and accessibility

- Use only the durations and curves listed above.
- With Reduce Motion on, everything becomes a fade.
- Every tap target is at least 44×44.
- Add semantics labels: "Back", "Notifications", "More", "Sort", "Clear search", "Add items", "Ask about [Space]", "Use one", "Add one", "Close".

## Check before you finish

1. `flutter analyze` is clean and the app builds for iOS.
2. Test with Spaces of 0, 3, 40 and 298+ items.
   - Include one Space **imported from a spreadsheet with custom column names**, one **made by Auto Extract**, and one **typed in by hand**.
3. **Data check:** for each of those Spaces, open one item in the **old** detail screen and in the **new** quick view. The fields, labels, order and values must be identical. Edit must open the same screen as before. Put a short table of what you compared in your summary.
4. Test search, both filters, every sort, paging past 60 rows, quantity − and +, Move, the more menu, the add sheet, and all Ask states (empty, one item, several items, low stock, no data, scope).
5. Check that no hidden sheet catches taps.
6. Check that every other screen looks and behaves exactly as before.
7. Run `git diff --stat` and show it. Every changed file must be from your step 0 list or the new widgets folder. Revert anything else.
8. In your summary, list:
   - anything you hid because the app doesn't support it;
   - the files you changed.
9. Commit on `feat/space-v2-ui`. **Don't push.**
