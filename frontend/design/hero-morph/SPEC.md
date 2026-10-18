# Hero morph: exact spec

`reference/index.html` is the working source. Where this file and the reference disagree, the reference wins.

## Structure

```
section#hero                 height: calc(100vh + 1300px)      (the scroll track)
  .stage                     position: sticky; top: 0; height: 100vh; overflow: hidden
    .inner                   position: relative; width: Wi px; margin: 0 auto; height: 100%
      .text                  hero copy (eyebrow, h1, sub, two buttons)
      .s2                    "Take a picture. That is it." copy and the two counters
      .photo                 4:3 workbench photo, darkened base + lit copy clipped to the lens
        .det x6              detection boxes with mono tags
        .lens                ring with an orange crosshair
        corner labels        bottom-left hint, bottom-right count
      .card                  "Workshop › Workbench" item card with the Ask bar
      .chip                  "Remembering 6 objects" with an animated viewfinder
```

All five children are absolutely positioned inside `.inner` and moved by the engine.

## Copy (exact)

- Eyebrow: `CAPTURE · ASK · FIND` (Geist Mono 12px, letter-spacing .12em, #8C8C8C, the dots are 4px circles #C9C6C0)
- H1: `FindEZ gives the physical world ` + `a memory.` in #E8590C
- Sub: `You don't organize your physical world for FindEZ. FindEZ organizes it for you.`
- Buttons: `Try FindEZ on the web` (dark) and `Get the iPhone app` (outline, phone icon)
- Section 2 eyebrow: `CAPTURE`
- H2: `Take a picture.` line break `That is it.` in #E8590C
- Body: `No forms, no categories, no typing. FIND separates every object in the photo, counts it, and tells you how sure it is.`
- Counters: `Objects found`, `Needs a look` (labels Geist Mono 11.5px uppercase)
- Photo corners: `Move your cursor to scan` / `One photo`, and `N object(s) in view` / `N object(s) found`
- Card header: `Workshop › Workbench`, right label `TODAY`
- Card rows: `Battery charger, 18V x1 0.97`, `Duct tape x1 0.93`, `Socket head screws x40 0.91`, `Gearbox housing x2 0.79` (0.79 in #C2410C)
- Chip: `Remembering 6 objects`

## Type

| Element | Size | Line height | Tracking | Weight |
|---|---|---|---|---|
| H1 | clamp(54px, 5.9vw, 92px) | .96 | -.055em | 400 |
| Sub | 21px | 1.45 | 0 | 400, #3F3D39 |
| H2 | clamp(34px, 3.4vw, 52px) | 1.04 | -.045em | 400 |
| Body | 17px | 1.6 | 0 | 400, #6B6B6B |
| Counters | 44px | 1 | -.04em | tabular numbers |
| Buttons | 16px, height 52px, radius 12px | | | |

## Colours

Ink #111112, body #3F3D39, muted #6B6B6B, label #8C8C8C, hairline #F1F1F0, outline #E3E3E1, orange #E8590C, dark orange #C2410C, low box outline #F5B48A, ask bar #F6F6F4, photo backing #2A2724.

## Constants

```
LENS_R     = 92     lens radius px (used as R = min(92, photoWidth * 0.2), so phones get a smaller lens)
SCROLL_LEN = 1300   pinned scroll length px
MAX_W      = 1160   content width cap px
GUTTER     = 48     side gutter px
OVER       = 170    card overhang below the photo in the hero px
NARROW     = 980    static layout below this viewport width
Q_EVERY    = 4200   ms between Ask questions
HDR        = real height of the site header, read at runtime
```

## Helpers

```
C(v)  = clamp(v, 0, 1)
ss(v) = C(v)^2 * (3 - 2*C(v))        smoothstep
L(a, b, v) = a + (b - a) * v         lerp
p = clamp(-rect.top / (rect.height - innerHeight), 0, 1)   rect = section#hero
```

## Curves

```
e       = ss((p - 0.08) / 0.62)    photo travels from the hero frame to the section 2 frame
textOut = ss(p / 0.24)             hero text: opacity 1 - textOut, translateY(-80 * textOut px)
cardOut = ss((p - 0.22) / 0.30)    card: opacity 1 - cardOut, translateY(60 * cardOut px)
s2In    = ss((p - 0.45) / 0.35)    section 2 copy: opacity s2In, translateY(-50% + 40 * (1 - s2In) px)
allOn   = ss((p - 0.50) / 0.30)    lens and lit copy fade out, base brightness .55 -> .92
ai[i]   = ss((p - 0.46 - i * 0.045) / 0.07)   detection i appears (i = 0..5)
chip opacity = 1 - textOut
```

Counters: `found` = number of detections with ai > .5; `needs` = those among them with confidence < .80. Write them as text every frame, so they count up on the way down and back on the way up.

## Geometry (px, inside .inner)

```
Wi   = min(MAX_W, innerWidth - 2 * GUTTER)
visH = innerHeight - HDR

Hero frame
hH = max(260, min(Wi * 0.62 * 0.75, visH - OVER - 40));  hW = hH / 0.75
hL = Wi * 0.52
hT = max(16, min(56, (visH - (hH + OVER)) / 2))

Section 2 frame
eW = min(Wi * 0.55, innerHeight * 0.74 / 0.75);  eH = eW * 0.75
eL = 0;  eT = (innerHeight - eH) / 2

Photo: left L(hL, eL, e), top L(hT, eT, e), width L(hW, eW, e), aspect 4:3, radius 20
Text:  left 0, top max(8, hT - 6), width hL - 48
S2:    left eW + 72, top 50%, width Wi - eW - 72, max-width 460
Card:  left hL - 36, top hT + hH - 120, width min(380, Wi * 0.33)
Chip:  left hL + hW - 250, top hT + hH - 66
```

The hero photo intentionally runs past the right edge of `.inner`; `.stage` clips it.

## Lens

- Idle drift (about 30fps, only while the mouse is off the photo and p < .6):
  `x = 54 + 13 * sin(t * 0.45)` %, `y = 47 + 11 * sin(t * 0.7 + 1)` %, t in seconds.
- On mousemove over the photo, the lens centre follows the pointer (% of the photo box). Mouseleave returns to drift.
- The lit copy of the photo is the same image with `clip-path: circle(92px at x% y%)`; the base image has `filter: brightness(.55)` in the hero.
- A detection is "in view" when its centre is within 92px of the lens centre (convert % to px with the photo's width and width * .75).

## Detections (% of the 4:3 photo: centre x, centre y, width, height)

| i | x | y | w | h | label | conf |
|---|---|---|---|---|---|---|
| 0 | 54.4 | 31.9 | 8 | 9 | battery pack 18V | 0.95 |
| 1 | 65.6 | 44.4 | 13 | 12 | battery charger 18V | 0.97 |
| 2 | 41.7 | 49.6 | 9 | 10 | duct tape | 0.93 |
| 3 | 27 | 58 | 8 | 7 | spur gear | 0.84 |
| 4 | 40 | 66 | 17 | 16 | socket head screws | 0.91 |
| 5 | 66.7 | 71 | 20 | 16 | gearbox housing | 0.79 |

Box: inset 1.5px outline #E8590C (low confidence #F5B48A). Tag above the box: 20px tall, Geist Mono 10.5px, white on #E8590C (low #C2410C), text `label conf`.
Box opacity = `max(ai[i], (inView or asked) ? 1 - allOn : 0)`, transition opacity .2s.

## Ask cycle (card search bar)

Every 4.2s while p < .3, move to the next question. The asked detection lights up on the photo.

| Question | Answer | Lights up |
|---|---|---|
| Where’s the duct tape | Workbench › Middle | 2 |
| How many socket head screws | 40 · Front bin | 4 |
| Do I own an 18V charger | Yes, 1 · Right side | 1 |
| What needs a look | Gearbox housing · 0.79 | 5 |

Blinking caret after the question (1s steps). Rows fade in once on load (.5s, staggered .25s).

## Static layout (under 980px wide, or prefers-reduced-motion)

No sticky, no scroll track. Stack in this order: text, photo, card, then the section 2 copy with the counters at their final values (6 and 1). The chip is hidden. Reduced motion also stops the idle drift, caret and row animations.
