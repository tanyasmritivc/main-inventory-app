# Native chat source menu208

## Implemented behavior

iPhone chat source menus use the existing UIKit grouped sheet with native search, SF Symbols, nested navigation and native dismissal. Root entries are Auto Extract, Attach, Inventory tools and Add context. Search matches the current page. Selection returns an allowlisted existing action only after the native sheet dismisses, so the next picker does not collide with it. Cancellation returns no action. Space question menus retain only Photo library, Take photo and Choose files. The native failure path displays an error.

Non-iOS menus, underlying extraction/import/save routing and main chat behavior are unchanged. The separate server timeout recovery is PR371.

## Repeatable automated checks

From `mobile/`:

- `flutter test test/chat_source_menu_test.dart`: all native action IDs, menu model, restricted actions, cancellation and failure behavior.
- Run the complete `flutter test` suite and `flutter analyze`; release208 passed 1,362 tests with one existing skip and no analysis issues.
- `flutter test integration_test/chat_attachment_menu_test.dart -d <iPhone-simulator-id> --no-pub --reporter expanded`: eight real UIKit light/dark page presentation and owner-route-disposal tests. Capture each `NATIVE_CAPTURE_READY` marker.

## Manual native acceptance

Launch the synthetic harness with `flutter run -t tool/native_source_menu_visual.dart -d <iPhone-simulator-id>`. Do not package this target in a release. For each menu action, confirm the returned Selected value after the native sheet disappears:

| Page | Expected actions |
| --- | --- |
| Root | auto_extract |
| Attach | library, camera, file |
| Inventory tools | spreadsheet, barcode |
| Add context | space, item, project, document, connections |

Verify native search filtering and an empty search result, clear search, submenu Back, Close, repeated open/close and sheet expansion. Open the Space menu and confirm only attachment actions appear. Compare root and all three subpages in light and dark mode for clipped rows, footer or search controls.

Release208 simulator acceptance exercised all eleven native callback values, search, Back, Close, expansion and restricted Space attachment selection. Eight actual UIKit screenshots were reviewed. Drag dismissal was not conclusively exercised by desktop automation.

On a physical iPhone with the TestFlight build, additionally verify swipe dismissal, Photos selection/cancel, camera permission/capture/cancel, Files providers and barcode camera; confirm each selected input reaches the existing workflow once and cancellation leaves no overlay. Physical-device acceptance remains pending.

## Scan recovery acceptance

See PR371 and `crowded-scan-recovery.md` in the backend lane for exact tests. The production public API accepted a regular photo and the user's crowded JPEG, returned crops/evidence, a durable draft and terminal done event, with no inventory writes. A separate real-provider probe forced the initial overview timeout and recovered partial regions from smaller sections. Overly crowded scans still have variable latency and unidentified regions; four minutes is approximate, not an end-to-end maximum.
