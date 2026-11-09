# Space creation latency

Backend-only change on `fix/space-chat-latency`, based on the live self-hosted
world-chat source recorded in `e4b1174a`. The baseline commit records already
deployed code, not a separate behavior change. Do not deploy that checkout wholesale.

## Scope

For a new conversation, commands such as `create a space called bathroom` can
prepare the existing confirmation card without model planning, stock retrieval,
or a model-authored summary. Reads are authorized inventory directory metadata
and exact matching Space identity metadata. Existing directory summaries can
still calculate counts in the database; no item records are loaded into chat.

The shortcut reuses the existing Personal/organization destination policy and
the existing creation proposal validators. Proposal creation rechecks access.
Nothing is saved until the existing confirmation endpoint authorizes and commits
the user's confirmation. Old and modern client card formats are preserved.
An existing exact Space is reported without proposing a duplicate.

The shortcut is deliberately narrow. Prior conversation context, attachments,
selected sources, extraction drafts, response retries, complex commands,
ambiguous destinations, and incomplete metadata results retain the regular flow.
It does not accelerate every chat request or the older inventory-specific agent.
The mobile's initial generic loading label remains unchanged; no app build is needed.

## Validation

Tests run against a fresh production source snapshot with placeholder credentials.
`test_chat_space_creation.py` covers zero model calls, metadata-only reads,
confirmation contracts, existing destinations, permission revocation, ambiguity,
and contextual/capture/retry fallback. Existing capture tests cover the unchanged
draft and receipt flows. Their outdated expectation for `capture_destination`
omits `revision`; that single failure reproduces on the unmodified live baseline.
The older inventory-knowledge test imports a helper absent from deployed source.
These unrelated test mismatches are not repaired by this change.

Results: 45 new shortcut tests pass. Focused shortcut/capture validation has
76 passes after excluding the one baseline-confirmed outdated assertion. The
broader snapshot suite (excluding the uncollectable old inventory-knowledge
module) has 230 passes and 40 failures, versus 185 passes and the identical 40
failures on the unchanged baseline. No new failure cases were introduced. The
old suite is not claimed green; it has unrelated runtime/fixture drift.

## Deployment and rollback

Only `app/services/world_chat.py` and `app/services/chat_space_creation.py` are
deployed to `/home/ubuntu/findez/backend`. Preserve the dirty server checkout,
verify the previous checksum, back up the old file, compile/import the overlay,
restart `findez`, and check `/health` and `/health/db`. No database migration,
environment change, web deployment, or mobile build is required.

Release backup: `/home/ubuntu/findez-space-chat-20261108/backup`.
Rollback restores the original `world_chat.py`, removes only the newly introduced
`chat_space_creation.py`, restarts `findez`, and rechecks both health endpoints.

## Deployed result

Commit `7b263a31` deployed on 2026-11-08. The two source checksums matched, every
other backend Python source remained unchanged, and the web process was not
restarted. Both local and public health endpoints returned 200. Synthetic checks
on the deployed runtime exercised old and modern confirmation contracts with
database/model calls blocked. No customer Space was created during verification.
An authenticated physical-phone round trip has not been measured.
