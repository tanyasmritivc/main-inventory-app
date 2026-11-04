# Space polish

Implemented in the existing checkout on `feat/space-polish`, based on build172. Preparing FindEZ 1.1.2 (173).

The existing Space thumbnail now uses the shared four-palette painter and unchanged grain asset. Four cached 384px images are reused by every fallback tile; no per-row animation, grain decoding or noise painting occurs while scrolling. Category uses a deterministic hash, falling back to the item location. Keyword icons are display-only. Existing photo URLs, authentication and BoxFit.cover remain unchanged.

The large title uses Inter Tight Regular at 34pt, 1.1 height and -0.68 tracking. Item titles remain exact stored strings, two lines at 15.5pt/600; secondary labels and quantities retain their existing content. Tight allocation fixes the sort label's right edge to match quantities.

**Review count exception:** LocationItemsPage receives inventory items and low-stock thresholds, but no pending Review count. Its existing list/search responses do not expose that count. The package explicitly permits retaining `Items to finish` without a new API call. Review remains visible (unknown is not zero); Low quantity hides at zero, giving Review full width. Review tap/long-press and all existing navigation/actions are preserved. No network request, API, schema, data, backend, web, dependency or copied screen was added.

Validation in progress: 17 focused checks pass, including retained photo rendering, no Review request, exact sort/quantity alignment, 300 lazy rows, search/filter/sort, quick view, confirmed quantity/move behavior and Ask. Native screenshots use synthetic Fastener DB fixtures and the bundled sample workbench photo; they are not customer inventory. Analyzer is clean. Final native/profile/full-suite results and Apple receipt will be recorded before delivery.

Runtime files changed: `mobile/lib/features/inventory/inventory_page.dart`, `mobile/lib/features/inventory/space_v2/space_widgets.dart`, `mobile/lib/features/founding_access/riso_art.dart`, `mobile/pubspec.yaml`. Existing `space_v2_test.dart` and `space_v2_audit_test.dart` are extended for verification. Supplied instructions and screenshots remain documentation only.
