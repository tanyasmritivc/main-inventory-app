# Codex prompt: landing hero, "Workbench" (web)

This replaces the hero-v2 and hero-v4 prompts.

Before you run this, put these files into the repo:

| File | Goes to |
| --- | --- |
| `findez-hero-workbench.html`, `walkthrough.mp4`, `hero-desktop.png`, `hero-mobile.png` | `docs/hero-workbench/` |
| `bench.jpg` (1600×1200) | `frontend/public/images/landing/workbench-wide.jpg` |

Then paste everything below the line into Codex from the repo root.

---

WEB (NEXT.JS) ONLY. Replace the first screen of the landing page with the dark "Workbench" hero in `docs/hero-workbench/findez-hero-workbench.html`. The video and screenshots next to it are the source of truth for layout, copy and timing. Everything below the hero stays as it is.

## Scope

- Change only the announcement band, the nav styling while it sits over the hero, and the hero section.
- Do not touch the other landing sections, other pages, the backend, Supabase, the Flutter app, env files or deploy config.
- Work on a new branch `feat/hero-workbench`. Do not push.

## Header

- **Announcement band:** full width, 40px tall, `#18181B` background, white 13.5px/500 text, centred.
  - It holds a "New" pill (white at 12% opacity), the text "FindEZ AI is now on iPhone", and a right arrow that nudges 3px on hover.
  - The whole band links to `https://apps.apple.com/us/app/findez-ai/id6760401697`.
- **Nav,** directly under the band:
  - background `rgba(13,13,15,.7)` with a 14px backdrop blur;
  - white Petals logo and "FindEZ" wordmark;
  - links in `#D4D4D8`;
  - "Log in" in white;
  - "Get started" as a white pill with ink text.
- **Fixed together.** The band and the nav stay fixed at the top. After 10px of scroll the band collapses to 0 height (450ms).
- **Phones:** hide the "New" pill and the menu links; keep the logo and Get started.

## Hero

- **Size:** full viewport height, at least 780px, on `#0D0D0F`.
- **Background photo:** `workbench-wide.jpg` covers the hero.
  - Position 50% 72%, `filter: brightness(.36) saturate(.7) contrast(1.05)`, scale 1.04.
  - A very slow zoom alternates over 40s, ending at scale 1.1 and translate −1%.
- **Shade** over the photo: a vertical gradient, dark at the top and bottom (85% to 90%) and lighter in the middle (15% to 20%).
- **Veil** over that, behind the text: `radial-gradient(42% 36% at 50% 50%, rgba(13,13,15,.96) 30%, rgba(13,13,15,.6) 65%, transparent 100%)`. This keeps the words readable.
- **Centre block,** absolutely centred, max width 680px:
  - **Headline:** "The AI that turns your inventory into **intelligence.**"
    - Inter Tight 400, `clamp(38px, 4.4vw, 64px)`, line-height 1.04, letter-spacing −0.022em, white.
    - "intelligence." uses the ember gradient as text fill: `linear-gradient(100deg, #F3A24C, #E2622F 48%, #B8392A)`.
  - **Composer:** white, radius 22px, 36px below the headline. It has a one-line textarea (no scrollbar, no wrap), a + button, a mic and the black Scan pill.
    - Placeholder: "Describe your inventory".
    - Pressing Enter goes to `/signup?prompt=<encoded text>`.
  - **Hint:** "Describe what you own, or tap Scan to start from a photo." 14px, `#6B6B70`, 16px under the composer.
- **Example placeholders.** While the visitor hasn't focused the box, the placeholder types these examples (28ms per character), holds each for 2.4s, then deletes it quickly:
  1. "Garage workbench: charger, gearbox, socket screws"
  2. "Parts drawer: 48 bearings, 60 washers, M4 screws"
  3. "Kitchen pantry: rice, pasta, olive oil"

  Focusing the box stops this for good.

## Detection boxes (the main animation)

White outlines appear on real objects in the photo, as if FindEZ is reading the bench.

Objects, in photo pixels on the 1600×1200 image (x1, y1, x2, y2), with labels:

| Label | Box |
| --- | --- |
| black wheels · 3 | 0, 660, 152, 905 |
| stacked bins · 1 | 10, 380, 362, 662 |
| brass gears · 4 | 400, 505, 572, 592 |
| hex screws · 20 | 495, 385, 615, 492 |
| socket head screws · 12 | 530, 715, 765, 865 |
| gearbox housing · 4 | 855, 770, 1290, 945 |
| battery charger · 1 | 765, 425, 1200, 660 |
| lock washers · 60 | 1370, 830, 1600, 965 |
| bagged parts · 3 | 150, 578, 425, 805 |
| duct tape · 1 | 575, 535, 772, 650 |

**Placement**, recalculated on resize (see `placeBoxes()` in the prototype):
- Map photo pixels to screen with the same cover maths as the background: scale 1.04, position 50% 72%.
- Clamp each box to the hero: at least 10px from the sides, 124px from the top (below the header) and 12px from the bottom.
- If a box sits mostly below the centre block, move its top to 14px under the hint.
- Drop any box that is smaller than 60×50px after clamping, or that overlaps the centre block by more than 45% of its area.

**Look:**
- 1.5px white outline (90% opacity), radius 10px, a faint glow.
- Label: Geist Mono 11.5px/500, ink text on white, radius 6px, sitting just above the box's top-left corner.
- If the box starts right under the centre block, the label sits below the box instead.

**Timing:**
- A new box appears every 1.5s, cycling through the visible boxes in order. Each stays for 2.9s, so up to two show at once.
- Enter: fade in, scale 1.06 → 1, 700 to 800ms.
- Start about 0.9s after load.

## Motion and accessibility

- One easing curve: `cubic-bezier(.32,.72,0,1)`.
- **Reduce Motion:** no slow zoom and no typing. Show the static placeholder, and boxes appear without scaling.
- Pause the box cycle and the typing while the hero is off screen.

## Mobile (below 900px)

- The veil becomes `radial-gradient(90% 34% at 50% 50%, ...)` so the centre stays dark across the narrow screen.
- The same box rules apply. Usually only the boxes above and below the centre block survive.
- There must be no horizontal scroll at 390px.

## Build notes

- Make one component, for example `components/landing-v5/HeroWorkbench.tsx`, and replace the current hero with it. Keep all styles scoped.
- Use `next/image` with `fill` and `priority` for the photo, or CSS `background-image` if the zoom is easier that way. Keep it to one request.
- Fonts: Inter, Inter Tight 400, Plus Jakarta Sans 600 (wordmark) and Geist Mono, all through `next/font/google`.

## Check before you finish

- `npm run lint` and `npm run build` pass.
- At 1440×900:
  - the headline is two lines;
  - boxes never cover the headline, composer or hint;
  - labels are never cut off by the screen edge.
- Check at 390px.
- Typing and pressing Enter goes to `/signup?prompt=...`.
- Compare with `walkthrough.mp4`.
- Commit on `feat/hero-workbench` and list the files changed.
