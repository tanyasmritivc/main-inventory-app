# Personalization implementation

## Audit and implementation plan

Source lanes: API `feat/personalization-engine` (from deployed prelaunch API);
mobile `feat/mobile-personalization` branches from TestFlight 138. Web source/layout stays unchanged unless
an essential existing-control integration is identified. Subscription WIP is not
part of this task. Migration 080 is reserved by that WIP; this feature uses 081.

Existing architecture: FastAPI, Supabase/Postgres with actor-aware inventory scopes,
FTCTools gateway completion/SSE, verified inventory tools, account memory with
explicit preferences and Space aliases, owned conversations, direct APNs iOS push,
existing notification/auth navigation. OpenAI/Claude connectors use their existing
API/MCP contracts; no new provider, model call, vector database or microservice.

1. Add bounded typed events, opt-in behavioral profile, item aliases, receipts and
   notification outbox. Capture completed mutations in database triggers so all
   callers share the same verified boundary. Fail optional event capture safely.
2. Add deterministic decay/ranking, exact-match precedence, scoped alias resolution,
   bounded context and existing memory reset integration.
3. Integrate scoped search and explicit chat controls. Preserve mutation safeguards,
   current facts and SSE response ordering.
4. Add conservative, opted-in low-stock/scan-review candidates, atomic claims,
   frequency caps/quiet hours, APNs acceptance receipts and verified completion.
5. Extend existing mobile notification routing without changing layouts. Keep web
   layouts, chat/composer, navigation and themes untouched.
6. Run isolated Python/SQL/client regressions and document activation and limits.

No production notifications or destructive production tests. Schema activation
and real-device acceptance are separate from isolated implementation verification.

## Implemented behavior

The behavioral profile is separate from `profiles` (identity) and existing explicit
`user_memory` preferences. It defaults **off**. Existing Memory settings remain the
master switch; Forget clears activity, item aliases and the notification outbox in
one transaction. Disabling preserves data but stops collection/use. Explicitly
re-enabling learning is required after disabling the master switch. Account and
inventory deletion cascade to the new stores.

`personalization_events` records verified item CRUD, movement, quantity changes,
scan review transitions and completed search outcomes. An item update that changes
only `updated_at` records nothing. A proposed action does not record a mutation.
Search telemetry contains a per-user query hash and bounded count, never the query,
transcript, notes, document content or credentials. Its 32-slot/two-worker queue
fails open under overload/outage; search context uses one bounded RPC with a 500ms
transport timeout. Database observation uses a subtransaction and nonwaiting profile
lock so optional learning cannot fail the inventory write. Delayed events carry the
profile generation and cannot resurrect data after reset.

Scores are `weight * 0.5 ** (age_days / 14) * confidence`, summed per item, capped
at 20, and retained for at most 90 days. Weights: view .25 (reserved), successful
search 1, create/move/quantity 3, edit 2, confirmed consumption 4 (reserved).
Confidence is 1 for database outcomes and .7 for search results. Only a single
unambiguous search result contributes item interest. Explicit aliases do not decay.
Exact identifiers (1000), identifier prefix (800), and exact names (600) outrank
confirmed aliases (500), ordinary token matches (400), prefix/fuzzy evidence.
Behavior only orders ties. All candidates remain; a tie influenced by behavior
cannot authorize a chat mutation without an explicitly unambiguous target.

The existing FTCTools/SSE pipeline receives ranked current inventory results,
not a whole profile dump. Short-lived references retain only actor/conversation
scoped IDs from verified result links, expire after 15 minutes, and require a fresh
lookup. Existing OpenAI Actions/Claude MCP integration contracts are unchanged.
Integration JWT claims are explicitly rejected by private account-session auth;
API-key integrations retain their separate scoped API authentication.

## Existing-chat controls (no UI redesign)

Ask about personalization to get the supported controls. Explicit current-message
commands work on both web and mobile via `world_personalization`:

- `Enable personalization` (enable the existing Memory master switch first).
- `Disable personalization` / `Reset personalization`.
- `Remember "my fasteners" as "M3 screws" in inventory "Hardware"`.
- `Forget alias "my fasteners" in inventory "Hardware"`.
- `Enable low stock notifications in America/Los_Angeles`.
- `Enable scan review notifications in America/Los_Angeles`.
- `Disable notifications`.

Aliases require an exact unique saved item and inventory. Corrections replace the
same normalized alias; null deletes it. Text inside notes/documents and a model's
arguments cannot grant consent. Compound/ambiguous commands return guidance instead
of writing. Confirmed settings commands return their verified receipt as ordinary
chat text, with no new card, dashboard, composer change or model round trip.
`GET/POST /personalization`, `POST /personalization/aliases`, and
`POST /personalization/reset` also expose typed authenticated controls with operation
UUIDs, revision compare-and-swap and replay receipts. Notification preference fields
include IANA timezone, quiet minutes and caps. Equal quiet-hour endpoints mean quiet
all day. Server maxima are two attempts/day and five/week; defaults are one/day and
three/week.

## Notifications and routing

Supported candidates: a known nonnegative quantity crossing an **enabled existing
reorder threshold**, and a still-pending capture review at least 24 hours old.
Candidates expire after seven days. No inactivity alerts, inferred consumption,
marketing, artificial urgency or generic recap. No historical backfill on opt-in.
Priorities are low-stock 90 / review 65, minus 15 per explicit dismissal (up to
three), plus 2 per verified completion (up to two). Three dismissals in 30 days
suppress that category. Opens, silence and delivery do not increase priority.

Claims serialize per actor across workers, reserve rolling frequency slots, check
current permissions/condition/preferences/timezone, and require a recently registered
capable iOS device. Eligibility is checked again immediately before sending. One
most-recent active device receives a candidate. APNs collapse IDs and durable claims
prevent repeated sends. APNs acceptance sets `accepted_at` and `notification.sent`,
not `delivered_at`. Foreground OS receipt, open, and dismissal are separate owner-bound
signals. Completion requires an open followed by an actual replenishment or resolved
review; it is not inferred from a click. Transport uncertainty consumes the slot and
becomes `unknown`; **no automatic retransmit** of an uncertain send. Stuck claims
become unknown after 15 minutes. Expired APNs tokens are disabled. Existing team/local stock notifications remain
separate; these caps govern the new personalization outbox only.

Every payload has an opaque notification UUID and intended recipient. The existing
mobile auth shell queues launch destinations. The destination endpoint rechecks
notification ownership, inventory access and current entity existence, returning the
fresh record and authorized inventory context. Existing item/review sheets open
unchanged. An unavailable target uses the existing error message pattern. Client
feedback cannot claim task completion. Old clients do not advertise
`personalization_destinations` and receive none of these new alerts. Permission
revocation unregisters the active server token on resume.

## Activation (not performed)

1. Review/apply `081_personalization_engine.sql` to a restored production-schema
   copy first, then the authorized production database. Migration 080 belongs to
   the separate subscriptions lane. 081 depends on existing inventory, memory,
   capture-review, push-device tables and inventory authorization functions.
2. Deploy the API lane only after migration success (push registration writes the
   new capability column). Publish the compatible mobile beta. No web bundle change
   is required; its existing chat calls gain the backend behavior.
3. Keep `FINDEZ_PERSONALIZATION_PUSH_ENABLED` absent/0 until isolated-device testing
   and explicit user/category opt-in. Configure existing server-only APNs settings:
   `APNS_KEY_PATH`, `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_TOPIC`. Match device sandbox
   versus production environment. The app's existing push entitlement/topic stays.
4. Schedule `python -m app.services.personalization.notifications` from `backend/`
   with the existing service environment, e.g. every five minutes. This is a short
   backend job, not another service. It dispatches only when the flag is `1`, then
   always runs 90-day retention cleanup. Monitor aggregate accepted counts and
   generic unavailable logs; never log tokens or document contents.
5. Test on an isolated account/device with real APNs foreground/background/terminated
   delivery, auth restoration, opt-out, denied permission and deleted targets before
   enabling the worker for users. Public App Store submission is not authorized.

RLS is enabled on all five tables. Authenticated clients have owner-only scoped
reads and no writes; RPC writers are service-only. No existing RLS policy is removed
or weakened. Reset/revision locks, generation fences, FK cascades, dedupe keys and
partial outbox uniqueness protect replay, retention and account isolation.

## Verification and limits

- Backend: **1,525 passed**, 10 subtests; existing 451 dependency/FastAPI deprecation
  warnings. Includes new deterministic scoring, source minimization, consent,
  SSE receipt, target ambiguity, actor isolation, malformed input and mocked APNs
  tests, plus all existing CRUD/search/scan/provider/SSE regressions.
- PostgreSQL 17: **40 assertions passed** in an empty local synthetic database;
  migration replay passed. Real concurrent connections verified one daily claim
  across six workers and rejection of delayed events after reset. SQL and Python
  notification priority explanations agree across feedback combinations.
- Mobile: **925 passed, one existing optional visual skip** in the full suite;
  subsequent focused lifecycle/exact-target suite **28 passed**. Analysis clean.
  Simulator native build succeeded; release/native final verification is recorded
  in the mobile lane's delivery notes.
- Web (source unchanged): **574 passed / 80 suites**, TypeScript passed; lint has
  **0 errors and 52 existing warnings**. Production build passed with webpack and
  nonproduction public Supabase placeholders. Default Turbopack cannot traverse this
  worktree's external `node_modules` symlink; Google Fonts needed network access.
- No production database mutation, real-user notification or live-provider test.
  Physical APNs foreground/background/terminated acceptance remains unverified;
  mocked platform lifecycle and exact authorized sheet navigation are verified.

Deliberately unsupported signals: item-view telemetry, separate confirmed-consumption
classification (quantity changes alone are not consumption), document-review/task
notification categories, automatic free-form preference extraction, learned category
or sensitive identity inference, recommendations/recaps, Android FCM and web push.
Existing project-readiness tools already use verified requirements and stock. This
implementation does not invent another recommendation UI or unsolicited chat.
Only the most recent 512 events per inventory are aggregated at request time; no
claim of complete lifetime behavioral statistics. Existing Memory export still
exports explicit preferences; the new read endpoint exposes behavioral profile and
scoped aliases/interests, not an event-history export. These are explicit limits,
not verified production capabilities.
