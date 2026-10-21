# Organization-wide Ask — candidate, October 20, 2026

Implemented on `feat/api-organization-chat-20261020`. Not deployed. Migration
073 requires explicit production authorization before this API can be published.
Existing inventory-scoped endpoints remain compatible; the web layout is unchanged.

## Behavior

`/worlds/{organization_id|personal}` serves an author-private conversation history,
accessible inventory directory and Space directory. Every read/proposal resolves
current organization and inventory access. Organization names are not confused
with inventory or Space names. The configured gateway/model interprets ordinary
text and existing FIND photo observations; voice remains mobile speech input.

Tools search authorized inventories and propose inventories/Spaces or item
additions/deletions. Review cards freeze exact destinations and values. Confirmation
uses service-only atomic SQL with current permissions, quotas, expiry, rollback,
existing-name reuse, idempotent receipts and audit entries. Structure creation
never renames, moves or deletes existing records. Item actions reuse the established
reviewed transaction. A saved response is read back before exposing its cards.

Photo questions compare current saved gallery references, including photos added
later. Three inventory comparisons run concurrently with task-local authorization;
photo search has a ten-second aggregate budget and explicit partial coverage.
Same/near-duplicate photos are evidence, not proof of product identity from any view.
Queries are bounded; this is not a 1,000-concurrent-user capacity certification.

Migration 073 adds a nullable conversation discriminator and private-read guards;
legacy rows are not rewritten. Direct authenticated clients cannot forge world
assistant proposals. Removed organization members cannot read their old world
history. API errors omit provider details. No model/provider settings changed.

## Validation

- Full Python suite: 1,199 tests and 10 subtests pass.
- New service/HTTP tests cover scope isolation, malformed calls, viewer denial,
  durable completion, SSE, image failures, live gallery routing and concurrent scopes.
- Full composed PostgreSQL fixture through 073 passes, including migration replay,
  duplicate confirmation, author/world isolation, revoked membership, quotas,
  rollback, byte-preservation of existing items and private history reads.
- Fresh production backup restored into a network-isolated disposable database:
  90 tables retain all original values after applying 073 twice. Production was
  read only; no customer QA writes. Private receipt remains on the VM under
  `/home/ubuntu/findez-world-release-rehearsal-20261020/rehearsal.json`.
- Configured live-model probe on synthetic data generated the requested Tools /
  Shelf review correctly, with database access disabled (15.2 seconds for that one
  probe, not a performance percentile).

## Release

Apply reviewed 073 only after authorization and a fresh backup. Then publish only
router.py, resource_access.py and the two world_chat.py files while preserving
unrelated VM overlays. Deploy this API before mobile build 100. Keep 073 on runtime
rollback. Public App Store build 99 is outside this candidate's scope.
