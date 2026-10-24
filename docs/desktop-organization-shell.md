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

- Web Jest: 489 tests in 63 suites passed, including six added regressions.
- `npx tsc --noEmit`: passed.
- `npm run lint`: zero errors, 52 existing warnings.
- `npm run build -- --webpack`: passed with local placeholder build credentials;
  production candidate is built separately using its preserved server environment.
- Browser review in an isolated local frontend copy using fictional organizations,
  users and inventory. Fixture-only authentication/API overrides are outside Git
  and must never be deployed. No customer writes or memberships changed.
- Self-hosted deployment and final narrow browser checks pending.

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
