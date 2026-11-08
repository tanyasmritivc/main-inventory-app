# FindEZ repeatable scan and full regression test plan

Updated November 8, 2026. Run from a fresh checkout of the reviewed branches,
with the repository's pinned dependencies. This is a test procedure, not a claim
that every possible defect or physical-device scenario has been eliminated.

## Automated release gate

Run each command from the stated directory. Any nonzero exit fails the gate.
Keep logs/coverage outside source control. Never replace failures with skipped tests.

| Directory | Command | Coverage |
| --- | --- | --- |
| Repository root | `python -m pip install -r backend/requirements-dev.txt` then `python -m pytest --cov=backend/app` | API, extraction, durable jobs, capture/save, permissions, imports, conversations, announcements |
| frontend | `npm ci` then `npm run test:ci` | Components, request contracts, stream/parser failures, deletion receipts, authentication, navigation, scan recovery |
| frontend | `npx tsc --noEmit` and `npm run lint` | Types and lint; record existing warnings separately |
| frontend | `npm run build -- --webpack` | Production compilation with the intended release environment |
| mobile | `flutter pub get`, `flutter analyze`, `flutter test --coverage` | Flutter state, HTTP contracts, themes, imports, scan/chat and scoped destinations |
| integrations/findez-mcp | `npm ci`, `npm test`, `npm run check:bundle`, `npm run test:bundle` | MCP/Actions and distributable consistency |

Also require all five jobs in `.github/workflows/test.yml`, including the real
PostgreSQL permission/concurrency job. Its SQL scripts create synthetic schemas;
run them only in an EMPTY disposable database, never the production database.

Focused web reproduction:

```sh
cd frontend
npx jest --runInBand scan-completion auto-extract-request assist-auto-extract space-extraction
```

The scan-completion tests use controlled streams and fake time to cover:
healthy keepalives beyond 180 seconds; completion without socket EOF; 120 seconds
without bytes; an absolute 300-second deadline even with heartbeats; explicit
Stop; premature EOF; invalid JSON; server errors; fragmented UTF-8/CRLF; and
ordinary chat retaining its existing request behavior. Failed scans must not
silently become successful empty results or trigger duplicate POSTs.

## Real HTTP acceptance runner

`scripts/scan_acceptance.py` runs against the deployed API, without mocking AI,
Auth, Storage, or the database. It requires Python 3.10+ and `httpx` (included in
the backend environment). It creates two marked disposable QA accounts and a QA
inventory/Space; it never selects an existing customer's account or inventory.
It consumes real inference capacity and requires the explicit write flag.

Set these environment variables through your existing secure environment loader;
do not paste keys into command history or commit them:

- `FINDEZ_QA_API_BASE`: application API origin, HTTPS or localhost.
- `FINDEZ_QA_AUTH_BASE`: Supabase origin.
- `FINDEZ_QA_SERVICE_KEY`: service credential for disposable-account setup/cleanup.
- `FINDEZ_QA_BUCKET`: optional; defaults to `item-images`.

Use a small JPEG with several clear objects and a crowded JPEG with more than
eight visible regions. Keep photos private. RAW/DNG support is not tested or added.

```sh
python scripts/scan_acceptance.py \
  --allow-disposable-writes \
  --regular /private/fixtures/regular.jpg \
  --crowded /private/fixtures/crowded.jpg \
  --legacy-web \
  --report /private/results/scan-acceptance.json
```

The destination directory for the report must already exist. Exit 0 requires all
cases and cleanup to pass. Logs contain timings/counts, not credentials, signed
URLs, item names, or image pixels. If cleanup fails, an operator must investigate
the runner-created accounts carrying the unique `findez_qa_run` metadata marker;
never delete accounts based only on a guessed email/name.

| Case | Steps and required result |
| --- | --- |
| Authentication | Anonymous photo request is 401; invalid image is 422. |
| Regular draft | Upload through the real SSE endpoint; progress arrives, crops/evidence exist, one terminal durable draft arrives before 300 seconds. |
| Keepalive | No received-line gap reaches 120 seconds. `done` finishes immediately without waiting for EOF. |
| Recovery | Reload capture by conversation/capture ID; all draft items remain. |
| Isolation | Second account cannot read the capture or its protected image. Owner can read the image through `/media/item-image`; raw storage URLs are not public grants. |
| Save as-is | Choose a disposable Space and save all rows without quantity/identity edits. Saved count and locations match the draft. |
| Duplicate prevention | Replay the same save request/revision; receipt and row count remain unchanged. |
| Repeat | A second fresh regular scan independently finishes and reloads. |
| Old web compatibility | `preview_only=false` still returns a valid draft; measure the extra reply separately. |
| Crowded photo | More than eight regions are returned with crops/evidence; do not interpret region count as verified SKU accuracy or hidden quantity. |
| Cleanup | Delete only marker-verified QA accounts and their images; confirm both account removals. |

Record total duration, time to first progress, longest line gap, item count and
unknown count. Five minutes is a failure bound, NOT a responsiveness target.
Compare several repetitions on identical inputs before claiming a speedup;
provider/model and network variation make single-run comparisons insufficient.

## Interactive acceptance matrix (record each as pass/fail/not run)

Use disposable test data and current Safari, Chrome and the iPhone release.
Do not mark these complete merely because a unit or API test passed.

| Area | Actions | Expected outcome |
| --- | --- | --- |
| Main photo scan | Upload a regular image, then crowded image | Progress advances; no eight-item UI cap; terminal draft renders; no extra text reply blocks it. |
| Space upload | Open a Space and scan from its add-item entry | Same extraction quality; destination is that Space; no accidental cross-Space save. |
| Draft edits | Save unchanged; separately edit one name/quantity, deselect one row | Unchanged save allowed; only selected rows saved; revisions/receipt reflect edits. |
| Stop/retry | Stop during upload/inference; retry a failed scan | Loading stops, explicit state appears, one retry request; no duplicate saved items. |
| Network failure | Drop network, restore it, reopen history | Error or recoverable job/draft; no indefinite spinner or silent empty success. |
| iPhone lifecycle | Lock/unlock and switch apps while scan/chat runs | Server work and recovery complete; verify returned result. Force-quit separately and record OS-dependent behavior. |
| Chat scope | Ask about another Space's unique item from a scoped chat | Only permitted scoped facts returned; photo/file question does not silently extract/save. |
| Main chat | Send text, attach file, stream reply, cancel, retry | Existing main-chat controls and behavior unchanged. |
| History | Open photo conversation, reopen draft, delete conversation | Correct content opens; successful delete removes entry after reload; failed delete remains recoverable. |
| Spreadsheet | Import CSV/XLSX/JSON, with extra/blank/custom columns and quantities | Choose destination or use current Space; no mandatory review; retain original fields; errors identify invalid rows without silent loss. |
| Spaces | Delete QA Space, check all pickers/search/counts after reload | Deleted Space absent; inventories remain with accurate counts. |
| Auth/announcements | Email/Google/Apple sign-in/up, grant/deny notification permission | Correct profile name; permission prompt closes before announcement; dismiss doesn't open Settings. |
| Item/labels | Open web item, save label and print preview in Safari/Chrome | Mobile-equivalent fields; readable complete label, QR scannable, no shell/chat in print. |
| Theme/layout | Light/dark, small phone, large text, keyboard, long names | Readable text/dividers; no clipped composer, sheets or plan card; focus/close/swipe works. |

## November 8 audit evidence

- Backend: 1,568 tests passed on the deployed backend lane.
- Mobile: 1,347 passed, one existing skipped test; analysis clean. No mobile runtime changes in this audit.
- Web: 614 passed across 78 suites after repairing stale route/API fixtures;
  TypeScript passed; full lint zero errors and 52 warnings.
- Live regular scans: 24.08 and 18.15 seconds; legacy extra-reply scan 30.80 seconds.
- Live crowded scan: 241.44 seconds, 77 regions, 29 unknown identities; longest
  received-line gap 10.05 seconds. This is still slow and is not an accuracy guarantee.
- Live capture reload, protected pixels, account isolation, unchanged save and
  replay without duplicates passed. See private JSON report for cleanup receipts.
- Browser plugin failed at startup; isolated standalone Chrome provided the fallback.
  Landing/sign-in/sign-up passed at desktop and phone widths, without horizontal
  overflow or page errors. A real signed-in browser scan reached the extraction
  draft in 25.663 seconds with exactly one preview-only request. Its additional
  disposable account and 13 images were cleaned up. No real customer was used.
- Physical iPhone/backgrounding acceptance above was not rerun; do not claim otherwise.
- Both PRs passed all five CI jobs, including PostgreSQL concurrency and connector
  checks. Web runtime commit `adf387c5` was published as release
  `scan-audit-20261108`, build `WLY1-Lx7Ljhu-Fk9oq8LU`; only two runtime files
  changed and 547 other files were preserved. The backend process was untouched.
  Production checks covered 19 routes/access guards and 41 static assets.
- Review requests: https://github.com/tanyasmritivc/main-inventory-app/pull/366
  (web) and https://github.com/tanyasmritivc/main-inventory-app/pull/367 (runner).

The web repair requests preview-only extraction and uses scan-specific idle and
absolute deadlines; ordinary text-chat behavior remains unchanged. No model,
recognition coverage, database schema, or mobile runtime behavior was changed.
