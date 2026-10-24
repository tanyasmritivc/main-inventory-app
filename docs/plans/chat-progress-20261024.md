# Extraction progress and draft-first chat

Backend lane: feat/extraction-progress-api-20261024, based on GLM PR194.

GLM groups up to two crops into one numbered contact sheet. Eight candidates now
need at most five initial calls instead of nine. Two concurrent requests and the
100-second overall budget remain. Strict local indices prevent cross-crop assignment.
Whole-object grounding boxes crop original EXIF-corrected pixels with a small margin;
contact-sheet whitespace and labels never become saved images. No inferred refinement
from the composite is applied. Existing field/evidence validation, uncertain identity,
printed-dimension rules, private storage, signed review and explicit saving remain.
FIND stays available. No schema change.

Actual work emits public activity labels into chat SSE: photo preparation, grounding,
object details/counts, confidence/crops, draft preparation and tool activity. No private
model reasoning, tool arguments, customer labels or fabricated timed milestones.
Old status consumers remain compatible. New mobile/web clients add shiny text and an
expandable activity list. Reduced Motion renders static text. Nav unchanged.

world_draft_items stages user-described items in the existing private durable capture
contract before choosing a destination. Counts and qualitative notes survive. Unknown
counts are visibly marked placeholders and cannot be saved until explicitly edited.
Capabilities gate older clients. Existing photo drafts cannot be overwritten. The
current account/world controls access; saving rechecks inventory/Space permissions.

Validation: 1,465 Python tests plus 10 subtests passed (452 existing warnings).
Real GLM with synthetic directory: pantry example produced three items (1,2,6), the
almost-out note, no destination guess and no stock writes in17.2s. Fixture photo:
2 objects11.2s (prior release18.3s); busy8-object scene93.3s (prior100.1s),6 identified
and2 unknown. These are individual gateway measurements, not controlled percentile
benchmarks. Crowded scenes remain slow. Single-pass all-fields and higher concurrency
experiments were not retained because reliability/quality was worse.

## October 24 — Activity progress and draft-first inventory delivered (PR195)

Runtime e629825f6462a1f14d0f9e9753d6ba48cd9d7af2 is live on the self-hosted API.
All five CI checks passed (40142265790). Guarded deployment preserved 112 unrelated
files, retained GLM routing and verified API/database health and anonymous denial.
No schema changes. Real HTTPS QA passed using two disposable accounts (both deleted):
full-field extraction with confidence/crops/private previews, cross-account denial,
explicit review/save, distinct Auto Extract versus ordinary photo chat, and the
pantry prompt with three unsaved drafts, counts 1/2/6 and the almost-out note.
The live close-up request took 17.4s. Crowded scenes remain slow; no general latency
percentile improvement is claimed. 1,465 tests +10 subtests passed. Details and
measurement limits: docs/plans/chat-progress-20261024.md. Mobile/web ship separately.
