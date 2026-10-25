# Chat stream reliability, October25

The apartment-inventory request failed in both mobile and web. Production logged
RuntimeError in completion_events. A write-blocked synthetic reproduction returned
finish_reason=length at1800 and2400 tokens, with7216 and10144 reasoning characters,
no response content and no tool arguments. The model's internal reasoning consumes
the same output budget as structured proposals.

At8192 tokens, the same fixture returned complete tool calls and a3351-character
creation proposal. Generation now allows8192 tokens and one bounded16384-token retry.
This is a maximum, not a requirement to generate long user-facing text. Existing
short-response instructions, final receipt checks, tool argument/index bounds and
mutation confirmation remain unchanged. A failed generation never executes partial
arguments, and already executed tools remain memoized across the retry.

Parser errors have fixed internal reason codes (output_limit, content_filter,
tool_index, tool_size, text_type); logs include only code and token budget, never
prompts, provider reasoning, item details or credentials. Mobile separately reuses
the failed assistant row and request ID instead of appending duplicate error rows.
No web bundle change is required because both clients use the shared API.

Verification:1529 Python tests passed (451 existing warnings;10 subtests). Focused
stream/world suite59 passed. Mobile Ask regression and clean analysis passed.
Physical-device retry acceptance is not yet verified. No customer records were
created/updated by model diagnostics. CI and release receipts follow deployment.
