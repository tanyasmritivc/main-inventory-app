# Assistant retrieval improvement

## Starting point

October 16, 2026: repository `dev/findez-mobile-color-accents`, clean branch
`feat/mobile-place-switcher-20261016`, commit
`3e3e095e563cba3d3db532a153a907ee2e1844d9`. Repository workflow requires a
separate implementation lane, now `feat/assistant-grounded-retrieval-20261016`.
The latest user instruction authorizes commit/push and a new TestFlight build
using completed checks. No repeated post-push/build checks or processing wait.
Backend deployment and production migrations are not part of this beta upload.

## Discovery and baseline

- Web `assist-client.tsx` -> `ask-stream.ts` and Flutter `features/chat/chat_page.dart` ->
  `api_client.dart` use authenticated inventory-prefixed `/ai_command` SSE and
  `/ai_photo_question`. Existing delta/done/answer_context contracts stay intact.
- `api/routes/ai.py` authorizes conversations and persists source snapshots;
  `services/ai_agent.py` runs read context and caller tools.
- `agent_gateway_client.py` is the sole runtime adapter. It sends an
  OpenAI-compatible envelope to the configured FTCTools gateway. There are no
  independent Claude/OpenAI SDK adapters to test. No provider selection changes.
- `InventoryClient` and `AccessClient` add current inventory, actor, private
  resource and membership fences to service-role queries. Keep these boundaries.
- Items: names, category/subcategory, brand, part number, barcode, notes,
  location/space/bin IDs, quantity, images, timestamps and imported source data.
  Documents have existing item links and metadata; not a universal text index.
  `item_events` has note/usage/restock/failure/success/photo events. No general
  verified compatibility graph or physical confirmation timestamp.
- Baseline: `pytest backend/tests -q`: 525 passed, six subtests, 70 warnings,
  7.22 seconds. Web test:ci: 296 passed across 40 suites, 13.477 seconds.
  Mobile: 31 chat tests passed; the first command also named a nonexistent
  ask_models_test.dart. Rerun the actual files. These are synthetic tests, not
  live provider latency or production failure-rate measurements.

## Ordered implementation and capability map

1. Add a small read capability registry and deterministic interpretation for
   item lookup, location, counts, descriptive matching and existing field filters.
   Retrieve through existing authorized repositories, use bounded projections,
   label likely matches, preserve unknown quantities and distinguish records/units.
2. Reuse saved conversation answer-context IDs for pronouns, with fresh record
   authorization. Ambiguous selections ask for clarification. No account-wide
   fallback for a named conversation.
3. Ground answers directly in retrieved fields and existing public evidence.
   Reuse item-linked document metadata and persisted event reads. Do not claim
   full document content, purchase price, compatibility or physical confirmation.
4. Validate caller tools against their existing definitions, reject disabled,
   malformed, unrequested and repeated mutations, and return real failure text.
   Guard quantity/event operations that lack atomic/idempotent persistence rather
   than presenting them as safe. No new transaction schema in this lane.
5. Add at least 100 synthetic question cases and negative tool/conversation
   regressions. Measure deterministic retrieval latency and outcome counts before
   and after; do not present fixture timings as live model latency.
6. Run full relevant backend, web and mobile regressions, static checks and diff
   review. Record unsupported capabilities and remaining security decisions.

## Risks and deliberate limits

- Gateway model responses are untrusted; tool schema and user intent both need
  server checks. A prompt alone cannot enforce mutation safety or grounding.
- Existing mutation paths have no general idempotency key and some stock/event
  writes are separate. Do not enable new natural-language stock-delta behavior
  without an atomic receipt-backed service. Existing editor paths remain separate.
- Search caches already exist. Add no new cache. Use authorized current reads for
  follow-ups; do not infer truth from assistant prose or persisted session memory.
- Service-role access needs explicit query boundaries even when RLS exists.
  Do not modify FIND transport/GPU infrastructure, provider credentials or keys.
- Full document text, calibrated recognition, automatic learning, generic item
  relationships, reminders and live spatial tracking remain unsupported unless
  the existing source proves otherwise. Project readiness already has its own
  grounded path and must remain compatible.
- Synthetic services cannot establish production storage privacy, current live
  RLS, real provider behavior or physical-device acceptance. Report these limits.

## Implementation and capability results

This is a local candidate, not a deployment. Web/mobile navigation, providers,
gateway model selection, FIND transport, schema and public request/response
contracts remain intact. There are no migrations, added dependencies, persistent
retrieval caches or new API routes.

The new registry is `services/inventory_questions.py::CAPABILITIES`. It declares
read purposes, arguments, permissions, evidence sources, ambiguity/empty behavior
and confirmation policy. Its resolver reports supported, incomplete, unavailable,
unsupported, ambiguous and empty outcomes. Tool validation reuses the existing
`ai_agent._TOOLS` definitions rather than duplicating schemas.

| Taxonomy | Local behavior and evidence | Remaining limit |
| --- | --- | --- |
| A-C: finding, inventory knowledge, counts | Token matching across existing saved fields; conservative spelling/prefix matching; exact identifiers; location/category/brand/quantity filters; explicit ISO creation dates; missing-field queries; record count separate from known unit sum | Selected inventory only; 500 candidate ceiling is disclosed, not a full inventory total. No general alias graph, inferred uses, relative date interpretation or implicit low-stock threshold |
| D: locations | Actual recorded location, unknown location, location-filtered contents | Flat saved location text; no new hierarchy traversal or physical confirmation claims |
| E: relationships | Existing project-kit path retained | General compatibility/accessory graph not added. Names never establish compatibility |
| F: photos | Existing photo endpoint, FIND pipeline and source snapshot format retained; streamed photo work now retains authorized scope | No new visual similarity, model training or live tracking; recognition quality is not established by synthetic tests |
| G: actions | Explicit literal name/category/location/notes edits to one freshly retrieved, named item; existing Space validation; compare-and-set against retrieved/current values; no automatic write retry; saved row determines success text and source snapshot | Chat additions, quantity deltas/events, creation and deletion hand off to existing confirmation editors. Their legacy services lack general durable chat receipts or atomic quantity/event transactions. This is an intentional safety restriction |
| H: purchases | Already-recorded items and known quantities are retrievable | Purchase date/price/warranty not inferred from creation date, filename or model knowledge |
| I: documents | Item-linked filenames from `list_documents(item_id=...)`, with metadata-only source labels | No new indexed full-text retrieval or document summarization. Existing explicit upload-analysis path remains separate |
| J: history | Current item notes plus actual `item_events`, bounded to recent events | Movement changes also exist in `app_access_audit` (migration 044), but that source is not newly wired into chat. No claim that history is complete or edits prove physical presence |
| K: projects | Existing authorized project-kit readiness and reservation-aware quantities preserved | No generated requirements, general workspace AI or inferred project associations |
| L: maintenance | Unsupported filter/condition questions state the limitation | No new service/calibration/expiration interpretation |
| M: comparison/calculation | Exact sums over known numeric quantities; explain saved supporting fields | No unverified unit conversion, model specifications or engineering guarantees |
| N: follow-ups | Saved assistant answer-context IDs from an owned conversation, followed by current inventory reads; fresh location/quantity; clarification for multiple/lost results | No ordinal or size inference. A named conversation cannot fall back to another thread's account history |
| O: cleanup | No automatic merge/delete/bulk rewriting | New duplicate cleanup/export intelligence is deferred |
| P: sharing | Existing inventory/actor/private-resource checks retained; read-only members cannot write | Organization membership never implies content access; no new organization-wide retrieval |
| Q: reminders | Explicitly says no reminder was scheduled | Scheduler integration not added |
| R: account/privacy | No new entitlement, profile or catalog write tools | Existing account/policy surfaces remain outside this read registry |
| S: uncertainty | Unknown quantities remain unknown; likely matches are categorical, not fabricated percentages; missing/revoked/ambiguous/unavailable cases have distinct outcomes | Unrecognized legacy/model-driven questions remain probabilistic; this is not a proof that every possible answer is grounded |

### Important stream-boundary correction

The new HTTP regression exposed dependency cleanup before SSE consumption in the
installed FastAPI version. Before the fix, the real scoped HTTP question fell
through to the model path because the inventory context had disappeared. Existing
service-only thread tests did not reveal this. `api/routes/ai.py` now captures the
server-validated scope/actor, installs them in the stream consumer, freezes the
effective owner instead of closing over a mutable auth object, and cleans up on
completion/cancellation. Deferred non-streaming memory tasks retain their original
context too. HTTP tests verify independent inventories, viewer/private conversation
ownership, refreshed follow-up facts and cross-inventory conversation rejection.
Concurrent/cancelled stream tests check cleanup and actor separation.

### Grounding and action safety

- Common selected-inventory reads produce text and `answer_context` directly from
  records without a model call. The existing delta/done SSE contract is retained.
- Search uses the existing authorized Supabase client with safe candidate terms,
  a 501-row read ceiling and an explicit partial-results flag. Unknown or unresolved
  words cannot silently become an all-inventory query.
- The gateway can request only existing allowlisted reads or a guarded literal
  edit. Disabled tools, invalid/extra arguments, speculative targets, unsafe
  operations and repeated writes are rejected or reused within one request.
- One request owns its reuse map. An edit invalidates prior reads; successful
  writes and stale-version rejection evict existing inventory cache entries.
- Literal edits validate existing field lengths and Space relationships, compare
  against the item actually retrieved and perform one conditional database update.
  A lost response is not automatically replayed. A repeated already-satisfied
  absolute edit performs no second write. No new quantity increment is enabled.
- Model prose cannot claim a requested edit happened without a saved row. Failed
  operations return server-created safe messages. Source rows reflect a confirmed
  edit rather than its earlier location.
- Provider-bound tool/context data omits storage URLs, owner IDs and tokens, caps
  text/data size and labels truncated collections. Tools remain sequential, with
  at most four calls per reply and the existing bounded step count. Provider
  selection and upstream timeouts are unchanged.

## Validation

| Check | Actual result | What it establishes |
| --- | --- | --- |
| Initial `pytest backend/tests -q` | 525 passed, six subtests; 7.22s | Pre-edit backend baseline, excluding root API documentation tests |
| Initial web test:ci | 296 passed, 40 suites; 13.477s | Existing client baseline |
| Corrected mobile baseline | 31 passed | Existing Ask and chat-focus contracts. Initial command also named a nonexistent file; that was a command error, not an application failure |
| Final root `pytest -q` | 727 passed, six subtests; dependency deprecation warnings remain | Full backend/API documentation suite plus deterministic retrieval, safe tool, scope, event/document, retry and conditional-write regressions |
| Final web test:ci | 296 passed, 40 suites; 12.381s | Existing web chat/components remain compatible |
| Full Flutter test --no-pub --concurrency=1 | 434 passed | Existing mobile regression suite, including Ask streams and context isolation |
| Flutter analyze --no-pub | No issues | Client static analysis |
| TypeScript `tsc --noEmit` | Passed | Existing web types accept unchanged contracts |
| MCP/Actions tests | 29 passed | Existing connector schemas, authorized transport and API behavior |
| Desktop bundle check/test | Source/dependency manifest matches; one bundle test passed | Existing distributable stays compatible |

The connector first failed because its locked SDK dependency was not installed.
Installing the existing lockfile resolved this; no manifest or dependency version
changed. No live model, GPU, customer database or customer record was used.

The committed-to-disk synthetic fixture is
`backend/tests/fixtures/physical_memory_questions.json`: 127 stable cases with
synthetic users/inventories/items/documents/events, expected IDs/fields, quantity
facts, outcomes, uncertainty and no-action requirements. New files remain
uncommitted as requested. Both service paths and actual HTTP SSE are exercised.

For 72 deterministic lookup cases, the existing normalized whole-substring matcher
selected the expected exact record set in 33 cases; the new resolver did so in
72. This isolates matching, not the entire previous model-assisted product.
The synthetic in-process run measured approximately 0.082ms median and 0.164ms
p95; these exclude all real database/network/provider latency and cannot support
a production speed claim. Live latency/failure rates were not measured. New
`ask_read` logs record capability/state/duration/count without questions, user IDs
or private record text, enabling a later authorized baseline before tuning.

### Reproduce checks

From the repository, using the existing Python environment:

```sh
/Users/tanyasmritivictorcharles/dev/main-inventory-app/backend/venv/bin/python -m pytest -q
/Users/tanyasmritivictorcharles/dev/main-inventory-app/backend/venv/bin/python -m pytest backend/tests/test_physical_memory_questions.py backend/tests/test_assistant_tool_safety.py -q
npm --prefix frontend run test:ci -- --runInBand
npm --prefix integrations/findez-mcp test
npm --prefix integrations/findez-mcp run check:bundle
npm --prefix integrations/findez-mcp run test:bundle
```

From `frontend/`: `npx tsc --noEmit`. From `mobile/`: `flutter analyze --no-pub`
and `flutter test --no-pub --concurrency=1`.

## Security review and remaining gates

This work does not establish production security. Verified source behavior and
synthetic tests are separate from deployed policy/storage/provider acceptance.

| Area | Evidence and current conclusion | Next verification |
| --- | --- | --- |
| Streaming scope | High-risk scope-loss behavior reproduced through HTTP and fixed locally; tool/thread-only tests had missed it | Two disposable accounts and independent/shared inventories on the deployed FastAPI version, including disconnect/revocation |
| Tool authorization and actions | Disabled/unknown calls and forged arguments rejected in both loops; real viewer/conditional write tests pass. Risky chat writes are blocked | Review the intentional editor handoff policy before enabling broader chat mutations. Introduce durable request receipts and atomic stock/event writes in a separate change |
| RLS/service role | `inventory_scope.py`, `resource_access.py`, migrations 043-047 and existing negative tests enforce additional inventory/private-resource boundaries in source | Run SQL fixtures against an empty disposable PostgreSQL database and inspect live routine ACLs/policies. No production schema assertions made |
| Photos | `config.py::supabase_storage_public` defaults true and `storage.py::upload_image` conditionally creates public URLs | High-priority live bucket and anonymous-object-access audit. Source configuration alone does not prove the live bucket is private |
| Documents/uploads | Signed document URL route authorizes the record; new chat exposes metadata only. `documents.py::upload_document_route` reads the entire file and trusts declared MIME; `ai.py::ai_upload_route` also reads without a route-level byte bound | Separate bounded size/content validation and private-object negative tests. Photo Ask already has 10MB/25MP validation, covered by its existing suite |
| FIND transport | `_validated_base_url` permits private/loopback HTTP and an explicit insecure override | Infrastructure-owner review of the real route/TLS. Integration and GPU configuration were not changed |
| Entitlements/catalog | No new chat writes to subscription or verified identity fields. Historical baseline profile self-update RLS is row-based; effective live column privileges/triggers are not proven by this audit | Verify direct authenticated profile entitlement writes are denied and canonical catalog writes require appropriate authority. Do not infer current vulnerability or safety from the old baseline alone |
| Logs/secrets | New retrieval/tool logs exclude prompts, record IDs, exception bodies and credentials; changed files contain only synthetic test identities | Existing query history/activity logging and server log policy still need privacy/retention review. No real key/bundle/production-env audit was performed |
| Tokens/provider behavior | Existing Supabase auth clients and gateway configuration are untouched; no new client secrets | Native credential storage, real gateway model behavior, live Claude/OpenAI routing if available outside this repository, and revoked-session checks require manual acceptance |

## Files and change review

Implementation files in this delivery:

- `backend/app/services/inventory_questions.py`: read registry, interpretation,
  authorized retrieval, follow-up references, bounded grounded replies and metrics.
- `backend/app/services/assistant_tool_safety.py`: existing-schema validation,
  action policy, request reuse identity, safe outcome text and bounded provider data.
- `backend/app/services/items_repo.py`: bounded candidate query and conditional
  literal-edit service, leaving existing editor APIs intact.
- `backend/app/services/ai_agent.py`: share the read resolver and safety guard
  across both agent loops; conversation-specific history and unchanged gateway.
- `backend/app/services/ask_presentation.py`: replace pre-edit evidence with the
  confirmed saved record.
- `backend/app/api/routes/ai.py`: retain server-authorized context for streamed
  answers, photo tasks and deferred non-streaming memory tasks.
- `backend/tests/fixtures/physical_memory_questions.json`: reusable synthetic cases.
- `backend/tests/test_physical_memory_questions.py`: real scoped queries, facts,
  HTTP/SSE persistence, permissions, races, cancellation, history and measurements.
- `backend/tests/test_assistant_tool_safety.py`: adversarial provider output,
  validation, non-executed edits, redaction, bounds and safe failures.
- `docs/plans/assistant-grounded-retrieval.md`: this plan, mapping and report.
- `TESTING.md`: commands and limitations for these regressions.
- `.agents/ACTIVE_WORK.md`, `.agents/CURRENT_STATE.md`, `.agents/DECISIONS.md`:
  task status, verification and durable safety decisions.
- `AGENTS.md`: standing push and beta delivery instruction.
- `mobile/pubspec.yaml`: beta build number 69; mobile runtime is unchanged.

No user changes existed initially; existing files and unrelated work were
preserved. No frontend/mobile runtime source, provider settings, dependencies,
schema or API contract changed. Mobile version is bumped to 1.0.8+69 for the
requested delivery. Work is on `feat/assistant-grounded-retrieval-20261016`.
Implementation `1c44e5e` is pushed on PR #88. Apple acknowledged signed
1.0.8 (69), delivery `dce3e75e-aaba-4994-b609-5953086d88b6`. No post-push/build
checks or processing wait per user instruction; availability remains unverified.
Durable artifacts and receipts: `Documents/FindEZ/AppStore/1.0.8-build69`. Backend changes require a separate deployment to become live; a
TestFlight binary does not deploy them. There are no migration rollback
requirements; rollback is a code rollback, not a data rewrite.

## Ordered next steps

1. Review this focused diff, especially the restricted chat action policy and the
   stream-context fix. Broader chat writes need receipt-backed confirmation and
   atomic quantity/history persistence before they can be safely enabled.
2. Complete the isolated SQL and storage/privacy gates above. Verify effective
   service-role/actor behavior, private files and profile/catalog privileges.
3. With disposable accounts, test Capture -> Save -> Ask from web and iPhone,
   then change a location/quantity on the other client and ask a follow-up. Check
   viewer denial, revoked access, switching inventory, cancellation and retries.
4. Verify the actual configured language gateway with a small authorized synthetic
   inventory and both intended upstream routes if the gateway provides them.
   Measure latency/failure rates before adjusting timeouts or adding caching.
5. Add authorized item movement-audit retrieval and consent-aware document content
   retrieval next, using the existing sources. Keep visual similarity, autonomous
   reminders, general relationship inference and enterprise features deferred.
