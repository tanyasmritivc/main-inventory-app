# Notification policy implementation

Source: FindEZ AI Notifications Codex package, November 6, 2026.

Audit: Flutter uses direct APNs, an account-bound token lifecycle and authorized
item/review deep links. FastAPI uses self-hosted Supabase/PostgreSQL. Migration
081 already provides notification candidates, deduplication and a scheduled
personalization worker. The five-minute systemd timer currently runs retention
with push explicitly disabled. The production checkout contains unrelated work;
deployment must copy only reviewed files with before/after hashes.

The current feed contains CRUD activity. Existing phone-local restock alerts
bypass cross-device limits. Existing server caps use rolling days and depend on
Memory settings. These are not the supplied policy.

Minimal change: extend the existing candidate table; add independent notification
preferences and a delivery ledger that survives clearing/resetting an inbox.
Serialize delivery claims per account in PostgreSQL. Reuse the APNs transport,
timer, and authorized item/review destinations. Use recorded threshold crossings
and positive-to-zero quantity transitions; saved pending capture reviews can be
reminded after one hour and expire after 24 hours. The actor and explicit personal-threshold subscribers with current inventory access
are eligible; no inferred shortages or automatic team-wide audience.

Preferences: push requires opt-in; in-app and supported event categories default
on. Limits are 2/local day, 5/rolling week, 1 noncritical/24h, one review/week and
one review/task. Recorded zero is critical but never bypasses quiet hours. Default
quiet hours 21:00–08:00, fallback America/Los_Angeles; details default off. Preserve
explicit existing server push opt-ins. Remove launch-time OS permission requests.

Unsupported: no reliable scheduler/target contract for user-created reminders,
no durable failed-import retry target, recap destination or supported cleanup and
re-engagement subscription. Expose availability honestly and leave these off;
do not manufacture candidates. Team invitations remain actionable in-app;
routine team activity stays in activity history. Legacy direct pushes/local alerts
must not bypass the new policy when enabled.

Release gates: isolated PostgreSQL tests including concurrent claims, API/provider
tests, Flutter tests/analyzer, native preferences/inbox review. Production migration
requires explicit approval under AGENTS.md. Push activation and real-device
background/cold/sign-in tests remain separate acceptance gates. No production
data mutations or real-user notifications are authorized for automated QA.

## Implemented and verified

Independent server preferences, actionable inbox/read/dismiss/clear, policy queue,
atomic caps, quiet-hour/DST checks, private APNs payloads, bounded rejection retries
and transport-unknown handling are implemented behind
`FINDEZ_NOTIFICATION_POLICY_ENABLED`. The existing worker still also requires
`FINDEZ_PERSONALIZATION_PUSH_ENABLED`; production currently forces that off.
`FINDEZ_NOTIFICATION_FALLBACK_TIMEZONE` configures the safe default. Existing APNs
credential variable names and provider remain unchanged.

Personal phone thresholds import into account-owned `notification_stock_rules`
without changing item quantities or shared reorder fields. Existing server values
win over old device copies, and cleared rules retain a null tombstone. Imports
skip inaccessible items; explicit saves deny access. Item/account deletion cascades.
Import does not generate historical alerts; future recorded crossings do. Push
still requires its own opt-in. Old phone-local sends are retired in mobile193.
Migration of phone-only rules occurs when that inventory is next opened online.

Verified locally: 1,541 Python tests; isolated PostgreSQL assertions including
8-worker claims, quiet-hour/DST, caps, expiry, account/token changes, threshold
migration and Memory independence. Rehearsed against production function definitions
in a disposable local database; no production data was copied or changed.
The worker change preserves the deployed response-feedback retention call.

Review: [PR332](https://github.com/tanyasmritivc/main-inventory-app/pull/332),
runtime `7dc3531a1d54622fc261b04235b47b5e26c75c9b`. All five CI jobs passed in
[42249433722](https://github.com/tanyasmritivc/main-inventory-app/actions/runs/42249433722).
The live-function rehearsal passed all 57 SQL assertions. The local test database
was stopped after verification. Production schema, code and push gate remain unchanged.

## Activation and rollback

1. Obtain explicit production database approval. Preserve a schema/function backup
   and back up only the reviewed source files. Do not reset the dirty VM checkout.
2. Keep push dispatch off. Apply `20261106_notification_policy.sql` transactionally
   after081; verify private grants, columns and PostgREST reload. Deploy only the
   six new/modified Python files in this lane and enable the policy API flag.
3. Verify authenticated preferences/inbox/rule operations with a disposable account,
   plus anonymous denial. No real-user pushes during automated smoke checks.
4. With an explicitly designated test account/device, verify foreground/background,
   cold-start and signed-out deep links, denied permission and lock-screen privacy.
   Only then enable the existing dispatch timer's push gate.
5. Emergency rollback: disable dispatch immediately. Keep policy enforcement active
   (do not re-enable direct legacy pushes). Retain additive data; restore reviewed
   API code only after checking compatibility. Restoring old SQL queue functions
   requires a reviewed database rollback and must not replay old candidates.

Real-device APNs delivery and production activation remain pending. Recaps,
re-engagement, cleanup insights, user-scheduled reminders and failed-import retry
notifications remain unsupported/off. They are not represented as working features.

## November 6 activation verification

The user authorized production migration and API/inbox activation, with push still
disabled. The initial migration and six reviewed files are live; both health checks
passed and all136 unrelated Python files were preserved. Private backups are at
`/home/ubuntu/findez-notifications193-20261106/backup`.

Live acceptance found that PostgREST14.12 retries the `40001` code used for stale
notification preferences instead of returning promptly. The follow-up migration
`20261106_notification_conflicts.sql` changes only that revision guard to `PT409`;
the API maps it to the existing public409 refresh message. This matches the
[provider's documented retry issue](https://supabase.com/kb/troubleshooting/high-cpu-and-infinite-transaction-retries-when-using-custom-error-codes-in-rpc-functions-77326b).
Regression verification:1,543 Python tests and58 isolated SQL assertions, including
unchanged preferences after a stale write and idempotent follow-up migration replay.
Follow-up publication and live acceptance are in progress; no push sends enabled.
