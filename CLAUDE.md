# CLAUDE.md

Guidance for Claude Code / Windsurf when working in this repository.

Rewritten 2026-08-04 from a direct read of the source; hosting sections updated 2026-08-22
after the self-hosting migration completed. Everything below was verified against code in
this repo. Claims that could **not** be verified from code alone are marked
**[UNVERIFIED — needs live DB]**. Do not promote those to fact without running the check.

---

## Repository ownership rules

This monorepo is worked on by two different tools. Crossing the boundary breaks things.

- **Windsurf** owns `mobile/` (Flutter) and `backend/` (Python)
- **VS Code + Claude** owns `frontend/` (Next.js)
- **OpenCode** does VM / infrastructure work over SSH, not repo edits (see `AGENTS.md`)

**The mobile app is the source of truth for how an item is presented. The web follows mobile,
never the reverse. Do not change `mobile/` in response to a web request.**

Never change backend code in response to a frontend request, and never change mobile code in
response to a web request. Prompts written for the other tool start with an explicit scope line
(`BACKEND ONLY.` / `MOBILE ONLY.`) and end with what must not change.

Commit and push after every change.

**There is effectively no test coverage** — only the default `mobile/test/widget_test.dart`.
Regressions surface on a physical device, not in CI. Weight risk accordingly.

---

## Commands

**Backend** (from repo root):

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r backend/requirements.txt
cp backend/.env.example backend/.env                # then fill in
uvicorn backend.app.main:app --reload --port 8000   # docs at /docs (dev only)
```

`/docs`, `/redoc`, `/openapi.json` are disabled when `ENV=production` (`main.py:29-35`).
`ENV` defaults to `production`, so they are off unless you explicitly set `ENV=development`.

**Mobile**:

```bash
cd mobile && flutter pub get
flutter run --release      # NOT --debug on iOS 26 beta: JIT restriction → EXC_BAD_ACCESS code=50
flutter analyze
```

**Frontend**: `cd frontend && npm install && npm run dev`

---

## Current production hosting — fully self-hosted

As of 2026-08-22 the entire stack self-hosts on one Ubuntu 24.04 VM in a private OpenStack
environment, reached with `ssh findez`. **The backend, web app, database, authentication, and
storage are not hosted by Render, Vercel, or cloud Supabase.** Render is retired and Vercel is
superseded. The old accounts remain only for migration/fallback purposes; `findez.ai` still
points at Vercel until its DNS is moved.

| Layer | Detail |
|---|---|
| **Edge** | Caddy on the owner's network, behind UniFi port forwarding. Terminates public TLS (Let's Encrypt), routes by hostname |
| **VM web server** | nginx, ports 80 and 443, two vhosts. Self-signed cert on the internal hop |
| **Backend** | systemd unit `findez`, uvicorn on `0.0.0.0:8000`. **Not** `127.0.0.1` — Caddy connects from off-box |
| **Web app** | systemd unit `findez-web`, Next.js on port 3000 |
| **Database / auth / storage** | Self-hosted Supabase, 11 Docker containers, Kong gateway on port 18000 |

Public hostnames:

- `https://findez.openstack.ftctools.com` → the API
- `https://findez-db.openstack.ftctools.com` → Supabase
- `https://findezapp.openstack.ftctools.com` (and eventually `findez.ai`) → the web app

The self-hosted Supabase stack is **live and carrying production traffic** — PostgreSQL 17.6,
PostgREST v14.12, GoTrue v2.189.0, Kong 3.9.3, Storage v1.60.4, Supavisor 2.9.5, plus
Realtime, postgres-meta, Studio, Edge Runtime and imgproxy. Because `supabase-py` talks to
PostgREST, **no data-layer code changed** in the migration.

**Cloud Supabase is still alive and is READ-ONLY.** It is the migration source, the fallback,
and currently the only off-machine copy of the data. Do not write to it.

Full detail in `docs/self-hosted-supabase.md`; tool inventory in
`docs/migration-stack-reference.md`.

**There is no auto-deploy. Deploying is three steps, and the middle one is the one people
skip:**

```bash
ssh findez
cd ~/findez
git pull
ls backend/supabase/migrations/          # ← new file here? Run it FIRST.
sudo systemctl restart findez            # or findez-web for the website
```

A new migration file must be executed by hand in Supabase Studio, followed by
`NOTIFY pgrst, 'reload schema';`. **This has been missed three times** — `010`, `011` and
`012` — and every failure was silent or misleading: Pro users quietly treated as free,
subscription data reading empty, and chat returning 500 with
`PGRST205: Could not find the table 'public.team_memberships'`. Nothing ever says
"you forgot a migration".

Environment variables live in `~/findez/.env` (backend) and `~/findez/frontend/.env.production`
(web) on the VM, loaded by systemd via `EnvironmentFile`, so the service must be restarted
after any change. Supabase's own secrets are in `~/supabase/.secrets.txt` (chmod 600).
**Never print secrets into a chat or a commit.**

Next.js bakes `NEXT_PUBLIC_*` values in **at build time**, so changing
`.env.production` requires a rebuild, not just a restart. A `localhost` value here reaches
users' browsers and fails there — this happened once with `NEXT_PUBLIC_SUPABASE_URL`.

**Ordering rule learned the hard way:** write the `.env` file *first*, then recreate
containers. Doing it the other way round leaves everything running on stale credentials while
the file claims otherwise, and verification passes against the stale state.

**Backups**: nightly at 02:30 UTC via systemd timer, `pg_dump` custom format, restore-verified
into a throwaway container by comparing row counts. Failures surface in the SSH login banner.
`~/findez-backups/daily/config-*.tar.gz` contains password hashes and **must never leave the
VM**. Everything currently lives on one disk (`/dev/vda1`); off-machine backup (restic → B2/S3)
is recommended and **not yet implemented**.

## Known open issues (2026-08-22)

- **Google / Apple sign-in is broken on the self-hosted stack.** `supabase-auth` cannot make
  outbound HTTPS: `Get "https://accounts.google.com/.well-known/openid-configuration": context
  deadline exceeded` → 504 after 10s. Established so far: host `curl` → 200; `curl` inside the
  auth container's *network namespace* → 200; `wget` inside the container → timeout. Not DNS,
  not a proxy env var, restart doesn't help, intermittent. Under investigation.
- **Web OAuth needs redirect config.** Mobile uses the native ID-token flow
  (`signInWithIdToken`); web uses the redirect flow and returns
  `{"code":400,"error_code":"validation_failed","msg":"Unsupported provider: missing redirect
  URI"}`. Needs `GOTRUE_SITE_URL` + `GOTRUE_EXTERNAL_*_REDIRECT_URI` and callback URLs
  registered with Google and Apple.
- **"Couldn't load your spaces"** on findezapp, despite `NEXT_PUBLIC_API_BASE_URL` being
  correct. Uninvestigated.
- **No SMTP**, so password reset and invites don't work. `ENABLE_EMAIL_AUTOCONFIRM=true` means
  no address is ever actually verified.
- **Credentials that were exposed during the migration and still need rotating**: the Google
  client secret, the Apple secret JWT.
- **`findez.ai` DNS** still points at Vercel; the owner is moving it.

## Auth — two verification paths

`core/auth.py` verifies the Supabase JWT and extracts `sub` as `user_id`. It branches on the
token's declared `alg`:

- **ES256/RS256** → verified against project JWKS, cached 1h. This is cloud Supabase.
- **HS256** → verified against `supabase_jwt_secret` from config. This is the self-hosted
  stack, which signs with a shared secret.

The HS256 branch was added additively (commit `8bb1fb6`) and is safe because it uses a
separate secret that is unset on cloud. Both paths are verified working. Do not collapse them.

---

## Architecture

Two clients (Flutter iOS, Next.js web) talk to one FastAPI backend, which is the only thing that
touches Postgres.

Auth flows one direction: the client authenticates with Supabase Auth in-process, then sends the
Supabase JWT as `Authorization: Bearer <token>`. The backend verifies it (`core/auth.py` — see
the two-path note above), extracts `sub` as `user_id`, and from then on uses the **service role
key** for all database work. Clients never query Postgres directly for inventory data. RLS is
defence in depth, not the primary access control — backend `user_id` filtering is.

The **anon key** is public by design and is safe in client bundles. The **service role key**
bypasses RLS entirely and must never leave the backend.

**Backend layering** (`backend/app/`): `api/routes/*` are thin HTTP handlers; `services/*_repo.py`
own Supabase access; `services/ai_*.py` own OpenAI. Several older routes call Supabase directly
(`routes/checkouts.py` does all its own table work); new code should not add to that.

**Register new routers** in `api/router.py` — a flat include list. Most routers have no prefix, so
paths are absolute (`/add_item`, `/spaces`, `/import/spreadsheet`). One exception:
`routes/billing.py` uses `APIRouter(prefix="/billing")`.

**Error handling** is centralised in `main.py`: handlers scrub internal details (tracebacks, file
paths, `/app/`, `/home/`, `/usr/`) before anything reaches a client. Raise `HTTPException` with a
user-facing message; never let internals into `detail`.

**Rate limiting** is slowapi, per-route:

| Route | Limit |
|---|---|
| `POST /search_items` | 30/minute |
| `POST /ai_command` | 20/minute |
| `POST /extract_from_image`, `/inventory/extract_from_image` | 10/minute |
| `POST /ai_upload` | 10/minute |
| `POST /import/spreadsheet` | 5/minute |

The mobile inventory page calls `/search_items` on every tab switch — 30/min is easy to hit.

**Health**: `GET /health` and `GET /health/db` exist (`main.py:146-151`). A startup Supabase check
runs in the lifespan hook.

---

## Route surface (complete, as of this rewrite)

Generated from `@router.*` decorators across `backend/app/api/routes/`.

- **items.py** — `POST /add_item`, `POST /search_items`, `DELETE /delete_item`,
  `PATCH /update_item`, `POST /extract_from_image`, `POST /inventory/extract_from_image`,
  `POST /inventory/bulk_create`, `POST /process_barcode`, `POST /barcode_lookup`,
  `GET /items/{item_id}/history`
- **spaces.py** — `GET|POST /spaces`, `PATCH|DELETE /spaces/{space_id}`
- **checkouts.py** — `POST /checkouts/ping`, `POST /checkouts/checkout`, `POST /checkouts/return`,
  `GET /checkouts/active`, `GET /checkouts/space`, `GET /checkouts/item/{item_id}`
- **sharing.py** — `POST /sharing/create`, `GET /sharing/my-shares`, `POST /sharing/join`,
  `GET /sharing/joined`, `DELETE /sharing/{share_id}`,
  `DELETE /sharing/{share_id}/members/{member_id}`, `DELETE /sharing/{share_id}/leave`,
  `GET /sharing/{share_id}/inventory`, `POST /sharing/{share_id}/invite`,
  `GET /sharing/{share_id}/members`, `GET /sharing/{share_id}/items/{item_id}/history`
- **ai.py** — `POST /ai_command`, `POST /ai_upload`
- **conversations.py** — `GET|POST /conversations`, `GET|DELETE /conversations/{conversation_id}`
- **documents.py** — `POST /documents/upload`, `GET /documents`, `PATCH /documents/rename`,
  `PATCH /documents/link`, `DELETE /documents`
- **imports.py** — `POST /import/spreadsheet`
- **activity.py** — `GET /activity/recent`
- **profile.py** — `PATCH /profile/update`, `GET /profile/me`
- **usage.py** — `GET /usage/status`, `GET /usage`, `POST /usage/check`, `POST /usage/increment`
- **billing.py** — `POST /billing/create-checkout-session`, `POST /billing/stripe-webhook`
- **stripe_routes.py** — `POST /stripe/create-checkout-session`, `POST /stripe/webhook`,
  `GET /stripe/subscription-status`, `POST /stripe/cancel-subscription`

There is **no `routes/inventory.py`**. A stale `__pycache__/inventory.cpython-*.pyc` exists
locally from a deleted file; it is gitignored and is not evidence of a live module.

---

## Database

### Migration files are incomplete — but there is now a schema baseline

`backend/supabase/migrations/` contains `001_init` … `012_teams_and_licenses.sql`. The early
files create only: `items`, `documents`, `activity_log` (altered), `profiles` (altered),
`usage_limits`, `item_events`, `conversations`, `messages`.

Code reads and writes these tables **with no `CREATE` migration in the repo**:

`spaces`, `checkouts`, `team_shares`, `team_members`, `parts_catalog`, `user_memory`,
`query_logs`, `conversation_sessions`, `conversation_history`, `user_plan`, and `profiles`
itself.

Those tables were created by hand in the Supabase dashboard, so the numbered migrations alone
cannot rebuild the database. **This was closed in August 2026** by dumping the live schema to
`backend/supabase/schema-baseline-2026-08-10.sql` (1,421 lines), which *is* committed and *can*
rebuild it. Treat the baseline as the source of truth for schema, not the numbered files.

`012_teams_and_licenses.sql` introduces a **second, separate** team model — `teams`,
`team_memberships`, `licenses`, `team_usage_counters` — deliberately named to avoid colliding
with the older `team_shares` / `team_members` sharing system, which it does not touch. Two team
concepts now coexist. Know which one you are looking at.

### `items`

Migration `001_init` defines: `item_id` (PK, uuid), `user_id`, `name`, `category` (NOT NULL),
`quantity` (NOT NULL), `location` (NOT NULL), `image_url`, `barcode`, `purchase_source`, `notes`,
`created_at timestamptz`. `002` adds `subcategory`, `brand`, `part_number`, `tags text[]`,
`confidence`.

`space_id` is used throughout the code but **added by no migration in the repo**.

**[UNVERIFIED — needs live DB]** A prior schema dump reported `items.created_at` as
`timestamp without time zone`, which contradicts `001_init`. If true, the live table drifted from
the migration and it is a real migration hazard. Check before writing any time-based query:

```sql
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'items' ORDER BY ordinal_position;
```

**RLS on `items`**: `001_init` creates SELECT, INSERT and DELETE policies only. **There is no
UPDATE policy.** Backend uses the service role so it does not surface, but it is a real gap in the
defence-in-depth story, and it will surface the moment anything queries with a user token.

**PK naming**: `items.item_id`, `documents.document_id`, `team_shares.share_id`,
`checkouts.checkout_id`, `item_events.event_id`, `activity_log.activity_id`. Not `id`.
Exceptions that *do* use `id`: `spaces.id`, `conversations.id`, `profiles.id`.

### Spaces

There is a real `spaces` table (`id, user_id, name, created_at`) — `services/spaces_repo.py`
queries it directly. `items.space_id` is a nullable FK with `ON DELETE SET NULL`.

`items.location` still holds the space name for backward compatibility, so the two duplicate each
other. `spaces_repo.rename_space` updates both. The eventual intent is for `location` to mean the
spot *within* a space; nothing does that yet, and **no `bin` column exists anywhere in the
codebase.**

Consequences:

- **Any item with `space_id IS NULL` is invisible in the mobile grid**, because the grid renders
  from `GET /spaces` only. This is the mechanism behind both the rename-empties-a-space bug and
  the delete-space-orphans-items bug.
- Anything that changes a space must go through `PATCH`/`DELETE /spaces/{id}`, never by looping
  over items and rewriting `location` — a partial failure splits the space in two.
- Spaces persist with zero items. Empty-state copy must not imply otherwise.
- `spaces_repo` used `.ilike("name", name)`, where `%` and `_` in a space name are wildcards and
  match the wrong space. **Fixed August 2026** — re-check before assuming any new lookup is safe.
- `spaces_repo.space_exists` is dead code.

### Shared spaces

`team_shares` / `team_members` implement sharing by code with `view` or `edit` permission.
`_resolve_owner_for_joined_space` in `routes/items.py` is the subtle part: when a user adds an item
to a location matching a share they have `edit` on, the item is written under the **owner's**
`user_id`, not theirs. `routes/checkouts.py` reimplements the same membership resolution inline
(memberships → share_ids → owner_ids → items). Two copies of this logic now exist; changing one
without the other is a live bug source.

**[UNVERIFIED — needs live DB]** A prior `pg_policies` dump showed `team_members.owner_see_members`
selecting from `team_shares` while `team_shares.member_view_shares` selects from `team_members` —
mutually referential `ALL` policies, a classic RLS infinite-recursion shape. The backend's service
role bypasses RLS so this may never have surfaced. It must be resolved before any client is
allowed to query with a user token.

---

## Monetization — Stripe, and it is duplicated

**There is no RevenueCat.** No `purchases_flutter` in `mobile/pubspec.yaml`, no RevenueCat SDK, no
webhook handler, zero references in `backend/`. If `profiles.rc_customer_id` exists in the live DB
it is a vestigial column with nothing writing to it.

What exists instead is **two independent Stripe implementations**:

| | `routes/billing.py` (92 lines) | `routes/stripe_routes.py` (152 lines) |
|---|---|---|
| Checkout | `POST /billing/create-checkout-session` | `POST /stripe/create-checkout-session` |
| Webhook | `POST /billing/stripe-webhook` | `POST /stripe/webhook` |
| On success | sets `profiles.is_pro = true` | sets `is_pro`, `stripe_subscription_id`, handles cancel/status |
| Extra | — | `GET /stripe/subscription-status`, `POST /stripe/cancel-subscription` |

Both are registered in `api/router.py`. Both read `STRIPE_SECRET_KEY`, `STRIPE_PRICE_MONTHLY`,
`STRIPE_PRICE_YEARLY`. Mobile `ProStatus.refresh` calls `getSubscriptionStatus`, which is the
`/stripe/*` family — so **`billing.py` appears to be the dead one**, but it is still mounted and
still has a live webhook URL. Whichever Stripe dashboard endpoint is configured decides which one
actually fires. Resolve this before touching pricing.

**Also note**: there is no in-app purchase path on iOS at all. Payment is Stripe Checkout only.
Selling a digital subscription from inside an iOS app without StoreKit is an App Store review
rejection. This needs a decision before pilot distribution.

### Free tier

`services/usage_service.py`, `FREE_LIMITS`: 20 AI chats/mo, 5 photo scans/mo, 2 spreadsheet
imports/mo, 10 barcode scans/mo, 1 active share, 3 spaces. `FREE_ITEM_LIMIT = 30` lives separately
in `items_repo`. Counters persist in the `usage_limits` table (migration `007`, atomic increment
RPC) — they are **not** in-memory and do not reset on deploy.

Three inconsistencies, all real:

1. `usage_service.get_usage_count("spaces")` counts **distinct `items.location` values**, the
   pre-`spaces`-table logic. `spaces_repo.get_or_create_space` enforces the same limit from the
   **`spaces` table**. Two sources of truth for one limit; they disagree whenever a space is empty
   or an item has a NULL `space_id`.
2. `usage_service.get_user_plan` queries a `user_plan` table that no migration creates and nothing
   else references. Its `except` returns `"free"`, so it silently always returns `"free"`.
3. `items_repo.check_free_tier_limits` hardcodes 30/3, runs its own inline `is_pro` query, and
   fetches every item row to count them.

Limits return 402/403/429 depending on path; the mobile client turns these into the upgrade sheet.
Check limits *before* doing bulk work, not partway through.

Pro tier is currently uncapped (`limit: 999999`). Intended caps are in `docs/pricing-and-limits.md`.

---

## AI and conversation storage

`services/openai_service.py` owns OpenAI calls; `services/ai_agent.py` owns tool dispatch;
`services/ai_memory.py` does background fact extraction.

**Four different conversation stores are referenced in live code:**

- `conversations` + `messages` — migration `009`, used by `routes/conversations.py` and `routes/ai.py`
- `conversation_sessions` — `ai_agent.py:58, 82`, no migration
- `conversation_history` — `ai_memory.py:216, 220`, no migration
- `user_memory`, `query_logs` — `ai_memory.py`, no migration

`conversations`/`messages` is the real one. The rest are either legacy or silently failing inside
`try/except`. Do not add a fifth.

`documents` has an undocumented AI-consent mechanism: `ai_access_granted` /
`ai_access_granted_at`, read and written by `documents_repo.get_ai_access_granted` /
`grant_ai_access`. Document text is only exposed to the model after that flag is set. Preserve
this behaviour — it is a privacy commitment, and this repo serves minors.

`parts_catalog` exists (`services/catalog_service.py`) but is **barcode-keyed only**:
`barcode → canonical_name, brand, category, subcategory, part_number, confirmation_count, source`.
It is populated as a flywheel from UPC lookups (upcitemdb → go_upc → openfoodfacts → AI) and from
confirmed user scans. It has no dimensions, no vendor SKUs, and no fuzzy name matching. It is not
the seeded vendor catalog the product plan calls for — that would be new work on top.

---

## Landmines

Each cost real debugging time. All re-verified 2026-08-04 unless noted.

**`from __future__ import annotations` breaks `UploadFile` routes.** It makes every type hint a
lazy ForwardRef and FastAPI's DI fails at import time, crashing the deploy. Add
`response_model=None` to such routes too. **Verified: zero occurrences in `backend/app/`. Keep it
that way.**

**Never call an LLM with an empty prompt and forced `tool_choice`.** `/search_items` used to call
`parse_search_query_to_keywords` unconditionally; the mobile inventory page loads via
`searchItems(query: '')`, so the model received an empty message with a forced function call,
invented a `category`/`location`, and the filter stripped every item. Nondeterministic. Both the
route and the parser now short-circuit on blank input. General rule: guard LLM calls on empty input.

**Reasoning models reject system prompts.** `gpt-4o-mini` is pinned deliberately (not
`settings.openai_model`) at `openai_service.py:347, 515, 605` and `ai_memory.py:58`. Switching any
of those to a reasoning model returns 400. **Note there are four pin sites, not one.**

**Supabase clients must be thread-local, never per-call.** A single `@lru_cache`d client shared
across concurrent `asyncio.to_thread` calls throws `RuntimeError: deque mutated during iteration`
inside hpack. A fresh client per call leaks sockets until `[Errno 11]` and every endpoint times
out. `create_supabase_admin()` is thread-local (`supabase_client.py:26-29`);
`get_supabase_admin()` (`@lru_cache`) is for the main async path only. **Verified still in place.**

**SSE byte padding — probably now obsolete, but untested.** `X-Accel-Buffering: no` alone is not enough.
`routes/ai.py:334` pads each chunk to ~1200 bytes to force a flush. Removing it re-buffers the
stream and chat stops feeling live. **This was a workaround for Render's proxy, and the
backend no longer runs on Render — it now sits behind nginx with `proxy_buffering off`,
which solves the same problem properly. The padding is very likely dead weight. Nobody has
checked. Re-test chat streaming before deleting it, don't just assume.**

**AI grounding bug — open.** `_should_enable_tools()` in `services/ai_agent.py` empties the
inventory context in some paths while `ai_memory` still injects remembered facts, so the model
answers confidently from memory about items it cannot currently see. Unfixed.

**The spreadsheet importer used to discard `Category`.** Fixed August 2026, but
`test-data/import-samples/` exists precisely because this class of bug is easy to reintroduce.
Run the fixtures after touching `imports.py`.

**Never swallow a write failure.** `catch (_) {}` on a Dart write path means the user believes an
action succeeded when it did not. This produced silent data loss on space rename and silent
failure to revoke share access. **17 bare `catch (_) {}` remain in `mobile/lib`** — read paths are
acceptable, write paths are not. Audit before adding more.

---

## Mobile notes

**TestFlight:** iOS version 1.0.5 build 7 was uploaded successfully to App Store Connect on
2026-08-28 (delivery UUID `9f3afa6c-f7c1-41dd-82b4-c5c12cb4fefd`). The app now targets iOS 15.

`mobile/lib` is 47 Dart files, ~31k lines. The four largest:
`inventory_page.dart` (3981), `shared_inventory_page.dart` (2869), `chat_page.dart` (2748),
`scan_page.dart` (2448).

`main_shell.dart` drives a `PageView`: Profile(0), Chat(1), Scan(2), Inventory(3), bumping a
refresh token on page change so inventory reloads when visible.

`core/api_client.dart` (1020 lines) is the single place API calls live.

`features/showcase/tutorial_controller.dart` is a custom spotlight overlay — it must skip steps
whose target widget does not exist, or a new user with no spaces gets a blocking scrim with no way
out. It still never teaches creating a space (targets a card key that does not exist for new users).

**`inventory_page.dart` controller disposal: this appears already fixed.** All four `State` classes
declare their `TextEditingController`s `late final`, initialise every one in `initState`, and
dispose every one in `dispose` — checked at lines 84-135/99-110, 1581-1612/1741-1754, 3557-3559,
3788-3808. `_InventoryPageState.dispose` also correctly calls `removeObserver`. If a disposal crash
is still being observed on device, it is not in this file and the repro needs re-capturing.

**Offline is not implemented.** `core/inventory_cache.dart` is 11 lines holding a static in-memory
`List<InventoryItem>`. It does not survive an app restart and does not persist to disk. The
"works on bad competition wifi" requirement is currently unmet.

**Low-stock thresholds are device-local.** `core/low_stock_prefs.dart` stores them in
`SharedPreferences` keyed by item id. They do not sync, and a team of fifteen people each sees
their own thresholds.

**`bin_label_sheet.dart` is misleadingly named.** It prints a *space* label — the QR encodes
`findez://space/<name>`. There is no bin concept in the app.

**Spreadsheet import**: backend `POST /import/spreadsheet` works and the web app uses it. The
mobile page (`features/scan/import_sheet_page.dart`, 770 lines) exists but has no entry point and
is written wrong — it parses on-device with the `excel` package (OOM risk) and posts to
`/ai_command` instead. The parser reads `rows[0]` as the header unconditionally, so files with a
title row or grouped headers import garbage. `test-data/import-samples/` holds eight fixtures
covering that and other failure modes, with measured expected output in its README.

---

## Repo hygiene

`.gitignore` ends with a malformed line: `mobile/.env.claude/settings.local.json` — two entries
concatenated with a missing newline. `mobile/.env` is still covered by the earlier `.env`
catch-all, but `.claude/settings.local.json` is not ignored. Split the line.

---

## Document policy

This file is the single source of truth for project context. `PROJECT_CONTEXT.md` and
`PROJECT_CONTEXT_EXPORT.md` were deleted (commit `36fd803`) as stale and are confirmed absent.
If either reappears, delete it again rather than maintaining two documents.

`docs/session-handoff-2026-07-30.md` is a point-in-time testing log, not a reference. Its
architecture section is superseded by this file.
