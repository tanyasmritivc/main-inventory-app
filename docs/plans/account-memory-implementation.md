# Account memory implementation: approved stages 1-4

October 16, 2026. Branch `feat/account-memory-foundation-20261016`, based on
`5ca4e97`, approval proposal `d9fffec`. Existing assistant improvements on PR #88
are included as a dependency, not redeployed by this work.

## Implemented behavior

1. **Storage and authorization:** local migration 048 extends the two existing
   memory tables. Typed rows have confirmed timestamps, revisions and a foreign
   key to the actor's source receipt. Legacy rows remain unverified. Account
   preferences are independent of the inventory's effective owner. Inventory
   aliases remain actor-private and require current inventory access and a real
   Space in that inventory. Owner-only reads exclude integration-key identities;
   all writes go through a backend-only transactional function.
2. **Explicit lifecycle:** authenticated `/memory` GET/POST and `/memory/export`
   use server-derived actor identity. Opt-in defaults off. Supported account
   preferences are answer length and format; location aliases map to Space IDs.
   Expected revisions serialize cross-device edits. Request IDs plus body digests
   deduplicate retries and reject changed-body reuse. Forget removes preferences,
   aliases and legacy key/value memory, disables personalization and advances its
   generation. Replay cannot recreate deleted content. Receipts contain metadata,
   not conversation or preference payload history. DB triggers reject older
   automatic extractors, including a late write after forget.
3. **Retrieval and personalization:** both text agent paths and photo answers use
   the same allowlisted preference service. Model selection and FIND transport
   stay unchanged. Enum-based style instructions cannot override authorization.
   Deterministic answers preserve every fact, caveat and evidence row; bullets
   alter presentation, and detailed mode can add an evidence limitation. Brief
   deterministic answers are not arbitrarily truncated. Aliases resolve a read
   filter to a freshly checked Space ID, not an invented location. Missing targets
   ask the user to review the alias. Preference chat commands direct to Settings;
   chat does not falsely claim a permanent preference write.
4. **Controls and privacy:** web Settings and the actual mobile Settings route
   expose Memory with load/error/refresh, opt-in, preference editing, alias
   creation/replacement/deletion, legacy inspection, forget confirmation and
   export. Pending unknown writes retain their operation identity for retry;
   account/inventory changes reject stale responses. Export excludes revoked
   inventories, omits historical URLs and clearly flags bounded partial exports.
   Mobile export is selectable JSON with an explicit Copy action. Memory settings
   are fetched from the backend, not a device-only preference cache.

Automatic key/value extraction from question plus model answer is disabled. Old
historical-answer RAG is disabled. New query signals retain intent but omit raw
message content, and unknown signal inserts are not blindly retried. Redundant
raw Q&A copies stop; owned conversations/messages remain the user-visible chat
history. Existing historical copies are not purged without approval. Forget
personalization explicitly preserves chats and inventory records.

## Verified production configuration issue, not yet fixed live

A read-only transaction inspected table columns, policies and grants only. It
confirmed the legacy user_memory policy named Service role full access applies to
PUBLIC with true predicates, while anon and authenticated have CRUD privileges.
This is an unsafe authorization configuration. No anonymous user records were
retrieved and no live write/exploit was attempted. Actual customer exposure is
not established by this inspection.

Migration 048 removes those policies/grants, enables RLS explicitly and permits
only private owner reads through authenticated clients. It also closes the legacy
public policy path for conversation_history/query_logs while retaining existing
inventory restrictions. SQL fixtures reproduce the unsafe starting configuration
and verify denial afterward. **The migration is local/pushed only. The production
issue remains open until an approved migration is applied and checked.**

## Actual verification

| Check | Result | What it does not prove |
| --- | --- | --- |
| Full Python/API docs | 772 passed, 72 dependency deprecation warnings, six subtests | Live providers, production policies after migration, customer/device behavior |
| Full Jest | 302 passed in 41 suites | Browser visual/device acceptance or live synchronization |
| Full Flutter | 444 passed | Native camera, real email, physical-device or live two-account acceptance |
| Static checks | Flutter analysis clean, TypeScript no errors, changed-file ESLint no errors | Runtime infrastructure behavior |
| Standalone Postgres | Actual RLS/grants, owner versus another account, viewer-private aliases, revoked access, anonymous/integration denial, replay, stale revisions, cascade and old-extractor rejection pass | Deployed permissions, retention/backups, external APIs |
| Concurrent Postgres | Two commands using the same revision: one succeeds, one is rejected as stale | Network reliability under production load |
| Composed Postgres | Complete existing inventory/organization migration fixture plus 048 passes; aliases work with actual inventory triggers | Unknown deployed drift beyond inspected definitions |
| Web compile fallback | `node tools/build-memory-check.cjs` passes using synthetic configuration and substituted bundled fonts | A production-configured/visually exact website build |
| Normal local web build | Blocked: default Turbopack rejects the existing external node_modules symlink; webpack encounters existing Google Fonts fetch/loader errors | Do not label this a passing production build |

SQL runs used temporary containers with no network or production mounts, removed
in finally. Local client tools lacked a PostgreSQL server; no production database
was used for fixtures. The read-only live metadata inspection read no user rows.
A first full mobile run exposed an existing setting being shifted below the lazy
viewport; moving Memory below the scanning controls fixed it. A new photo test
needed its own synthetic client identity to avoid sharing the existing suite's
rate-limit bucket; the production limiter was not changed.

Reproduction commands:

```sh
# Repository root, existing backend environment activated
python -m pytest -q
# Separate empty disposable databases only
psql -X -v ON_ERROR_STOP=1 -f backend/tests/sql/api_key_rls.sql
psql -X -v ON_ERROR_STOP=1 -f backend/tests/sql/account_memory.sql
# frontend/
npm run test:ci -- --runInBand
npx tsc --noEmit
npx eslint src/components/site/memory-settings.tsx src/components/site/settings-client.tsx src/__tests__/memory-settings.test.tsx
node tools/build-memory-check.cjs
# mobile/
flutter analyze --no-pub
flutter test --no-pub --concurrency=1
```

The compile helper intentionally substitutes fonts and auth config. Never publish
its `.next` output. Use the ordinary build with actual public deployment config
and real font assets for a web release. No dependencies or secrets were changed.

## Files changed

- `.github/workflows/test.yml`: execute the new standalone SQL fixture in another DB.
- `backend/supabase/migrations/048_account_memory.sql`: typed extensions, receipts,
  private policies/grants, controlled promotion triggers and transactional RPC.
- `backend/tests/sql/api_key_rls.sql`: run the composed compatibility extension.
- `backend/tests/sql/account_memory_integration.sql`: existing schema/trigger compatibility.
- `backend/tests/sql/account_memory.sql`: standalone security/replay fixtures.
- `backend/app/schemas/memory.py`: strict bounded explicit command types.
- `backend/app/services/account_memory.py`: actor-owned lifecycle, consistent
  snapshots, authorized exports and safe database error/outcome mapping.
- `backend/app/api/routes/memory.py`, `backend/app/api/router.py`: thin account routes,
  outside inventory route aliasing.
- `backend/app/services/memory_context.py`: bounded explicit preference selection,
  fixed style instructions and honest preference-management replies.
- `backend/app/services/ai_agent.py`: integrate preferences into both text paths.
- `backend/app/api/routes/ai.py`: apply preferences to photo answers before persistence.
- `backend/app/services/inventory_questions.py`: resolve alias read filters by Space ID.
- `backend/app/services/ai_memory.py`: disable unconfirmed promotion/old-answer RAG,
  omit query content and stop redundant raw history duplication.
- `backend/tests/test_account_memory.py`: API, ownership, validation, failures and exports.
- `backend/tests/test_memory_context.py`: evidence-preserving personalization,
  provider paths, photo persistence, aliases, corrections and privacy behavior.
- `backend/tests/fixtures/account_memory_cases.json`: ten reusable synthetic cases.
- `backend/tests/test_agent_gateway.py`: require disabled legacy extraction rather
  than expecting an automatic model call.
- `frontend/src/components/site/memory-settings.tsx` and `.module.css`: Memory controls.
- `frontend/src/components/site/settings-client.tsx`: expose Memory in existing Settings.
- `frontend/src/__tests__/memory-settings.test.tsx`: client lifecycle, errors,
  confirmation, stale responses and exact retry identity.
- `frontend/tools/build-memory-check.cjs`: portable compile-only font/config fixtures.
- `mobile/lib/core/memory_controller.dart`: account/context-bound lifecycle and retry state.
- `mobile/lib/features/profile/memory_page.dart`: accessible, scrollable Memory controls.
- `mobile/lib/features/profile/profile_page.dart`: entry in the actual Settings page.
- `mobile/test/memory_controller_test.dart`, `mobile/test/memory_page_test.dart`:
  lifecycle, controls, offline/errors, account changes, large text/dark appearance.
- `mobile/pubspec.yaml`: beta build 1.0.8+70.
- `TESTING.md`, `.agents/ACTIVE_WORK.md`, `.agents/CURRENT_STATE.md`,
  `.agents/DECISIONS.md`, `.agents/ARCHITECTURE.md`: status, commands and durable boundaries.
- `docs/plans/account-memory-foundation.md`: approval/status pointer.
- `docs/plans/account-memory-implementation.md`: this report.

## Activation, rollback and device acceptance

No production migration, service restart, web publication or customer data change
was performed. TestFlight delivery is recorded in CURRENT_STATE.md and private
AppStore release receipts. A mobile upload does not install backend APIs.

After separate approval, inspect/preserve the self-hosted checkout, verify backup
recovery and schema metadata, apply 048 transactionally, then publish the reviewed
backend including its dependency on PR #88. Verify only with empty/disposable
accounts. A web release additionally requires a normal, correctly configured font
build, not the compile fixture. No Render/Vercel service is needed.

Migration 048 is additive except intentional permission/collector tightening.
It is applied once; a repeated migration fails transactionally without discarding
data. Keep schema, receipts and tightened permissions on runtime rollback. Do not
restore anonymous access or reenable the old extractor. Existing chat/inventory
contracts remain compatible; old optional background memory writes are intentionally
rejected. The source runtime disables them without affecting core requests.

Device/cross-client acceptance after activation:

1. With disposable A/B accounts, open web/iPhone Memory. Default is off. Enable A,
   choose bullets/detailed, restart app and open a new conversation. Verify the
   answer uses the preference and keeps saved facts, uncertainty and sources.
2. Sign into B on the same phone. A's preferences/legacy values must not appear.
   B may be a viewer in a shared inventory and still manage B's private preferences.
3. Save a location alias in inventory 1. Ask what is in it; verify actual Space/item
   records. The alias must not apply in inventory 2 or for another user.
4. Change preferences/alias on web, refresh phone and ask again. Race two edits
   from the same revision; one must require refresh. Revoke inventory access;
   Memory refresh must hide the inaccessible alias and return an error.
5. Use airplane mode and Retry. An unknown save retains the same operation ID;
   no success is claimed before confirmation. Sign out during a slow request and
   ensure no response or export is shown to the next account.
6. Export and verify only authorized account memory appears, with URLs omitted
   and partial export clearly flagged. Forget with confirmation; restart/refresh
   and verify personalization is off and content gone. Retry an old operation;
   it must not recreate the forgotten value. Chats/items remain intact.
7. On an iPhone check large text, VoiceOver, keyboard, light/dark, and returning
   to existing Capture, inventory and chat. Real provider behavior, cross-device
   persistence and native-device acceptance remain unverified until demonstrated.

## Deliberately deferred

Stages 5-6: new capture/document/event ingestion, broad relationship intelligence,
model-derived candidates, durable extraction queues, semantic/vector retrieval,
automatic learning/fine-tuning, cost/latency optimization, retention automation and
complete account deletion reconciliation. Existing evidence and capture flows are
preserved, not rebuilt. Receipt retention and historical raw-chat cleanup require
privacy decisions. No inferred sensitive traits, hidden preferences or new services.

## Source and beta delivery receipt

Implementation stages are pushed on PR #89, stacked on PR #88:

- `64067e1`: schema, RLS and transactional revisions.
- `3a457ec`: authenticated lifecycle APIs.
- `c0be848`: explicit retrieval/personalization and privacy behavior.
- `967ab48`: web/mobile controls, verification and build 70.

Apple acknowledged signed 1.0.8 (70), delivery
`a4f9218f-38c5-405f-bb60-3de7c938bd3d`. The signed archive, IPA, checksum,
build log and upload receipt are preserved in
`Documents/FindEZ/AppStore/1.0.8-build70`. No post-push/build test reruns, CI
polling or Apple processing wait per Tanya's instruction. Processing, group
availability and physical acceptance are unverified. No public App Store action.
No production migration, backend deployment or web publication occurred. Migration
048 and backend activation still require approval; the unsafe live memory grants
remain open. The normal web/font build must pass before web publication.
