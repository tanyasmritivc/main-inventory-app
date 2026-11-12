# Public CAD Intelligence release

Live: https://www.findez.ai/cad-intelligence

Released November 11, 2026 directly to the existing self-hosted production server. No Vercel, Render, staging site, duplicate route, local preview server, or new package was used.

## Deployment

A guarded, narrow source overlay was applied to the active frontend at `/home/ubuntu/findez-back-chat-20261111/frontend`. Existing production files were checked before replacement, including changes made concurrently by another task. Rollback archives were retained. The production Next.js webpack build and TypeScript check passed, then the existing `findez-web` systemd service restarted. Backend, database, auth, environment/configuration, mobile, downloads and the comparison/setup routes were untouched.

Final build: `UOIn6365V3p9Vu-e-t0ON`. The earlier build was followed by a title and phone-tab layout correction, rebuilt successfully before restart. The existing Google Fonts build cache was reused. No alternate deployment provider was invoked.

## Route and links

There was no existing public CAD marketing route, so `/cad-intelligence` was added with the exact title `CAD Intelligence | FindEZ AI`.

Other-page changes are link targets only:

| Location | Before | After |
| --- | --- | --- |
| Shared public header CAD Intelligence | `/#cad` | `/cad-intelligence` |
| Shared public footer CAD Intelligence | `/#cad` | `/cad-intelligence` |
| Solutions header CAD override | `/#cad` | `/cad-intelligence` |
| Solutions footer CAD override | `/#cad` | `/cad-intelligence` |
| Home Explore CAD Intelligence | `/cad` | `/cad-intelligence` |

The checkout's legacy `home-content.tsx` header/footer defaults were also updated from `#cad` to `/cad-intelligence`; that older file was not overlaid onto production because the live home page already uses shared public chrome.

The new page preserves these functional destinations:

- Download the Fusion add-in / Download add-in: `/downloads/findez-fusion-preview.zip`
- Open CAD Intelligence / Export shortages: `/cad`
- Read the setup guide: `/docs/cad`
- Download the CSV template: `/downloads/findez-bom-template.csv`
- Header Download: `/desktop`; Sign in: `/signin`
- Other header/footer destinations remain the supplied existing routes.

Plan name remains **Founders Access**.

## Shared components and files

The home and Solutions redesigns were already live. This page reuses the existing shared `public-chrome` header/footer, `ScrollMotion`, `mountBackground`, lifecycle helpers and frame scheduler. Their current compact header is retained. Public chrome files were synchronized into this older local checkout from production; only their CAD href default changed live.

Added runtime files:

- `frontend/src/app/(marketing)/cad-intelligence/page.tsx`
- `frontend/src/components/marketing-dark/cad-public.tsx`
- `frontend/src/components/marketing-dark/cad-public.css`
- `frontend/src/components/marketing-dark/cad-public-content.tsx`
- `frontend/src/components/marketing-dark/cad-public-motion.tsx`
- `frontend/src/components/marketing-dark/cad-public-runtime.js`

Existing production files changed only for hrefs:

- `frontend/src/components/marketing-dark/public-chrome.tsx`
- `frontend/src/components/marketing-dark/solutions.tsx`
- `frontend/src/components/marketing-dark/cad-intelligence-section.tsx`

Additional repository synchronization/documentation:

- `frontend/src/components/marketing-dark/public-chrome.css` (existing live stylesheet, copied unchanged)
- `frontend/src/components/marketing-dark/home-content.tsx` (two legacy href defaults)
- `docs/cad-intelligence-v3/` (supplied archive extracted intact)
- `docs/releases/cad-public-20261111/` (this receipt and six live screenshots)
- `.agents/ACTIVE_WORK.md`

No files removed. Source hash comparison after the initial deployment showed only the intended runtime changes.

## Copy and prototype differences

Current `/docs/cad` was checked against the prototype. Added its explicit privacy clarification: **“Reviewing spreadsheet columns uploads the spreadsheet to read its headers and sample rows.”** This prevents the page implying that spreadsheet review happens wholly on the device. Status definitions, limitations and file-limit wording otherwise remain as supplied and consistent with the guide.

The current shared compact 52px header is reused instead of recreating the prototype's larger header. The Sample data label remains visible on phones, as explicitly required; its row wraps to fit. File preview numbers are grey rather than amber so amber remains reserved for Short and Missing. Browser font rendering and these intentional differences mean the page is not pixel-identical to every supplied screenshot.

## Verification

- Both required production builds passed, including TypeScript. No additional test suite or local preview was run, following the requested deployment-only workflow.
- Live route returns HTTP 200 and exact metadata title.
- Safari inspected at 1440×900 and 390×844 against supplied screens, including the full desktop page and repeated phone scroll passes.
- Pinned comparison scrubbed forward to final statuses and backward to the earlier matching stage.
- Header hides downward and returns upward.
- Results cycle and respond to clicks; Short and Covered states inspected. File previews cycle and Excel responds to selection.
- Setup guide opened successfully in Safari; Open CAD Intelligence reached the existing `/cad` tool. Unauthenticated HTTP follows to `/signin?redirect=%2Fcad`.
- Add-in ZIP downloaded over public HTTPS and passed archive integrity verification. Template and guide return HTTP 200.
- Live home, Solutions and public CAD HTML confirm marketing CAD links point to `/cad-intelligence`; functional comparison links remain `/cad`.
- Offscreen/document-hidden pausing, teardown and reduced-motion final states are implemented. OS reduced-motion mode was not toggled during this task.
- The observed Safari renderer PID 32007 stayed between 40,704 and 40,816 KiB RSS (39.75–39.86 MiB), returning to its starting value. Seven samples span about 2 minutes 42 seconds, including a scheduling gap. This is a bounded process-memory observation, not a heap-leak proof or long-duration performance guarantee. No visible scrolling stalls were observed during inspection.

## Live screenshots

| View | Hero | Pinned comparison | Results |
| --- | --- | --- | --- |
| Desktop 1440×900 | [Hero](desktop-hero.png) | [Comparison](desktop-pinned.png) | [Results](desktop-results.png) |
| Phone 390×844 | [Hero](phone-hero.png) | [Comparison](phone-pinned.png) | [Results](phone-results.png) |

Screenshots are cropped from native Safari responsive viewport captures of the production URL. The desktop and phone hero captures precede the title-only metadata correction; their visual content is unchanged in the final build.
