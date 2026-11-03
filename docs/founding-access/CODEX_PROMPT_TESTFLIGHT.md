# Codex prompt: Founding Access sheet, then ship to TestFlight

Unzip this folder into the repo at `docs/founding-access/`. Then paste everything below the line into Codex from the repo root on your Mac.

---

MOBILE (FLUTTER) ONLY. Build a native "Founding Access" bottom sheet that new users see once, right after they sign up. Follow the spec below exactly. Then build the app and upload it to TestFlight.

## Rules

- **Native Flutter only:** build it from the spec below. No WebView and no HTML.
- **The reference files are in `docs/founding-access/`:**
  - `findez-founding-access-popup.html` is the approved design. Open it in a browser to see the motion, and check your build against it.
  - `screens/01-welcome.png`, `02-whats-included.png` and `03-your-plan-from-settings.png` show each state.
  - These are references only. Don't embed, port or ship the HTML.
- **Text only, no billing logic.** Every word on the sheet is fixed text.
  - Don't touch billing, entitlements, plans, the backend, the API, Supabase, the web app, or how items are stored.
  - Don't change any existing screen, apart from the one Settings row described in "Where it shows" below.
- **No new packages,** unless one is truly needed for something the app can't already do. If you add one, say which and why.
- **Credentials:**
  - Use the signing, certificates and App Store Connect access already set up on this Mac or in the repo.
  - Never print, log, commit or ask for passwords, keys or tokens.
  - If something needed for the upload is missing, stop at that step and tell me exactly what's missing.
- **Git:** work on a new branch, `feat/founding-access-sheet`. Commit there and push the branch to `origin`. **Don't merge into main.**

## Step 0: look before you build

Before writing any code, find these and list them:

1. Where sign-up finishes and the user first lands in the app (after onboarding, if there is any).
2. The Settings screen, and any existing plan or usage screen.
3. The app's existing pieces for:
   - colour constants and fonts (Inter Tight included, or not);
   - the grainy gradient art (from the mobile theme work);
   - the clove logo widget;
   - bottom sheets;
   - local key-value storage;
   - analytics.
4. How iOS builds are released today: fastlane (`ios/fastlane`), Xcode Cloud, Codemagic, a script in the repo, or a manual upload.

Reuse whatever already exists. New widgets go in one new folder, for example `lib/features/founding_access/`.

## Where it shows

1. **After sign-up:** show the sheet **once per account**, right after a **new** account is created and the user lands on Ask (after onboarding if there is any). Wait about 500ms after Ask appears.
   - Save "seen" in the existing local storage, keyed by user id (for example `founding_access_seen_<userId>`).
   - Don't show it to people who are only logging in to an existing account.
   - Closing it in any way marks it as seen: Get started, Got it, swiping down or tapping the backdrop.
2. **Settings:** add one row, "Your plan", with "Founding Access" as its value on the right.
   - If there's an existing plan or usage screen, put the row there. Otherwise put it at the top of the account section.
   - Tapping it opens the same sheet, **straight on the details view**, with the title "Your plan".
   - Don't remove or move any existing row.
3. **Analytics:** only if the app already has an analytics client, log `founding_sheet_shown`, `founding_sheet_details` and `founding_sheet_closed`. Otherwise skip this.

## Colours, fonts and motion

| Token | Value |
|---|---|
| Sheet background | vertical gradient `#161618` → `#121214` |
| Card background | the same gradient |
| Soft fill | `#1B1B1E` |
| Text | `#F4F4F5` |
| Secondary text | `#A1A1A6` |
| Tertiary text | `#6B6B70` |
| Hairline | white at 7% |
| Ring | white at 12% |
| Ink (text on light) | `#0B0B0C` |
| Curve | `Cubic(0.32, 0.72, 0, 1)` |

- **Fonts:**
  - Inter for everything else.
  - **Inter Tight Regular (400)** for the big title. If the app doesn't bundle Inter Tight already:
    - copy `docs/founding-access/assets/InterTight-Regular.ttf` and its licence `InterTight-OFL.txt` into the app's fonts folder (for example `assets/fonts/`);
    - register the font family `Inter Tight` in `pubspec.yaml`;
    - don't add a package for it.
- **No orange or amber anywhere in the interface.** Colour appears only in the art.

## The art: Plum / Rust, with grain

This is a risograph-style gradient with visible grain, the same as the web app.

**1. Base gradient.** A linear gradient at 150°: `#453349` at 0%, `#773F42` at 55%, `#996050` at 100%.

**2. Soft radial blobs on top.** Positions are given as a share of the width and height. Each blob runs from its colour at full strength to transparent at about 72% of its radius.

| Colour | Centre (x, y) | Size (width × height) |
|---|---|---|
| `#453349` | 12%, 70% | 50% × 60% |
| `#773F42` | 55%, 60% | 55% × 55% |
| `#996050` | 92%, 10% | 40% × 45% |
| `#B69D9F` | 25%, 5% | 35% × 35% |

**3. Grain.**
- Copy `docs/founding-access/assets/grain.png` (a 256×256 greyscale noise tile) to `assets/textures/grain.png`, and register it in `pubspec.yaml`.
- In a `CustomPainter`, paint it tiled over the gradient twice, in the same layer:
  - with `BlendMode.overlay` at 95% opacity, tiled at 180 logical px;
  - with `BlendMode.softLight` at 80% opacity, tiled at 120 logical px.
- The grain must be clearly visible, like film grain, not a faint haze.

**4. Shape and motion.**
- **Corners:** clip the whole art with a `ClipRRect` so the colour has **rounded corners on all four sides**. Check this on a device.
- **Size:** the art layer is 12% larger than its box on every side.
- **Drift:** it drifts slowly to a 5% offset right, 4% up and 1.06× scale, then back, over 14 seconds on a loop. Turn this off when Reduce Motion is on.

**Make all four palettes reusable,** in a small `RisoPalette` with these colours. The sheet uses Plum / Rust.

| Palette | Colours |
|---|---|
| Blue / Slate | `#97A6B1`, `#748193`, `#4B556F`, `#222236` |
| Terracotta / Ochre | `#AB5D44`, `#AC7A52`, `#757067`, `#D3B19E` |
| Plum / Rust | `#453349`, `#773F42`, `#996050`, `#B69D9F` |
| Sage / Olive | `#576B5B`, `#6C7F6D`, `#84947F`, `#AAB3A9` |

## The sheet

- **Backdrop:** black at 55% with a 4pt blur. It fades in over 400ms.
- **Sheet:**
  - inset 8pt from the left, right and bottom, corner radius 38;
  - the sheet gradient as its background, a 1pt ring of white at 8%, a 1pt top highlight of white at 4.5%, and the shadow `0 −30 70` black at 60%;
  - it slides up from below over 600ms using the curve;
  - **its height wraps its content.** Animate height changes between the two views with `AnimatedSize` over 450ms. The bottom button must never be cut off. Test on the smallest supported iPhone and with large text.
- **Grab handle:** 38×5, radius 3, white at 18%, 10pt from the top.
- **Content padding:** 12 top, 20 on the sides, 22 at the bottom, plus the bottom safe area.

### View 1: welcome

Top to bottom:

1. **Art card:** full width, 168 tall, radius 26. It has a 1pt inner edge of white at 10%, drawn above the art.
   - **Chip,** 14pt from the top and left:
     - 28 tall, radius 14, white at 14% over a 12pt background blur, with a 1pt ring of white at 22%;
     - the text "Founding Access", 12.5pt, weight 500, white.
   - **Logo tile,** centred:
     - 64×64, radius 18, white at 12% over a 14pt blur;
     - a 1pt ring of white at 24%, a 1pt top highlight of white at 30%, and the shadow `0 14 40` black at 25%;
     - the white clove logo at 30pt in the middle;
     - it pops in from 0.75× scale with a fade over 800ms, 200ms after the sheet opens.
2. **Title:** "You're in early.", 20pt above it.
   - Inter Tight 400, 34pt, letter spacing −0.02em, line height 1.08, text colour.
3. **Lead,** 8pt above it: "FindEZ is free while we get ready for launch. Here's how it works."
   - 15.5pt, secondary colour, line height 1.45.
4. **Three points,** 18pt above them, 14pt apart.
   - Each point is a row with a 13pt gap:
     - a 36×36 icon tile, radius 11, soft fill, a 1pt ring of white at 7%, and an 18pt line icon in the text colour;
     - a title at 15.5pt, weight 500, text colour;
     - a body at 14pt, secondary colour, line height 1.4, 2pt below the title.
   - They fade in and rise 8pt, 300ms, 400ms and 500ms after the sheet opens.

   | Icon | Title | Body |
   |---|---|---|
   | Shield with a check | Your inventory stays yours | Everything you save stays in your account, even if you never subscribe. |
   | Magnifier | Always find what you saved | Opening, searching and exporting your items stays free. |
   | Plus | Adding more will need a plan later | When paid plans launch, you'll get a small free allowance. Adding more will need a subscription. |

5. **Fine print,** 18pt above it: "We'll tell you before anything changes. You can find this anytime in Settings."
   - 12.5pt, tertiary colour, line height 1.5.
6. **Buttons,** 16pt above them, stacked 8pt apart. Each is full width, 52 tall, radius 26, 16pt weight 600, and scales to 0.98 when pressed.
   - **"Get started"** (primary):
     - a vertical gradient from `#F4F4F5` to `#D4D4D8` with ink text;
     - a 1pt top highlight of white at 60% and the shadow `0 8 24` black at 35%.
     - It closes the sheet and leaves the user on Ask.
   - **"See what's included"** (secondary): transparent with a 1pt ring of white at 12% and text in the text colour. It opens view 2.

### View 2: what's included

Moving between the two views, the outgoing view fades out and slides 24pt to the side over 300ms, and the incoming one slides in from the other side over 450ms using the curve.

1. **Header row:**
   - a 40pt round back button: transparent, a 1pt ring of white at 12%, a chevron;
   - 10pt gap;
   - the title "What's included", or "Your plan" when opened from Settings, at 17pt weight 500.
   - Back returns to view 1. From Settings, back closes the sheet.
2. **Plan card,** 16pt above it:
   - radius 20, the card gradient, a 1pt ring of white at 7%, a 1pt top highlight of white at 4.5%;
   - padding 12 / 14 / 12 / 12;
   - a 46×46 art tile (radius 13, the Plum / Rust art with grain, rounded corners) with the white clove at 18pt;
   - "Founding Access" at 16pt weight 500, and "Your plan right now" at 13pt secondary;
   - on the right, a "Free" chip: 26 tall, radius 13, soft fill, a 1pt ring of white at 12%, 12.5pt weight 500.
3. **Table card,** 10pt above it, same card style, clipped to its corners.
   - **Column header** (padding 11 / 16 / 9, 12pt weight 500, tertiary): an empty label column, then "Now" in a 64pt column and "Free plan" in an 84pt column, both centred.
   - **Rows:** padding 12 / 16, 14.5pt, text colour, a 1pt hairline on top. The checks are line icons at 17pt with stroke 2.2.
   - **"Limited" chip:** 24 tall, radius 12, soft fill, secondary text at 12pt weight 500.
   - **"Plan" chip:** 24 tall, radius 12, a 1pt ring of white at 18%, text colour at 12pt weight 500.

   | Row | Now | Free plan |
   |---|---|---|
   | Open and search items | ✓ | ✓ |
   | See item details | ✓ | ✓ |
   | Export your inventory | ✓ | ✓ |
   | Ask FindEZ | ✓ | Limited |
   | Add new items | ✓ | Limited |
   | Snap a shelf | ✓ | Limited |
   | Import a spreadsheet | ✓ | Plan |

4. **Fine print:** "**Free plan** is what you keep without subscribing once paid plans launch. Prices and the date aren't set yet. We'll message you before anything changes, and nothing you've saved is ever deleted."
   - Same style as before, with "Free plan" in the secondary colour.
5. **One primary button, "Got it",** in the same style as "Get started". It closes the sheet.

### Accessibility

- The sheet is a modal with the semantics label "Founding Access".
- Every button has a label, and the back button says "Back".
- Tap targets are at least 44×44.
- The layout holds up with large Dynamic Type: the sheet scrolls inside if it's taller than 90% of the screen.
- Reduce Motion turns off the drift, the pop and the staggered rise, leaving simple fades.

## Check before uploading

1. `flutter analyze` is clean, and `flutter test` passes if there are tests.
2. Run it on an iOS simulator and check:
   - a new sign-up shows the sheet once, and it doesn't show again after relaunching;
   - logging in to an existing account doesn't show it;
   - Settings › Your plan opens the details view;
   - both views fit with nothing cut off on the smallest supported iPhone and on a Pro Max;
   - the art has rounded corners and visible grain.
   - Take screenshots of view 1, view 2 and the Settings row, and include them in your summary.
3. Confirm nothing else in the app changed (`git diff --stat`). Only these should appear: the new folder, the sign-up hook, the Settings row, the grain and font assets, the `pubspec.yaml` asset and font entries, the build number, and `docs/founding-access/`.

## Build and upload to TestFlight

1. Bump the **build number** by 1 in `pubspec.yaml` (the number after `+`). Keep the version name unless it has to change for App Store Connect.
2. Commit on `feat/founding-access-sheet` with a clear message, and push the branch to `origin`.
3. Build and upload **the way this repo already does it:**
   - **fastlane:** run the existing beta or TestFlight lane (for example `cd ios && fastlane beta`);
   - **Xcode Cloud or Codemagic:** trigger the workflow from the pushed branch, or tell me exactly which button to press if it can't be triggered from here;
   - **nothing set up:** run `flutter build ipa --release` with the existing signing, then upload the `.ipa` with `xcrun altool --upload-app --type ios` using the App Store Connect API key **already configured on this Mac**. If no key or signing is set up, stop here and tell me what's missing. Don't create keys, certificates or profiles.
4. Set the TestFlight "What to Test" note to: "New: Founding Access sheet after sign-up (shown once), plus Settings › Your plan. Please check it fits your screen and the art has rounded corners."
5. **Report:**
   - the version and build number;
   - the commit hash and branch;
   - whether the upload succeeded, and its processing status in App Store Connect if you can see it;
   - the files you changed;
   - the screenshots.
