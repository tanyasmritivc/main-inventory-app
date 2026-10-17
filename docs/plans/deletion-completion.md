# Deletion completion and account navigation, October 16

Branch: `feat/hierarchy-navigation-20261016`, PR #90. Workspace-delete source
`5d5f530` is included in this release, stacked on runtime `9bec964` (beta71).
The final implementation commit and Apple delivery receipt are recorded below
when available. Production is self hosted.

## Behavior

- Workspace owners now have Delete workspace on mobile home, settings and web
  directory/header menus. Existing owner-only DELETE /teams/{id} is reused.
  Exact-name confirmation describes removal of collaboration, tasks and files;
  physical inventories are retained in Personal. Confirmed success refreshes
  directories, clears mobile caches and resets the active workspace to Personal.
- Inventory deletion keeps the empty-only default. An unchecked, explicit
  "also delete everything" option sends delete_contents:true. Current owner/admin
  and exact name are checked in the API and again inside a locking SQL operation.
  Unknown dependencies and cross-inventory references fail closed. Items, Spaces,
  documents, review records and private inventory conversation/memory history
  follow their existing inventory foreign-key cascades. No dashboard or Spaces
  presentation was changed.
- A private durable manifest captures file references before SQL deletes them.
  The backend retries pending cleanup on startup and every minute. It validates
  owner paths and scans existing references before removing Storage objects.
  Files referenced by surviving records are retained. Unknown or truncated
  reference scans leave cleanup pending, rather than risking shared files.
- Account deletion now prepares a private manifest, checks organization/workspace
  ownership and shared legacy records, and calls Auth deletion before file or
  legacy row cleanup. Failed Auth removal leaves existing content intact.
  Success is accepted only with an explicit server success:true receipt. All
  three mobile entry points and the web use the same strict client behavior.
  Requests cannot sign out a different account after a slow response.
- Organizations and workspaces owned by the user must be deleted or transferred
  before deleting their account. Records created in another owner's inventory
  require ownership review. These blockers return actionable messages.
- Another inventory's borrower loan history survives account removal with a null
  borrower UUID. A restrictive Storage policy denies private-object access to
  unexpired JWTs whose Auth identity no longer exists. Security audit receipts
  and shared records are distinct from private inventory content, and existing
  backup retention is unchanged. This is not a claim of universal erasure.
- Web account navigation uses a compact avatar menu and separate authenticated
  pages for Profile, Appearance, AI memory, Plans, Developer, Help and Account.
  Each category renders only its own existing controls. /settings stays a Profile
  entry point and /settings/api-keys is preserved. Account navigation is expanded
  on desktop without changing the user's normal inventory sidebar preference.
  Scoped Inter typography, bordered cards, aligned compact rows and padded theme
  choices apply to account pages/menu only. No new profile fields or pretend
  settings were added.

## Actual verification before push/build

| Check | Result | Scope and limit |
| --- | --- | --- |
| Backend pytest | 786 passed, six subtests; 212 warnings | Includes route authorization and durable cleanup unit/integration cases; provider/customer deletion not exercised live. |
| Web Jest | 322 passed, 45 suites | Actual Edge handler executed with injected external service boundaries, strict client receipts, category separation, existing navigation/profile flows. |
| Flutter | All 457 tests passed | Strict account success/failure, last place, owner/nonowner delete controls, explicit purge body, refresh and existing mobile suite. |
| Static analysis | Flutter analyze clean; TypeScript and changed-file ESLint passed | Source checks, not physical device acceptance. |
| Composed PostgreSQL 17 tests | Passed through 050 | Synthetic owner/outsider/stale name, content/history cascades, other inventory retention, borrower history, failed Auth rollback, private grants and deleted identity guard. |
| Restored-schema rehearsal | Passed | Applied 050 to an isolated restored snapshot before touching live schema. No customer rows printed. |
| Real web production builds | Passed | Normal webpack, production configuration and real fonts; no fixture build published. |
| Rollout | Passed | Public/backend health, missing auth and invalid Edge JWT rejected, seven category routes protected, exact reviewed hashes and 89 unrelated backend files preserved. |

The initial final-category test run had one ambiguous test query for Account
(breadcrumb and sidebar). The query was scoped to navigation; the final complete
322-test run passed. No application behavior was weakened to satisfy the test.

Reproducible commands from this checkout (existing installed Python environment):

```sh
/Users/tanyasmritivictorcharles/dev/main-inventory-app/backend/venv/bin/python -m pytest -q
cd frontend
npm test -- --runInBand
npx tsc --noEmit
npx eslint src/components/site/app-shell.tsx src/components/site/account-menu.tsx src/components/site/settings-client.tsx src/lib/settings-sections.ts 'src/app/(workspace)/settings/[section]/page.tsx'
npm run build -- --webpack
cd ../mobile
flutter analyze --no-pub
flutter test --no-pub --concurrency=1
```

For SQL use backend/tests/sql/api_key_rls.sql only in an empty disposable local
PostgreSQL instance, following TESTING.md. It now composes account_deletion.sql
and inventory_content_delete.sql. Never run that synthetic test bootstrap on
production. Private one-off rehearsal/rollout scripts and results are retained
under the release paths below.

## Deployment

Tanya explicitly approved migration 050 and publishing the fixes. It is applied;
backend systemd findez and mounted self-hosted delete-user Edge source are updated.
Private backup, rehearsal, source hashes, migration and rollout receipts:
`/home/ubuntu/findez-deletion-release-20261016`.
Mounted Edge source: `/home/ubuntu/supabase/volumes/functions/delete-user/index.ts`.
The canonical backend/ and root supabase/ copies are identical in source.

Current web: `/home/ubuntu/findez-web-releases/web-account-pages-20261016/frontend`.
Normal build, preserved-source manifest, prior service override, auth and
activation receipts are in its parent. Intermediate workspace-delete and
account-layout releases remain available for rollback. Homepage and unrelated
server work are preserved. The migration itself deleted no customer records;
no customer deletion was performed for QA.

Rollback: restore reviewed runtime files from backend-before.tar.gz and
edge-before.ts, or switch the web service override to its saved prior release.
Keep 050 schema/ACL/Storage safeguards and durable manifests for cleanup. Do not
reintroduce pre-Auth destructive account cleanup or blindly restore NOT NULL on
checkout borrower IDs, since deleted borrowers can now be null. Restoring deleted
customer records would require a separate explicit recovery decision.

TestFlight 1.0.8 (72) is being prepared with private configuration and existing
signing. Apple acknowledgement, not processing or tester availability, is the
requested stopping point. Public App Store submission is unchanged.

## Remaining acceptance

1. With a disposable account and workspace, delete an empty workspace; confirm
   inventories remain in Personal, menus refresh and restart opens Personal.
2. In a disposable inventory containing an item, Space, photo, document and
   conversation, leave the checkbox off and confirm deletion is blocked.
3. Select the checkbox, type the name and confirm. Refresh both clients and
   history; records should be gone while a neighboring inventory is intact.
   Confirm file cleanup completes or visibly remains pending after service failure.
4. Verify editor/viewer/outsider/revoked membership cannot purge or delete workspace.
5. Owned organizations/workspaces block account deletion before content removal.
   Remove/transfer them deliberately, then delete the disposable account. Confirm
   signout, cold-start denial and private Storage denial with the old token.
6. Test real iPhone navigation, larger text, dark/light, slow requests and retry.
   Real customer deletion, cross-client mutation and final signed binary physical
   acceptance have not been performed by the agent.
7. Review each web settings category, browser Back, reload and menu keyboard use.
   The initial signed-in account layout/menu was inspected live. The Safari
   session ended before final category review; user is signing back in.

## Files changed in this follow-up

- `backend/app/api/routes/inventory_workspaces.py`
- `backend/app/main.py`
- `backend/app/services/deletion_cleanup.py`
- `backend/supabase/functions/delete-user/index.ts`
- `backend/supabase/migrations/050_inventory_content_delete.sql`
- `backend/tests/sql/account_deletion.sql`
- `backend/tests/sql/api_key_rls.sql`
- `backend/tests/sql/inventory_content_delete.sql`
- `backend/tests/test_deletion_cleanup.py`
- `backend/tests/test_inventory_delete.py`
- `docs/plans/hierarchy-navigation.md`
- `frontend/src/__tests__/account-deletion-service.test.ts`
- `frontend/src/__tests__/account-menu.test.tsx`
- `frontend/src/__tests__/collaboration-access.test.tsx`
- `frontend/src/__tests__/inventory-management-actions.test.tsx`
- `frontend/src/__tests__/inventory-navigation.test.tsx`
- `frontend/src/__tests__/workspace-management-actions.test.tsx`
- `frontend/src/__tests__/workspace-profile.test.tsx`
- `frontend/src/app/(workspace)/settings/[section]/page.tsx`
- `frontend/src/app/(workspace)/settings/page.tsx`
- `frontend/src/components/site/account-layout.module.css`
- `frontend/src/components/site/account-menu.tsx`
- `frontend/src/components/site/app-shell.tsx`
- `frontend/src/components/site/inventory-management-actions.tsx`
- `frontend/src/components/site/organization-directory.tsx`
- `frontend/src/components/site/settings-client.tsx`
- `frontend/src/components/site/workspace-directory.tsx`
- `frontend/src/components/site/workspace-management-actions.tsx`
- `frontend/src/lib/delete-account.ts`
- `frontend/src/lib/settings-sections.ts`
- `mobile/lib/core/account_deletion.dart`
- `mobile/lib/features/profile/profile_page.dart`
- `mobile/lib/features/profile/settings_page.dart`
- `mobile/lib/features/shell/main_shell.dart`
- `mobile/lib/features/workspaces/hierarchy_page.dart`
- `mobile/lib/features/workspaces/inventory_actions.dart`
- `mobile/lib/features/workspaces/workspace_actions.dart`
- `mobile/lib/features/workspaces/workspace_home.dart`
- `mobile/pubspec.yaml`
- `mobile/test/account_deletion_test.dart`
- `mobile/test/inventory_directory_actions_test.dart`
- `mobile/test/workspace_deletion_test.dart`
- `mobile/test/workspace_home_test.dart`
- `supabase/functions/delete-user/index.ts`
