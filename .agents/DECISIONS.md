# Decisions

Only decisions supported by current code or repository records belong here.

## 2026-08-22: Production is self hosted

**Decision:** Run the backend, web app, database, Auth, and Storage on the OpenStack
environment rather than Render, Vercel, or cloud Supabase.

**Reasoning:** Keep the product stack and data under project control and support the
private inference architecture.

**Implications:** Deployments and migrations are manual. Cloud Supabase is read-only.
Environment changes require service restarts, and Next.js public values require a
rebuild.

## 2026-08-30: Mobile leads item presentation

**Decision:** The iOS app is the source of truth for item field order and item
presentation. Web mirrors those semantics.

**Reasoning:** Mobile is the primary product client and the most developed inventory
workflow.

**Implications:** Do not redesign shared item concepts on web first. Preserve mobile
field meaning across platforms.

## 2026-08-30: Spaces are persistent records

**Decision:** Space operations use the Spaces API and `space_id`; deleting an owned
Space intentionally deletes its items.

**Reasoning:** Looping over item `location` strings caused split, orphaned, and stale
inventory.

**Implications:** Keep the legacy `location` value synchronized for compatibility.
Never reintroduce orphan-to-Unsorted deletion behavior.

## 2026-09-09: Public integrations use scoped API keys and RLS

**Decision:** External integrations use `/api/v1` with hashed, expiring, revocable
workspace or organization keys. They do not receive service-role access.

**Reasoning:** Team permissions, revocation, and least privilege must remain enforced
for assistant and automation clients.

**Implications:** MCP and Actions wrap the public API. They do not connect directly to
the database. Migration `034` and its PostgreSQL tests are part of the contract.

## 2026-09-19: FIND owns inventory photo understanding

**Decision:** Route single-item and multi-item photo analysis through the server-side
FIND pipeline.

**Reasoning:** Inventory capture needs segmentation, identification, OCR/barcode
evidence, and measurement rather than a general language model vision response.

**Implications:** Clients never receive the FIND key or call FIND directly. Current
jobs are temporary, so durable crops, geometry, review state, and training signals
require new persistence work.

## 2026-09-22: OpenAI is not a runtime dependency

**Decision:** Use FIND for photos and the FTCTools agent gateway for language tasks,
with no OpenAI SDK, key, model, or fallback in the application runtime.

**Reasoning:** The project uses its own inference pipeline and gateway while keeping
the existing authenticated application tool layer.

**Implications:** Keep FIND and the language gateway separate. Do not send inventory
images to the text-only tool path or silently restore an external fallback.

## Current coordination rule: one lane per pull request

**Decision:** A change should own one clear implementation lane and avoid concurrent
edits to the same area. Use a branch or worktree for isolation.

**Reasoning:** Several coding agents and local worktrees operate on this monorepo.

**Implications:** Register active work, inspect git state, keep changes scoped, and
write a handoff only when another agent must continue unfinished work.

## 2026-09-28: Recover the public App Store mobile baseline

**Decision:** Restore the complete mobile source from the live App Store release,
FindEZ AI `1.0.6 (17)`, and use that code for the next TestFlight build.

**Reasoning:** The current TestFlight line contains an unaccepted mobile rebuild.
The public release is the known product baseline the user asked to recover.

**Implications:** Commit `0bb4f01066ca8326e0bc807e8a790bf54bba935f` is the
mobile recovery source. The TestFlight artifact differs only in version/build
metadata. Keep later redesign work on its separate branch until it is explicitly
accepted.

## 2026-09-28: Keep item photo galleries backward compatible

**Decision:** Keep `items.image_url` as the primary item thumbnail and store
additional item photo references as `photo` records in `item_events`.

**Reasoning:** Existing mobile, web, barcode, import, integration, and sharing
paths already depend on the singular `image_url` field. The existing event table
was designed for item photos and supports a gallery without a production schema
migration.

**Implications:** New uploads become the primary thumbnail, deleting the primary
promotes the next photo, and scan-generated images remain compatible with older
clients. Photo access must use the owning user's item scope, including Team Space
and legacy Shared Space authorization.

## 2026-09-30: Uncertainty is Review state

**Decision:** Persist uncertain photo results in `capture_reviews`; create an
inventory item only after explicit user confirmation.

**Reasoning:** A guessed identity should not silently become a remembered fact.
Review must survive app restarts and work across mobile and web.

**Implications:** Clients read their own queue. The authenticated backend owns
mutations. Resolution is transactional and idempotent. Save flows require a
durable review identity for uncertain results.

## 2026-09-30: Evidence stays useful and implementation-neutral

**Decision:** Show identity, detection, text, barcode, measurement, assumptions,
warnings, and review reasons. Filter pipeline free text and infrastructure names
at the backend boundary.

**Reasoning:** Users need the evidence to correct an item without exposure to
changing implementation details.

**Implications:** Clients render only the public `scan_evidence` contract.

## 2026-09-30: Image-less inventory rows are text-only

**Decision:** Render a thumbnail only when `image_url` exists. Keep the existing
item photo gallery for adding and deleting photos on items from every source.

**Reasoning:** Empty thumbnail squares waste list space and look broken.

**Implications:** Photo captures retain their crop or source image. Barcode,
spreadsheet, and manual items can receive photos later from item detail.

## 2026-09-30: Home is a concise overview, not a second navigation menu

**Decision:** Match the user's supplied matte-dark Home reference: "My home",
one borderless Ask field, two real-item question suggestions, four "Needs a
decision" cards, retained-photo captures, and grouped persistent Spaces. Use
the previous floating rounded-pill four-tab icon Home / Capture / Ask / Find
navigation (30pt corners, inset 18pt, 70pt bar), per the user's
follow-up request; no separate Home app bar,
header gradient/divider, oversized greeting, or duplicate action tiles.

**Reasoning:** Duplicated actions and an oversized greeting obscured the user's
inventory. The bottom navigation must reserve layout space rather than overlay
content.

**Implications:** "Where things live" uses actual Space records, including empty
ones, and opens by exact ID rather than ambiguous names or legacy locations.
Cards use real pending Review, positive low stock, zero stock, and owned distinct
checkout counts; unknown reads show a dash, not a false zero. Use "out of stock"
instead of inventing physical missingness. Older photos use "Recent captures"
rather than claiming "Captured today". Documents, notifications, and profile
remain reachable through Find's More menu; bottom navigation reserves layout
space and does not overlay the list. Embedded Ask, Capture and Find must not add
the old overlay-clearance padding on top of that reserved space. The user-requested navigation restoration
supersedes the reference's text-only five-tab bar without changing Home content.

## 2026-09-30: Ask presents checked records, not internal reasoning

**Decision:** Match the supplied Ask reference with a plain question card,
collapsed "What it read", readable response, and one grouped set of actual
quantity rows. Keep the restored four-tab pill and Home unchanged.

**Reasoning:** Evidence should explain which accessible records informed an
answer without exposing provider names, private reasoning, or tool internals.
Project readiness cannot be based on invented requirements or stock.

**Implications:** The additive public `answer_context` contract contains only
bounded source labels/details and item quantities. Named project readiness uses
the same authorization and reservation-aware calculation as project kits;
ambiguous or unknown projects request clarification. Status badges are derived
from available versus required quantities, and duplicate requirements cannot
reuse the same units. Migration `037` saves this snapshot on assistant messages
under existing conversation ownership/RLS, so later history does not imply a
fresh stock check. Older answers without a snapshot have no fabricated trace.
General streaming, voice input, and existing inventory actions remain intact.
Conversation setup and snapshot write failures must surface a safe error;
missing/foreign conversation IDs are rejected instead of silently opening a new
thread. Optional memory retrieval remains best-effort and is not claimed as a
successful history write.
