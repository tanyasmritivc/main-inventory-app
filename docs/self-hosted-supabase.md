# Self-hosted Supabase on the VM

Set up 2026-08-10. **This is a parallel stack. The live app still uses cloud Supabase.**
Nothing has been switched over.

---

## Deploying the backend — read this every time

There is no auto-deploy. Render used to do this invisibly; the VM does not.

```bash
ssh findez
cd ~/findez
git pull
ls backend/supabase/migrations/          # ← DO NOT SKIP
sudo systemctl restart findez
systemctl status findez --no-pager
```

**If `git pull` brought a new file into `backend/supabase/migrations/`, you must run that
SQL by hand in the Supabase SQL editor before the code is safe to serve.** Then
`NOTIFY pgrst, 'reload schema';` so PostgREST notices the new tables.

This has been missed **three times**, each costing 30–60 minutes:

| Missed | Symptom |
|---|---|
| `010_tier_and_usage_counters` | Every Pro user silently treated as free tier |
| `011_stripe_billing` | Subscription info read as empty |
| `012_teams_and_licenses` | Chat and `/me/limits` returning 500 — `PGRST205: Could not find the table 'public.team_memberships'` |

Every one failed *silently or confusingly*, never with a message naming the real cause.
Checking the migrations directory takes two seconds.

---

## What is running where

Everything lives on the OpenStack VM, reached with `ssh findez`
(`10.20.0.85` internally, `192.168.1.215` from the uncle's network).

| What | Where | Notes |
|---|---|---|
| **Live backend** | systemd unit `findez`, uvicorn on `127.0.0.1:8000` | Still points at **cloud** Supabase |
| **nginx** | ports 80 and 443 | Proxies to the live backend |
| **Native Postgres 17** | `127.0.0.1:5432`, database `findez` | A restore experiment. Superseded by the stack below — kept only as a second copy |
| **Self-hosted Supabase** | `~/supabase`, 11 containers | The real target. Not yet used by anything |

### Self-hosted stack ports — deliberately remapped

| Service | Default | Remapped to | Why |
|---|---|---|---|
| Kong HTTP (the API gateway) | 8000 | **18000** | 8000 is the live uvicorn backend |
| Kong HTTPS | 8443 | 8443 | free |
| Postgres via Supavisor | 5432 | **15432** | 5432 is the native Postgres |
| Supavisor txn pool | 6543 | 6543 | free |

**Nothing in the stack binds to 80, 443, 8000 or 5432.** That is deliberate and must stay
true — those belong to the live app.

API endpoints on the stack: `http://<vm>:18000/rest/v1`, `/auth/v1`, `/storage/v1`,
Studio at `/studio`.

---

## Files on the VM

| Path | Contents | Sensitivity |
|---|---|---|
| `~/supabase/` | The running stack: docker-compose, `.env`, volumes | `.env` holds all secrets |
| `~/supabase/.secrets.txt` | Generated keys, `chmod 600` | High |
| `~/findez-backup/schema.sql` | Public schema dump from cloud | Also committed to the repo |
| `~/findez-backup/data.sql` | All table data | Real user data — never commit |
| `~/findez-backup/auth-schema.sql` | Auth schema **including password hashes** | **Highest. Never leaves the VM.** |
| `~/.findez-migration.env` | `LOCAL_DB` and `SUPA_URL` connection strings | High, `chmod 600` |
| `~/supabase-src/` | Leftover sparse checkout, used to extract `docker/` | Safe to delete |

The repo holds `backend/supabase/schema-baseline-2026-08-10.sql` — the schema only, no data.

---

## Running the stack

```bash
ssh findez
cd ~/supabase
sudo docker compose ps          # all 11 should be healthy
sudo docker compose up -d       # start
sudo docker compose down        # stop (data survives — it's in volumes)
sudo docker compose logs -f kong
```

**Calling the API needs two headers, not one.** Kong uses key-auth, so `Authorization`
alone returns "No API key found":

```bash
curl -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY" \
  "http://localhost:18000/rest/v1/items?select=item_id&limit=1"
```

`200` with an empty array is **success** — anon has no SELECT policies, so no rows is
correct. The signal is 200 versus 401.

---

## What was migrated, and verified

All 19 public tables match cloud exactly:

`activity_log` 3617 · `checkouts` 2 · `conversation_history` 134 ·
`conversation_sessions` 8 · `conversations` 151 · `documents` 12 · `item_events` 0 ·
`items` 216 · `messages` 299 · `parts_catalog` 3 · `profiles` 18 · `query_logs` 136 ·
`spaces` 20 · `team_members` 5 · `team_shares` 31 · `usage_counters` 1 ·
`usage_limits` 26 · `user_memory` 20 · `user_plan` 0

`auth.users`: **19** — the faithful cloud figure, with password hashes and Apple/Google
identities. (The native Postgres on 5432 has only 18; its user list was reconstructed from
IDs found in public tables, which missed an account that had never created any data.)

Message text integrity was checked by character count, not just row count:
`SUM(LENGTH(content))` 27398, `SUM(LENGTH(role))` 1941, `MAX(LENGTH(content))` 1881 —
identical on both sides.

### Two gotchas hit during the restore

**The `messages` COPY aborts** because the `AFTER INSERT` trigger
`update_conversation_on_message` runs an unqualified `UPDATE conversations …`, and
`pg_dump` sets `search_path` to empty during a data restore, so `conversations` can't be
resolved. Fix: `ALTER TABLE messages DISABLE TRIGGER update_conversation_on_message`
around the load, re-enable after. This is also *correct* rather than a workaround —
letting the trigger fire would overwrite every restored `conversations.updated_at` with
today's date.

**Restore order is auth first.** `auth-schema.sql` → `schema.sql` → `data.sql`, because ten
tables have foreign keys to `auth.users`.

---

## Storage — migrated and verified (2026-08-10)

Both buckets recreated on the stack as public, all 24 objects transferred with exact paths
preserved.

| Bucket | Objects | Bytes |
|---|---|---|
| `documents` | 18 | 9,072,439 |
| `item-images` | 6 | 823,477 |

Verified by count, total bytes, three SHA-256 spot checks (a PDF, a filename containing
spaces, a PNG whose MD5 matched the cloud eTag), and — the check that actually matters —
**all 12 `public.documents.storage_path` values fetched successfully from the stack**,
every one returning 200 with non-zero length.

Two things surfaced during the survey, both worth fixing eventually:

- **Both buckets are public.** Any uploaded document is readable by anyone with the URL, no
  login required. That mirrors cloud, so it is not a migration bug — but for a product
  serving minors it deserves a deliberate decision rather than a default.
- **Six orphaned objects.** The `documents` bucket holds 18 files but only 12 rows
  reference them. Deleting a document removes the row and leaves the file. Storage grows
  forever, and "deleted" files aren't.

---

## Backend compatibility — measured, not guessed (2026-08-11)

A second, temporary uvicorn was run on `127.0.0.1:8001` against `.env.selfhosted`, while
the live one kept serving on 8000. Results:

| Check | Result |
|---|---|
| `GET /health` | 200 |
| `GET /health/db` | **200** — the data layer works against the stack, unmodified |
| Authenticated call with a stack-issued token | **401 `Invalid token header`** |

**The data layer needs no code changes at all.** `supabase-py` talks to PostgREST, which is
what the stack runs. All 149 `.table(...)` call sites work as-is. The "rewrite the data
layer" scenario does not exist.

### Auth — RESOLVED 2026-08-12, commit `8bb1fb6`

An **additive** HS256 path was added to `auth.py`, with `supabase_jwt_secret` in
`config.py` and `SUPABASE_JWT_SECRET` in `.env.example`. The existing JWKS / ES256 / RS256
path is untouched and remains the default.

Verified both ways: a stack-issued HS256 token now returns 200 from `/profile/me` on the
test instance, and the live app on a real phone still authenticates a genuine cloud-issued
token. Deployed to the VM and running.

`SUPABASE_JWT_SECRET` lives **only** in `~/findez/.env.selfhosted`, never in
`~/findez/.env`. On cloud the setting is unset, which makes the HS256 branch unreachable —
that is what makes branching on the token's declared `alg` safe here rather than a JWT
algorithm-confusion hole. There is a comment in the code saying so.

### Original diagnosis, kept for reference

`backend/app/core/auth.py`:
- `_select_jwk` (~line 76) requires a `kid` in the token header to match against JWKS
- the decode (~line 122) only accepts `["ES256", "RS256"]`

Cloud Supabase signs asymmetrically and publishes a JWKS. **The self-hosted stack signs
HS256 with a shared `JWT_SECRET` and its JWKS endpoint returns `{"keys":[]}`.** So a
stack-issued token has no `kid`, `_select_jwk` rejects it, and every authenticated request
401s.

Fix: add an HS256 branch — when the header `alg` is HS256 (or JWKS is empty), verify with
`jwt.decode(token, settings.supabase_jwt_secret, algorithms=["HS256"], audience=...)`, and
short-circuit `_select_jwk` so it never sees the token. Add `supabase_jwt_secret` to
`config.py`.

**Write it as an additional path, not a replacement.** Done that way the same code works
against cloud *and* the stack, so it can ship immediately while still on cloud, and the
eventual switch becomes purely a config change.

### Email is broken on the stack — a bigger blocker than the auth change

`/auth/v1/signup` returns 500. The compose references a mail container that isn't running,
so the confirmation send fails and the user row rolls back. That means **nobody can sign
up, reset a password, or be invited.** For a product where a mentor sets up a team and
invites fifteen students, that blocks a pilot outright.

It's configuration, not new infrastructure: GoTrue takes SMTP settings, and `resend` is
already in `backend/requirements.txt` with a `RESEND_API_KEY` in the env template. Point
GoTrue's SMTP at Resend.

---

## Still to do before anything can switch over

| | Size |
|---|---|
| ~~`auth.py` HS256 path~~ | ✅ done, `8bb1fb6` |
| GoTrue SMTP via Resend, so signup / reset / invite work | config |
| `mobile/.env` repoint — the Flutter app authenticates against Supabase directly | one line, **Windsurf's lane** |
| Apple + Google sign-in reconfigured against the new auth URL and callbacks | external, fiddly, not automatable |
| Backups for the stack — cloud did this invisibly, here there are none at all | ops |
| Regenerate the keys, which have been pasted into chat transcripts | minutes |

**Everyone gets logged out** at the switch: the stack signs with a different `JWT_SECRET`,
so existing sessions won't validate. Passwords carried over, so people can log back in.
With 19 test users that's nothing; with pilot teams it's an announcement.

## How the switch works, when it happens

`~/findez/.env.selfhosted` already exists on the VM with the four lines repointed
(`SUPABASE_URL`, anon key, service role key, JWKS URL). Switching is copying it over
`~/findez/.env` and restarting `findez`. Reverting is the same move backwards.

Keep cloud Supabase alive and paid for well past the switch.
