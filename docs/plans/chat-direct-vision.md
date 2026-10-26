# Direct chat images and explicit extraction

Ordinary world-chat photos now reach the private GLM gateway as image content.
They bypass FIND, saved-photo comparison, capture creation, and scan allowance.
The model still uses authorized inventory tools for saved-stock claims. An image
is evidence, never authority or a saved inventory record. Text/file sources use
the same explicitly selected `glm-5.3-flash-agent` model. The production gateway
advertises that ID; the old generic gateway model default was misleading.

Photos are retained in hidden assistant receipts linked to the owned user turn before generation so a failed
reply can be retried with the same request ID. Follow-ups reload only validated,
actor-owned storage paths. Arbitrary URLs and foreign paths are rejected. The
latest direct image takes precedence over an older extraction draft.

Only explicit `auto_extract=true` enters the extraction path. FIND remains the
production default. `FINDEZ_CHAT_EXTRACTION=glm_grounded` is an opt-in experiment:
validated normalized boxes, real rectangular crops, duplicate-region filtering,
batched crop identification alongside the original, and explicit Review
uncertainty. No pixel masks or verified stock counts are claimed. Crop uploads
start only after all identification batches validate. This is not an approved
replacement for FIND.

The gateway answered an ordinary workbench image question in 2.8 seconds; the
full FindEZ streaming prompt also correctly described orange pliers, perforated
metal brackets and parts bins (2.5/8.3 seconds in two probes). These probes used a
reference photo and mocked directory reads, not customer inventory. Grounding
experiments exposed unreliable structured-output support: forced tool responses
were empty; JSON-schema requests sometimes returned gateway 502; final JSON with
local schema validation was more successful but still failed a refinement batch.
The experimental implementation retries generation at most once per stage. Do
not enable it until representative-photo quality and latency pass acceptance.

Local validation: 1,371 Python tests and 10 subtests pass. Coverage includes
ordinary-photo routing, retained-image follow-ups and interrupted replies,
foreign storage rejection, valid pixel crops, duplicate/invalid boxes, strict
refinement mappings and explicit uncertainty. No migration is required.

API runtime 1beab287c0893d47d9a4411c70bdc57b05dc1d51 is live. All five CI
jobs passed for that exact source. Guarded selective publication preserved other
VM files; API and database health passed. Authenticated HTTPS QA used a fresh
disposable account: ordinary photo answer 3.5 seconds, retained-image follow-up
3.7 seconds, no capture event/draft and no inventory items created. The account
and uploaded photo were removed afterward. No customer inventory was changed.

Mobile source 9906ecc targets build 113; its separate delivery receipt records
Apple acknowledgment. Physical-device acceptance remains unverified. Broad
document OCR, exact segmentation masks, and the rest of the product roadmap
are not claimed by this change.

Live schema correction: messages_answer_context_object only permits metadata on
assistant rows. The authenticated smoke caught a user-row update rejected by that
constraint. Retention now uses the existing verified assistant write path with an
attachment_receipt flag; conversation responses hide that internal record. No
constraint or permission is weakened and no migration is needed.
