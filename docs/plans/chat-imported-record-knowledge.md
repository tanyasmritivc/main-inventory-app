# Chat access to original imported item records

Status: deployed to the self-hosted production backend on November 12, 2026. Branch
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

## Production release

PR #392 runtime source `3a59f7c17ee1118db7dc05e5ba3a948449d5894c`
was deployed after SSH escalation was approved in the follow-up session. Exact
preflight hashes matched the previously tested overlay. Applied that patch to a
fresh production source snapshot; all 18 focused regressions passed. Activated
only world_chat.py, assistant_tool_safety.py and the new world_imports.py.
All 172 unrelated Python files were preserved. No database migration, inventory
writes, web release, mobile release, Vercel deployment or Render deployment.

Local and public HTTPS `/health` and `/health/db` pass. Anonymous access to
`/worlds/personal/directory` returns 401. Rollback originals and the verified
manifest remain at `/home/ubuntu/findez-pr392-release-20261112/rollback`.
See `chat-imported-record-release.json` for checksums.

The full prior backend/API-doc suite passed 1,671 tests plus ten subtests. GitHub
backend, PostgreSQL permissions, web and AI connector checks passed. The mobile
CI job failed on Flutter 3.50 deprecation diagnostics in unchanged mobile files;
this backend-only deployment does not resolve that separate upgrade issue.

Real-provider browser acceptance remains pending: Safari's FindEZ session had
expired and refreshing redirected to sign-in. The saved Haas audit replay is
historical validation, not a fresh authenticated production answer. After signing
in, ask about cancelled orders in the inventory spreadsheet and verify distinct
order counts are distinguished from item rows. No claim of live model acceptance.
