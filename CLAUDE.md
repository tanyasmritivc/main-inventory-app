# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository ownership rules

This monorepo is worked on by two different tools. Crossing the boundary breaks things.

- **Windsurf** owns `mobile/` (Flutter) and `backend/` (Python)
- **VS Code + Claude** owns `frontend/` (Next.js)

Never change backend code in response to a frontend request, and never change mobile code
in response to a web request. When writing a prompt for the other tool, start it with an
explicit scope line (`BACKEND ONLY.` / `MOBILE ONLY.`) and end with what must not change.

Commit and push after every change.

## Commands

**Backend** (from repo root):

```bash
python -m venv .venv && source .venv/bin/activate   # Windows: .\.venv\Scripts\activate
pip install -r backend/requirements.txt
cp backend/.env.example backend/.env                # then fill in
uvicorn backend.app.main:app --reload --port 8000   # docs at /docs (dev only)
```

`/docs`, `/redoc`, and `/openapi.json` are disabled when `ENV=production`.

**Mobile**:

```bash
cd mobile
flutter pub get
flutter run --release        # NOT --debug on iOS 26 beta: JIT restriction → EXC_BAD_ACCESS code=50
flutter analyze
```

**Frontend**:

```bash
cd frontend
npm install && npm run dev   # build | start | lint
```

**Tests**: there is effectively no test coverage — only the default `mobile/test/widget_test.dart`.
Regressions surface on device rather than in CI. Treat that as context when judging risk.

## Architecture

Three clients (Flutter iOS, Next.js web) talk to one FastAPI backend, which is the only thing
that touches Postgres.

Auth flows one direction: the client authenticates with Supabase Auth in-process, then sends the
Supabase JWT as `Authorization: Bearer <token>` to FastAPI. The backend verifies it against the
project JWKS (cached 1h in `core/auth.py`), extracts `sub` as `user_id`, and from then on uses the
**service role key** for all database work. Clients never query Postgres directly for inventory
data. RLS exists as defence in depth, not as the primary access control — the backend's
`user_id` filtering is.

**Backend layering** (`backend/app/`): `api/routes/*` are thin HTTP handlers; `services/*_repo.py`
own all Supabase access; `services/ai_*.py` own OpenAI. Routes should not call Supabase directly —
several older ones do, but new code should not add to that.

**Register new routers** in `api/router.py`. It is a flat include list with no prefixes, so route
paths are absolute (`/add_item`, `/spaces`, `/import/spreadsheet`).

**Error handling** is centralised in `main.py`: four exception handlers scrub internal details
(tracebacks, file paths) before anything reaches a client. Raise `HTTPException` with a
user-facing message; never let internals into `detail`.

**Rate limiting** is slowapi, per-route via `@limiter.limit(...)`. `/search_items` is `30/minute`
and the mobile inventory page calls it on every tab switch — easy to hit in normal use.

### Spaces

Spaces were originally derived from distinct `items.location` values with no table. **That is no
longer true.** There is now a real `spaces` table (`id, user_id, name, created_at`) with a
case-insensitive unique index on `(user_id, lower(trim(name)))`, and `items.space_id` is a
nullable FK to it.

`items.location` still holds the space name for backward compatibility, so the two duplicate
each other today. `spaces_repo.rename_space` updates both in one transaction to keep them in
sync. The eventual intent is for `location` to mean the physical spot *within* a space
("third shelf, blue bin"), but nothing does that yet.

Consequences worth knowing:

- Spaces persist with zero items. Empty-state copy must not imply otherwise.
- Anything that changes a space must go through `PATCH`/`DELETE /spaces/{id}`, never by
  looping over items and rewriting `location` — a partial failure splits the space in two.

### Shared spaces

`team_shares` / `team_members` implement sharing by code with `view` or `edit` permission.
`_resolve_owner_for_joined_space` in `routes/items.py` is the subtle part: when a user adds an
item to a location matching a share they have `edit` access to, the item is written under the
**owner's** `user_id`, not theirs. Shared-space code paths are easy to break with changes that
look local — check membership resolution before touching item writes.

### Free tier

`services/usage_service.py`, `FREE_LIMITS`: 20 AI chats/mo, 5 photo scans/mo, 2 spreadsheet
imports/mo, 10 barcode scans/mo, 1 active share, 3 spaces, plus `FREE_ITEM_LIMIT = 30`.
Limits return 402/403/429 depending on the path; the mobile client turns these into the upgrade
sheet. Check limits *before* doing bulk work, not partway through.

## Landmines

These have each cost real debugging time. They are not hypothetical.

**`from __future__ import annotations` breaks `UploadFile` routes.** It makes every type hint a
lazy ForwardRef, and FastAPI's dependency injection fails at import time with
`ForwardRef('UploadFile')`, crashing the deploy. Any file containing a route with an `UploadFile`
parameter must not have that import. Add `response_model=None` to such routes too. No file in
`backend/app/` currently has it — keep it that way.

**Never call an LLM with an empty prompt and forced `tool_choice`.** `/search_items` used to call
`parse_search_query_to_keywords` unconditionally; the mobile inventory page loads via
`searchItems(query: '')`, so gpt-4o-mini received an empty message with a forced function call,
invented a `category`/`location`, and the result filter stripped every item. Nondeterministic:
sometimes fine, sometimes an empty inventory. Both the route and the parser now short-circuit on
blank input. The general rule — guard LLM calls on empty input.

**Reasoning models reject system prompts.** `parse_search_query_to_keywords` is pinned to
`gpt-4o-mini` deliberately, not `settings.openai_model`. Switching it to a reasoning model
returns a 400.

**Supabase clients must be thread-local, never per-call.** A single `@lru_cache`d client shared
across concurrent `asyncio.to_thread` calls throws `RuntimeError: deque mutated during iteration`
inside hpack. But creating a fresh client per call leaks sockets — each `Client` owns an httpx
pool that nothing closes — until the worker hits `[Errno 11] Resource temporarily unavailable` and
every endpoint times out. `create_supabase_admin()` is thread-local for this reason.
`get_supabase_admin()` (`@lru_cache`) is for the main async path only.

**SSE needs byte padding to survive Render's proxy.** `X-Accel-Buffering: no` alone is not enough.
`routes/ai.py` pads each chunk to ~1200 bytes to force a flush. Removing the padding re-buffers
the stream and chat stops feeling live.

**Never swallow a write failure.** `catch (_) {}` on a Dart write path means the user believes an
action succeeded when it did not. This produced silent data loss on space rename and silent
failure to revoke share access. Read paths may still have bare catches; write paths must not.

**`items` primary key is `item_id`, not `id`.** Same for `documents` (`document_id`),
`team_shares` (`share_id`), `checkouts` (`checkout_id`).

## Mobile notes

`inventory_page.dart` is ~4000 lines and holds the space grid, item list, item detail sheet, and
most space actions. `main_shell.dart` drives a `PageView`: Profile(0), Chat(1), Scan(2),
Inventory(3), and bumps a refresh token on page change so the inventory reloads when visible.

`core/api_client.dart` is the single place API calls live. `features/showcase/tutorial_controller.dart`
is a custom spotlight overlay — it must skip steps whose target widget does not exist, or a new
user with no spaces gets a blocking scrim with no way out.

Spreadsheet import already exists (`POST /import/spreadsheet`, `features/scan/import_sheet_page.dart`).
It reads `rows[0]` as the header unconditionally, so files with a title row or grouped headers
import garbage. `test-data/import-samples/` holds eight fixtures covering that and other parser
failure modes, with measured expected output in its README.

This file is the single source of truth for project context. `PROJECT_CONTEXT.md` and
`PROJECT_CONTEXT_EXPORT.md` were deleted in favour of it — they had drifted out of date
(claiming spaces had no table, pointing at a `routes/inventory.py` that does not exist).
If either reappears, reconcile it here rather than maintaining two documents.
