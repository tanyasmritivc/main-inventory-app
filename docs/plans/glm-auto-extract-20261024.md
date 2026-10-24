# Temporary GLM Auto Extract

User requested one temporary GLM provider throughout FindEZ while FIND improves
separately. This backend-only lane preserves the public item/evidence schema,
existing inventory permissions, catalog enrichment, previews, Review and saves.
No database migration, client UI change or mobile binary is required.

## Configuration

- `FINDEZ_EXTRACTION_PROVIDER=glm` selects GLM for single/multi-item capture,
  explicit world-chat Auto Extract, and legacy image extraction entry points.
- `FINDEZ_EXTRACTION_PROVIDER=find` selects the unchanged FIND service. Default
  remains `find` to avoid implicitly changing other environments.
- Existing `FINDEZ_CHAT_VISION_MODEL=glm-5.3-flash-agent`,
  `FINDEZ_AGENT_BASE_URL` and backend-only `FINDEZ_AGENT_KEY` configure the gateway.
- The former chat-only `FINDEZ_CHAT_EXTRACTION` flag is deprecated and ignored.
  Ordinary attached-photo questions remain direct vision chat.
- Keep FIND settings and service intact for separate development and rollback.

## Fields and evidence

Every `ExtractedInventoryItem` field remains in the response. GLM supplies name,
category/subcategory, tags, count, notes, visual identity confidence, OCR text and
confidence, plus detection confidence and reasoning/review evidence. Brand and
part number must also occur in the item's visible text. Printed physical
measurements require an exact visible quote and matching unit-converted numbers.
There is no image-scale metrology. Barcode readings require readable digits and
strong model confidence; they are visual readings, not independently decoded or
verified identifiers. Provider confidence is an uncalibrated estimate.

Unknown values remain null. Purchase source and destination/location are not
inferred from a photo; the existing user-selected save destination remains
responsible for location. Catalog matches, review IDs and tokens remain
server-controlled. Unknown counts use the existing integer field's candidate
value 1 with explicit review reasons; users must confirm. All GLM candidates
remain reviewable, including high-confidence candidates.

## Crops and limits

EXIF orientation is applied before inference and cropping. Model input is JPEG
without metadata. Up to eight foreground objects are grounded per request;
cluttered/overlapping scenes or limits produce `summary.partial=true` and an
explicit review reason visible in existing clients. Each crop
is identified independently, with at most two concurrent calls. Original pixels
supply the final crop, with validated bounds, optional tighter refinement and a
small edge margin. Near-duplicate detections are removed. Tiny label-only
refinements are rejected in favor of the original whole-object crop and a review
reason. If an individual identification fails, retain its crop as an explicitly
unidentified candidate and mark the result partial; all failed identifications
produce an error. Crops are JPEG, at most 1280 pixels per side.

Rectangular crops cannot remove overlapping neighbors and are not segmentation
masks. Clear, close photos are the intended input. No claim of calibrated
measurement, perfect recall or accuracy parity with FIND is made.

All candidate fields and crops validate before storage. Failed partial storage
attempts clean up already-created crop files. No inventory write happens in the
provider. Invalid model output can retry once; network failures do not trigger a
silent retry/fallback. The provider deadline is 100 seconds; each HTTP call is
bounded by the remaining budget and a 40-second limit.

## Operating costs

Normal extraction uses one scene call plus one vision call per candidate (up to
nine calls). Invalid JSON may add one retry per call. Costs depend on the existing
gateway's compute/provider agreement; no new subscription or priced service is
introduced. Original images and crops consume existing object storage and
bandwidth. Existing scan limits remain enforced.

## Validation and manual acceptance

Automated coverage checks complete response fields, confidence bounds, printed
measurement/part-number safeguards, unknown counts, crop geometry, duplicate
removal, EXIF/privacy normalization, upload cleanup, deadlines, provider selection,
preview ownership and explicit versus ordinary chat attachments.

After activation, on both web and mobile:
1. Open Auto Extract with a clear photo of two objects, including a readable part
   label. Verify both draft rows and their individual photo previews.
2. Open item details. Check category, quantity, brand, part number, notes, OCR,
   confidence and review reasons. Unreadable fields must remain unknown.
3. Cancel the draft and confirm inventory did not change. Extract again, review,
   choose a destination and save; open the saved item and confirm crop/fields.
4. Repeat from chat Plus > Auto Extract. Ordinary Attach + a question must still
   answer the question without creating an extraction draft.
5. Try a cluttered scene. Check the incomplete/partial result and review uncertain
   counts instead of assuming all objects were captured.
6. Switch accounts/organizations; previous private drafts and images must remain
   inaccessible to unrelated accounts.

Deployment and real-provider verification results are recorded below when run.

## Gateway integration finding

The deployed gateway is an agent, not a raw model completion proxy. Its OpenAPI
`RunOptions` supports `enabled_tools` and `max_steps`. Extraction explicitly
disables external tools, bounds the run to two steps, and instructs finalization
to put serialized JSON inside the final action's nonempty `answer`. Asking for
bare JSON while forbidding all tools intermittently caused HTTP 502 with
"Final action did not contain a non-empty answer". Preserve this distinction.
Each identification call contains one image, so assembly uses the trusted request
index rather than the model's global index. Unknown prose/category/count values
are normalized without inventing identity or count confidence.

Initial activation of dfff1fc passed all five CI gates and candidate API
preview/private-image/review/save QA (15.8s), but the broader live chat check
exposed the gateway issue. The provider was restored to FIND while correcting
that integration. The corrected candidate passes 1,453 Python tests plus
10 subtests (452 warnings); final activation results will be appended below.


Corrected candidate API QA passed against real GLM and disposable accounts:
24.9-second extraction identified the flange at 0.85 model confidence and kept
an orange edge fragment unknown at 0.35. It verified full response keys, identity
confidence, signed preview, private crop access, unrelated-account denial,
explicit review/save and retained crop. Chat Auto Extract produced a crop/evidence
draft; ordinary photo questions did not. Neither chat operation wrote stock.
Both accounts, their inventory and uploaded objects were cleaned up. A cluttered
workbench probe returned eight candidates in 100.1s (six identified, two unknown,
partial). This is a limited smoke test, not an accuracy benchmark. Physical-device
acceptance is still manual.

Final local checks after measurement-unit safeguards: 1,458 passed,
10 subtests passed, 452 warnings. Labeled dimensions support joined units and
mixed-unit groups; unsupported fractions remain unknown. Confidence below 0.5
shows Unknown item with the tentative description only in notes.

Rollback: set `FINDEZ_EXTRACTION_PROVIDER=find` in the FindEZ systemd environment,
run `systemctl daemon-reload` and restart `findez`. The current override is
`/etc/systemd/system/findez.service.d/90-glm-extraction.conf`. Confirm `/health`
and `/health/db`; FIND code and credentials have not been changed.
