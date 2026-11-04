# Space polish

Implemented in the existing checkout on `feat/space-polish`, based on build172. Delivered FindEZ 1.1.2 (173).

The existing Space thumbnail now uses the shared four-palette painter and unchanged grain asset. Four cached 384px images are reused by every fallback tile; no per-row animation, grain decoding or noise painting occurs while scrolling. Category uses a deterministic hash, falling back to the item location. Keyword icons are display-only. Existing photo URLs, authentication and BoxFit.cover remain unchanged.

The large title uses Inter Tight Regular at 34pt, 1.1 height and -0.68 tracking. Item titles remain exact stored strings, two lines at 15.5pt/600; secondary labels and quantities retain their existing content. Tight allocation fixes the sort label's right edge to match quantities.

**Review count exception:** LocationItemsPage receives inventory items and low-stock thresholds, but no pending Review count. Its existing list/search responses do not expose that count. The package explicitly permits retaining `Items to finish` without a new API call. Review remains visible (unknown is not zero); Low quantity hides at zero, giving Review full width. Review tap/long-press and all existing navigation/actions are preserved. No network request, API, schema, data, backend, web, dependency or copied screen was added.

Validation: all 1,329 Flutter tests passed (one existing skip), 17 focused and 17 native iOS scenarios, clean analyzer, all five exact-source CI gates (41744964899). Five native screenshots are retained in `verification/`; 27 were captured privately. The macOS profile fixture scrolled 300 items with four cached palette images: 277 frames, build p95 4.235ms and no build frame over 16.67ms. Desktop timings do not certify physical iPhone smoothness. A dedicated scroll harness was used because the general widget suite's text entry and VM timeline tracing are not portable to desktop profile mode. Native screenshots use synthetic Fastener DB fixtures and a bundled photo, not customer inventory.

Apple validated and acknowledged 1.1.2 (173), runtime `6091565f8a74011dffec3b6c2fa0ced3f357692a`, delivery `b052bbd1-56cb-49af-9702-4ab31ae4600f`. Processing is VALID; requested What to Test notes verified. Strict archive/export signatures, 33 device binaries each, 27 privacy manifests and production configuration/assets verified. Tester availability and physical-device acceptance remain unverified. See `testflight173-receipt.json`.

Runtime files changed: `mobile/lib/features/inventory/inventory_page.dart`, `mobile/lib/features/inventory/space_v2/space_widgets.dart`, `mobile/lib/features/founding_access/riso_art.dart`, `mobile/pubspec.yaml`. Existing `space_v2_test.dart` and `space_v2_audit_test.dart` are extended for verification. Supplied instructions and screenshots remain documentation only.
