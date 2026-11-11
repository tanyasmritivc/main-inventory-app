# CSV and Excel BOM comparison

The CAD page now accepts Fusion JSON, UTF-8 CSV (comma, semicolon or tab-delimited),
and Excel `.xlsx` files. CSV/XLSX entry uses explicit Review columns, worksheet
selection, suggested mappings with numbered columns, a five-row sample, and
confirmation that rows contain a flat parts list with total individual-unit
quantities. Selecting a file alone does not upload it. A CSV template is linked
on the page. Legacy `.xls` must be saved as `.xlsx` first.

## Contract and behavior

Authenticated `POST /inventories/{inventory_id}/cad/preview` receives a spreadsheet
and returns its SHA-256, worksheets, bounded samples, headers, row counts and
suggested mappings. It checks inventory scope and membership before parsing and
again before returning. It stores neither files nor BOM records.

Existing comparison accepts optional multipart `sheet`, `mapping` (JSON object
of field-to-zero-based-column indices), and `flat_bom_confirmed`. Name and quantity
are required; manufacturer, manufacturer part number, barcode and unit are
optional. Each field must use a distinct valid column. JSON continues through
the existing Fusion graph validator; no change to the exported Fusion format.

Spreadsheet requirements use their explicit quantities, without generating
occurrences or pretending to preserve a CAD hierarchy. Each source row remains a
separate requirement; stock is shared across matching rows, and reservations and
active checkouts are deducted using the existing read-only comparison. Names
alone remain probable matches requiring review. No AI inference or inventory
writes are added. Spreadsheet results explicitly lack verified CAD hierarchy,
suppression and revision data and are labeled as spreadsheet BOMs.

Limits: 5 MiB upload; 5,000 data rows, 200 columns and 20 worksheets; bounded ZIP
entries and expanded size; checked XLSX dimensions/cell coordinates; XML DTD and
entity declarations, macros and encrypted workbooks rejected. Parsing reuses the
existing spreadsheet reader without changing its other consumers. Mapped formulas,
missing names, invalid/nonpositive/fractional quantities, oversized fields and
non-each units produce row-specific errors. Numeric Excel identifiers must be
re-entered as text to avoid guessing lost leading zeros or precision. No formulas
are evaluated. Header suggestions do not arbitrarily select duplicate names.

## Verification

- 132 local backend checks passed, covering CAD and shared spreadsheet/connector
  behavior; 75 CAD checks passed against the exact production-source candidate.
- 21 frontend CAD tests passed, including explicit preview, confirmation gating,
  worksheet/file resets, errors and stale-inventory responses. The final selector
  accessibility fix also passed all six CAD component tests.
- Changed frontend source/tests pass ESLint. Final production webpack build,
  including TypeScript, passed with real server configuration and fonts.
- Staging and public HTTPS tests compare synthetic CSV and XLSX as eight required,
  six covered and two missing (75%). Anonymous/foreign inventory access is denied;
  synthetic stock stays unchanged. Original Fusion JSON comparison and malformed
  input denial also pass against production.
- Final public browser acceptance passed real sign-in, CSV and XLSX selection
  without automatic upload, suggested mappings, confirmation, correct 75% results,
  template download and no page errors. Narrow-screen layout passed after the
  existing navigation resize animation settled. Desktop and narrow screenshots
  were visually reviewed. Two disposable QA accounts and their stock were removed;
  the temporary staging API was stopped.
- Full historical web/mobile suites were not rerun for this scoped change. Their
  previously documented unrelated failures are not represented as fixed here.

## Release

Final web build: `WfWMGfPCND7k6Ul5w4SsC`.
Web directory: `/home/ubuntu/findez-cad-sheets-20261111/candidate-v2/frontend`.
The release overlays the latest Connections link release and preserves 586 other
web files and 262 other backend files. Existing dependencies already include
openpyxl; no packages, database migrations, mobile code or stock writers changed.
Deployment guards check exact source hashes, current web directory, environments,
tests, staging acceptance and compiled output before switching services.

Rollback: restore the three existing Python files from
`/home/ubuntu/findez-cad-sheets-20261111/backup` and restart `findez`. The new
`tabular.py` can remain unused. Remove only `zzzzzz-cad-sheets.conf` from the web
systemd overrides, daemon-reload and restart `findez-web`; previous source remains
at `/home/ubuntu/findez-connections-link-20261111/frontend`. Check API, database
and web health. Never reset the production checkout.
