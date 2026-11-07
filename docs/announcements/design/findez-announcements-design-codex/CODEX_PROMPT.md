# Codex prompt: announcement pop-up design (mobile only, design only)

Unzip this folder into the repo at `docs/announcements/`. Then paste everything below the line into Codex from the repo root on your Mac.

---

MOBILE (FLUTTER) ONLY. DESIGN ONLY. Restyle the existing Founders Access sheet and its "Your plan" row to the new design in `docs/announcements/findez-announcements.html`. Also build the other announcement designs (pricing note, what's new, banner) as reusable widgets.

- **Prototype:** open the file and use the buttons above the phone (Founders Access, Pricing note, What's new, Banner, Your plan, Light mode).
- **Targets:**
  - dark mode: `docs/announcements/screens/dark/1-founders.png` to `6-your-plan-row.png`;
  - light mode: the same names in `screens/light/`.

## THIS IS A DESIGN CHANGE ONLY. READ THIS FIRST.

- **Do not touch:**
  - the backend (FastAPI or any Python), Supabase (tables, migrations, RLS, SQL);
  - the API client, services, repositories, models;
  - billing, plans, entitlements, auth;
  - env and config files, and `pubspec.yaml` dependencies;
  - the web app.
- **No new logic:**
  - **Don't add an announcement system,** remote config, scheduling, targeting or frequency rules.
  - **Keep when and how often the sheet shows exactly as it works today.** The existing Founders Access sheet keeps its current trigger and its "seen" storage.
  - The pricing note, what's new and banner widgets are built but **not shown anywhere** in this task. Don't wire them to any trigger.
- **Change the existing widgets in place.** No copy, no "v2" file, no feature flag.
- **Don't remove anything** the sheet or the row does today, apart from the intro view described below.
- **No new packages.** No em or en dashes in any copy.
- **Plan name:** use the name the app shows today. If the app says "Founding Access" and the prototype says "Founders Access", keep the app's name and mention it in your report.

## What changes

### 1. The Founders Access sheet opens straight on the info

- **Remove the intro view.** That's the big art card, the "You're in early." page with the three points, "Get started" and "See what's included".
- The sheet now opens directly on the plan info (`screens/*/1-founders.png`). Opening it from Settings or More shows the same view.
- **Closing it:** the X, "Got it", dragging the sheet down, or tapping the backdrop. All of them run the existing close and "seen" handling.

### 2. The reusable info sheet (one widget used by every category)

Build one `AnnouncementSheet` widget with these inputs:

- `title`;
- an optional `line`;
- a `body` widget;
- optional `fine` print;
- one `primary` button with a label and a callback.

Every category uses it.

**Colours** (follow the app's theme setting):

| Token | Dark | Light |
|---|---|---|
| Sheet | gradient `#161618` to `#121214` | gradient `#FFFFFF` to `#F7F7F9` |
| Soft fill | `#1B1B1E` | `#F2F2F5` |
| Text | `#F4F4F5` | `#0B0B0C` |
| Text 2 | `#A1A1A6` | `#5C5C62` |
| Text 3 | `#6B6B70` | `#9A9AA0` |
| Hairline | white at 7% | black at 7% |
| Ring | white at 12% | black at 12% |
| Primary button | gradient `#F4F4F5` to `#D4D4D8`, text `#0B0B0C` | gradient `#1C1C1F` to `#0B0B0C`, text `#FFFFFF` |
| Backdrop | black at 55% | black at 30% |
| Curve | `Cubic(0.32, 0.72, 0, 1)` | same |

**The sheet:**

- Inset 8pt from the left, right and bottom, radius 38.
- A 1pt ring, a 1pt top highlight of white at 4.5%, and the shadow `0 -30 70` black at 60%.
- **Height wraps its content,** up to the screen height minus 66pt. Past that, the content scrolls inside and the button stays reachable. Test with large text and on the smallest supported iPhone.
- **Grab handle:** 38×5, radius 3, text 3 colour at 50%, centred in a 22pt top area.
- **Content padding:** 4 top, 20 on the sides, 24 bottom, plus the bottom safe area.

**Header row:**

- the title at 26pt, weight 500, letter spacing −0.025em, filling the row;
- on the right, a 40pt round close button with a 1pt ring and a 16pt X.

**Line** (optional): 15pt, text 2, 6pt below the header.

**Fine print:** 12.5pt, text 3, line height 1.5, 18pt above.

**Primary button:** full width, 52 tall, radius 26, 16pt weight 600, 22pt above. It scales to 0.98 when pressed.

**Motion:**

- The backdrop fades in over 400ms. The sheet slides up from below over 600ms with the curve.
- The table rows rise 6pt and fade in, 50ms apart. The checkmarks draw in (stroke animation) just after their row.
- With Reduce Motion on, everything just fades.

### 3. The plan body (used by Founders Access and the pricing note)

1. **Plan card,** 16pt below the header:
   - radius 20, the sheet gradient, a 1pt hairline ring, padding 12 / 14 / 12 / 12;
   - a 46×46 tile (radius 13) with the app's existing Plum / Rust grainy art and the white clove logo at 18pt;
   - the plan name at 16pt weight 500, and "Your plan right now" at 13pt text 2;
   - a "Free" chip on the right: 26 tall, radius 13, soft fill, a 1pt ring, 12.5pt weight 500.
2. **Table card,** 10pt below it, in the same card style and clipped to its corners.
   - **Header:** 12pt weight 500 text 3, with padding 11 / 16 / 9. Columns: the label, "Now" (64pt wide) and "Free plan" (84pt wide), both centred.
   - **Rows:** padding 12 / 16, 14.5pt, a hairline on top. Checks are line icons at 17pt with stroke 2.2.
   - **"Limited" chip:** 24 tall, radius 12, soft fill, text 2 at 12pt weight 500.
   - **"Plan" chip:** 24 tall, radius 12, a 1pt ring, text at 12pt weight 500.

   | Row | Now | Free plan |
   |---|---|---|
   | Open and search items | ✓ | ✓ |
   | See item details | ✓ | ✓ |
   | Export your inventory | ✓ | ✓ |
   | Ask FindEZ | ✓ | Limited |
   | Add new items | ✓ | Limited |
   | Add from a photo | ✓ | Limited |
   | Import a spreadsheet | ✓ | Plan |

### 4. The three categories (exact copy)

| Category | Title | Line | Body | Fine print | Button |
|---|---|---|---|---|---|
| Founders Access | You're in early. | none | the plan body | Nothing you save is ever deleted. We'll tell you before anything changes. | Got it |
| Pricing note | FindEZ is free to explore. | Paid plans may come later. Here's what stays free. | the plan body | We'll tell you before anything changes. | Got it |
| What's new | Photos scan on their own. | none | the what's new body (below) | none | Try it |

**The what's new body** (`screens/*/3-whats-new.png`):

1. **An art card,** 16pt below the header: 150 tall, radius 24, clipped.
   - **Aurora art:**
     - an amber glow (`#E2864F` at 90%) at the top left;
     - a blue glow (`#5E7FB8` at 90%) at the bottom right;
     - over a dark base gradient (`#2A2023` to `#141418` to `#151A24`);
     - with the app's grain on top and the same slow drift as the other art.
   - **Chip** at the top left: "What's new", 28 tall, radius 14, white at 14% with a 1pt ring of white at 22%, 12.5pt weight 500, white text.
   - **A photo frame** in the centre: 150×104, radius 14, white at 10%, with a 1pt ring of white at 22%.
     - Inside, two 1.5pt white outlines (radius 8) fade in and out on a 3.2s loop.
     - A soft white line sweeps down on the same loop.
2. **Three rows,** 16pt below it, 10pt apart, rising in one after another.
   - Each row has a 36pt icon tile (radius 11, soft fill, a 1pt hairline ring, an 18pt line icon), then the text at 15.5pt weight 500.
   - The rows: camera icon with "Add a photo"; scan corners with "Auto Extract starts right away"; check with "Review, then save".
3. **"Try it"** runs a callback passed in. It's not wired in this task.

### 5. Banner widget (built, not placed)

See `screens/*/4-banner.png`.

- **Shape:** 48 tall, radius 24, the surface colour with a 1pt ring, and the shadow `0 10 30` black at 25%.
- **Inside:**
  - a 32pt tile (radius 10) with the Plum / Rust art and the white clove at 15pt;
  - the plan name at weight 500, then " · Free right now" in text 2, at 14pt;
  - a 36pt X on the right.
- **Inputs:** `onTap` and `onDismiss` callbacks.
- **Motion:** it slides down 12pt and fades in over 600ms with the curve.

### 6. The "Your plan" row in Settings or More

Restyle the existing row to match `screens/*/6-your-plan-row.png`:

- a card with radius 20 and a 1pt ring, padding 12 / 14;
- a 42pt tile (radius 12) with the Plum / Rust art and the white clove at 18pt;
- the plan name at 16pt weight 500, and "Your plan" at 13pt text 2;
- the "Free" chip on the right.

Tapping it opens the Founders Access sheet, as it does today.

## Check before finishing

1. `flutter analyze` is clean, and `flutter test` passes.
2. **Scope check:** run `git diff --name-only`.
   - Only Flutter UI files may change: the sheet, the new reusable widgets, the row, and the theme if truly needed.
   - There must be zero changes in: the backend, Supabase, API, services, models, providers that load or save data, `pubspec.yaml` dependencies, or the web app.
3. **On a simulator, check:**
   - the Founders Access sheet opens straight on the info after sign-up, exactly when it did before;
   - the "Your plan" row opens it;
   - close, Got it, swipe down and backdrop tap all close it and mark it seen as before;
   - light and dark mode;
   - the smallest supported iPhone and a Pro Max;
   - large text;
   - Reduce Motion.
4. **Preview the unwired pieces:** render the pricing note, what's new and banner widgets once in a debug-only preview or widget test, to confirm they match the screens. Don't ship them in a visible place.
5. Take screenshots of all of them in both themes.

## Git

- Work on a new branch, `feat/announcement-design`. Commit, and push the branch to `origin`.
- Don't merge into main and don't upload to TestFlight.
- **Credentials:** never create, print, log or ask for passwords, keys or tokens.

## Report

- the branch and commit hash;
- the output of `git diff --name-only`;
- the plan name the app uses;
- anything in the prototype you couldn't match;
- the screenshots.
