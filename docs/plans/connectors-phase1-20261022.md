# Connector imports and compact cards

Migration 079 and the backend/web release are live after explicit user approval.
Apple acknowledged TestFlight build 114, delivery `b5637833-5240-4f71-b04b-e48c0ddf238d`. Processing and tester availability were not polled. Google and all unfinished connectors are omitted from the
build at the user's October22 direction. Existing Claude Desktop/ChatGPT outbound
setup remains; it is not shown as a connected Google account.

## Architecture and scope

The existing FastAPI auth/scoped inventory clients, Supabase item fields,
openpyxl/CSV parser, original imported fields, project stock allocation, Flutter
navigation and Next.js components are reused. No paid dependencies or new AI calls.
New `/connectors/imports` routes retain an actor-private source snapshot, map
columns by index, validate rows, detect duplicates and submit reviewed stock.
The new SQL transaction is a secure equivalent to item creation: the actor and
inventory are authorized again, item limits checked, and item writes plus durable
row receipts commit together. Nothing is silently merged, increased or overwritten.
The first release supports Skip or Create a separate item for duplicate review;
merge/update is deliberately unavailable until a snapshot-checked update workflow
is implemented. Legacy routes remain compatible with older clients.

CSV/XLSX: 10 MB compressed/upload limit, 50 MB expanded workbook, 5,000 rows,
200 columns, 20 worksheets, bounded cells and archive entries. UTF-8 CSV supports
comma, semicolon and tab delimiters. Legacy XLS, macros and encrypted workbooks
are rejected. Formulas are never evaluated; mapped formulas require exported
values. Barcodes/part identifiers are preserved as text when the source stores
text; leading zeros already lost by numeric spreadsheet cells cannot be recovered.
A destination must be an existing Space. Category and quantity defaults are visible
in the mapping UI. Original labels/values remain in each item's import_data.

An import is tied to actor, destination, source bytes and kind. Reuploading that
same file returns the existing session/results instead of adding stock twice.
Mapping changes use revision compare-and-swap. Confirmation freezes all row
choices; per-row receipts survive later stock edits/deletion. Batches are 200 rows.
A lost HTTP result is safe to retry. The existing personal/team import allowance is charged atomically once per file, not per batch or retry (pilot mode remains exempt). Partial failures remain visible. Source
snapshots are private, with no client-table privileges. Drafts expire after seven
days; uploading the same file renews only an uncommitted draft and invalidates its old preview. Committed receipts remain until their owning account/inventory is removed.
No source file is deleted or changed.

File BOMs use the same parser/mapping and project stock allocator. Exact barcode,
part/brand or name matches can supply stock; ambiguous/fuzzy suggestions do not.
Reservations and earlier requirement allocations are subtracted. DNP rows are
explicitly excluded. BOM analysis creates no items, project reservations or orders.
CSV purchasing exports escape spreadsheet formula prefixes. Supported profiles
are file exports, not live CAD connections. Fusion Electronics CSV is supported;
other exported tables require manual mapping and are not advertised as a CAD API.

Verified format references:
- https://docs.kicad.org/10.0/en/cli/cli.html
- https://help.autodesk.com/cloudhelp/ENU/Fusion-ECAD/files/ECAD-BOM-EXPORT.htm

## Google configuration (future; no UI in this build)

The active API environment was inspected for Google/connector variable names only;
none were present. Supabase Google sign-in is separate from Drive authorization.
Future implementation requires Google Cloud Drive, Sheets and Picker APIs, consent
configuration/test users, a web OAuth client, verified origins/exact callback URI,
a restricted Picker browser key, and a server token-encryption key. Exact names
and callback URL will be documented with the implemented OAuth routes, not invented
as working endpoints here. Client secrets/refresh tokens never belong in frontend
code or chat. Use selected-file drive.file permissions with Picker, one-use
actor-bound state and server refresh/revocation. No broad Drive scan or sync.
https://developers.google.com/workspace/drive/api/guides/api-specific-auth
https://developers.google.com/identity/protocols/oauth2/web-server

## Manual verification after activation

1. Use a disposable test inventory with an existing Storage Space. Open Connections:
   CSV & Excel and Parts lists are present; Google/unfinished providers are absent.
   Search and assistant setup rows work; API-key management still opens its page.
2. Upload test-data/import-samples/phase1-review.csv to Storage. Before confirmation,
   open inventory separately: nothing has been added. Inspect mapping and originals.
3. The repeated AA battery row is flagged; HDMI quantity -2 is invalid. Leave both
   as Skip and confirm. Expect two created records (10 batteries, four USB-C cables),
   two skipped rows, zero failed. Open inventory and verify fields/barcode zeros.
4. Reupload the identical file. Expect the same results and unchanged quantities.
   Interrupt/retry a commit; the session resumes, never increments existing stock.
5. Upload a changed source with duplicate stock. Choose Skip or explicitly Create
   a separate item. Verify existing stock is unchanged. Change sheet/mappings and
   ensure the preview is regenerated before confirmation.
6. Try XLS, empty/oversized/invalid UTF-8, duplicate headers, fractional/negative
   quantities and formula cells. Errors must be specific and no hidden defaults.
7. Upload phase1-kicad-bom.csv through Parts lists. Review required quantities/DNP.
   Compare stock and reservation-aware shortages. Export the shortage CSV. Verify
   inventory quantities did not change. Check fuzzy suggestions do not count.
8. In chat create Chat QA + Storage + ten batteries. One compact card shows all
   changes. Confirm once; open the saved inventory. Use three batteries: the receipt
   shows the quantity change once and Open item navigates to the saved item.
9. Check Connections/cards at 320pt width, light/dark appearance, large text and
   VoiceOver. Confirm all controls remain reachable and no card implies a pending
   action has already succeeded. Actual device file picker/share sheet needs QA.
10. A viewer/another account must not retrieve or submit someone else's import.
    Revoking edit access between preview and confirmation must deny the write.

## Main files changed

- `backend/app/api/routes/connectors.py`: authenticated upload, mapping, preview,
  commit, provider status and BOM endpoints; ownership derived from the session.
- `backend/app/services/connector_tables.py`: shared field mapping, validation,
  duplicate detection, cautious BOM matches and safe CSV export.
- `backend/app/services/spreadsheet_import.py`: bounded CSV/XLSX parsing and source
  row/header retention; existing parser remains the shared implementation.
- `backend/app/services/project_kits_service.py`: shared reservation-aware stock
  calculations; existing kit behavior retained.
- `backend/supabase/migrations/079_connector_import_sessions.sql`: private snapshots,
  atomic row receipts and once-per-file quota charging; inventory deletion cleanup.
- `backend/app/api/router.py`: legacy and inventory-scoped connector routes. The
  live deployment preserves its existing agent-management and approval overlays.
- `backend/app/services/world_chat.py`: concise creation-card introductions.
- `mobile/lib/features/scan/connector_destination_page.dart` and
  `connector_review_page.dart`: authorized destination selection, mapping, duplicate
  choices, import receipts and BOM export; existing upload/BOM pages delegate here.
- `mobile/lib/features/chat/assistant_connections_page.dart`, `chat_item_action_card.dart`
  and `mobile/lib/features/world/world_action_card.dart`: compact, actionable cards.
- `frontend/src/components/site/spreadsheet-import-modal.tsx`: complete reviewed
  spreadsheet/BOM flow; scan center and scoped transport reuse it.
- Connector unit/widget tests, the disposable SQL fixture and native screenshot
  harness cover these changes. Sample files are in `test-data/import-samples/`.

## Required configuration and current limits

No new environment variables or provider credentials are needed. Existing
FastAPI/Supabase authentication, service-role credentials, frontend public API/auth
configuration and mobile production defines are reused. Migration 079 is required.
Google OAuth is intentionally absent from this build, so no Google setup is needed.

This release imports one selected worksheet per source session. To import another
worksheet after committing, export it to a separate file. Duplicate choices are
Skip or explicitly Create a separate item; there is no merge/update control.
Correct invalid source values in the file or skip those rows; mappings can be
corrected before confirmation. Committed choices stay frozen for safe replay.
BOMs with invalid rows cannot export a complete purchasing list until corrected.
These are file imports, with no automatic synchronization or purchasing.

## Costs and limits

Deterministic imports and BOM matching make no model calls and use existing
free/open-source dependencies. Private snapshots, database receipts and source
fields consume hosting/database/storage resources. No paid connector platform or
CAD subscription is introduced. Google account entitlements and API quotas are
not promised free/unlimited; Google is not activated in this release. Existing
photo/document model costs are unchanged.

## Validation and release receipts

- Backend: full pytest 1,409 passed, 10 subtests; 451 pre-existing deprecation warnings.
- Web: 60 suites / 478 tests passed; TypeScript and changed-file ESLint passed.
- Mobile: full host suite 799 passed, one optional skip; analysis clean. Six native
  iOS layout/action checks passed in light/dark mode; screenshots inspected.
- SQL: migration applied twice against isolated production-schema-only copy; synthetic
  tests verify cross-user denial, revoked actor, private table/RPC privileges, partial
  failure, replay after item edits/deletion, 201-row batching, monthly quota rollback/
  single charge, and inventory deletion cleanup. The full empty-database permissions
  fixture also passed with the new migration/tests included.
- No Google configuration, credentials or extra paid SDK required for this build.
  Existing API/Supabase configuration is reused. Migration 079 must be approved and
  applied before exposing the new frontend/mobile import flow in production.
- All five CI jobs passed for API PR #176, mobile PR #175 and web PR #174.
- Final full-data rehearsal applied migration 079 twice to a network-isolated copy;
  all 91 existing tables retained identical row counts and hashes.
- Approved migration/backend/web activation succeeded. API/database health passed;
  eight web routes passed. Deployment preserved 109 unrelated API files and 348
  unrelated web files. Production web build passed with real deployment config.
- Live HTTPS acceptance used two temporary synthetic accounts, both removed:
  CSV review/duplicates/invalid quantities/commit/replay/barcode zeros, cross-user
  denial, BOM shortage/DNP/export without inventory mutation, and XLSX save passed.
- Build 114: production configuration, 24 privacy manifests, 32 archive and 32 export
  device executables, strict signature and Apple validation passed. Apple acknowledged upload: `b5637833-5240-4f71-b04b-e48c0ddf238d`; processing and tester availability are unverified.
- Physical-device picker/share-sheet and customer-file acceptance remain pending.
  Google and other unfinished providers are hidden and unimplemented.
