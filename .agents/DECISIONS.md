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

## 2026-09-27: A project link is an object relationship

**Decision:** `item_relationships` uses `to_item` for object links and
`project_kit_id` for `needed_by` links. A personal item has no Team workspace ID.

**Reasoning:** Project kits are projects, not inventory objects. The existing
Team workspace model leaves personal items with a null `workspace_id`.

**Implications:** Relationship reads return both directions for object links and
return project details for project links. Server authorization checks every target.

## 2026-09-27: Keep See unavailable until inference is measured

**Decision:** The authenticated `/vision/observe` endpoint returns a prompt to use
Photo, and the status endpoint reports unavailable.

**Reasoning:** The local backend has no FIND endpoint for frame embeddings or
workspace matching and no configured FIND connection. A p50 under 400 ms against a
real workspace cannot be measured here. The existing photo job takes much longer
and writes inventory, so it cannot safely serve See.

**Implications:** The mobile See mode must show the unavailable state and let the
user switch to Photo. Live inference requires a separate measured implementation.

## 2026-09-28: Map common inventory files locally

**Decision:** Import Excel, CSV, and JSON inventory files with deterministic column
mapping for familiar headers. Use the agent gateway only when the item name column
cannot be identified locally.

**Reasoning:** A remote model call delayed ordinary imports without adding value
for headers such as Name, Description, Quantity, or Part Number.

**Implications:** Keep the local header list and import tests current. Unusual
layouts retain the gateway path. A live large-file timing check is still needed.
