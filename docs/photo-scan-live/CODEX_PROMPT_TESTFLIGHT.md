# Codex prompt: live photo scan and review layout (mobile only), test, fix, then TestFlight

Unzip this folder into the repo at `docs/photo-scan-live/`. Then paste everything below the line into Codex from the repo root on your Mac.

---

MOBILE (FLUTTER) ONLY. Replace the layout of the **existing** Auto Extract "Review extraction" card (the photo scan in Ask) **in place**, so it matches the prototype in `docs/photo-scan-live/findez-photo-scan.html`.

- **The prototype** plays a full scan. The buttons above the phone replay it, jump to the review, and switch between light and dark mode.
- **Today's screens:** `docs/photo-scan-live/screens/current/`.
- **Target screens:**
  - dark mode: `docs/photo-scan-live/screens/dark/1-reading.png` to `9-review-tap.png`;
  - light mode: the same names in `docs/photo-scan-live/screens/light/`;
  - overview: `docs/photo-scan-live/overview.png`.

Then run the tests, fix the bugs you find in this flow, and upload the build to TestFlight so it replaces the current scan screen in the next TestFlight build.

## THIS IS A UI CHANGE ONLY. READ THIS FIRST.

**Only the layout and display of the Review extraction card change. Nothing is added to or removed from how Auto Extract works.**

**Do not touch, in any way:**

- the backend (FastAPI or any Python), the extraction pipeline, the AI model, prompts, or vision settings;
- Supabase (tables, columns, migrations, RLS, storage, SQL);
- the API client, request or response models, services, repositories, or the providers / state that run the scan or save items;
- env, config, keys, or `pubspec.yaml` dependencies (except the build number bump);
- the web app.

**Behaviour rules:**

- **No extra network calls, and no second AI call** to get more detail or confidence. Display only what the scan already returns to the app.
- **Item data stays exactly as returned and as saved:** names, categories, quantities, fields, column names and values. Don't rewrite, shorten, translate or "clean up" any value.
- **Sorting is display-only.**
  - The list on screen is reordered, but the items' ids, the selected set, and the order and payload sent when saving stay exactly as today.
  - Every row action (checkbox, edit pencil, missing quantity) must act on the correct item after sorting. Use the item's id, never its list position.
- **Keep every existing control and text with its current behaviour:**
  - close (X), refresh / scan again, the "N of N selected · Not saved yet" line;
  - checkboxes, the edit pencil, "Needs Review", the helper text and its button ("Add missing quantity" or "Choose a Space", whichever the app shows);
  - the Steps list, "Nothing is saved until you review and approve.";
  - the composer under the card with its placeholders, and the stop button while scanning if it exists;
  - the Save to a Space flow.
- **If the app shows something the prototype doesn't, keep it** and style it to fit.
- **If the prototype shows something the app has no data for, show it only when the data exists** (see the fallbacks below). Never fake data or fake progress.
- **Change the existing widgets in place.** No copy, no "v2" file, no new screen, no feature flag.
- **No new packages.**
- **No em or en dashes** in copy.

**Font:** use the current iOS system font, **SF Pro**. Use Flutter's default on iOS: don't set a `fontFamily` on these texts and don't bundle a font. The prototype uses a lookalike only for previews on non-Apple machines.

**Theme:** support both light and dark mode, following the app's existing theme setting. Colours for both are below.

## The two main rules for the review list

### 1. Most confident first, unknowns last

When the scan finishes and the review list shows, order the items like this:

1. **Rank by the scan's own confidence**, if each item has one: a confidence, score, probability or certainty field, or any similar number the result already includes. Highest first. Equal values keep the original scan order.
2. **If there's no confidence number,** rank with the flags the app already has, in this order:
   1. items with a name and category and no warning;
   2. items marked "Needs Review";
   3. items with a missing quantity or other missing fields;
   4. unknown items.

   Within each group, keep the original scan order.
3. **Unknown items always go last,** under a small section label: "Not sure about this one" (one item) or "Not sure about these" (more than one).
   - An item is unknown if its name is empty or null, its name is a placeholder such as "unknown", "unidentified", "object" or "item" (case-insensitive), or its confidence is below 0.5 when a confidence exists.
   - **For the name of an unknown item,** use the app's existing fallback text. If there isn't one, use "Unknown item".

### 2. Say what each item is, in detail

**Each review row shows all the descriptive information the scan already returns for that item, in this order:**

1. **Name:** the full name, up to 2 lines, then an ellipsis. 15.5, semibold.
2. **Detail line:** up to 2 lines, 13, regular, text colour at 78% opacity.
   - Join with " · " whichever of these fields exist and aren't empty: brand or maker, model, colour, material, size or dimensions, condition, and the description, notes or "what it is" text.
   - Use the exact values, with nothing invented. Skip any field that's empty.
3. **Info line:** category · "Qty N" (13, secondary colour), exactly as the app shows them today.
4. **Tags row** (6 below):
   - **Confidence:** a small coloured dot and a word:
     - "Confident" when confidence ≥ 0.85 (green `#34C759`);
     - "Likely" from 0.6 to 0.85 (amber `#E3B45C`);
     - "Not sure" below 0.6 (grey `#8E8E93`).
     - **Show this only when a real confidence number exists. Never make one up.**
   - **The existing "Needs Review" status** as a small amber tag.

**If the scan returns only a name, category and quantity,** show just those. Don't call anything to get more detail.

## Layout (all sizes in pt)

**Colours:**

| Token | Dark | Light |
|---|---|---|
| Page background | `#000000` | `#F2F2F7` |
| Card, composer | `#1C1C1E` | `#FFFFFF`, with a shadow of black at 6%, blur 24, y 6, plus a 1pt ring of black at 5% |
| Card ring | white at 8% | black at 7% |
| Photo frame background | `#0E0E10` | `#ECECF0` |
| Text | `#FFFFFF` | `#000000` |
| Text 2 | `#98989F` | `#6C6C70` |
| Text 3 | `#636366` | `#AEAEB2` |
| Primary button, checked box, number badge | `#FFFFFF` with black content | `#000000` with white content |
| Progress track | white at 12% | black at 10% |
| "Needs Review" tag | text `#E3B45C` on `#E3B45C` at 14% | text `#8A5A00` on `#E3B45C` at 20% |
| Highlighted row | white at 6% | black at 4.5% |

On the photo itself, the outlines, number badges and name tags stay white in both modes.

**Card:**
- Same place as today, between the Ask header and the composer.
- Radius 28, 1pt ring.
- **Header:** the scan icon, then "Review extraction" (17, semibold), then the existing close button as a 34 round button.
- **Inside:** a fixed top area (photo, status) and a list that scrolls on its own, so **the photo never scrolls away**. The list fades out over its last 18pt.

### State A: scanning (while progress events come in)

1. **Photo frame:** 300 tall, radius 20, frame background.
   - The **user's photo** (the one being scanned, already on the device) at `BoxFit.contain`, centred.
   - **While reading, preparing and finding:** a soft light band sweeps from top to bottom over the photo, about every 2.2s. It's a white gradient fading in near the bottom edge, with screen blend.
2. **Object outlines:** draw them as soon as each item's box is known.
   - Each is a radius 10 outline, 1.5pt white at 75%, with a number badge in its top-left corner (white, black number, 11.5 bold).
   - Each fades and scales in (1.06 to 1) over 0.45s. The status line counts them: "Finding objects in your photo... · 3 found".
   - **Map the boxes** with the contained image's real displayed rect, accounting for letterboxing.
3. **While each object is checked:**
   - Dim the photo slightly (black at 35%).
   - The current object's outline goes solid white (2pt) with a soft glow, and its **name** shows in a small blurred dark tag above the box (below it if the box touches the top).
   - Finished outlines go to 55%.
4. **Status line** under the photo:
   - a small spinner;
   - the current step text, exactly as the app already shows it ("Reading your photo...", "Preparing your photo...", "Finding objects in your photo...", "Reading details for N objects...", "Checked K of N objects...");
   - when the current object's name is known, "Checking K of N · name", with the name in Text 2;
   - on the right, "Steps ⌄", which expands the existing step checklist (done steps get a check, the current one gets "···").
   - **Under it:** a 3pt progress bar that fills with the real progress (steps done plus objects checked out of N).
5. Then the existing "Nothing is saved until you review and approve." (12.5, Text 3).
6. **List:** one row per detected object, added as each object is found.
   - **Not checked yet:** its crop thumbnail plus two shimmering placeholder bars, and a small "Waiting" on the right.
   - **Being checked:** the highlighted row background and "Checking".
   - **Done:** fills in with the full detail row (name, detail, info, tags).
   - While scanning, rows stay in scan order and the list auto-scrolls to keep the current row visible.

### State B: review (the scan has finished)

1. **The photo frame** animates down to 128 tall (0.6s) and keeps all the outlines.
2. **Renumber** the outlines and the row badges 1, 2, 3... in the sorted display order, so the numbers on the photo match the list from top to bottom.
3. **Then:** "N of N selected · Not saved yet" on the left, and the existing refresh button on the right.
4. **The sorted list** (confident first, unknowns last under their label).
   - **Each row:** a 24 checkbox (radius 7), a 52 thumbnail (radius 13) with its number badge on the top-left corner, the detail text block, and the edit pencil.
   - Rows are top-aligned.
5. **Tapping a row** (not its checkbox or pencil) highlights that row and its outline on the photo, and shows the item's name tag there. This is display-only.
6. **Footer** with a 1pt top border:
   - the existing helper text (13.5, Text 2);
   - the existing main button, full width, 50 tall, radius 25, in the Primary colour, with the same text and action as today.

**Thumbnails:** use the crop thumbnail the app already has for each item. If there isn't one but a box exists, show the photo cropped to that box (`BoxFit.cover` centred on the box). Otherwise, show the photo itself.

### Fallbacks (use only the data that exists)

- **No boxes in the result:**
  - skip the outlines and the photo-row link;
  - keep the photo, the sweep and everything else;
  - number only the rows.
- **Items only arrive when the scan has finished:**
  - keep the sweep and the real step text running until then;
  - then reveal the outlines and rows one by one (about 0.25s apart) and move to the review state;
  - don't show fake "checking" steps for data that doesn't exist yet.
- **The current object's name isn't known while checking:** show the existing "Checked K of N objects..." text only.
- **No real confidence number:** order with the flags (see the main rules) and hide the confidence label.

## Motion and accessibility

- Every animation uses `Cubic(0.32, 0.72, 0, 1)`.
- Respect reduced motion: no sweep, no scale, and no reveal delays.
- **VoiceOver:**
  - each row reads its number, name, detail, quantity, confidence (if shown), status, and checked state;
  - the status line is a live region.
- **Performance:** decode the photo once and reuse it for the frame and the crops. Keep scrolling smooth with 30 or more items.

## Tests and bug fixing

1. Run `flutter analyze` (clean) and `flutter test` (pass).
2. **Add unit tests** (test files only) for:
   - the display sort: confidence first, the flag order when there's no confidence, stable ties, unknowns last;
   - unknown detection;
   - the box-to-display-rect mapping with a letterboxed photo;
   - row actions hitting the right item id after sorting.
3. **On a simulator or device, scan at least three real photos:**
   - a desk with mixed items;
   - a bin of fasteners;
   - a photo that gives at least one unknown item.

   For each, check:
   - live progress and outlines (or the fallbacks);
   - sorting and the unknowns label;
   - the detail text, compared with what the scan returned;
   - checkbox, edit, Add missing quantity, Choose a Space and saving;
   - close, refresh, stop while scanning, and the keyboard;
   - light and dark mode;
   - a small iPhone (SE) and a large one;
   - reduced motion.
4. **Fix every bug you find in this flow's UI code** (layout overflow, wrong item after sorting, state not resetting on rescan, scroll jumps, dark or light colours, and so on).
   - **If a bug can only be fixed in the backend, the API or data models, don't fix it.** Write it down in your report instead.
5. **Confirm the saved items are identical to before the change** (same items, same values, same order sent). Save the same photo with the old build and the new build, and compare.

## Git and TestFlight

1. Work on a new branch, `feat/scan-live-review`.
2. **Run `git diff --name-only`.**
   - Only Flutter UI files for this card (widgets, theme) and new test files may change, plus the build number in `pubspec.yaml`.
   - Zero changes in: backend, Supabase or SQL, API, services, models, providers that load or save data, env, config, dependencies, or the web app.
   - Undo anything else.
3. **Build number:** set it to one more than the latest build already on TestFlight for this version. Commit, and push the branch to `origin`. Don't merge into main.
4. **Upload the way this repo already releases iOS:**
   - **fastlane:** the beta lane;
   - **Xcode Cloud or Codemagic:** trigger it from the branch;
   - **otherwise:** `flutter build ipa --release` with the existing signing, then `xcrun altool --upload-app --type ios` with the API key already set up on this Mac.

   This build replaces the scan screen for TestFlight testers.
5. **Credentials:** never create, print, log or ask for passwords, keys, certificates or profiles. If something is missing, stop and tell me exactly what.
6. **"What to Test" note:** "Photo scan: your photo stays on screen while it scans, with each object outlined and named as it is checked. Review list shows the most confident items first with full details, and unknown items last. UI only; scanning and saving work the same."

## Report

- the version and build number, the commit hash, and whether the upload succeeded;
- the output of `git diff --name-only`, confirming no backend, API or data files changed;
- **which data the scan actually gives the app:**
  - boxes, yes or no;
  - per-item progress, yes or no;
  - confidence, yes or no, and which field;
  - which detail fields;
  - and which fallbacks you used because of that;
- the tests you added and their results;
- the bugs you found and fixed, and any you couldn't fix because they need backend changes;
- confirmation that saved items are identical to before;
- screenshots in light and dark mode: scanning, checking, review, unknowns.
