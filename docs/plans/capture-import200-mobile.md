# Mobile capture/import repair 200

Space photo uploads reuse the main extraction service, progress panel and capture card. The invoking inventory and Space are verified and locked before saving; the main chat/photo flow is unchanged.

Inventory spreadsheet imports save directly without Review. Main entry chooses a destination; an existing Space supplies its stable ID. XLSX, CSV and JSON use durable import receipts and resume unfinished rows after a connection failure. BOM review remains unchanged.

Light backgrounds are #F6F8F9 and raised surfaces white. Native light lists follow the same background; dark defaults remain intact.

Validation: Flutter 1332 passed / 1 existing skip; analysis clean; 11 native iPhone contextual-sheet/Space-layout tests passed with screenshots retained. Native history Delete was exercised with synthetic rows, including active search. No native deletion regression reproduced; the web confirmation trap is fixed in the companion lane. Physical-device acceptance is pending.

Build 1.1.2 (200) is prepared for signed production delivery after exact-commit CI. Apple receipt will follow. Public App Store unchanged.

## Apple delivery

Apple acknowledged TestFlight 1.1.2 (200), delivery `97d95078-21f8-46f3-8c8a-65095b5faea6`. Runtime `57cc953d`, PR346. All five exact-commit CI jobs passed (42424952291). Processing and tester availability were not polled; physical iPhone acceptance remains pending. Public App Store unchanged.
