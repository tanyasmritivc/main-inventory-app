# Original capture photos and return to Items

Prepared October 18, 2026. Production activation of migration 056 is pending
separate user approval. This is additive to the live model-written Chat release.

For new auto-extract saves, keep the detected crop as `items.image_url`. Attach
the uncropped, orientation-correct full scan as a private `item_events` photo,
marked `Original scan photo`. Gallery ordering is primary first, original second,
then other photos. One Storage object can serve many items from the same scan;
it is not duplicated per item or published to workspace-wide Files. Without a
distinct crop, show the full photo once. Existing item galleries on mobile/web
already load these photo records. No customer Dashboard layout changes.

Bulk capture uses a stable per-item event UUID and confirms real photo receipts.
A missing/lost photo write keeps the draft unconfirmed; retry repairs the gallery
without creating another item or changing quantity. A retry cannot replace an
already saved original. Normal scoped/guarded writes enforce current inventory
role and private image access. Storage deletion checks all item/photo references
and pending Review crop/source references, including restricted sibling records.

Migration 056 changes only the existing service-only Review resolver. It creates
the original photo event before marking the Review resolved, while the pending
Review still authorizes its source. Item, photo and resolution commit together.
The existing row lock/replay receipt prevents duplicate items/photos. The patch
checks its expected insertion point, preserves the original function's grants,
security and other behavior, and can be replayed. It does not backfill or rewrite
historical items. Earlier confident scans did not retain their source identity in
item rows; lost associations cannot be reconstructed reliably.

Mobile Capture completion opens the saved Space's item list in the same API
context; a partial refresh stays in Capture. The Chat-launched scanner returns
the destination Space before opening its items. In-Space photo uploads refresh
the current list directly, without a QR offer covering it. Web Capture replaces
the route with `/inventory?space=...&inventory=...` only after all receipts are
confirmed. Existing in-Space web capture already stays on its item list.

Validation: full Python 996 tests + 10 subtests; final capture/gallery focus 24.
The composed PostgreSQL fixture replays 056 twice, checks crop retention, one
original, authorized teammate access after Review resolution, outsider rejection,
revocation, lost-preview cleanup and rollback on a synthetic photo-write failure.
A fresh private production dump was restored into a network-disabled container:
all public/auth/storage rows, unrelated functions/policies/constraints/grants
remain unchanged after first and repeated application. Source/receipts are private
under `/home/ubuntu/findez-capture-release-20261018`; production was not written.
Web full suite/types/lint/build and mobile final suite/analysis/native beta87
verification are tracked in their separate lanes. No customer writes for QA.

Release gate: apply reviewed 056 only with explicit production database approval,
then activate the matching API/web runtime and upload the signed production beta87.
Apple processing and tester availability are not polled; physical camera/library
and real device navigation/appearance acceptance remain manual.
