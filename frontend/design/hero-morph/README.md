# FindEZ hero morph: handoff for Codex

Replaces the current landing hero (dark photo + lens) and the statement screen ("You don't organize your physical world…" with the phone) with one pinned section that starts as the new hero and morphs, on scroll, into "Take a picture. That is it."

## What is in here

| Path | What it is |
| --- | --- |
| `PROMPT.md` | Paste this into Codex. |
| `SPEC.md` | Every number, curve, string and colour. |
| `reference/index.html` | The approved prototype as a plain HTML page. Open it in Chrome, scroll slowly and hover the photo. This is the source of truth for how it looks and moves. |
| `reference/assets/hero-workbench.jpg` | The workbench photo (1600x1200). The detection boxes are positioned on this exact image. |
| `reference/assets/findez-wordmark.png` | Only used by the stand-in header in the reference. The site keeps its own header. |

## Setup (Tanya)

1. Copy this whole folder into the repo at `frontend/design/hero-morph/`.
2. Open Codex in the repo and paste everything in `PROMPT.md`.
3. Codex first writes `frontend/design/hero-morph/AUDIT.md` listing the current sections and which ones it will replace. Skim it.
4. When it finishes, run the site locally and compare `http://localhost:3000` against `reference/index.html` at the same window size. Codex also saves side by side screenshots in `frontend/design/hero-morph/compare/`.
5. Nothing is pushed or deployed until you say so.

## What the section does

- Hero: big headline on the left; a large darkened workbench photo on the right that runs off the edge of the screen. A scan lens drifts over the photo and follows the mouse, lighting up the photo and tagging any object under it. An item card hangs off the photo's bottom-left corner, and its search bar cycles through four Ask questions, lighting up each answer's object.
- Scroll: the section stays pinned for 1300px. The headline and card slide away, the photo moves left and brightens, the six detection boxes appear one by one, and "Take a picture. That is it." fades in on the right with counters that count up with the boxes (6 objects found, 1 needs a look). Scrolling back reverses it.
- Phones and reduced motion: no pin and no morph. Everything stacks, with the finished counts.
