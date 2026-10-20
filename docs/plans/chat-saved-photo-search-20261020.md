# Saved item photos in Chat

Scope: backend photo questions only. No mobile/web source, model/provider,
Dashboard, permissions, schema, item values or upload behavior changes. User
requested matching existing/later-added item photos, tests and App Store
submission of the already uploaded 1.0.9 (99).

Photo questions now compare with current primary and gallery photographs of
already-authorized inventory records, including photos attached after import or
item creation. Saved names need not match the vision detector's label. Matching
records and comparison coverage reach the existing model-written answer path;
there is no scripted successful answer or alternate model.

This is conservative same/near-duplicate photograph retrieval, not semantic
recognition from arbitrary viewpoints. Exact file matches are distinguished from
possible matches after resize, recompression, rotation or modest center cropping.
Neither proves product identity, dimensions, present stock or physical ownership.
The model receives those limits and must disclose incomplete comparisons.

The lookup reads current item existence/primary URLs and photo events every time.
Only scoped, previously authorized item IDs are queried. Private image permission
is checked using the requesting actor, including cache hits; matching references
and authorization are rechecked before returning. Deleted/replaced photos and
revoked access cannot survive in the result through cached pixel features. Only
configured item-image Storage locators are downloaded, never supplied external
URLs. Pixel features have a bounded five-minute process cache; no customer image
or content index is persisted. Four concurrent workers and an eight-second
comparison budget avoid unbounded work. At most 1,000 unique photos are compared
per question, with partial coverage disclosed. No new database migration.

## Validation

- 81 focused photo tests pass, including 27 new retrieval cases.
- Full Python/API-documentation suite: 1,172 pass plus 10 subtests.
- Synthetic pixel transforms, unrelated images, late gallery additions, deletion,
  concurrent removal, revocation, actor-vs-owner authorization, private locators,
  cache revocation, corruption, timeouts and bounded coverage are covered.
- A synthetic candidate service probe using the configured production Chat model
  correctly named fictional QA-PN-F117 and QA Fastener DB from the saved-photo
  match despite a different detected label. All inventory/Storage reads and
  writes were mocked; no customer data was used or changed.
- CI, selective deployment and App Store receipt: pending.

## App Store release

Existing signed build 1.0.9 (99) is VALID and APP_STORE_ELIGIBLE. A new 1.0.9
App Store draft selects that build and inherits the accepted five iPhone and five
iPad screenshots. Release is configured after Apple approval, per the user's
request to submit for distribution. New release/review notes accurately describe
this update and its limits. Apple review approval is not guaranteed. Existing
native audit evidence and physical-device/provider limitations are recorded in
`docs/plans/simulator-release-audit-20261020.md` on the mobile release lane.
Private receipts: `~/Documents/FindEZ/AppStore/submission-20261020`.
