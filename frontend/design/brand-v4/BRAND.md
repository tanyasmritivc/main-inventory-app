# FindEZ brand kit (v4, Oct 25, 2026)

## Logo: Petals

The logo is four rounded petals joined in the center, in plain orange (#E8590C). It replaces every earlier logo: Blue echo, sharp Blue echo and Item ring.

- **Wordmark:** the mark plus "FindEZ" in ink, or white on dark (Plus Jakarta Sans 600, outlined in the SVGs). The name is always written "FindEZ".
- **Colour:** orange only. On orange backgrounds the mark is white. Use the black version only when you can print in one colour and orange is not available.

### Files in `logo/`

| File | Use |
| --- | --- |
| `findez-mark.svg` / `.png` | The mark in orange, for white, light or dark backgrounds |
| `findez-mark-white.svg` / `.png` | The white mark, for orange or photo backgrounds |
| `findez-mark-black.svg` / `.png` | One-colour print only |
| `findez-mark-small.svg` | Wider gaps between the petals. Use it below 32px so the petals stay readable |
| `findez-wordmark.svg` / `.png` | The mark plus "FindEZ" in ink, for light backgrounds |
| `findez-wordmark-white.svg` / `.png` | The mark plus "FindEZ" in white, for dark backgrounds |
| `findez-app-icon.png` (1024, `-180`, `-120`) + `.svg` | **The iOS app icon.** A white mark on orange, with no transparency |
| `findez-app-icon-light.*` | Alternative icon: an orange mark on white |
| `findez-app-icon-dark.*` | Alternative icon: an orange mark on black |
| `findez-favicon.svg`, `.png` (512), `-32`, `-16` | Browser tab icon: a white small-cut mark on an orange rounded tile |
| `jpeg/` | JPEGs of the mark, the wordmark and the three app icons |

### Rules

- Do not rotate, stretch, outline or recolour the mark, and do not add gradients or shadows.
- Leave clear space around the mark of at least a quarter of its width.
- Smallest sizes: 16px for the favicon (use the small cut), 20px for the mark anywhere else, 96px wide for the wordmark.

## Colour

| Token | Hex | Use |
| --- | --- | --- |
| orange | #E8590C | The logo, the capture or camera button, key highlights |
| orange-ink | #C2410C | Orange text on white |
| orange-tint | #FFE8DA | Location chips, the highlighted result |
| ink | #111112 | Text and primary buttons |
| white | #FFFFFF | Backgrounds |
| baby blue | #A9D6F5 | Soft accents, illustrations, highlights behind headline words |
| blue-tint | #EEF6FD | Chat bubbles, section backgrounds |
| night | #0B0B0D | Dark sections |

## Type

- Plus Jakarta Sans for everything: 600 for headlines with tight tracking (about -0.04em), 400 for body text.
- Geist Mono for data: quantities, part numbers and counts.
- Sentence case everywhere.

## Voice

- Plain and specific: "Saved 12 items to Garage".
- Headlines and subtitles avoid "you", "your" and "us".
- No em dashes. Short sentences.

## Theme files (in `theme/`)

These are unchanged from v3:

- `tokens.json`
- `findez-theme.css`
- `tailwind.findez.js`
- `findez_theme.dart`
