# Memory, action context and photo previews

Backend lane: fix/api-memory-and-action-context. No web layout changes.

The actual effective personalization state is supplied to chat. Conversation recall is independent of durable preferences. Missing settings default on; migration 084 initializes new accounts and untouched defaults while retaining explicit off/reset revisions. The visible Memory switch enables the learning profile. Notification opt-ins are unchanged.

World tools retain canonical inventory_id/source and target_inventory_id/destination names, with the shared bounded private-data filter intact. Requests without direct-write authorization retain their review card. Invalid argument diagnostics contain field names only.

Mobile photo preview is additive: preview_only requires auto_extract and supports_capture. It saves one durable capture, returns it, and skips the chat model and chat allowance. Older clients retain their existing path. Blank photo captions remain blank.

Verification: 1,572 backend tests and 10 subtests pass (452 existing warnings). Migration 084 replayed on a network-isolated schema-only production clone. Synthetic SQL checks cover new defaults, explicit opt-out, switch synchronization, notifications remaining off, and private RPC denial. Run backend/tests/sql/personalization_defaults.sql only in a disposable database after 084.

Deployment: apply 084 before code, retain private backup, publish only changed API files after all five CI gates. No provider or production configuration changes required. Exact original customer mutation failure has not been replayed; the source/destination contract defect is verified. Physical mobile acceptance remains separate from backend tests.
