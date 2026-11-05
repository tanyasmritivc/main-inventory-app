# Import column semantics

The prior importer mapped Vendor Part #/Vendor Part Number/Supplier Code into purchase_source. New imports already exclude those aliases. This change projects proven legacy identifier values out of the purchase-source field on inventory list/search reads and item-update responses, retaining the unchanged source columns. Matching genuine purchase-source columns and unrelated/manual purchase values remain intact. No customer database rewrite or schema migration.

Ambiguous duplicate canonical headers no longer select an arbitrary source column. All original fields, names, order, duplicate/unnamed columns and typed JSON values remain in import_data. Connector review now accepts JSON as well as CSV and multi-sheet XLSX. Google Sheets exports use those same file paths; this does not introduce a live Google Sheets connector.

Deployed runtime 4cd2eb7c6a4b433f8bc2129dddf846ff41f189e0 from PR316 after all five CI gates passed (run 41979118056). 1,538 backend tests, 12 final update-return regression tests, and three staged/live-source regressions passed. Authenticated HTTPS limits and connector catalog returned200; invalid authentication returned401. The disposable QA account was removed. API/database health passed; unrelated live source is unchanged. No customer database rewrite or schema migration. See docs/import-column-semantics182-release.json.
