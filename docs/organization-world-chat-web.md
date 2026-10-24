# Organization chat and direct Space items

## Behavior

Selecting an organization opens `/worlds/<organization-id>`; Personal uses
`/worlds/personal`. New chat, Spaces, Search and Tools stay at that level.
Chat searches only authorized inventories in the selected world. Conversations
remain private to the signed-in actor, not visible to every organization member.
The existing mobile `/worlds` service handles current membership, grounded
retrieval, direct edits, durable request IDs and reviewed create/delete actions.
No backend, database or Flutter changes are part of this release.

Spaces combines authorized inventory directories and opens the existing editable
item view directly. Legacy `/home?inventory=...` redirects to Items after access
verification; `/assist?inventory=...` resolves its organization and preserves the
question. Organization Tools retains capture/import, documents, review, activity,
restock, checkouts, project kits, collections, labels and inventory settings.
Earlier private inventory chats remain readable/deletable in Tools > Earlier chats.
Workspace administration (people, locations, tasks, files, activity and settings)
remains available through Workspaces. No Google/unfinished connectors are added.

## Implementation

- `world-navigation`, organization/workspace navigation, switcher and shell share
  organization destinations. Protected route and theme lists include `/worlds`.
- `world-workspace` loads the current authorized directory, lists Spaces, and
  provides manual Space creation through the existing inventory service. Revoked
  access clears cached views; account/organization changes remount private state.
- `assist-client`/`ask-stream` use world endpoints, scoped drafts/history, private
  account tokens, cancelled stale requests and same-request retry identifiers.
- `world-chat` and cards validate review plans, receipts and resource links. A
  fresh authorized resolver call precedes navigation to saved records. Creation
  plans include their item additions and moves in one confirmation.
- Existing inventory editing and project detail services are reused. Ordinary
  photos remain chat photos and never automatically invoke extraction.

## Validation

Local: 525 tests in 70 suites passed. The archive's focused two tests passed again
after cleanup. TypeScript passed. ESLint: zero errors, 52 unchanged baseline
warnings. Production webpack build passed with placeholder public Supabase config;
real server configuration is used for the release build. Initial sandbox build
could not download fonts; an unrestricted rerun exposed missing build env vars,
then the configured build passed.

Chrome visual review used fictional local API fixtures, with writes disabled:
organization chat, organization Spaces in light/dark, 390px responsive Spaces,
direct Space items and the existing Edit Item dialog. No customer inventory was
changed. The new Spaces console had no hydration errors. Existing item-dialog
missing-description warnings are outside these changes.

Deployed backend source hashes for `routes/world_chat.py`, `services/world_chat.py`
and `services/world_tasks.py` exactly match the inspected current API worktree.
The public OpenAPI document is disabled (404); compatibility was verified from
actual deployed sources and an unauthenticated world-directory 401 response.

## Manual verification

1. Choose an organization from the sidebar. Confirm New chat and Spaces stay
   visible before selecting any inventory. Ask where an item is across its Spaces.
2. Open History. Switch organizations and verify that each has its own history
   and draft. New chat resets the current conversation.
3. Open Spaces and select one. It must open its items, not an inventory dashboard.
   Use an item action > Edit item; review fields and Cancel without writing.
4. With an authorized disposable account, update an item and confirm its saved
   quantity. Ask for a new inventory, Space and items; one review completes all.
   A viewer must be denied writes by the server. Retry a lost response safely.
5. Open an item link from a chat. Remove its access in a disposable test account;
   reopening must fail without exposing the record.
6. Tools retains existing inventory features and Earlier chats. Workspaces retains
   workspace management. Test manual Space creation with a disposable inventory.

## Release

Self-hosted web candidate and CI checks pending. Production authenticated chat
and write verification still requires the user's signed-in session; local fixtures
and existing API tests are not a live model/database round-trip.
