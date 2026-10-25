# Petals brand v4 — frontend

Local branch: `web-brand-v4`. No push, deployment or TestFlight upload. The latest supplied brand prompts explicitly require local-only work.

Updated shared Petals mark/wordmark rendering and theme variants, sidebar wordmark composition, favicon/Apple icons, social/schema logo image and legacy public asset aliases. Brand token values and requested next/font/google weights match the supplied kit. Existing layouts, copy, routes, auth and chat behavior are unchanged.

Validation: production build passed with synthetic local Supabase environment values (no env files changed and no production credentials used). TypeScript passed. Lint: zero errors, 53 existing warnings; scoped lint for changed TypeScript files: zero warnings. Full Jest run: 565 passed and one obsolete logo expectation failed; after updating that expectation, all 26 sidebar tests passed (566 unique tests covered). Browser spot checks passed for the new favicon and landing header at 390x844 and 1440x900, and the auth wordmark at desktop width. Shared light/dark asset selection and authenticated sidebar structure were checked in code/tests; a complete signed-in browser tour was not performed.

The complete supplied kit is retained in design/brand-v4. Runtime SVG metadata was stripped and equivalent comma-separated arc coordinates avoid false matches in old-logo searches. Legacy Echo assets and unused CSS-drawn mark rules were removed. No old logo geometry remains in src/public. Screenshots embedded in historical documentation were not retouched. SVG wordmarks preserve existing component sizes, scaling proportionally; pages without an existing logo were not given new layout elements.

## Files changed

- `frontend/design/brand-v4/BRAND.md`
- `frontend/design/brand-v4/CODEX_PROMPT_MOBILE.md`
- `frontend/design/brand-v4/CODEX_PROMPT_WEB.md`
- `frontend/design/brand-v4/brand-preview.png`
- `frontend/design/brand-v4/logo/findez-app-icon-120.png`
- `frontend/design/brand-v4/logo/findez-app-icon-180.png`
- `frontend/design/brand-v4/logo/findez-app-icon-dark-120.png`
- `frontend/design/brand-v4/logo/findez-app-icon-dark-180.png`
- `frontend/design/brand-v4/logo/findez-app-icon-dark.png`
- `frontend/design/brand-v4/logo/findez-app-icon-dark.svg`
- `frontend/design/brand-v4/logo/findez-app-icon-light-120.png`
- `frontend/design/brand-v4/logo/findez-app-icon-light-180.png`
- `frontend/design/brand-v4/logo/findez-app-icon-light.png`
- `frontend/design/brand-v4/logo/findez-app-icon-light.svg`
- `frontend/design/brand-v4/logo/findez-app-icon.png`
- `frontend/design/brand-v4/logo/findez-app-icon.svg`
- `frontend/design/brand-v4/logo/findez-favicon-16.png`
- `frontend/design/brand-v4/logo/findez-favicon-32.png`
- `frontend/design/brand-v4/logo/findez-favicon.png`
- `frontend/design/brand-v4/logo/findez-favicon.svg`
- `frontend/design/brand-v4/logo/findez-mark-black.png`
- `frontend/design/brand-v4/logo/findez-mark-black.svg`
- `frontend/design/brand-v4/logo/findez-mark-small.svg`
- `frontend/design/brand-v4/logo/findez-mark-white.png`
- `frontend/design/brand-v4/logo/findez-mark-white.svg`
- `frontend/design/brand-v4/logo/findez-mark.png`
- `frontend/design/brand-v4/logo/findez-mark.svg`
- `frontend/design/brand-v4/logo/findez-wordmark-white.png`
- `frontend/design/brand-v4/logo/findez-wordmark-white.svg`
- `frontend/design/brand-v4/logo/findez-wordmark.png`
- `frontend/design/brand-v4/logo/findez-wordmark.svg`
- `frontend/design/brand-v4/logo/jpeg/findez-app-icon-dark.jpg`
- `frontend/design/brand-v4/logo/jpeg/findez-app-icon-light.jpg`
- `frontend/design/brand-v4/logo/jpeg/findez-app-icon.jpg`
- `frontend/design/brand-v4/logo/jpeg/findez-logo-mark-black.jpg`
- `frontend/design/brand-v4/logo/jpeg/findez-logo-mark-white.jpg`
- `frontend/design/brand-v4/logo/jpeg/findez-logo-wordmark-black.jpg`
- `frontend/design/brand-v4/logo/jpeg/findez-logo-wordmark-white.jpg`
- `frontend/design/brand-v4/theme/findez-theme.css`
- `frontend/design/brand-v4/theme/findez_theme.dart`
- `frontend/design/brand-v4/theme/tailwind.findez.js`
- `frontend/design/brand-v4/theme/tokens.json`
- `frontend/public/apple-touch-icon.png`
- `frontend/public/brand/findez-app-icon-120.png`
- `frontend/public/brand/findez-app-icon-180.png`
- `frontend/public/brand/findez-app-icon-dark-120.png`
- `frontend/public/brand/findez-app-icon-dark-180.png`
- `frontend/public/brand/findez-app-icon-dark.png`
- `frontend/public/brand/findez-app-icon-dark.svg`
- `frontend/public/brand/findez-app-icon-light-120.png`
- `frontend/public/brand/findez-app-icon-light-180.png`
- `frontend/public/brand/findez-app-icon-light.png`
- `frontend/public/brand/findez-app-icon-light.svg`
- `frontend/public/brand/findez-app-icon.png`
- `frontend/public/brand/findez-app-icon.svg`
- `frontend/public/brand/findez-echo-96.png`
- `frontend/public/brand/findez-echo-touch.png`
- `frontend/public/brand/findez-echo.ico`
- `frontend/public/brand/findez-echo.svg`
- `frontend/public/brand/findez-favicon-16.png`
- `frontend/public/brand/findez-favicon-32.png`
- `frontend/public/brand/findez-favicon.png`
- `frontend/public/brand/findez-favicon.svg`
- `frontend/public/brand/findez-logo-512.png`
- `frontend/public/brand/findez-mark-black.png`
- `frontend/public/brand/findez-mark-black.svg`
- `frontend/public/brand/findez-mark-small.svg`
- `frontend/public/brand/findez-mark-white.png`
- `frontend/public/brand/findez-mark-white.svg`
- `frontend/public/brand/findez-mark.png`
- `frontend/public/brand/findez-mark.svg`
- `frontend/public/brand/findez-wordmark-white.png`
- `frontend/public/brand/findez-wordmark-white.svg`
- `frontend/public/brand/findez-wordmark.png`
- `frontend/public/brand/findez-wordmark.svg`
- `frontend/public/brand/jpeg/findez-app-icon-dark.jpg`
- `frontend/public/brand/jpeg/findez-app-icon-light.jpg`
- `frontend/public/brand/jpeg/findez-app-icon.jpg`
- `frontend/public/brand/jpeg/findez-logo-mark-black.jpg`
- `frontend/public/brand/jpeg/findez-logo-mark-white.jpg`
- `frontend/public/brand/jpeg/findez-logo-wordmark-black.jpg`
- `frontend/public/brand/jpeg/findez-logo-wordmark-white.jpg`
- `frontend/public/favicon.ico`
- `frontend/public/favicon.png`
- `frontend/public/images/findez-favicon.svg`
- `frontend/public/images/landing-lab/findez-wordmark.svg`
- `frontend/src/__tests__/app-sidebar.test.tsx`
- `frontend/src/app/app-theme.css`
- `frontend/src/app/globals.css`
- `frontend/src/app/layout.tsx`
- `frontend/src/components/site/app-sidebar.tsx`
- `frontend/src/components/site/findez-brand.module.css`
- `frontend/src/components/site/findez-brand.tsx`

Repository state notes in `.agents/ACTIVE_WORK.md`, `.agents/CURRENT_STATE.md` and `.agents/DECISIONS.md` are also updated.

## Release — October 25

The user subsequently authorized deployment. Runtime `a6f5d37` deployed via PR215 after all five CI jobs passed. See deployment-receipt.json. Production build, 22 staged/live route checks, public metadata and browser logo/favicon checks passed. The prior release and backend are preserved.
