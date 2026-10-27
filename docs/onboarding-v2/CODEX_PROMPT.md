# Codex prompt: onboarding v2, scan a sample photo (Flutter)

This replaces the earlier chat-first onboarding prompt. The big change: the main path is now **scanning a bundled sample photo**. There is no camera, no network call and no sign in until the person has seen the items and asked a question.

Before you run this, put these files into the repo:

| File | Goes to |
| --- | --- |
| `findez-onboarding.html` | `docs/onboarding-v2/findez-onboarding.html` (the reference prototype; open it in Chrome at 390×844) |
| `onboarding-flow.png` | `docs/onboarding-v2/onboarding-flow.png` |
| `onboarding_world.html` | `mobile/assets/onboarding/onboarding_world.html` (replaces the old one; the 3D logo is now Petals) |
| `sample_workbench.jpg` | `mobile/assets/onboarding/sample_workbench.jpg` |
| `sample_workbench.json` | `mobile/assets/onboarding/sample_workbench.json` |
| `pip.svg` | `mobile/assets/mascot/pip.svg` (skip if it is already there) |

Then paste everything below the line into Codex from the repo root.

---

MOBILE (FLUTTER) ONLY. Rebuild the first-run onboarding so that the person scans a bundled sample photo, sees the items FindEZ found, asks where something is, and only then is asked to make an account. `docs/onboarding-v2/findez-onboarding.html` is the source of truth for layout, copy, motion and timing. Rebuild its UI in Flutter. Do not embed the whole prototype.

If a chat-first onboarding already exists from the earlier `feat/chat-onboarding` work, modify it. Otherwise build it new and remove the older "Build your world" steps (organization name, workspace purpose, first inventory) from first run.

## Scope (strict)

- Do NOT change the FastAPI backend, the Supabase schema, RLS, the Next.js web app, env files, CI or deploy config.
- Keep the existing auth screen and sign-in logic.
- Existing signed-in users never see onboarding.
- Work on a new branch `feat/onboarding-sample-scan`. Do not push.

## Principles

- **Nothing before the value.** No sign in, no camera permission and no network call before the person sees items and gets an answer.
- **No continue buttons.** Every tap moves the flow forward. The only automatic step is the sign-up sheet, which rises 2.2 seconds after the first answer.
- **No structure setup.** No organization, workspace or inventory names.

## Remove from onboarding

- The camera step ("Snap a shelf", the viewfinder and shutter).
- Any call to the photo extraction endpoint during onboarding.
- `supabase.auth.signInAnonymously()` and the 401/403 "Make a free account to read this photo" path. If you added anonymous-session code only for onboarding, delete it.

## Flow and copy

Use the exact text below.

### 1. Intro

- Shown on first launch, or when signed out with no session.
- The 3D layer shows the Petals logo with item blocks circling it (`mode:'intro'`).
- Headline: "Memory for physical things." with "physical things." highlighted by a peach band (#FFD3B8) behind the lower part of the text.
- Subtitle: "Scan a sample photo. No account needed."
- **Sample card** (the main action; tapping anywhere on it starts the scan):
  - `sample_workbench.jpg`, full width, aspect 1100:560, radius 24, cover fit, soft warm shadow.
  - A dark gradient over the bottom half.
  - White viewfinder corner brackets that slowly breathe (2.4s loop).
  - A soft orange scan line that sweeps down every 3.2s, as a teaser.
  - Bottom left: "SAMPLE PHOTO" (small caps, 11.5pt, 80% white) over "A robotics workbench" (16pt, 600).
  - Bottom right: an orange pill with a scan icon and "Scan it", with a soft pulsing orange glow.
- Below it, two equal pill buttons in a row: "Type a list" and "Describe a space". They keep the existing behaviour (see section 2b).
- Link: "Already have an account? Sign in". It opens the sheet as "Welcome back" / "Sign in to your inventory." with no "Ask another question" link.
- Top: four progress dashes (scan, list, ask, keep). A back arrow appears once the chat is open, and it restarts onboarding.

### 2a. Scan (sample path)

1. The chat panel slides up and covers everything below the top 300pt. The 3D logo turns into an empty shelf (`mode:'shelf', filled:0`).
2. The sample photo appears as the user's message: ink bubble with 5pt padding, photo 292pt wide, radius 17 17 5 17.
3. After 350ms the scan starts:
   - The photo dims slightly (28% black overlay).
   - An orange beam (a gradient that ends in a bright edge line) sweeps from top to bottom over 1.5s, ease-in-out.
   - Pip bobs under the photo with the shimmer text "Scanning the sample photo...".
   - Each detection box from `sample_workbench.json` pops in (scale 1.2 to 1) when the beam reaches its top edge. Boxes: 2pt orange border, radius 6, label tag above the box in Geist Mono 8pt, white on orange. If a box starts within the top 9% of the photo, put its label inside the box instead.
4. After the sweep, remove the dim and the Pip line.
5. FindEZ says: "Found 7 things on this workbench, with brands and models read from the labels. Tap a number to fix it."
6. The item card follows (see "Item card" below), using the items from `sample_workbench.json`.
7. FindEZ says: "This is what FindEZ remembers. Now ask where something is."

Load the JSON and image from assets. Do not call the AI or any API.

### 2b. Type a list / Describe a space

These stay as they are in the current chat onboarding (or as in the prototype if you are building new):

- **Describe:** "Which space should FindEZ remember first?", chips Garage, Workshop, Kitchen, Lab, Closet, Craft room, and a starter list from the on-device templates (`T` in the prototype script).
- **Type:** "List a few things. Counts help, but they are optional.", parsed on the phone the same way as `parseList`.
- Reply: "Here is a starter list for the {space}. Tap a number to fix it." then the item card, then "Saved to **{space}**. Now ask where something is."

### Item card (all paths)

- White, 1px line, radius 18. Header: space name, and "{n} items" in mono.
- One row per item, appearing 70ms apart:
  - colour swatch;
  - the name, with the detail under it in Geist Mono 11pt muted (for example "Makita · DC18RC"), only when there is a detail;
  - the spot, right aligned, muted;
  - the quantity in mono.
- Tapping a quantity shows − and + inline on that row only.
- Each new row adds a block to the 3D shelf (`filled = row count`). Swatch colours follow the block colours in order: ink, baby blue, off-white, ink, baby blue, ink.

### 3. Ask

- Chips, the first highlighted (ink with a soft pulsing ring):
  - Sample path: "Where is the battery charger?", "What model is the charger?", "How many screws?"
  - Type/describe paths: "Where is the {item}?" and "How many {item}?", picked the same way as the prototype.
- Input placeholder: "Ask about anything on the list...". Typed questions work too.
- Answer on the phone by matching words in the question against item names (the prototype's `findItem`). No AI call.
- Show Pip with "Looking..." for about 0.4s, then:
  - Where: "{Item} is in **{space}**, {spot}." plus an orange-tint chip "{space} · {spot}".
  - How many: "**{qty}** {item} in {space}." plus the chip.
  - Model or brand (question contains model, brand, make, what kind or which) and the item has a detail: "The {item} is a **{detail}**, read from its label." plus the chip.
  - No match: "That is not on this workbench yet. Try one of these:" (or "on this list" for the other paths) plus three "Where is the ...?" chips.
- The 3D scene focuses on that item's block (`mode:'found', found:index`). It turns orange with a pulsing ring.

### 4. Keep

- 2.2s after the **first** answer only, the blocks fly into the Petals logo (`mode:'keep'`) and the sign-up sheet rises.
- Sheet copy:
  - Sample path: title "Now try it on real stuff". Subtitle "Make a free account, snap a shelf, and FindEZ remembers every item on every device."
  - Type/describe paths: title "Keep these {n} items". Subtitle "Make an account and FindEZ remembers them, on every device."
- Buttons: "Continue with Apple", "Continue with Google", "Continue with email", wired to the existing auth methods. Show only the methods the app supports today.
- Fine print: "Free to start. Nothing is shared without permission."
- Under it, a text link "Ask another question". It lowers the sheet, returns the 3D scene to `found`, and shows three new "Where is the ...?" chips for items not asked about yet. Later answers do not raise the sheet again on a timer. Tapping the back arrow restarts.

## After sign up

- **Sample path:** do NOT save the sample items. They are demo data and do not belong to the person.
  - Land on the Ask (chat) tab with an empty state.
  - Show a toast: "Snap a shelf to add your first items".
  - Highlight the camera button in the composer with the same pulsing orange ring used on the sample card, until it is tapped once.
- **Type/describe paths:** save the items with the same API calls the Confirm Items save already uses:
  - Location: the space name. Spaces are location values on items; there is no spaces table.
  - Spot: put it in the item's position or sub-location field if the model has one. Otherwise leave it out.
  - Destination: the default (Personal) workspace and inventory.
  - Make the save idempotent, so a retry never creates duplicates. Clear the local draft only after the save succeeds.
  - Land on the Ask tab with that space selected and the toast "Saved {n} items to {space}".
- Keep the draft (space and items) in shared_preferences until then, so it survives the app being closed.

## 3D layer

- Show `assets/onboarding/onboarding_world.html` in a full-screen transparent `WebView` (webview_flutter) behind the Flutter UI.
  - Turn off scrolling and zoom, and block navigation.
  - Let pointer moves through so the slight tilt works.
- The API is unchanged; only the logo inside the scene changed to Petals:
  - `FindEZWorld.set({mode:'intro'})`
  - `FindEZWorld.set({mode:'shelf', filled:N})`
  - `FindEZWorld.set({mode:'found', found:I})`
  - `FindEZWorld.set({mode:'keep', found:I})`
- JavaScript channel `World` receives `ready` once loaded. Queue calls until then.
- Coordinate UI motion with the scene using roughly 600ms ease-out-cubic transitions. Never jump-cut.
- If the WebView fails or WebGL is unavailable, hide the layer and keep the flow working.
- If iOS Reduce Motion is on, load the page with `?reduce=1`, make UI transitions instant, show all boxes at once, and skip the beam sweep, pulse, breathing brackets and shimmer.

## Visual spec

- Light, warm theme. Page background: a soft peach radial glow (#FFEDE2) at the top fading to white.
- Colours: ink #111112, orange #E8590C, orange-ink #C2410C, orange tint #FFE8DA, peach highlight #FFD3B8, baby blue #A9D6F5, blue tint #EEF6FD, muted #6B6C72, lines #ECEDF0.
- Fonts: Plus Jakarta Sans for everything, Geist Mono for quantities, details, counts and box labels.
- Chat: user bubbles ink with white text, radius 20 20 6 20. FindEZ messages are plain text with no bubble.
- Chips: pills with a 1px line. The highlighted chip is ink with a pulsing baby-blue ring.

## Analytics

Use the existing logger:

- `onboarding_started`
- `onboarding_option` (sample, list or describe)
- `onboarding_scan_finished`
- `onboarding_items_added` (count)
- `onboarding_first_question`
- `onboarding_signup_shown`
- `onboarding_ask_another`
- `onboarding_completed` (method, path)

## Check before you finish

- `flutter analyze` passes with no new warnings.
- With the network turned off, the sample path runs end to end: scan, items, an answer, and the sheet. No sign in or camera permission prompt appears before the sheet.
- `git grep -n "signInAnonymously" mobile/lib` returns nothing used by onboarding.
- "What model is the charger?" answers "The battery charger is a Makita DC18RC, read from its label."
- "Ask another question" lowers the sheet and the flow continues.
- After signing up from the sample path, no sample items exist in the account, and the Ask tab shows the camera hint.
- After signing up from Type or Describe, the items appear under the right space, and a retry does not create duplicates.
- Turn on Reduce Motion and confirm the flow still works.
- Commit on `feat/onboarding-sample-scan`. Summarize the files changed, what was removed, which auth methods are shown, and anything that could not be matched exactly.
