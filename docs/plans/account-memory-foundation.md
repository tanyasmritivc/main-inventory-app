# Account-specific memory foundation: discovery and proposal

Date: October 16, 2026. Review branch:
`feat/account-memory-foundation-20261016`, based on `5ca4e97`.
Source specification: Tanya's `AI MEMORY - PERSONALISING EACH ACCOUNT` document.
This is the required first architecture review and approval proposal. No memory
application code, SQL migration, infrastructure or production data has changed.

## Current architecture and authoritative sources

Production is self hosted. Repository context describes Ubuntu/OpenStack,
Caddy -> nginx, systemd `findez`/`findez-web`, and Docker/Kong hosting Supabase
Auth, Postgres, PostgREST and Storage (`.agents/ARCHITECTURE.md`, Infrastructure;
`CLAUDE.md`, Current system boundaries). These are documented deployment facts,
not newly verified live infrastructure. Render, Vercel and cloud Supabase are not
production dependencies. No new host, vector database or worker service is proposed.

| Layer | Existing implementation and evidence | Important boundary |
| --- | --- | --- |
| Authentication | `backend/app/core/auth.py::get_current_user`; Next.js `lib/supabase/{server,browser}.ts` and `use-api-session.ts`; Flutter `main.dart` and `core/api_client.dart` | Supabase sessions, backend JWT verification including self-hosted HS256 and JWKS; server-derived identity |
| Collaboration | `api/routes/inventory_workspaces.py::inventory_session`, migrations 043-047, `services/inventory_scope.py` and `resource_access.py` | Optional organization -> existing Team/workspace -> inventory; physical locations are a separate hierarchy. Effective inventory owner differs from the signed-in actor |
| Identity/setup | `api/routes/profile.py`, `onboarding.py`, migration 041, Flutter `profile_store.dart` | Explicit profile and voluntary setup answers already exist. Neither proves learned preferences or approval to infer sensitive traits |
| Durable personal memory | `services/ai_memory.py::fetch_user_memory`, `extract_and_save_memory`; baseline `user_memory` | Key/value upserts. In inventory context, InventoryClient aliases this to `inventory_user_memory` and enforces actor + inventory |
| Session memory | `ai_agent.py::_load_session`, `_save_session`, `_get_state`; baseline `conversation_sessions`, migration 043 `inventory_conversation_sessions` | Durable bounded recent state plus process-local cache. Not a substitute for independent named conversations or current item facts |
| Conversation/evidence | `api/routes/conversations.py`, `ai.py`, migration 009 and 037; `messages.answer_context` | Owned conversations, saved answer evidence and photos. Last task retains validated scope across SSE/deferred work |
| Grounded reads/actions | `inventory_questions.py`, `assistant_tool_safety.py`, `items_repo.py::update_item_from_chat` | Last task adds selected-inventory record retrieval, fresh conversation references and guarded conditional edits. Source is pushed on PR #88; backend not deployed by the beta upload |
| Physical memory | Existing items, spaces, bins, `app_physical_locations`, documents/item links, project kits/reservations, `item_events`, `app_access_audit` | Reuse relational records. Migration 044 records before/after quantity and recorded location; a database move is not physical confirmation |
| FIND/capture | `find_pipeline.py::map_find_result`, `review_queue.py`, `capture_previews.py`, migrations 036/039 | Source images/available crops, public scan evidence and durable uncertain reviews exist. Transactional review resolution is reusable. Masks/full geometry and a training correction corpus are not established |
| Documents | `documents_repo.py`, `document_text_extractor.py`, migration 038 | Item links and private signed access exist; text extraction supports PDFs/text with a character ceiling. New assistant reads metadata, not full-content semantic retrieval |
| Analytics/background work | `ai_memory.py::log_query`, `save_conversation`; `ai.py` uses `asyncio.create_task`/BackgroundTasks | Query text and duplicate Q&A storage; no durable memory processing receipt, retry lease or dead-letter workflow found in these paths |
| Search/providers | Relational queries, Postgres history full-text query, private `AgentGatewayClient` | No pgvector/embedding store or Redis/Celery memory worker found in application code, migrations or backend requirements. Sole runtime is the existing OpenAI-compatible gateway, not independent Claude/OpenAI SDK adapters |
| Client consistency | Web `assist-client.tsx` and `ask-stream.ts`; Flutter `chat_page.dart` and immutable inventory API sessions | Same authenticated backend and conversation contracts. Account switches retire client state. Actual two-device consistency still requires acceptance tests |
| User control/deletion | Both Settings clients call `delete-user`; two different source copies exist under `supabase/functions/` and `backend/supabase/functions/` | No durable-memory inspect/edit/forget/export UI or endpoints found. Deletion implementations differ and are not a proven complete account erasure path |

## Concrete gaps and risks

1. **Unvalidated memory promotion:** `extract_and_save_memory` gives the gateway
   both question and assistant answer, accepts arbitrary scalar keys and upserts
   them immediately. The extraction prompt asks for explicit facts, but code does
   not prove the source was explicit, useful or correct. An answer can reinforce
   its own invented fact. No candidate/confirmation/provenance/conflict lifecycle.
2. **Account versus inventory:** existing memory follows the selected inventory,
   not an independently retrievable account preference layer. `inventory_session`
   changes `user.user_id` to the inventory owner while preserving the actor;
   InventoryClient privately substitutes actor IDs. New account preferences must
   derive the actor explicitly and must not accidentally use the shared owner or
   the alias intended for inventory memory.
3. **Unbounded/stale context:** `fetch_user_memory` reads all keys, and
   `fetch_similar_history` falls back to latest Q&A when search fails. The agent
   bounds supplemental text, but selection lacks typed relevance/freshness.
   Synchronous agent execution does not receive the same supplemental context
   package as SSE. Deterministic answer paths return before personalization.
4. **No idempotent processing:** memory upsert is last-writer-wins, without
   revision checks, source ID or correction precedence. Fire-and-forget extraction
   can disappear at restart; history/query ReadError retries can duplicate rows.
5. **No meaningful control/retention:** no memory list/edit/forget/export flow;
   old extracted keys have no consent or confidence metadata. Raw query/Q&A
   copies lack an explicit retention policy in this implementation.
6. **RLS must be verified and corrected before activation:** baseline lines
   997/1004/1011 declare policies named Service role full access without a
   `TO service_role` clause, using true predicates. Policy names do not restrict
   roles. Effective live table grants and policies are unverified. Migration 044
   adds restrictive inventory policies for history/logs, not legacy user_memory.
   Migration 043 denies direct anon/authenticated access to inventory memory.
   Do not declare a live exploit or live isolation from baseline SQL alone.
7. **Deletion is not atomic:** the two delete-user sources differ; the longer
   version deletes storage/rows sequentially before auth removal. Query log FK
   uses SET NULL in the baseline, while memory/history use cascade. Shared
   ownership constraints, deployed function identity and complete erasure need
   dedicated verification. Do not extend deletion with an unreviewed cascade.
8. **Evidence is fragmented:** capture reviews preserve recognition evidence;
   item movement audit exists separately. Ordinary item save and review resolution
   are not evidence of model retraining. Compatibility, universal projects and
   purchases cannot be invented from notes.

## Proposed minimum data model

Reuse the two memory tables rather than introduce a second memory database.
Numbers and names below are proposals until the exact deployed schema is checked.

- Extend `user_memory` for account-level settings and allowlisted explicit
  preferences. Preserve legacy key/value columns for compatibility. Add a typed
  JSON payload, kind/schema version, origin, lifecycle state, revision, source
  reference, confirmed/updated/expiry timestamps and optional confidence for
  actual model-inferred candidates. Do not manufacture confidence for user input.
- Extend `inventory_user_memory` with the same typed envelope for account-private,
  inventory-specific terminology. Keep its existing composite ownership key.
  Location aliases reference an existing authorized Space/location ID, rather
  than making free text authoritative or sharing an alias across inventories.
- Add one bounded `memory_events` table for source identity, processing receipts
  and preference version history. Include actor, optional inventory, correlation
  ID, event/pipeline version, status, attempts, lease/retry time, memory revision
  and permitted evidence references. Uniqueness on account + source + pipeline
  version deduplicates extraction; a separate operation key and request digest
  make retried preference commands safe. Reject key reuse with a different body.
- Put opt-in/memory generation settings in a reserved typed user_memory entry,
  not profile identity/entitlement fields. All writes use a transactional
  backend-controlled function with revision checks. Initially no hidden inferred
  preferences; only explicit, confirmed allowlisted preferences become active.
- Existing keys become legacy/unverified, excluded from authoritative context.
  Preserve them for review; do not auto-confirm, delete, or reinterpret them.
- Current item facts stay in items/spaces/documents/project kits and existing
  audit tables. No duplicate item fact table, universal graph, embeddings,
  proprietary recognition model or inferred purchase/compatibility schema.

All memory APIs sit outside inventory-scoped route aliasing. Account identity is
server-derived. Inventory-specific operations additionally authorize inventory and
referenced records. No account/owner ID is accepted from model output. Direct
DB read policies require the owning account, current inventory access when
applicable and exclusion of public integration-key identities. Anon gets no access;
mutations go through verified backend functions. Service-role credentials remain
backend-only. Test role grants and policy predicates with real disposable SQL.

## Processing and response flow

1. Receive an explicit preference command or confirmed saved mutation with a
   stable source ID. Bind actor and authorized inventory before deferred work.
2. Parse allowlisted fields deterministically first. Later model extraction can
   propose strict candidates from user-authored text, never from its own answer
   as verified evidence. Uploaded documents never create personal preferences.
3. Validate type/length/value, authorization, source ownership, opt-in and current
   revision. Explicit corrections supersede prior versions; ambiguous resource
   aliases or conflicting candidates require confirmation.
4. Atomically record receipt and preference revision. Confirm success only from
   committed results. Existing item mutations remain in their own authoritative
   services; the initial preference slice does not execute inventory actions.
5. Retrieve a bounded package: explicit account style, current inventory aliases,
   current owned conversation and freshly authorized physical records/evidence.
   Do not pull unrelated historical Q&A. No new cache in the initial slice.
6. Apply style without changing facts or dropping unknowns/evidence. Resolve
   aliases to permitted IDs for retrieval. Both sync/SSE and deterministic/model
   answer paths use the same package. Pending confirmations remain conversation
   scoped; a preference cannot disable permission checks or required confirmation.
7. Record bounded operational metadata: pipeline/capability, result count/status,
   duration and actual provider usage when available. No full prompts/documents
   in telemetry; unknown cost stays unknown.
8. Forget removes content, advances the memory generation and cancels pending
   events transactionally so retries cannot resurrect deleted preferences.
   Retain only minimal non-content deduplication receipts for an approved period.
   Export contains only the caller's authorized memory, with no signed URLs or
   another member's private conversations. Full account erasure remains separate.

A durable poller is unnecessary for synchronous explicit preferences. If candidate
extraction is added, process memory_events using Postgres leases and SKIP LOCKED,
bounded retries and a failed status. Use an existing FastAPI process lifecycle;
no Redis, Celery or separate host initially. Concurrent workers and crash recovery
must pass SQL tests before enabling this mode. Do not promise durable retries from
an in-process task alone.

## Stages, approval boundary and acceptance

The source document says: "First, return" the architecture/gaps/model/risks/plan,
then "implement the approved work in stages." This proposal is that first return.
Requested approval is for the smallest complete preference foundation, not the
entire long-term graph or infrastructure deployment.

| Stage | Proposed work and dependencies | Verification required before push/build |
| --- | --- | --- |
| 1: Schema and safe ownership | Additive local migration after schema review; owner-only policies, typed entries/events, opt-in/generation, conditional RPCs. Disable unsafe legacy auto-promotion when the replacement is enabled. No production migration | Disposable Postgres reconstruction; A/B accounts, same shared inventory, anon, viewer, integration keys, revoked membership, foreign source IDs; migration rerun/rollback compatibility |
| 2: Explicit preference lifecycle | Thin memory routes/services; save/list/edit/forget/export/disable with idempotency and revision checks. Only answer length/format and confirmed inventory aliases first | Save, restart, fetch; stale revision conflict; duplicate/unknown-outcome retry; source tampering; forget during pending processing; no sensitive or unsupported key promotion |
| 3: Shared retrieval/personalization | Extend ai_memory and agent entry points with one bounded context package; deterministic and gateway paths use approved preferences without replacing factual evidence | Preference changes the next answer correctly on a new conversation; same facts/unknowns and sources; sync/SSE parity; ambiguous alias clarification; no cross-account or cross-inventory references |
| 4: User controls and feedback | Small Memory section in existing web/mobile Settings using account-bound clients. Show what is stored, source/state, edit/forget/disable/export; explicit corrections versioned | UI loading/error/retry, sign-out/account change during request, expired session, stale changes, real response outcomes; full relevant Python/Jest/Flutter suites and analysis |
| 5: Existing evidence integration | Add authorized movement-audit reads; link existing reviewed capture/document/project evidence. Candidate extraction only behind explicit consent and review, after durable receipt tests | Synthetic capture -> review -> save -> cross-client ask -> correction -> later ask; foreign/private document injection; duplicate capture/review tests; no physical verification claims |
| 6: Operational readiness | Retention purge and protected reprocessing; provider failure metrics; bounded event poller only if required; deletion-source reconciliation reviewed separately | Restart/lease/retry/failure tests, actual latency/failure/cost measurements, disposable live two-device demonstration, schema/backup restore and separate deployment approval |

Recommended approval scope: stages 1-4 as one complete, incrementally validated
user-facing preference foundation. Stages 1-2 establish storage/control, stage 3
proves the stored preference affects an answer, stage 4 exposes user control.
Do not ship a memory row without retrieval behavior or a way to remove it.
Stages 5-6 remain separately scoped after this foundation is demonstrated.

## Tests, evaluation and infrastructure gates

- Reuse the 127-case physical-memory fixture and existing API/SSE permission tests.
  Add stable synthetic memory cases with expected preference selection, source,
  revision, answer facts, absence of foreign evidence and action outcome.
- Report per-case factual/evidence coverage, unsupported claims, isolation and
  action correctness. Evaluate prompt contents and deterministic presentation with
  fake gateway replies; distinguish these from actual provider quality tests.
- Add a real SQL script beside `backend/tests/sql/workspace_inventories.sql` for
  constraints, RLS/grants, concurrent revisions, idempotency, leases and deletion.
- Backend commands: existing venv `python -m pytest -q`; focused memory and prior
  physical-memory/tool-safety tests. SQL against disposable Postgres using the
  committed baseline plus required migrations, never a customer database.
- Web: `npm run test:ci -- --runInBand`, `npx tsc --noEmit` and changed UI build.
  Flutter: `flutter analyze --no-pub`, `flutter test --no-pub --concurrency=1`.
- Existing pre-task baseline from implementation 1c44e5e: 727 Python tests plus six
  subtests, 296 web tests, 434 Flutter tests; static and connector checks passed.
  This discovery makes no runtime changes and does not rerun them after the prior
  push/build, following Tanya's latest instruction. These results do not verify
  any proposed memory functionality, live RLS or live providers.
- Keep current gateway routing and FIND/GPU/transport untouched. Self-hosted
  migration application, service restart and deployment require separate approval.
  Schema must precede dependent runtime; if unavailable, disable new memory rather
  than silently reverting to unsafe auto-extraction. Preserve old clients/contracts.
- Rollback: turn off new collector/context consumption and restore compatible
  runtime. Keep additive schema/legacy rows; do not drop memory or shared records.
  Test rollback against the previous runtime before applying any production change.
- Reuse standing commit/push and TestFlight delivery authorization for completed
  implementation after checks, without post-push/build reruns or processing wait.
  This documentation-only proposal requires no new TestFlight binary.

## Decisions needed now

Approve stages 1-4 with explicit-only, opt-in personalization and inventory-private
aliases. This avoids hidden inference and does not change saved inventory facts.
Retention periods for event receipts and optional inferred candidates need a
product/privacy decision before enabling those later processing modes. No live
migration, backend deployment, FIND transport or public App Store submission is
included in this approval.
