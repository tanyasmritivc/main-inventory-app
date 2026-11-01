# FindEZ brand kit

## Logo: Blue echo

The logo is the original FindEZ mark (a black upside-down L with an orange square) with rounded corners, plus a baby blue copy of the L sitting just behind it. The blue copy is the "memory" of where things are.

- `logo/primary/` holds the main version, with round corners. Use it everywhere.
- `logo/soft-corners/` is a slightly sharper version, kept in case it is ever needed.

| File | Use |
| --- | --- |
| `findez-mark.svg` / `.png` | The mark on white or light backgrounds |
| `findez-mark-white.svg` / `.png` | The mark on black or dark backgrounds |
| `findez-wordmark.svg` / `-white.svg` | The mark with "Find" in black (or white) and "EZ" in orange |
| `findez-app-icon-light.png` (1024, 180, 120) | App icon on white |
| `findez-app-icon-dark.png` (1024, 180, 120) | App icon on black |
| `findez-favicon.svg`, `-32.png`, `-16.png` | Browser tab icon |

Rules:
- Use the logo on white or black. On a baby blue background the blue copy blends in, so avoid that.
- Leave clear space around it of at least half the mark's width.
- Smallest sizes: 16px for the mark, 96px wide for the wordmark.
- Do not recolour, outline, add shadows to or separate the three pieces.

## Colour

| Token | Hex | Use |
| --- | --- | --- |
| ink | #111112 | Text, primary buttons, the L in the logo |
| white | #FFFFFF | Backgrounds |
| orange | #E8590C | The found thing: the capture button, highlights, "EZ" |
| orange-ink | #C2410C | Orange text on white (easier to read than brand orange) |
| orange-tint | #FFE8DA | Location chips, the highlighted result |
| baby blue | #A9D6F5 | The echo, soft backgrounds, illustrations, toasts |
| blue-tint | #EEF6FD | Chat bubbles, section backgrounds |
| night | #0B0B0D | Dark sections |

- Black and white do most of the work. Orange marks the moment something is found. Baby blue is for softness and memory.
- Primary buttons are black. Orange is reserved for the capture or camera button.
- Text on an orange background is black, not white.

## Type

- Plus Jakarta Sans for everything: 600 for headlines with tight tracking (about -0.04em), 400 for body text.
- Geist Mono for data: confidence scores, quantities, part numbers.
- Use sentence case everywhere.

## Voice

- Plain and specific: "Saved 12 items to Garage", not "Success!".
- Headlines and subtitles avoid "you", "your" and "us".
- No em dashes. Keep sentences short.

## Theme files

- `theme/tokens.json`: every value above, for any tool.
- `theme/findez-theme.css`: CSS variables plus button, card and chip classes.
- `theme/tailwind.findez.js`: spread into `theme.extend` in the Tailwind config.
- `theme/findez_theme.dart`: Flutter `ThemeData` (needs the `google_fonts` package).
