# FindEZ AI — session handoff (2026-07-30, ~1am)

Paste this into a new chat for full context. `CLAUDE.md` at the repo
root is the permanent project reference; this file is the state of
play right now, mid-testing.

---

## Project

FindEZ AI — AI inventory app. Flutter iOS (`mobile/`), FastAPI on
Render at api.findez.ai (`backend/`), Next.js on Vercel
(`frontend/`), Supabase Postgres, OpenAI. Repo:
github.com/tanyasmritivc/main-inventory-app, branch `main`.

Tool boundary (strict): **Windsurf owns mobile/ + backend/. VS Code
+ Claude owns frontend/.** Prompts for Windsurf start with
`BACKEND ONLY.` or `MOBILE ONLY.` and end with what must not change.

---

## OPEN BUG — being tested right now

**Renaming a space appears to empty it.** User renames a space →
the renamed space shows 0 items → items seem to belong to a "new"
space under the old name (or vanish entirely).

The rename code path itself was checked and is correct:
- Mobile `_renameSpace` (inventory_page.dart ~2875) calls
  `PATCH /spaces/{id}` once — no per-item loop, errors surfaced.
- Backend `rename_space` (spaces_repo.py:153) updates `spaces.name`
  then syncs `items.location` for all items `WHERE space_id = id`.

**Leading hypothesis, unverified:** the items in the renamed space
have `space_id = NULL`, so the backend's item-location sync matches
zero rows. The space row gets the new name (0 linked items); the
items keep the old location text and, because the grid renders only
from the spaces table now, they become invisible — same orphan
mechanism as the delete-space bug below.

**Verify with this SQL before changing any code:**

```sql
-- Items whose location has no matching space (the orphans)
SELECT i.name, i.location, i.space_id
FROM items i
JOIN auth.users u ON u.id = i.user_id
WHERE i.space_id IS NULL
  AND i.location IS NOT NULL AND TRIM(i.location) <> ''
  AND LOWER(TRIM(i.location)) <> 'unsorted';
```

If rows come back with the pre-rename space name, hypothesis
confirmed. Root-cause question then becomes: what created items
with NULL space_id after the backfill ran? (Possibilities: items
added between backfill and the space_id fix deploying; a write path
still missing space_id resolution; or rename happened from a page
with a stale space list.)

Also worth checking: whether a rename path exists on the space
detail page / shared spaces that bypasses `PATCH /spaces/{id}`.

---

## Architecture facts that matter (details in CLAUDE.md)

- `spaces` table is new today: `id, user_id, name, created_at`,
  case-insensitive unique index on `(user_id, lower(trim(name)))`.
  `items.space_id` nullable FK, `ON DELETE SET NULL`.
- `items.location` still duplicates the space name (legacy).
  Space cards + counts come from `GET /spaces` (spaces table only).
  **Any item with NULL space_id is invisible in the grid.**
- `items` PK is `item_id` not `id`.
- All item write paths now resolve space_id via
  `items_repo._resolve_space_id` → `get_or_create_space`
  (add_item, update_item on location change, bulk_create_items).
  AI agent's duplicate direct update was removed.
- Free-tier space limit (3) enforced inside `get_or_create_space`
  via `SpaceLimitExceeded`, translated to
  `HTTPException(403, "FREE_TIER_SPACE_LIMIT")` at routes and to a
  polite message in the AI agent.

## Landmines (full list in CLAUDE.md — do not relearn these)

`from __future__ import annotations` breaks UploadFile routes.
Never call an LLM with empty prompt + forced tool_choice
(/search_items bug — fixed, b4143eb). parse_search_query_to_keywords
pinned to gpt-4o-mini (reasoning models 400 on system prompts).
Supabase clients: thread-local, never per-call (leak → Errno 11).
SSE needs ~1200-byte padding for Render proxy. `catch (_) {}`
banned on Dart write paths.

---

## Infrastructure state

- **Render free tier: spins down after 15 min idle; cold start
  50s+.** This caused three "everything is timing out" false
  alarms today. `/health` and `/health/db` endpoints exist now.
  UptimeRobot pinger was set up but is NOT working (zero /health
  hits in Render logs). User plans to upgrade to Starter ($7/mo).
- Mobile timeouts are still 20s (_loadItems) / 30s (Dio) — a cold
  start always breaks the app. A prompt exists to raise them to
  90s + show a "waking up" banner; not yet applied.
- Supabase orphan-item backfill SQL was run ~11pm; verified 0
  unlinked afterwards. The rename bug above may have re-created
  orphans since.

## Testing state — release checklist

`test-data/release-checklist.md` (10 sections). Gates are §2, §5,
§6, §7. Progress:

- §1–§4: passed after fixes (spaces persist, counts correct,
  3 add paths set space_id).
- **§5 rename: FAILING — the open bug above.**
- §6 share/revoke (verify from second account!) and §7 airplane
  mode: NOT YET RUN.
- §10 import: mobile page exists (import_sheet_page.dart, 770
  lines) but is UNREACHABLE (no entry point) and is written
  wrong — parses on-device with `excel` pkg (OOM crash) and calls
  /ai_command instead of POST /import/spreadsheet. Rewrite prompt
  drafted, deferred to v1.1. Web app import works and must not be
  touched.

## Known bugs, deliberately deferred (not gates)

1. **Delete space orphans items** (FK SET NULL, items invisible).
   Prompt drafted: move-to-Unsorted vs delete-items dialog.
2. `.ilike("name", ...)` in spaces_repo (3 sites) treats % and _
   as wildcards — can match the wrong space.
3. `check_free_tier_limits` hardcodes 30/3, inline is_pro query,
   fetches all items to count. Consolidation prompt drafted.
4. `space_exists` in spaces_repo is dead code.
5. Tutorial never teaches creating a space (targets
   firstSpaceCardKey which doesn't exist for new users). Prompt
   drafted to add a "New Space" step.
6. Pro tier is uncapped (`limit: 999999`) — plan written in
   docs/pricing-and-limits.md: 1000 chats/mo, 300 scans/mo,
   30 scans/day, Team tier ($99/season idea), reset-time messaging
   for pro users. Pro caps are pre-launch; Team tier is v1.1.

## Today's major fixes already landed (all pushed)

spaces table migration + RLS + backfill; GET/POST/PATCH/DELETE
/spaces; space_id resolution in all write paths; space limit at
chokepoint; empty-query LLM bug; thread-local Supabase client leak;
6 write-path silent catches surfaced (incl. share revoke); atomic
rename/delete from mobile; tutorial dead-end + Skip placement;
global keyboard dismiss; /health endpoints; CLAUDE.md created;
PROJECT_CONTEXT*.md deleted as stale; 8 import test fixtures in
test-data/import-samples/ with measured expected outputs.

## Immediate next steps, in order

1. Diagnose §5 rename bug (SQL above first, then trace whichever
   path created NULL-space_id items).
2. Re-run §5 including the category-filter variant.
3. §6 with a second account — revoke MUST be verified from the
   receiving side.
4. §7 airplane mode (quantity, profile, revoke, purchase source).
5. Render Starter upgrade (or fix pinger).
6. Pro caps (docs/pricing-and-limits.md implementation section).
7. Ship-readiness call.
