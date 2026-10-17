# Notification and reliability follow-up, October 16

## Implemented

- Mobile bell with unread badge on workspace home, hierarchy/People/Activity,
  opened-inventory header, Tasks, Files and Account/settings. Existing inventory
  content and Spaces behavior are preserved. The bell remains usable when count
  retrieval fails; the real inbox supplies loading, error and Retry states.
- Existing authenticated APNs registration now reconnects after root launch/resume,
  with explicit permission setup in the inbox and a Send test notification action.
  Test success means Apple accepted a request, not proof that iOS displayed it.
  Foreground receipt refreshes badges. Cold-start taps wait for Dart readiness.
  Registration and pending alerts are cleared on signout; recipient identity gates
  taps. Account generation guards reject late results.
- Existing activity pushes recheck membership/inventory access, and the inbox
  filters revoked access. Pending invitation pushes recheck confirmed recipient,
  expiry/status and sender permission. Payloads contain no invitation secret code.
  APNs transport/429/5xx retries are bounded to three attempts; permanent rejection
  is not retried. The inbox is durable; there is no new durable APNs outbox, so a
  service restart or persistent provider outage can still lose a phone alert.
- Workspace creation used six UUID hex characters while the production constraint
  excludes 0 and 1. Migration 051 uses the existing 32-character alphabet and retries
  only code-constraint collisions transactionally. Tests now include the actual
  alphabet constraint, previously missing from the minimal fixture.
- Planning questions, including the user's FTC-season example, bypass literal
  item-name lookup. Suggestions are separated from verified ownership/requirements,
  and ambiguous goals prompt clarification. Provider selection is unchanged. No
  cross-inventory leak was established by the screenshot or code inspection; do
  not treat earlier assistant replies as evidence of current inventory facts.
- Web auth retains the existing single PKCE exchange and reset flow, adds safe
  recovery messages, removes spent codes from history, and supports resending
  confirmation with the existing invitation redirect. Live Auth reported missing
  one-time tokens, but why those particular tokens were unavailable is unproven.
  A fresh real email-link success is still unverified.

## Validation before push/build

- Full Python: 802 passed, six subtests passed; existing deprecation warnings.
- Full Flutter: 462 passed. Flutter analysis: no issues found.
- SQL: composed API/RLS suite through 052 passes, including 1,000 alphabet samples,
  40 workspace creations, real collision/exhaustion rollback, denied recipient
  lookup, unverified/expired/canceled/revoked invitation cases.
- Both 051 and 052 passed in a disposable network-isolated restored live schema.
- Auth focused web suite: 17 tests passed. Final full web suite: 329 passed.
- Normal production web build with real fonts/config passed before activation.
- Physical background notification receipt, device appearance, live model planning
  quality and fresh real email verification remain manual, not mocked completion.

Commands (from repository root; use an environment with requirements-dev installed):

```sh
python -m pytest -q
cd frontend
npm test -- --runInBand
npx tsc --noEmit
cd ../mobile
flutter analyze
flutter test
```

SQL entry point: `backend/tests/sql/api_key_rls.sql` in the existing disposable
Postgres harness described in TESTING.md. Do not run fixture tests on production.

## Publication and rollback

User separately approved 051 and 052. Private VM backup/rehearsal/activation receipts:
`/home/ubuntu/findez-workspace-codes-release-20261016` and
`/home/ubuntu/findez-notifications-release-20261016`. Reviewed sources match live;
87 unrelated backend files match the latter predeployment archive. Public health
200; notification feed/test endpoints reject missing sessions with 401. No customer
workspace, account or invitation was created, deleted or pushed for QA.

Web is `/home/ubuntu/findez-web-releases/web-auth-link-recovery-20261016/frontend`.
Its normal production build, preservation and activation receipts remain private.
Restore only reviewed runtime files or prior web service override if needed.
Retain 050 protections, 051 valid code generation and additive service-only 052;
rolling back 051 to the invalid generator restores the intermittent bug. Applying
051/052 changes no records; there is no data rollback needed for installation.

TestFlight 72 was acknowledged, delivery c3658bef-a8c9-4546-afef-09006dc96c1b.
Apple acknowledged TestFlight 1.0.8 (73), runtime d212f95, delivery cc0229a0-325c-42f4-90e2-04deec6a302d. Processing and tester availability remain unverified; no polling. Actual iPhone background delivery and fresh email-link success remain manual acceptance.
No App Store release or processing/group availability claim.

## Real iPhone acceptance

1. Install beta 73. Sign in, open the bell from Personal, an organization and an
   inventory; confirm the same authorized inbox and correct unread count.
2. Tap Enable phone alerts and Allow. Send test notification, check iOS Notification
   Center and sound. Deny permission on a separate attempt and test Open Settings.
3. Background the app. Have an authorized teammate generate existing subscribed
   activity or send an invitation. Confirm the real phone alert, tap it and verify
   the correct accessible place/inbox. Force quit and repeat a cold-start tap.
4. Revoke access before opening an alert; no private activity or inventory opens.
   Sign out and switch accounts; previous alerts/counts must not leak.
5. Test airplane mode/Retry, launch/resume and read-all badge clearing. iOS Focus,
   notification settings and Apple delivery can affect visible presentation.
6. With a disposable account, request a fresh confirmation/reset email, open only
   the newest link in the requesting browser and complete the intended action.
7. Create several disposable workspaces, verify membership and refresh web/mobile.
   Ask the FTC planning example in two inventories: no literal no-match or invented
   ownership/official requirements. Keep dashboard and Spaces acceptance unchanged.

## Changed files

- `TESTING.md`
- `docs/plans/notification-reliability.md`
- `.agents/ACTIVE_WORK.md`
- `.agents/CURRENT_STATE.md`
- `.agents/DECISIONS.md`
- `backend/app/api/routes/collaboration.py`
- `backend/app/api/routes/notifications.py`
- `backend/app/services/access_invitations.py`
- `backend/app/services/ai_agent.py`
- `backend/app/services/inventory_questions.py`
- `backend/app/services/push_notifications.py`
- `backend/supabase/migrations/051_workspace_creation_codes.sql`
- `backend/supabase/migrations/052_invitation_push_target.sql`
- `backend/tests/sql/api_key_rls.sql`
- `backend/tests/sql/invitation_push_target.sql`
- `backend/tests/sql/organization_access.sql`
- `backend/tests/sql/workspace_creation_codes.sql`
- `backend/tests/test_collaboration_access.py`
- `backend/tests/test_notification_inbox.py`
- `backend/tests/test_physical_memory_questions.py`
- `backend/tests/test_team_invitation_notifications.py`
- `docs/plans/deletion-completion.md`
- `frontend/src/__tests__/auth-callback.test.ts`
- `frontend/src/__tests__/auth-signup.test.tsx`
- `frontend/src/app/auth/callback/page.tsx`
- `frontend/src/components/site/auth-callback-client.tsx`
- `frontend/src/components/site/auth-form.tsx`
- `frontend/src/lib/auth-callback.ts`
- `mobile/ios/Runner/AppDelegate.swift`
- `mobile/lib/core/api_client.dart`
- `mobile/lib/core/push_notifications.dart`
- `mobile/lib/features/notifications/notification_bell.dart`
- `mobile/lib/features/notifications/notifications_page.dart`
- `mobile/lib/features/profile/settings_page.dart`
- `mobile/lib/features/shell/main_shell.dart`
- `mobile/lib/features/teams/team_board_page.dart`
- `mobile/lib/features/teams/team_documents_page.dart`
- `mobile/lib/features/workspaces/hierarchy_page.dart`
- `mobile/lib/features/workspaces/inventory_context_host.dart`
- `mobile/lib/features/workspaces/workspace_home.dart`
- `mobile/pubspec.yaml`
- `mobile/test/notification_bell_test.dart`
- `mobile/test/notifications_page_test.dart`
- `mobile/test/push_notifications_test.dart`
