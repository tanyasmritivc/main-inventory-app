# Organization-wide contextual Ask — published November 17, 2026 local

The floating Ask window on inventory/Space pages now uses the selected Space's
organization, with the same authorized organization tools used by organization
chat. Personal is separate. The server verifies that the entry inventory belongs
to that organization before charging quota or opening history, and again before
saving the answer. Every target inventory still uses existing role authorization.
Restricted/deleted inventories are omitted from the directory without leaking
names or counts or breaking accessible results. Conversations remain private to
both their author and organization.

The main chat's scope, layout, request defaults and generation prompt remain
unchanged. Contextual draft/resume storage is separate from main chat. Contextual
lookups ask for bold headings and tables with exact part names, recorded counts,
and locations. Table padding is scoped to the floating panel. Bounded searches
must not claim complete totals or infer physical absence.

## Repetition and interruption findings

The world HTTP route discarded `reset` events emitted by the tool/retry loop.
Consequently failed attempts and tool preambles were concatenated in the browser.
It now forwards the existing protocol event. Gateway whole-message snapshots no
longer append already-streamed text or tool arguments. Repeated tool identity
metadata no longer grows on every argument fragment and hits false size limits.
A conflicting final snapshot, true output limit, failed persistence, malformed
provider output or missing completion still produces an error, never false success.
The contextual window has a bounded five-minute deadline for multi-Space reads;
main chat keeps its existing deadline.

Production logs contained `control_markup` and `tool_size` generation failures.
Those logs do not identify the exact user's screenshot. The reset defect and
snapshot/identity parser cases were reproduced independently; we do not claim
that every possible provider/network interruption has been eliminated.

A final browser-console review also found that animated Markdown wrapped table
separator whitespace in spans, creating invalid table children. Separator text now
stays unwrapped; actual cell content still animates. This renderer correction
preserves the main chat's appearance and behavior.

## Validation

- 20 focused backend tests and 23 focused web tests passed.
- Real configured gateway, fictional records only: both “Were are my gears” and
  “Where are my gears?” completed with bold headings, a table, and both fixture
  locations. No customer records were read or written by these probes. Network
  access in the probe was restricted to the configured model gateway.
- Actual React panel, mocked authentication and SSE: 1440px and 390px in light/dark
  passed. Checked organization route and entry ID, table/bold rendering, reset
  replacement, stale-answer clearing on organization switch, and absence of table
  hydration errors. Screenshots and browser receipts are included. No fixture
  route was published.
- Production webpack builds and TypeScript passed. Changed-file lint had no
  errors; three existing warnings remain in AssistClient.
- Broad backend suite: 1,071 passed, 314 failed; untouched source baseline:
  1,053 passed, the identical 314 failed IDs. Two further focused tests passed
  after that full run.
- Broad web suite: 735 passed, 12 failed; untouched baseline: 727 passed, the same
  12 failures. The animated-table regression was added and passed afterward.
- The broad suites are **not green**. Their older fixtures disagree with several
  already-deployed behaviors. This patch adds no failure IDs/headlines; it does
  not repair those unrelated failures.
- Live source hashes match the reviewed candidate. Website routes, API health,
  database health and unauthenticated-chat rejection passed. Generated public API
  schema remains intentionally unavailable (404).

These are isolated browser/model tests and public deployment checks, not a claim
that the reporting user's authenticated conversation was replayed end to end.
Existing failed or duplicated messages are not rewritten; refresh the website
and start a new contextual question.

## Release and rollback

Recorded deployed source baseline: `7c5dc778`, separately committed to preserve
newer unrelated work that was absent from the CAD checkout. Only manifest-listed
runtime files were patched on the server. No migration, stock mutation, native
binary, CAD ZIP, public landing content or external hosting deployment.

First release: `/home/ubuntu/findez-context-ask-20261117/frontend`, build
`op8pbHQzFAPtgOZ_ypJkN`. Final web-only animation correction:
`/home/ubuntu/findez-context-tables-20261117/frontend`, build
`Xh97AxD2rflMaFWKfx01a`. API remains `/home/ubuntu/findez/backend`.
Both activation scripts retain previous releases, asset compatibility and
rollback receipts. The first release's `rollback/backend` contains prior API
files; restore those and remove the new `context_ask.py` only if rolling back the
backend. Restore the prior systemd working directory to roll back the web.
Do not blindly reset or pull the production repository.

`manifest.json` and `table-fix/manifest.json` contain per-file before/after hashes;
`live-verification.json`, `verification.json`, `browser-results.json` and
`model-probe-results.json` record the evidence. The browser fixture is documentation
only (`browser-fixture.tsx.txt`), not a deployed route. No branch push was performed.
