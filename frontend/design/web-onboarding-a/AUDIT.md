# Web onboarding audit

Audited October 18, 2026 against `c242920`, the latest local published authenticated
web lane. Isolated worktree: `dev/findez-web-onboarding`, branch `web-onboarding`.
The supplied package is the task specification. Local only: no push, deployment,
production probes, backend, mobile, schema, environment or CI changes.

## Signup and session

- `src/app/signup/page.tsx` renders `AuthForm` in signup mode.
- `src/components/site/auth-form.tsx::onSubmit` calls Supabase `auth.signUp`.
  A returned session supplies `session.user.id`; profile upsert finishes before
  navigation. Without a session it shows email-confirmation instructions.
- Both providers and email confirmation return through `/auth/callback?next=...`.
  `auth-callback-client.tsx` and `lib/auth-callback.ts::resolveAuthCallback` leave
  PKCE exchange to the existing Supabase browser client and verify `getSession`.
- Default destination is `/home`, not `/dashboard`. Explicit invitation and
  password-recovery destinations must retain precedence. Existing sign-in stays
  unchanged. Signup will use `/onboarding` for ordinary application destinations;
  that authenticated route checks eligibility before showing any questions.
- `lib/auth-guard.ts::requireUser` verifies the server user. Client API calls use
  `lib/use-api-session.ts::useApiSession` and the account-bound credential checks in
  `lib/account-request.ts::accountRequest`.

## Existing create operations

There are no separate organization/inventory create helpers: current directories
call the existing `accountRequest` transport directly from their submit handlers.

| Operation | Existing frontend file/function | Endpoint | Existing backend handler |
| --- | --- | --- | --- |
| Organization | `components/site/organization-directory.tsx::Directory.save` | `POST /organizations`, `{name}` | `collaboration.py::create_organization`; returns `organization.organization_id` |
| Workspace in organization | `organization-directory.tsx::Directory.save` | `POST /organizations/{id}/workspaces`, `{name}` | `collaboration.py::create_project`; returns `workspace.team_id` |
| Standalone owner workspace | `workspace-directory.tsx::WorkspaceDirectoryAccount.submit` | `POST /teams`, `{name, program}` | `teams.py::create_team_route`; returns `team.team_id` |
| Inventory | `workspace-directory.tsx::WorkspaceDirectoryAccount.submit` | `POST /inventory-workspaces/{id}/inventories`, `{name}` | `inventory_workspaces.py::create_workspace_inventory`; returns `inventory.inventory_id` |

All four operations exist on both frontend and backend. No missing-call stop
condition applies. A standalone workspace is an existing owner-only Team record
with no organization; it does not rename or modify the built-in Personal context.
The required category for its existing create contract can use `other`.

## Eligibility and routing

- `GET /organizations` returns authorized organization memberships.
- `GET /inventory-workspaces` returns the built-in `personal` context plus
  authorized Team/workspace records, including those created on iPhone.
- Eligibility requires no organizations and no non-Personal workspace, plus no
  per-user `fz_web_onboarding_done_<userId>` completion flag. Failed reads must
  show retry instead of treating unknown data as empty.
- An interrupted setup must be allowed to resume its own confirmed creation IDs;
  otherwise the first successful organization/workspace write would incorrectly
  disqualify the next refresh. Unrelated organizations/workspaces still exclude it.
- `lib/workspace-directory.ts::directoryInventoryHref` opens an accessible
  inventory at `/home?inventory=<inventory_id>`.
- `components/site/inventory-boundary.tsx` validates that inventory and supplies
  its workspace to the shell. There is no web last-place persistence to update;
  selected inventory context is window-local and URL-bound in
  `lib/inventory-selection.ts`. Unscoped `/home` goes to `/organizations`.
- Skip should open Personal's existing default inventory dashboard when present,
  otherwise `/workspaces/personal`, without creating any record.

## Retry boundary and local verification

Existing POST contracts do not accept idempotency keys or caller-specified IDs.
Persist each returned ID before continuing, serialize setup across tabs with a
browser lock, and reconcile an uncertain outcome against authorized owner records
before retrying. Do not claim transactional exactly-once creation across browser
storage loss; that would require a backend contract change outside this task.

No local auth/database service is supplied in the ZIP. Automated local auth/API
fixtures can verify signup routing and both creation paths without contacting
production. A real fresh-account email/OAuth round trip requires an isolated local
Supabase environment; fixture screenshots must be identified as such.
