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
- Production deployment pending; preserve all unrelated live source with a hash-guarded three-file overlay and rollback.
