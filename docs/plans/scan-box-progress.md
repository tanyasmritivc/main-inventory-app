# Real photo crop progress

The photo scan UI consumes additive `scan_regions` SSE events through the existing
`result` envelope. Initial `regions` describe accepted, deduplicated crop IDs and
normalized xyxy coordinates (0..1000) on the EXIF-oriented source photo. `states`
report actual pending/checking/checked/unreadable transitions. Batches may overlap
in time; the overlay reflects actual concurrent analysis rather than invented
one-at-a-time progress. No rectangles are shown before grounding returns.

Extraction outputs, item identities and save payloads stay unchanged. The original
40-second call timeout, 100-second overall deadline, two workers, model and prompts
remain intact. No migration, inventory mutation or extra inference call is added.
The mobile client ignores malformed regions and removes overlays when stopped or
complete; older clients ignore the new event.

Backend runtime: `177a807a592ad76daee1cdab88336e72674ad076` (PR321).
Full local suite: 1,542 passed; final targeted and staged production-source suites:
58 passed each. All five exact-source CI gates passed (42161346041), including
full backend tests. CI exposed a final-callback scheduling race; callbacks on the
stream loop now queue immediately, while worker callbacks remain thread-safe.

Deployed only the three changed runtime files with pre/post hash verification,
backups and failure rollback. API/database health both passed; unrelated live
source was preserved. Backup and receipt: `/home/ubuntu/findez-scan-boxes-20261105`.
No live provider latency or physical-device behavior is claimed by these tests.
Mobile overlay is delivered separately as build185.
