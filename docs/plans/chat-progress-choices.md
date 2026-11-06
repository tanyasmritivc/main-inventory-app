# Chat progress and choices

The mobile186 companion advances scan progress from actual received stages/crop completions, rotates wording within the current activity, adds reduced-motion-aware diagonal shimmer placeholders, and keeps every draft card behind its streamed summary. The existing per-chunk fade is immediate and has no presentation queue.

Follow-up choices are optional model-generated UI data appended after the natural-language answer using `<findez-question>` delimiters. The server streams prose before parsing the trailer, holds only partial delimiter prefixes, validates the complete JSON, and drops malformed or inaccessible choices while preserving the text question. No additional model turn, schema migration, or save action is introduced. Names from existing Space targets are canonicalized against current permissions; new Space options send a user-selected request into the normal reviewed-creation flow. Cards and summaries remain usable by older clients.

The destination tool queries at most 201 Space metadata rows from freshly authorized writable inventories. It exposes no item content and reports truncation. Greetings and ordinary replies need no destination tool.

Tests cover all delimiter split boundaries, immediate first prose, malformed trailers, duplicate/invalid options, cross-world/viewer/missing destinations, bounded metadata, and single-model-call presentation. Full backend suite: 1,556 passed. Live gateway timing: 20.503 seconds to first text; 30 text events, final text at21.823 seconds. Provider generation latency remains a limitation.

Deployment status: pending exact-source CI and staged live-source checks. Preserve the already deployed raw tools=[] gateway fix and all unrelated live changes.

Live-source reconciliation found a private READY generation followed by a separate final-answer request. The reviewed compatibility patch removes that extra pass from world chat and streams validated public prefixes directly, retaining receipt checks, control-markup filtering, diagnostics, replay restrictions, model budgets, and every unrelated live change. The complete patch is recorded in chat-progress-choices-live.patch. Seventy-six compatible tests passed against the actual staged source; three legacy-baseline assertions (ID key spelling, an already-raised token budget, and unchanged legacy-agent final-pass behavior) are excluded from that compatibility run. New-world first-delta, one-generation ordinary answers, hidden UI metadata, permission and receipt tests pass on both source variants. Full repository suite:1,556 passed.

After deployment, a synthetic two-item draft with a real model request verified both an existing Space option and a new Space option. Tightening the protocol instruction made concrete choice questions include the chooser and prevented premature destination selection. First visible text:3.205 seconds;12 streamed prose events;2 model requests (one destination lookup, then the answer);complete at3.826 seconds. No database reads/writes: all inventory metadata in this probe is an explicit synthetic fixture. This is a bounded example, not a response-time guarantee.

Delivered: backend c563044 is live; Apple acknowledged TestFlight186. Processing/tester availability remains pending and unpolled. Full receipts and limits are in chat-progress-choices186-release.json.
