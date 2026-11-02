# Signed-in web theme — November 2, 2026

Applied the supplied dark/light theme to the existing authenticated web app. Existing Appearance choices, routes, data, controls and actions are retained. The user's later instruction authorizes self-hosted deployment and overrides the attachment's no-push restriction.

## Deployment

Published directly to https://findez.ai on November 2, 2026. Runtime commit `79a4501` is pushed on `feat/app-theme`. The external homepage serves the verified build ID, and the protected route returns HTTP 307 to sign-in. All deployment preservation checks passed; see `deployment-receipt.json`. The previous release remains available for rollback.

## Implementation

Shared interior-only tokens cover the shell, typography, controls, cards, dialogs, menus, tables, status/empty/loading states, account settings and chat. Resource art is assigned by a stable hash of the resource ID. Shared PageHeader, ThemeCard and ResourceArt helpers avoid duplicated artwork logic. The existing Appearance setting still owns light, dark and system selection. Public pages have no interior theme marker.

Reference files are in this directory. `route-inventory.json` lists all 31 authenticated route patterns reached by the shared theme. This includes inventory tools, organization/workspace views, account settings and dynamic access/share/approval routes; it is an implementation inventory, not a claim of permission-complete browser coverage.

## Validation

- Local and actual-production-environment server builds passed. Server build ID: `QAWxphsKffeBp4ydhcQIE`.
- TypeScript passed. Full `npm run lint` passed with 52 warnings and zero errors; changed-file lint had 41 warnings and zero errors.
- Theme tests: 12 passed, covering persisted/system choices, route transitions, public-page cleanup and stable resource palettes.
- Focused regression run: 38 passed, 4 failed. The four workspace-management failures also fail on the unchanged baseline.
- Full inherited Jest run: 41 suites passed, 23 failed (420 tests passed, 69 failed). Pristine deployed baseline: 39 suites passed, 25 failed (404 passed, 66 failed). Existing fixture/navigation drift prevents a green full suite; these totals are not directly equivalent because the theme adds tests and baseline fixture availability differs. No full-suite pass is claimed.
- AST audit found all 369 existing action handlers across 23 edited TSX files unchanged.
- Browser checks used the existing review account without creating or editing inventory data: Ask in both themes, populated Spaces, Tools, Profile, Appearance, Upgrade/account menus and a New Space dialog opened then cancelled. Additional navigation checks reached Workspaces and all ten tool destinations, including empty Documents/Restock states. The exact staged production build was checked through a private tunnel.
- The resumed browser session had expired and correctly returned to sign-in. Permission-specific organization/workspace tabs, every dynamic share/approval URL, a toast in both modes, reduced-motion emulation and every route at exactly 1280px were not exhaustively browser-tested.
- Deployment smoke checks compare visible content for 12 public URLs and auth redirects for seven protected routes. Hash checks preserve all public assets and environment/package/config files. Backend PID must remain unchanged. The previous compiled release remains available for rollback.

## Reference differences and limits

Normal-size tertiary text uses darker/lightened neutral shades for readability instead of the low-contrast decorative reference grays. The light headline highlight is also darker than the mockup. This is not a complete WCAG conformance audit. Reduced-motion behavior is implemented in CSS.

The provided HTML defines four art palettes (dusk, moss, slate, plum); it does not define the prompt's mentioned sand palette. Existing photo controls and navigation pin behavior are retained. Counts appear only where the existing data supplies them; no placeholder names or counts were introduced.

`remaining-color-literals.txt` is the source search inventory. It includes unchanged public/marketing components, artwork and image/PDF/label output, permitted muted avatar/status/destructive colors, and legacy styles whose signed-in appearance is overridden by the interior tokens. The override approach intentionally retains shared public CSS. The browser checks did not show orange interface accents, but the inventory is not proof that every permission-specific state has been rendered and inspected.

## Runtime files changed

- `frontend/src/app/interior-tokens.css`
- `frontend/src/app/layout.tsx`
- `frontend/src/app/workspace.css`
- `frontend/src/components/site/account-layout.module.css`
- `frontend/src/components/site/activity-feed-client.tsx`
- `frontend/src/components/site/app-shell.tsx`
- `frontend/src/components/site/app-theme-ui.tsx`
- `frontend/src/components/site/assist-client.tsx`
- `frontend/src/components/site/checkout-client.tsx`
- `frontend/src/components/site/collections-client.tsx`
- `frontend/src/components/site/desktop-shell.module.css`
- `frontend/src/components/site/directory-design.module.css`
- `frontend/src/components/site/documents-client.tsx`
- `frontend/src/components/site/home-inventory-client.tsx`
- `frontend/src/components/site/home-overview.tsx`
- `frontend/src/components/site/inventory-access-request.tsx`
- `frontend/src/components/site/label-studio-client.tsx`
- `frontend/src/components/site/member-avatar.tsx`
- `frontend/src/components/site/memory-settings.module.css`
- `frontend/src/components/site/message-actions.module.css`
- `frontend/src/components/site/notification-preview.module.css`
- `frontend/src/components/site/organization-directory.tsx`
- `frontend/src/components/site/organization-switcher.module.css`
- `frontend/src/components/site/page-transition.module.css`
- `frontend/src/components/site/plans-usage.module.css`
- `frontend/src/components/site/project-kits-client.tsx`
- `frontend/src/components/site/restock-client.tsx`
- `frontend/src/components/site/scan-center-client.tsx`
- `frontend/src/components/site/settings-client.tsx`
- `frontend/src/components/site/share-space-modal.tsx`
- `frontend/src/components/site/shared-space-client.tsx`
- `frontend/src/components/site/teams-client.tsx`
- `frontend/src/components/site/use-app-theme.tsx`
- `frontend/src/components/site/workspace-directory.tsx`
- `frontend/src/components/site/world-resource-links.module.css`
- `frontend/src/components/site/world-tools.module.css`
- `frontend/src/components/site/world-tools.tsx`
- `frontend/src/components/site/world-workspace.module.css`
- `frontend/src/components/site/world-workspace.tsx`
