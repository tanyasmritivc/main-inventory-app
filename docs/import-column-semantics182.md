# Import column semantics

The prior importer mapped Vendor Part #/Vendor Part Number/Supplier Code into purchase_source. New imports already exclude those aliases. This change projects proven legacy identifier values out of the purchase-source field on inventory list/search reads, retaining the unchanged source columns. Matching genuine purchase-source columns and unrelated/manual purchase values remain intact. No customer database rewrite or schema migration.

Ambiguous duplicate canonical headers no longer select an arbitrary source column. All original fields, names, order, duplicate/unnamed columns and typed JSON values remain in import_data. Connector review now accepts JSON as well as CSV and multi-sheet XLSX. Google Sheets exports use those same file paths; this does not introduce a live Google Sheets connector.

Validation: 37 focused import checks and 1,538 backend tests passed. Three regression checks passed against the staged live source using the server Python environment. Deployment pending five exact-source CI checks; the server's unrelated changes are preserved using a five-file hash-checked patch.
