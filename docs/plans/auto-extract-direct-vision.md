# Auto Extract with whole-photo vision

User instruction: make Auto Extract use the successful attached-photo analysis;
ordinary chat attachments and AI chat must not change.

The explicit Auto Extract branch and both inventory extraction endpoints opt into
`direct_photo=True`. Default extraction dispatch remains the existing GLM/FIND
path for legacy chat callers. No chat prompt, model setting, gateway client,
ordinary attachment branch, mobile/web UI or database schema is changed.

The new provider makes one whole-photo streamed vision call using the configured
chat vision model, the user's photo-listing prompt, no tools, an 8192-token ceiling
and a 110-second timeout. A second, text-only call converts that description to
rows (60-second timeout). It cannot invent quantity values: the server requires
verbatim description evidence and derives the count or lower bound from that
quote. Approximate quantities and ranges stay estimated, unknown counts retain
the existing review-only placeholder, and no stock is saved automatically.

The two steps do not ask the vision model for bounding boxes. Rows use the owned
source-photo preview, avoiding duplicate uploads and slow crop inference. This
release does not provide tight per-item crops. Optional printed identifiers and
sizes are not promoted to verified structured fields from prose; the original
observation is preserved in notes. All rows require review. This improves the
workflow, not the underlying model's truthfulness or counting accuracy.

The deployed optional recognition-learning receipt is retained under its original
actor/inventory context; this path does not retrieve reference images. Existing
GLM extraction stays intact for legacy callers and rollback. Broad release is a
four-file guarded overlay: new direct provider, dispatcher opt-in, two dedicated
item extraction calls, and one flag inside world chat's explicit auto_extract
branch. All unrelated production source files must match their recorded hashes.

Validation before deployment: 1,627 local backend tests pass. Focused tests cover
stream truncation/tools, EXIF stripping, exact versus estimated versus unknown
counts, table-formatted answers, ungrounded rows, source-image reuse, upload cleanup,
and unchanged legacy dispatch. Isolated production-candidate tests pass (81).
The same original parts-bin image was recovered from earlier private scan fixtures.
Its natural photo answer completed in 14.53 seconds in a standalone probe. A first
structured candidate completed in 48.37 seconds; table-count validation identified
and fixed a conversion issue before activation. Final end-to-end receipts follow.

## Live release — November 11, 07:57:52 UTC

Runtime `d755769d573af0540fc71222987b96fe33d9c0bb`, PR389. All five CI jobs pass
in run42982555391; backend CI reports 1,638 tests. One existing legacy grounding
parallelism test initially observed three simultaneous workers instead of four
in its 20ms sleep window; the unchanged job passed on rerun. No test or old
extractor code was altered to bypass that check.

The guarded four-file overlay preserved 168 unrelated Python files. Ordinary
chat services/prompts, default legacy extraction dispatch, gateway configuration,
mobile/web UI and database schema remain unchanged. The only world-chat route
edit is the opt-in flag inside its already-existing explicit auto_extract branch.
API/database health and anonymous extraction denial pass. Private server receipt,
rollback and candidate sources: `/home/ubuntu/findez-auto-extract-direct-20261111`.
New provider SHA256: `78e3026d848d9e59ca5468f0bc92691eb56e9cf494749690aef97c55ca36728f`.

Final candidate HTTP: crowded image 29 rows in 31.0s (13 estimated), regular photo
6 rows in 10.7s. Live public HTTPS: same crowded image 31 rows in 43.1s (13 estimated),
regular photo 6 rows in 33.1s (one estimated, one unknown count). Both runs returned
durable editable drafts and terminal completion, without automatic retries or
inventory writes. Disposable accounts and all test uploads were removed. These
are individual observations, not latency guarantees or validated exact counts.
The original source photo is the row preview; tight per-item crops are not part
of this path. Physical iPhone acceptance remains for the user; no new binary is
needed because this is a backend-only change.
