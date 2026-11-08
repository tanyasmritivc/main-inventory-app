# Capture and import repair 200

History closes before Delete confirmation to release the modal focus/pointer trap. Space photo upload uses the existing main photo service and capture widgets, then verifies and locks the invoking inventory/Space before saving. Manual/barcode additions retain the originating Space.

Inventory spreadsheet imports bypass Review, choose a Space from main chat or use the invoking Space, and resume durable receipts after failures. CSV, XLSX and JSON supported; BOM review unchanged. Main chat/photo presentation and behavior otherwise unchanged.

Validation: TypeScript passed; changed-file lint has no errors; 13 focused tests pass. Full web suite retains the pre-existing 76 failures with identical failure headings and no new failures. Updated spreadsheet wrapper tests pass separately. Isolated production build is staged; deployment receipt will follow.

## Deployment

Production release space-imports-20261107 is live, build GjlDASBKZhL3cIOsA9lOA. Eight route checks returned 200; 541 unrelated files, public assets and configuration preserved. PR347. Browser automation could not initialize because its installed runtime dependency is missing; UI behavior is covered by component tests, production build and route checks.

Final runtime CI 42425038754: backend, mobile, connectors and PostgreSQL pass. Web: 525 pass / 71 pre-existing failures (previous CI 72); no new failure headings. Updated direct-import wrapper removes one old failure. Exact comparison retained in capture-import200-web-ci.json.
