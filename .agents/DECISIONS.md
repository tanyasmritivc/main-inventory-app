# Decisions

Only durable architectural, product, or engineering decisions supported by
current code or repository records belong here. Do not bury such decisions only in
a handoff. Promote them here with date, decision, reasoning, and implications.

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

## 2026-09-23: Transactional email uses one delivery transport

**Decision:** Keep audited email orchestration, templates, idempotency, and delivery
state in `email_service.py`, while all provider delivery goes through the existing
`email_delivery.py` transport.

**Reasoning:** The production-only implementation duplicated SMTP behavior already
present on `main`. One transport preserves the existing Brevo SMTP and Resend
fallback behavior without discarding the production audit and idempotency work.

**Implications:** New transactional workflows should use the audited service. Direct
callers such as the existing Team invitation path may continue using the transport
until migrated deliberately. SMTP credentials stay server-side, and migration 035
owns the service-only `email_deliveries` audit table. Compare the live table schema
with migration 035 before treating that migration as applied in production.

## 2026-09-23: Treat `maybe_single()` as nullable

**Decision:** Code using supabase-py's `maybe_single().execute()` must handle a `None`
result, not only a response whose `data` is empty.

**Reasoning:** The pinned `supabase==2.11.0` resolves `postgrest` 0.19.x, which returns
`None` when no row matches. The INFRA-002 review verified this against the installed
library. Code that read `.data` directly crashed on every first transactional send.

**Implications:** Guard results with the `result and result.data` pattern already used
in `catalog_service.py`. Test fakes must return `None` for a missing row. A fake
returning an object with `data=None` hides this bug.

## 2026-09-23: Audited email never reports a delivered message as failed

**Decision:** When the provider has accepted a message, an audit-row update failure is
logged and the request still succeeds. The row remains `pending`, so a retry with the
same idempotency key returns a duplicate instead of resending.

**Reasoning:** Reporting 503 after delivery invites a retry and sends a second email.
The user-visible action did succeed, so reporting success is accurate. Any failure
before the provider accepts the message is still surfaced as 503.

**Implications:** A `pending` row can mean the email was delivered but its audit update
failed, or the process stopped mid-send. Search the logs for
`transactional_email_status_update_failed` before assuming it was never sent.
Account deletion removes `email_deliveries` rows because they hold third-party
recipient addresses.

## Current coordination rule: one lane per pull request

**Decision:** A change should own one clear implementation lane and avoid concurrent
edits to the same area. Use a branch or worktree for isolation.

**Reasoning:** Several coding agents and local worktrees operate on this monorepo.

**Implications:** Register active work, inspect git state, keep changes scoped, and
write a handoff only when another agent must continue unfinished work.
