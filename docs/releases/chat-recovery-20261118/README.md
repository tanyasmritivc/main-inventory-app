# Main and Space chat recovery — published November 17, 2026 Pacific

The supplied screenshots show the main organization chat. The prior release
intentionally limited inventory answer formatting to the floating Space window.
Inventory lookup presentation now applies to both: bold headings and Markdown
tables for two or more records. Scope, tools, main-chat layout and permissions
remain unchanged. Historical messages are not rewritten.

Server logs during the screenshot window (05:24–05:31 UTC November 18) recorded
two control_markup failures followed by chat_reply failure. The logs do not
include a customer message/request ID, so this is evidence from the reported
window, not a claim to have replayed the customer's exact private conversation.
The previous retry used the same streaming transport. The bounded retry now uses
the gateway's complete-message API after a control-markup error, preserving tool
receipts and the existing authorization/validation pipeline. Tool markup remains
rejected, never interpreted or executed as a command. Malformed recovery still
fails visibly. Explicit tools=[] prevents accidental gateway-managed execution
when tools are disabled. The recovery request has a 60-second timeout.

Live fictional testing exposed completed native tool arrays with repeated index=1.
Full messages now use array position rather than delta-stream indices. Final
snapshots reconcile ordered prior deltas without duplicating calls. Conflicting
snapshots and truncated responses continue to fail closed.

## Verification

- 33 focused backend regressions passed: context isolation, retries, native tool
  arrays, snapshot consistency, no replay, failure preservation, and stream parsing.
- 19 web Markdown, transport and stream tests passed.
- Six live-model fictional-data cases passed: main and Space queries, plus forced
  malformed-stream recovery in each. All returned bold headings and tables with
  fresh read tools. Requests were restricted to the configured gateway; fixture
  tools performed no customer reads or inventory writes. The final recovery run
  exercised a real gateway full tool array with indices [1, 1].
- Actual main AssistClient with mocked authentication/SSE passed at 1440px and
  390px in light/dark. Checked tables, bold text, no abandoned retry text, unchanged
  main-chat scope, and no table hydration errors. Screenshots inspected. Temporary
  fixture route removed and never published.
- Additional related backend suite: 26 passed, six failed. All six failure IDs
  match the prior baseline recorded in /tmp/findez-context-backend-tests.log
  (gateway mocks and existing reply-style fixtures). Broad suites are not green.
- Live website and API HTTP200; unauthenticated chat HTTP401. API/database health
  passed after restart. Source guards preserved 197 unrelated Python files.

## Deployment

Only the three files in manifest.json changed under /home/ubuntu/findez/backend.
No web bundle, native binary, schema or inventory data change. Rollback copies
are in /home/ubuntu/findez-chat-recovery-20261118/rollback; restore those three
files and restart findez to revert. activation.json records exact source hashes.
No Git push. Refresh and send a new question to see new answer formatting.
