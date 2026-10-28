# Landing and branding v5

Local branch: `web-landing-v5`. User authorized publication to the existing self-hosted site; no Git push. No Vercel or Render configuration is used.

## Changes

The homepage ports the supplied prototype into ten section components under `frontend/src/components/landing-v5`, with scoped styles, one reversible scroll loop, audience tabs, reduced-motion/phone finished states and the existing signup draft handoff. The old three.js landing is removed. Fonts and the workbench photo use Next font/image support. Existing title and description are preserved.

Shared wordmark/mark assets, onboarding logo, favicon, Apple icon and structured logo metadata use the supplied black Petals kit. Legacy asset URLs now serve the new artwork. Other routes retain their behavior and layout.

## Verification

- 636 tests across 87 suites pass, including four motion/audience regressions.
- TypeScript passes. ESLint: zero errors, 52 existing warnings.
- Production webpack build passes (52 generated pages); deployment performs an additional build and staged/live route checks.
- Safari desktop 1440x900 and mobile 390x844 checked. The inventory count changes 5 → 7 and reverses when scrolling back. Phone layout shows the finished state without horizontal overflow.
- No `three` imports remain in the homepage component tree. No logo uses of E8590C remain in frontend source.
- GitHub CI was not triggered because this handoff explicitly requests no push. Local checks and server build results are recorded separately, not represented as CI.

## Intentional differences and compatibility

The written handoff specifies a fixed white header; it is white from the first frame. The prototype's initial transparent header is not retained. Existing safe session-storage draft handling, IME handling and Safari Back recovery remain. The mobile footer wraps and demo tile text scales to avoid overflow. SVG noise is clipped to each rounded panel in Safari. Reduced-motion and no-JavaScript views show finished content. Safari was used at the user's request instead of Chrome.

## Non-logo orange retained

Existing app accents in `globals.css`, `app-theme.css`, `workspace.css`, onboarding legends and the organization/scan visuals in `site/onboarding/world-model.ts` remain unchanged. Historical design reference files are retained as references, not runtime logos.

## Removed files

- `frontend/src/__tests__/landing-v3-motion.test.tsx`
- `frontend/src/__tests__/landing-v3-webgl.test.ts`
- `frontend/src/components/landing-v3/AppCarousel.tsx`
- `frontend/src/components/landing-v3/Business.tsx`
- `frontend/src/components/landing-v3/Closing.tsx`
- `frontend/src/components/landing-v3/LandingV3.tsx`
- `frontend/src/components/landing-v3/SceneDetails.tsx`
- `frontend/src/components/landing-v3/StoryA.tsx`
- `frontend/src/components/landing-v3/Sync.tsx`
- `frontend/src/components/landing-v3/Tools3D.tsx`
- `frontend/src/components/landing-v3/Who.tsx`
- `frontend/src/components/landing-v3/landing.module.css`
- `frontend/src/components/landing-v3/motion.js`
- `frontend/src/components/landing-v3/navigation.ts`
- `frontend/src/components/landing-v3/sceneData.ts`
- `frontend/src/components/landing-v3/toolsScene.js`
- `frontend/src/components/landing-v3/useScrollProgress.ts`

## Publication

Published runtime `654236e` on the existing self-hosted service. All 27 staged and live route/asset checks pass; prior compiled release preserved and API process unchanged. HTTPS Safari loads the new homepage. Receipt: `deployment-receipt.json`.

Safari console showed four unused-font preload notices from fonts loaded by the shared layout, but no hydration/runtime errors or image sizing warning. The final scoped font fix resolves inherited app typography. A full frame-by-frame pixel diff was not performed; key desktop/phone sections were compared to the supplied prototype in Safari.
