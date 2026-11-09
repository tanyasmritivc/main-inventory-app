# Creation-to-capture handoff

## Cause and fix

The mobile combined creation/save button requires a `capture` in the existing
structure-action confirmation response. A successful creation receipt could omit
it because `attach_created_destination` rejected any revision change after the
proposal. Read-only production diagnostics confirmed a revision-2 binding and a
revision-3 draft with no destination, the same requested place, and one matching
Space receipt. The earlier standalone Space shortcut skips capture drafts and is
not involved in this path.

The handoff now allows item edits while checking the actual destination intent:
the draft must remain editable and unplaced, any selected inventory must match,
and any requested place must still match. Legacy bindings still require a named
place match. Future binding revisions and ambiguous receipts remain rejected.
The existing `edit` service reauthorizes the destination and compares the current
revision atomically. Item edits, selection, photos, unknown-count evidence, and
save checkpoints are preserved. An already-attached receipt remains idempotent.

Creation still does not save inventory. The existing mobile button receives the
updated draft and calls the existing explicit save endpoint. No API shape,
database migration, client source, or App Store build changes.

## Validation

The regression suite reproduces the problem on baseline `5efb0ef8` (11 failed,
13 passed) and passes all 24 handoff tests after the fix. Combined with capture
and standalone Space tests: 100 passed, with one previously baseline-confirmed
outdated capture-binding assertion deselected. The broader historic suite has
unrelated runtime/fixture drift documented in `space-chat-latency.md`.

## Release

Only `app/services/chat_capture.py` is deployed, after comparing its live hash
and backing it up. Release directory:
`/home/ubuntu/findez-capture-handoff-20261108`.
The original live file is in `backup/app/services/chat_capture.py` under that
directory. Rollback restores that file, restarts `findez`, and checks `/health`
and `/health/db`. The production checkout is not reset or replaced.

The user's existing confirmed card can be retried without recreating the Space.
Verification never creates or saves customer inventory on the user's behalf.

Deployed on 2026-11-08 as commit `d951ac25`. The deployed file hash matched,
all other backend Python sources were unchanged, the web process stayed running,
and both local and public health endpoints returned 200. Synthetic checks on
the deployed runtime verified the revised-draft handoff and changed-destination
guard without database writes. The user's physical-phone retry remains unverified.
