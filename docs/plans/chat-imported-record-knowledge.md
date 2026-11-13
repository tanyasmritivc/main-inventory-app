# Chat access to original imported item records

Status: implemented and locally verified; NOT deployed. Branch
`fix/chat-imported-record-knowledge`, stacked on
`fix/auto-extract-direct-vision` to keep this PR limited to the chat data fix.

An inventory spreadsheet can contain order statuses and source quantities while
the separate Connections purchase library is empty. Chat previously treated that
empty library as evidence of no cancelled orders. The new read-only
`world_imports` tool discovers saved source columns, filters their original values,
groups statuses, and counts distinct order IDs separately from item rows. Original
source fields are flattened in the tool result so the provider's depth limit does
not replace their values with omission markers. Current recorded stock is labeled
separately. Empty Connections results explicitly say inventory imports were not
searched. The system instruction directs supplier/spreadsheet questions to this
source and requires both sources for unspecified purchase-history questions.

Every inventory is freshly authorized against the selected organization; the
existing scoped client also restricts the database read. No database mutations,
new migrations, client API changes, photo changes or client releases are needed.
The scanner stops after 10,000 item records and reports incomplete coverage.
Row, column and group previews are paged. Counts are calculated before preview
limits. Unknown/duplicate headers cannot produce a zero-count claim; missing
filter fields, missing order IDs and unusable numeric values are reported.
Distinct values are counted per inventory; they do not establish current stock.

Validation:
- Full backend/API-doc suite: see final receipt in ACTIVE_WORK.md.
- 18 new focused tests also pass against a local copy of the live composite
  backend. This is synthetic integration verification, not a live model run.
- Read-only replay of the existing private Haas audit: all 11 original columns
  accessible; cancelled records are 113 rows / 8 distinct order numbers. No
  customer records are committed and no inventory data is changed.
- Source scan cap, wide-column pagination, repeated order IDs, missing/ambiguous
  fields, original vs current quantity, foreign-organization rejection, and
  chat tool handoff are covered.

Deployment still required. The current session's SSH network connection stopped
resolving and its escalation request was automatically rejected because sandbox
approval is disabled. A private checksum manifest and production overlay are in
`.chat-import-knowledge-private/` in the command-center workspace. They preserve
all unrelated live changes. Before publishing, re-read the three live files and
check their hashes, apply the overlay to an isolated copy, run the new tests, back
up originals, activate only those three files, restart `findez`, and verify
`/health`, `/health/db` and an authenticated read-only Haas chat. Roll back those
three files and restart if health fails. Do not reset/pull the composite VM tree.
A real provider response and fresh production data read remain unverified.
