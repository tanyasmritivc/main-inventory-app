# Stable chat answer delivery

## Problem

Immediate client streaming exposed intermediate GLM openings before tool calls, transport retries and answer repairs. Those attempts emitted reset events, so the visible answer disappeared and returned to working repeatedly.

## Change

The organization, inventory and photo-answer HTTP streams suppress private deltas and resets. After final validation and successful history persistence, they deliver the exact saved answer in word-aligned chunks, then the identical completion receipt. Existing web/mobile fades animate arrival. Progress remains available before text; a terminal answer ends the event loop. The shared helper preserves Unicode, Markdown and whitespace and bounds presentation to at most 40 chunks, separated by 25ms (under one second of added cadence).

This does not speed up model reasoning. It deliberately waits for a settled answer so drafts never appear as facts. No client binary, schema, provider, scope, tool or write behavior changes. Very short answers may arrive as one fading chunk.

## Validation

- 107 focused tests passed.
- Full backend: 1,624 tests plus 10 subtests passed.
- Regression tests cover multiple provisional openings/resets, generation and persistence failures, stable final chunk concatenation, terminal event ordering, photo answers, exact whitespace/Unicode and cancellation during delivery.
- Real loopback HTTP/SSE probe: 12 separate chunks over 0.288s, minimum interval 25.6ms; saved before first delta, identical terminal text, no resets or progress after answer. Synthetic model output and mocked persistence; no customer data or writes.
- Runtime `84dd1cf0159373a14f1f6f6708935ebc318759fe` deployed after all five CI gates (40816903062) passed. Three-file overlay preserved 130 unrelated backend files; rollback snapshot retained on server.
- Public API/database health, website HTTP200 and anonymous denial pass. No client binary or migration required. Main stays `1c97e1f4838ee6fbda6ea97ed34fc275cc3b9db0`.
- No new real-account model query or physical-device animation acceptance was performed for this server patch. Existing client animation is unchanged; the regression and HTTP checks use controlled upstream sequences.
