# Per-item photo close-ups, October 16

## Verified cause and implementation

The existing FIND integration guide specifies per-item images at
`GET /v1/jobs/{job}/items/{item}/crop.jpg` and bbox `[x,y,width,height]` in
its stored image frame. The adapter only fetched an explicit crop URL/path and
otherwise interpreted bbox as opposite corners against the original upload.
An item at x greater than its width produced an invalid rectangle and fell back
to the full source. The mobile Review, scan and inventory views already use each
item's `image_url`, independently of confidence.

The adapter now generates the documented crop request for valid item IDs when
no explicit crop path is provided. It requests a masked close-up up to 1024px,
decodes it and persists a JPEG in the existing account/inventory-scoped Storage
before deleting the temporary job. Crop errors fall back to the correct bounding
rectangle, scaled using result width/height. Invalid/missing geometry continues
to use the original image, never an invented crop. Existing explicit crop paths
and named-corner aliases remain compatible. Identity certainty, review status,
preview signatures, authorization, provider/model selection and transport settings
are unchanged. Original source URLs remain separate.

The notification bell is also added to the existing Review and Space page
app bars from the screenshots. No other inventory/Space layout is redesigned.
Build number is 74.

## Validation

Full backend suite: 814 tests and six subtests pass. Twelve new cases verify real
pixel content/size, stored-frame scaling, invalid boxes and low-confidence crop
persistence through successful, 404, invalid-image and timeout outcomes. Legacy
crop tests now use actual image bytes and the documented bbox format.
Flutter analysis is clean and the full Flutter suite passes all 462 tests.
The signed beta74 release receipt will follow.
The preceding web suite passed 329 tests; this stage changes no web code.
No regression checks are repeated after pushing/building the checked source.

## Publication and limitations

The reviewed one-file backend overlay is published on the self-hosted service.
Private backup, candidate hash, import and rollout receipt are in
`/home/ubuntu/findez-crop-release-20261016`. All 91 unrelated backend files match
the predeployment hashes, public health is 200 and unauthenticated extraction is
401. No schema changes, customer-photo scans, record updates or backfill were
performed. To roll back, restore find_pipeline-before.py and restart only findez;
there are no migrations to reverse. Earlier notification/deletion protections
remain installed. Existing FIND transport review remains separate and unchanged.

Existing records may only retain a source image or an incorrectly generated crop;
there is no saved geometry to safely repair these automatically. A fresh scan is
required. Actual new-camera visual acceptance and segmentation quality are not
established by the synthetic regression tests. The upstream detector can still
propose an inaccurate region, and the UI honestly retains low-confidence review.

## Manual acceptance

1. Scan a photo with several separated items, including an item near the bottom
   right and a small unknown item. Confirm distinct close-ups in the scan preview.
2. Save uncertain detections to Review; reopen them and confirm the same close-up
   while the confidence warning remains. Correct one and add it to inventory.
3. Open the item's Space and refresh web: primary thumbnails should match the
   saved close-up. Original source must not replace an available crop.
4. Test a fresh photo on an iPhone, light/dark appearance and larger text. Verify
   the Review and Space bell opens the same authenticated inbox.
5. If no usable crop/geometry exists, the original remains the honest fallback.
   Previously saved screenshots/records will not automatically acquire new crops.

## Changed files

- `.agents/ACTIVE_WORK.md`, `.agents/CURRENT_STATE.md`, `.agents/DECISIONS.md`
- `.agents/ARCHITECTURE.md`, `TESTING.md`
- `backend/app/services/find_pipeline.py`
- `backend/tests/test_find_pipeline.py`, `backend/tests/test_capture_crops.py`
- `mobile/lib/features/inventory/inventory_page.dart`
- `mobile/lib/features/review/review_queue_page.dart`, `mobile/pubspec.yaml`
- `docs/plans/capture-crop-fix.md`
