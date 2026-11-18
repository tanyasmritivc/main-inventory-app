# Inventory chat readout — November 17, 2026 (published)

The reported "what gears do I have?" failure was reproduced against the selected
organization's authorized reads, using the current account context and no saved
conversation/stock mutations. The failing reproduction used 26 read operations,
exhausted all eight tool rounds, and emitted control markup after tools were
disabled. The buffered retry also emitted markup and failed closed.

## Cause and change

Nested spreadsheet field values hit the shared provider depth limit. Bulky item
records also exhausted its 12,000-character data budget before all useful fields
reached the model. A 15-record result had about 160 omitted-value markers. The
model repeatedly searched for missing descriptions. Separately, the query schema
did not explain that terms are AND constraints, so lists of alternative gear types
returned zero matches and encouraged more queries.

Inventory search/query previews now prioritize exact IDs, names, quantities,
locations, part descriptions and verified links for up to 20 rows. Imported scalar
fields are flattened. Optional details follow the essential rows; shared privacy,
URL, size and depth guards still apply. Full records remain in server receipts.
Complete totals and display truncation remain distinct. Price, expiry and reorder
fields remain available in the optional details. Tools now explain AND matching
and organization-wide lookup; the final tool-free round explicitly asks for a
grounded answer with any remaining limits. Control markup remains rejected,
never parsed into executable commands.

## Validation

- 49 focused regression tests passed, covering imported descriptions, all-row
  quantities, unknowns, zero values, capped previews, tool-limit completion,
  organization isolation, private history, retries and existing write guards.
- 54 additional related tests passed; eight failed. An isolated unchanged HEAD
  baseline reproduced the same eight failures. The broader suite is not green.
- Six live-model fictional cases passed with 15 bulky imported gear records,
  main and Space contexts, including the reported phrasing and a typo. All
  completed with bold headings and substantial tables. One additional real-model
  case completed after forcing eight tool rounds with fictional evidence.
- Candidate main and Space replays of the reported question each completed with
  one organization query and a table (18.5s and 16.0s). No inventory writes or
  conversation saves were enabled. Later diagnostic runs also disabled optional
  search analytics. The first baseline run used normal read-tool analytics.
- Deployed source hashes, API/database health, public routes and unauthenticated
  chat rejection passed. Deployed main and Space replays completed with one
  query and a table in 10.9s and 13.5s respectively. Replay receipts are metadata
  only; customer answer text and inventory contents are not saved in this folder.

The diagnostic directly exercises the authorized service/model path, not a full
signed-in Safari click or browser history save. UI/rendering is unchanged by this
backend release. Existing failed messages are not rewritten. Provider failures
remain possible; these checks establish the reproduced failure path was fixed,
not that every account and every possible question has been exhaustively tested.

## Deployment and rollback

Changed only the three manifest files under `/home/ubuntu/findez/backend`.
198 other Python sources preserved. Web shell remains on its existing release.
No schema, model/provider configuration, inventory mutation, mobile binary or
Git push. Restarted `findez` after guarded source/hash checks; activation includes
automatic rollback for failed health checks.

Rollback restores `world_chat.py` and `world_insights.py` from
`/home/ubuntu/findez-chat-readout-20261118/rollback/app/services`, removes only the
new `world_inventory_preview.py`, and restarts `findez`.
