# Capture save timeout recovery

## Evidence and scope

The creation-to-draft fix succeeded. The next item insert encountered PostgREST
SQLSTATE 57014 (statement timeout), producing one unconfirmed-save message per
item. The configured database statement timeout is eight seconds. Read-only
inspection subsequently confirmed the same draft was saved with 27 records,
27 processed entries, and zero failures. No manual customer data repair is needed.
The precise transient contention source was not established; a read-only sample
of four image permission checks completed in about eight milliseconds.

## Behavior

Capture inserts are limited to eight records per statement while retaining all
database permissions, triggers, and the existing timeout. After an insert, the
backend reads stable item IDs to establish actual receipts. A known 57014 failure
can be retried once per request, only for missing IDs after a successful receipt
read. Unknown outcomes, unavailable receipts, and other errors are not blindly
retried. Existing rows are never upserted or overwritten. On an unresolved batch,
remaining writes stop and the existing draft can resume safely on retry.

The bulk endpoint still returns one indexed result per item. Only the capture
receipt display groups identical failure reasons. Each group retains `index`
and `reason`, plus an optional `indices` list for all affected items. Single
failures retain their original shape. Existing mobile clients render these as
one message per reason. Chat summaries count affected indices, not groups.
No schema, environment, mobile, or web changes are included.

## Verification and release

130 targeted tests pass across timeout recovery, capture persistence, edited
draft handoff, and Space creation. One known baseline-failing old capture binding
assertion remains deselected; broader historic test drift is documented in
`space-chat-latency.md`. Regression cases cover timeout before commit, lost
success responses, failed receipt reads, repeated failure, partial success,
stable retry identities, unchanged quantities, and grouped error counts.

Deploy only `app/services/capture_save.py` and `app/services/chat_capture.py`.
The prechange source is recorded in `064a3de0`. Deployment compares checksums,
backs up both files, checks the runtime, restarts `findez`, and verifies health.
Release directory: `/home/ubuntu/findez-capture-save-batches-20261108`.
Rollback restores both files from its `backup` directory and restarts `findez`.
No customer save is issued during deployment verification.

Deployed on 2026-11-08 as commit `0cfaadda`. Only the two expected Python files
changed. Their checksums matched, the web process remained unchanged, and local
and public health endpoints returned 200. Synthetic checks in the deployed
runtime verified recovery of a 27-item timeout, duplicate-free retry, and error
grouping without database writes. Real future timeout latency remains dependent
on database availability; this change does not guarantee every save succeeds.
