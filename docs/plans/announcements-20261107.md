# Announcement system implementation

## Audit and plan

The Flutter authenticated root currently opens PlansWelcomeGate before retained
onboarding recovery and before the organization shell is ready. It persists a
version in auth metadata with a local retry receipt. There is no campaign queue.
The web Founding Access UI is a separate, locally remembered implementation and
is outside this mobile design task. Native Settings uses a UIKit table bridge.
The shell owns a successfully loaded profile and directory; contextual workflows
use routes and native presentations. Chat activity must also gate announcements.

The backend owns plan enforcement in services/limits.py. Pilot mode removes quotas
and supplies the label Free pre-launch access. Future marketing quotas differ from
runtime limits. The user approved verified policy/allowances instead of the
prototype's absolute retention promise and paid-only spreadsheet restriction.
No general mobile analytics pipeline was found. Store only delivery receipts.

Implementation order:
1. Add private campaign configuration and account-scoped delivery receipts, with
   atomic selection, priority, seven-day and thirty-day caps, and legacy suppression.
2. Add authenticated routes for current access, claim, and idempotent receipts.
   Keep entitlements and authentication unchanged. Seed drafts only.
3. Implement the supplied themed sheets, plan row, banner and product art.
4. Replace the early auth popup with a shell-ready, idle-only gate. Keep one
   delivery per account session, defer active workflows, and invalidate on logout.
5. Test selection/RLS/concurrency, account changes, dismissal, layout, both themes,
   accessibility and reduced motion. Commit and push for review.

No production migration, campaign publishing, web deployment or TestFlight upload
is authorized by these packages. Activation requires a separate final approval.

## Persistence and frequency

`20261107_announcements.sql` adds two independent tables. Campaigns are private
server configuration. JWT users can read only their own delivery records, cannot
write them directly, and integration keys cannot read personal receipts. The
backend binds all RPCs to the authenticated actor. A per-user transaction lock
serializes claims across devices. A successful claim consumes the seven-day cap
and the session before returning the payload. This is intentionally conservative:
a crash or lost response can skip a campaign, but cannot replay it on another
device. `shown_at` is recorded separately when presentation starts. Dismissal,
acknowledgement and click timestamps are idempotent.

The mobile account-bound outbox retries receipt writes on the next eligible
session. It never determines eligibility. A dismissal with an unavailable network
is visibly described as pending synchronization. Claim failures are quiet reads
and never block the app. Local legacy intro dismissals and server metadata version
1 suppress only `founders-access-v1`. They do not consume a new frequency window.

The capability revision is 1, not a claimed app version. Campaigns can require a
higher revision when their CTA needs a newer implementation. This version supports
only dismiss and the existing camera/Auto Extract action. The banner is a tested
reusable component, deliberately not an extra persistent promotion in the app.
No unrelated notifications, inventory behavior, plan enforcement or web UI changed.

## Publishing and disabling after approval

Apply the migration before deploying the backend and before distributing the new
mobile client. Check the actual deployed backend tree first and overlay this
feature's additive files and router registration; this mobile lane's historical
backend baseline must never replace the whole production checkout.

All three seeds are drafts. Do not enable all three together. The reviewed welcome
can be rolled out by an authorized operator using the existing database admin
process, for example setting status to published, starts_at to now(), audience to
all, and rollout_percent to 10 for `founders-access-v1`. Increase the percentage
only after verifying the new mobile build. Set status to archived to stop new
claims. Existing delivery receipts are retained; never delete receipts to force a
repeat. If genuinely new content warrants another campaign, create a new stable
ID and leave the old ID unchanged. Validate both themes, copy, schedule, platform,
capability revision and actual CTA availability before publishing.

`auto-extract-v1` may only be published for the mobile platform with Auto Extract
available. `pricing-note-v1` remains a preview draft unless a real pricing notice
is approved. Founders milestones require real approved content and are not seeded.
Their design key is message with a Got it action. There is no new admin dashboard.

The verified current label is Free pre-launch access. During pilot mode, the
Now and Free plan columns both show actual unrestricted access. Outside pilot,
Limited follows the runtime limit configuration, including item/import caps.
No future paid-only spreadsheet policy or absolute data-retention promise is used.

## Validation and review

The server and mobile tests use synthetic accounts and sample payloads. No live
accounts or production inventory were modified.

- Backend and existing API documentation regression suite: 840 passed. Existing
  dependency deprecation warnings remain (213); no new dependencies were added.
- Disposable PostgreSQL 17 fixture: 24 assertions passed, covering eligibility,
  priority, schedule/expiry, platform, capability, audience, rollout, frequency,
  legacy suppression, idempotence and row-level access.
- Concurrent delivery test: 24 simultaneous claims yielded exactly one campaign.
- Focused announcement suite: 21 passed, including late claim deferral, account
  disposal, asynchronous capture CTA, outbox retry and all dismissal paths.
- Final iOS simulator preview suite: 14 passed, covering all five supplied
  presentation variants in both themes and narrow/wide layouts at 1.0/2.6 text
  scale with reduced motion. Flutter static analysis is clean.
- Complete mobile regression suite: 1,321 passed, one existing skip.
  `flutter test --no-pub --concurrency=2` exited successfully.
- Native Settings customization compiled in the iOS simulator. The supplied
  design variants have retained native simulator captures in
  `docs/announcements/evidence/`. Those captures use a synthetic preview host,
  not a production sign-in or the real UIKit Settings screen.
- Physical-device VoiceOver, reinstall on two real devices, and end-to-end
  production delivery remain acceptance checks after an approved staging/release
  rollout. The server and widget tests cover their persistence/lifecycle contracts.

An incomplete access response now produces a retry state rather than crashing
Settings or displaying invented allowances. Large text and narrow widths use a
stacked plan card and labeled comparison rows so the plan name is readable.
Normal-size layouts retain the supplied comparison table. The camera CTA opens
without waiting for receipt network delivery; its dismissal still enters the
durable outbox. Native rendering uses the existing system font and logo rather
than embedding the prototype HTML.

### Changed areas

- Backend: additive announcement service, JWT routes, router registration,
  migration and focused Python/PostgreSQL/concurrency tests.
- Mobile: announcement controller, safe presentation gate, supplied themed UI,
  current-plan entry in Flutter and native Settings, authenticated host wiring,
  and a read-only chat-idle callback. The obsolete early PlansWelcomeGate is removed.
- Regression tests: legacy-introduction core coverage retained; profile/native
  settings expectations updated; announcement behavior and native previews added.
- Documentation: original packages, audit, activation instructions, review
  screenshots and repository state/decision notes.
- No web, auth protocol, plan enforcement, inventory storage or dependency changes.

### Review on a simulator or device

1. Run `flutter test integration_test/announcements_preview_test.dart -d <device>`
   from `mobile/` for the isolated dark/light reference previews and native layouts.
2. For end-to-end testing, apply the migration only to an approved test database,
   deploy the additive backend feature there, and publish a test campaign for
   synthetic users. Existing production campaigns remain drafts.
3. Confirm the home has loaded before the announcement appears. Dismiss using
   Got it, X, backdrop and pull handle. Reopen the plan manually from Settings.
4. Start camera/import/edit/chat before the idle window and while a claim is in
   flight. No announcement should interrupt the workflow. Sign out while it is
   visible; it must disappear and never carry account data to the next login.
5. Repeat with another device and with receipt writes offline. The claim remains
   unique, and queued dismissal receipts retry on the next eligible session.

### Screenshots

- [Access, dark](../announcements/evidence/announcement-dark-access.png)
- [Access, light](../announcements/evidence/announcement-light-access.png)
- [Pricing, dark](../announcements/evidence/announcement-dark-pricing.png)
- [Pricing, light](../announcements/evidence/announcement-light-pricing.png)
- [Product update, dark](../announcements/evidence/announcement-dark-whats_new.png)
- [Product update, light](../announcements/evidence/announcement-light-whats_new.png)
- [Banner, dark](../announcements/evidence/announcement-dark-banner.png)
- [Banner, light](../announcements/evidence/announcement-light-banner.png)
- [Plan row, dark](../announcements/evidence/announcement-dark-plan.png)
- [Plan row, light](../announcements/evidence/announcement-light-plan.png)
- [320pt](../announcements/evidence/announcement-native-320-1.0.png)
- [320pt, large text](../announcements/evidence/announcement-native-320-2.6.png)
- [430pt](../announcements/evidence/announcement-native-430-1.0.png)
- [430pt, large text](../announcements/evidence/announcement-native-430-2.6.png)

### Scope check

`git diff --cached --name-only` before the implementation commit:

```text
.agents/ACTIVE_WORK.md
.agents/CURRENT_STATE.md
.agents/DECISIONS.md
backend/app/api/router.py
backend/app/api/routes/announcements.py
backend/app/services/announcements.py
backend/supabase/migrations/20261107_announcements.sql
backend/tests/sql/announcement_concurrency.py
backend/tests/sql/announcements.sql
backend/tests/test_announcements.py
docs/announcements/design/findez-announcements-design-codex/CODEX_PROMPT.md
docs/announcements/design/findez-announcements-design-codex/findez-announcements.html
docs/announcements/design/findez-announcements-design-codex/screens/dark/1-founders.png
docs/announcements/design/findez-announcements-design-codex/screens/dark/2-pricing.png
docs/announcements/design/findez-announcements-design-codex/screens/dark/3-whats-new.png
docs/announcements/design/findez-announcements-design-codex/screens/dark/4-banner.png
docs/announcements/design/findez-announcements-design-codex/screens/dark/5-banner-opens-plan.png
docs/announcements/design/findez-announcements-design-codex/screens/dark/6-your-plan-row.png
docs/announcements/design/findez-announcements-design-codex/screens/light/1-founders.png
docs/announcements/design/findez-announcements-design-codex/screens/light/2-pricing.png
docs/announcements/design/findez-announcements-design-codex/screens/light/3-whats-new.png
docs/announcements/design/findez-announcements-design-codex/screens/light/4-banner.png
docs/announcements/design/findez-announcements-design-codex/screens/light/5-banner-opens-plan.png
docs/announcements/design/findez-announcements-design-codex/screens/light/6-your-plan-row.png
docs/announcements/evidence/announcement-dark-access.png
docs/announcements/evidence/announcement-dark-banner.png
docs/announcements/evidence/announcement-dark-plan.png
docs/announcements/evidence/announcement-dark-pricing.png
docs/announcements/evidence/announcement-dark-whats_new.png
docs/announcements/evidence/announcement-light-access.png
docs/announcements/evidence/announcement-light-banner.png
docs/announcements/evidence/announcement-light-plan.png
docs/announcements/evidence/announcement-light-pricing.png
docs/announcements/evidence/announcement-light-whats_new.png
docs/announcements/evidence/announcement-native-320-1.0.png
docs/announcements/evidence/announcement-native-320-2.6.png
docs/announcements/evidence/announcement-native-430-1.0.png
docs/announcements/evidence/announcement-native-430-2.6.png
docs/announcements/system/IMPLEMENTATION_SPEC.md
docs/announcements/system/QA_CHECKLIST.md
docs/announcements/system/README.md
docs/plans/announcements-20261107.md
mobile/integration_test/announcements_preview_test.dart
mobile/integration_test/plans_preview_test.dart
mobile/ios/Runner/NativePresentation.swift
mobile/lib/features/announcements/announcement_controller.dart
mobile/lib/features/announcements/announcement_host.dart
mobile/lib/features/announcements/announcement_widgets.dart
mobile/lib/features/chat/chat_page.dart
mobile/lib/features/profile/native_account_menu.dart
mobile/lib/features/profile/plans_welcome.dart
mobile/lib/features/profile/profile_page.dart
mobile/lib/features/world/world_shell.dart
mobile/lib/main.dart
mobile/test/announcements_test.dart
mobile/test/native_account_menu_test.dart
mobile/test/plan_introduction_test.dart
mobile/test/profile_navigation_test.dart
mobile/test/support/announcement_fixture.dart
```
