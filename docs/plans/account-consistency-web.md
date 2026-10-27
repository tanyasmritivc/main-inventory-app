# Account consistency: web

Server-owned inventory, Space, workspace, document, checkout, review, kit, restock and memory views refresh while visible (15 seconds), on focus, visibility return and reconnect. Existing permission refresh is retained. Open editors/pending saves pause their view's refresh. Background refresh keeps the page mounted and preserves chat and input drafts. API requests explicitly bypass browser caches.

Space selection follows the stable saved ID across renames and returns to the list when that ID disappears. Inventory search keeps its current query, and reads refresh quantities/checkouts alongside the Space directory. Deleted rows are replaced by authoritative results, not merged back from prior snapshots.

Validation: 633 Jest tests across 88 suites, TypeScript, and lint (0 errors, 52 existing warnings) passed. Final focused inventory/review checks follow the search-preservation adjustment. Added cross-client rename/delete/reconnect regression. No schema, pricing, color or authentication change. CI and self-hosted deployment pending.
