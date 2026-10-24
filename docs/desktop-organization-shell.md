# Desktop organization shell

## Implementation

- `organization-switcher.tsx` and its CSS module: authenticated, sorted organization
  menu; current organization, Personal, all workspaces, management, creation, and
  invitation review. Existing account guard and server authorization retained.
  Loading, retry, empty, keyboard dismissal and account-change handling included.
- `context-navigation.ts`, `app-shell.tsx`, `app-sidebar.tsx`: carry the organization
  identity through organization/workspace/inventory navigation. Default expanded
  248px desktop sidebar; existing pin preference and narrow drawer retained.
- `desktop-shell.module.css`: scoped navigation, header, breadcrumb, content,
  action wrapping, table scrolling, and chat composer styling. Marketing, auth,
  branding, backend and Flutter remain outside this change.
- Organization/workspace directories and directory CSS: clearer icon/name/metadata
  hierarchy with all existing permission-dependent actions intact. Creation query
  uses the existing form and is consumed so cancellation/reopening works.

## Validation

- Web Jest: 508 tests in 66 suites passed, including six added regressions.
- `npx tsc --noEmit`: passed.
- `npm run lint`: zero errors, 52 existing warnings.
- `npm run build -- --webpack`: passed with local placeholder build credentials;
  production candidate is built separately using its preserved server environment.
- Browser review in an isolated local frontend copy using fictional organizations,
  users and inventory. Fixture-only authentication/API overrides are outside Git
  and must never be deployed. No customer writes or memberships changed.
- Browser checks cover Organizations, Workspaces, Home, Ask, Items, Spaces,
  Documents, Review, Activity, Capture and profile layout. Light/dark and 390px
  navigation checked; Escape closes the organization menu without dismissing its
  parent drawer. Capture tab scrollbar regression fixed and visually rechecked.
- Reconciled existing live account-verification and organization-settings code
  from `2afb817` before release. No live feature was overwritten.
- All five CI gates passed: run `40120059401`.
- Self-hosted release live, runtime `4b879d98d836756f591bf498cf4e459295e66add`,
  build `XAq7FeqLtoueYFUgAFjOs`. 21 route statuses and six brand assets verified;
  360 unrelated source/public files preserved; backend PID unchanged.
- Live browser Organizations entry correctly redirects to sign-in with its return
  route. Authenticated visual checks used isolated fixtures, not a customer login.

## Deployment receipt

- PR: https://github.com/tanyasmritivc/main-inventory-app/pull/191
- Live directory: `/home/ubuntu/findez-web-releases/desktop-shell-20261024/frontend`.
- Previous directory: `/home/ubuntu/findez-web-releases/direct-auth-20261024/frontend`.
- Server receipt: `/home/ubuntu/findez-web-releases/desktop-shell-20261024/deployment-receipt.json`.
- Rollback: restore that release's `previous-web-rebuild.conf` to the existing
  `findez-web.service.d/web-rebuild.conf`, daemon-reload and restart `findez-web`.
  The prior release remains intact. No Vercel deployment or database changes.

## Manual verification

1. Sign in, open Organizations, and expand the top-left organization selector.
2. Verify only your organizations appear, with the current one checked. Select
   another organization and verify its existing workspaces and permissions.
3. Select Personal, then All workspaces. Open an inventory and verify breadcrumbs,
   Items, Capture, Ask, Spaces, Documents, Review and inventory settings still work.
4. Choose New organization, cancel, and choose it again. Review invitation must
   open the existing invitation entry flow. Do not create data just to test layout.
5. Collapse/pin the sidebar, reload, and verify the preference persists. Use Tab,
   arrow keys and Escape in the organization menu.
6. Check light/dark appearance and a 390px viewport; open/close navigation and its
   organization menu. Verify controls remain reachable and tables scroll locally.
7. Check People, Tasks, Files, Activity and Settings in a workspace. Existing
   membership, transfer, rename and deletion safeguards must remain unchanged.

## Limits and cost

No new packages, OAuth providers, database tables, AI calls or paid services.
The selector fetches the existing organization endpoint when opened. Broad data
mutation flows are covered by the existing suite, not re-executed on customer data.
