# MOB-004 Phase B ASK architecture

## Objective and status

Phase B establishes one production ASK execution path for text and attachment
questions. ASK remains the query interface to FindEZ physical memory, not a generic
chatbot. Implementation is complete on `mobile/mob-004-phase-b-integrated` at
application commit `7f3bb1f3a7f5e8ed5716796de39baeffeae1e22e`.

## Architecture implemented

The active path is now:

`ChatPage -> AskController -> AskClient -> AskSseDecoder/AskEventAdapter -> /ai_command or /ai_upload`

- `AskClient` owns authentication, text and multipart requests, timeouts, transport
  errors, stream normalization, client lifetime, and cancellation.
- `AskController` owns request lifecycle, busy/status/error state, conversation
  identity, navigation events, and the canonical shared message state.
- `ChatPage` renders and collects input, applies presentation timing, invokes the
  controller, shows user-facing errors, and renders navigation actions. It no
  longer creates ASK HTTP clients or parses SSE.
- Typed and speech-recognized text enter the same `_submit` path. The existing
  `speech_to_text` implementation is unchanged.

## Files changed

- `backend/app/api/routes/ai.py`
- `backend/tests/test_ai_stream_routes.py`
- `mobile/lib/core/api_client.dart`
- `mobile/lib/features/chat/ask_client.dart`
- `mobile/lib/features/chat/ask_controller.dart`
- `mobile/lib/features/chat/ask_event.dart`
- `mobile/lib/features/chat/ask_sse_decoder.dart`
- `mobile/lib/features/chat/chat_page.dart`
- `mobile/test/ask_controller_test.dart`
- `mobile/test/ask_sse_decoder_test.dart`
- `mobile/test/chat_page_ask_test.dart`

## Streaming protocol decisions

The decoder follows the real backend protocol rather than introducing a new wire
format. Text ASK emits JSON `content`, optional `nav_hint`, a new
`conversation_id` frame, backend `error`, and `[DONE]`. Upload ASK emits typed
`status`, `delta`, and `done` JSON frames followed by its existing named terminal
SSE event. One incremental UTF-8-safe decoder handles partial chunks, CRLF/LF,
multiple frames per network chunk, comments/padding, and incomplete final frames.

The internal normalized model is `status`, `delta`, `conversation`, `navigation`,
`error`, and `done`. Unknown or malformed payloads become public errors. Tool
payloads and raw results are never exposed.

## Backend and continuity

`/ai_command` now emits the effective conversation ID before content while keeping
the existing content/navigation/terminal protocol. The existing web stream parser
already consumes this optional frame, so web behavior remains compatible.
Follow-up mobile requests send the returned ID.

`/ai_upload` now accepts an optional multipart `conversation_id`, creates or
validates a conversation through the same helper, persists a filename-only user
message, persists the assistant summary, and returns the effective ID on the typed
done frame. The uploaded bytes are not retained for conversation history and no
migration or table was added.

Backend stream failures return a stable public error and do not expose exception
text. The authoritative `ai_service.py`, `AgentGatewayClient`, and FTCTools gateway
runtime remain unchanged. No retired OpenAI runtime, dependency, configuration, or
environment variable was restored.

## Cancellation, retry, tools, and navigation

Closing the per-request HTTP client cancels an active stream; the controller also
cancels its subscription and ignores stale generations. The send control becomes a
user-visible stop control while streaming. There are no automatic retries because
ASK may execute mutating tools and replay could duplicate inventory operations.

Successful completed ASK requests retain the existing inventory refresh callback
and snapshot refresh. Navigation hints still render as user actions. Tool selection
and execution remain backend-owned.

## Validation

- Focused Flutter ASK tests: 21 passed.
- Focused backend ASK route tests: 6 passed, with one dependency deprecation warning.
- Full Flutter suite: 48 passed.
- `flutter analyze`: no issues.
- Full backend suite: 205 passed plus 6 subtests, with two dependency deprecation warnings.
- `git diff --check`: passed.
- No native iOS files changed, so no iOS build was required.
- No physical-device validation was performed.

Coverage includes real protocol decoding, partial and combined chunks, malformed,
empty and unexpected events, terminal behavior, transport errors, cancellation,
no automatic retry, controller state, conversation propagation and reuse,
attachment association, navigation rendering, and post-ASK inventory refresh.

## Remaining MOB-004 work and next step

No Phase B blocker remains. Later MOB-004 phases were not started. The exact next
step is to review the application commit, then perform an authenticated iOS
simulator smoke test for a two-question conversation, attachment history,
navigation action, and stop behavior before merging. Any later MOB-004 phase must
begin from its separately approved scope after Phase B is accepted.
