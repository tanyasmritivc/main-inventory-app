# Space capture entry

The Space empty-state Add Item button previously opened the manual editor. It
now opens the same three choices as the plus control: Scan Photo, Scan Barcode
and Import Spreadsheet. All three reuse their existing flows with the current
inventory client and Space name. The obsolete manual-create method is removed
only from LocationItemsPage; existing item editing and scan correction remain.

Capture controls respect both readOnly and the inventory's canEdit permission.
Menu labels wrap at large text. The existing camera/library source sheet gains
a transparent Material ink surface for compatibility with current Flutter.
Dashboard, other entry points, backend, web, API contracts and schema are unchanged.

Eight focused cases cover both entry controls, exact options, photo source
selection, barcode route, spreadsheet destination identity/Space, cancellation
without writes, both viewer restrictions, and narrow 1.8x text. All eight pass.
The full local coverage suite passes 557 tests and static analysis is clean.
iPhone 16e/iOS 26.2 native fixture review confirms both entry controls, all three
choices, photo camera/library selection and import with Garage preselected,
including cancellation. Screenshot: design/space-capture-entry/out/options.png.
Apple acknowledged signed TestFlight 1.0.8 (81), runtime
257bb3e850bb5c258ff1ae5417380db71142acd2, delivery
0ada0dcc-7654-425e-870a-15607fdeb248. All 31 native executables in both archive
and exported IPA verify as iOS device binaries, with strict archive signatures.
Final IPA SHA-256: bf5e356844d099415dbac2080a8d5d864d84f581dbc414f3a41deb63b0f01a07.
Archive, IPA, verification and Apple receipt are preserved privately in
Documents/FindEZ/AppStore/1.0.8-build81. Processing and tester availability are
unverified and were not polled. Automatic checks are tracked in PR 97; no
manual regressions were repeated after the successful release build.
Real camera/barcode/file selection on the final phone binary remains manual
acceptance; fixture tests do not claim physical hardware or production writes.

Files: mobile/lib/features/inventory/inventory_page.dart,
mobile/lib/features/scan/upload_photo_flow.dart,
mobile/test/space_capture_entry_test.dart,
mobile/tool/space_capture_preview.dart, mobile/pubspec.yaml and project docs.
The preview uses a network-free disposable bundle and is excluded from lib/main.dart.

Branch: fix/space-add-capture-20261017, clean start be4ab48. No backend deployment or
migration is needed. The production archive must use lib/main.dart, existing
production defines, a clean native cache after tests/simulator, and verification
of every archive/export executable's iOS device platform before upload. Stop at
Apple acknowledgment; do not poll processing. Rollback uses a later mobile build
reverting this scoped change, without modifying stored items or Spaces.
