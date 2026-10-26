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

- 82 focused photo tests pass, including 28 new retrieval cases.
- Full Python/API-documentation suite: 1,173 pass plus 10 subtests.
- Synthetic pixel transforms, unrelated images, late gallery additions, deletion,
  concurrent removal, revocation, actor-vs-owner authorization, private locators,
  cache revocation, corruption, timeouts and bounded coverage are covered.
- A synthetic candidate service probe using the configured production Chat model
  correctly named fictional QA-PN-F117 and QA Fastener DB from the saved-photo
  match despite a different detected label. All inventory/Storage reads and
  writes were mocked; no customer data was used or changed.
- All five CI jobs pass on runtime `5bc885d0999394a23f92e3e4facbe8b3747d1119`,
  run39397356053 (PR146).
- The two-file backend overlay is live; source hashes match the tested candidate.
  All99 unrelated Python files are unchanged. API/database health pass, and
  anonymous private-photo/Chat requests are denied (401).
- Dedicated Apple review login/workspace read, public privacy/terms/support/API
  links and inherited screenshot checksums pass. The excluded founder account
  was not used.

## App Store release

Existing signed build 1.0.9 (99) is VALID and APP_STORE_ELIGIBLE. A new 1.0.9
App Store draft selects that build and inherits the accepted five iPhone and five
iPad screenshots. Release is configured after Apple approval, per the user's
request to submit for distribution. New release/review notes accurately describe
this update and its limits. Apple review approval is not guaranteed. Existing
native audit evidence and physical-device/provider limitations are recorded in
`docs/plans/simulator-release-audit-20261020.md` on the mobile release lane.
Private receipts: `~/Documents/FindEZ/AppStore/submission-20261020`.

## Final submission receipt

Apple acknowledged submission `a07e0629-8f1f-4043-ae87-d06fb06fe4c0` at
2026-10-20T09:09:34.236Z. Both review submission and version1.0.9 are
`WAITING_FOR_REVIEW`; build99 is selected and release type is `AFTER_APPROVAL`.
No new iOS binary was necessary for photo matching. This is a submitted update,
not an Apple approval or a claim that the update is already publicly available.
The accepted five iPhone/five iPad screenshots are preserved, with complete
processing and unchanged checksums. Review notes and release notes describe the
cumulative build99 update and conservative photo matching without promising
arbitrary viewpoint recognition. No customer inventory was used for testing.
