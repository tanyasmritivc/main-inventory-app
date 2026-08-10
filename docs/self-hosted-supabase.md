# Self-hosted Supabase on the VM

Set up 2026-08-10. **This is a parallel stack. The live app still uses cloud Supabase.**
Nothing has been switched over.

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

## Still to do before anything can switch over

1. **Storage has not moved.** Every uploaded document is still in cloud Supabase Storage.
   `documents.storage_path` points at files that do not exist in this stack.
2. **The mobile app also authenticates against Supabase directly** — `mobile/.env` would
   change too, not just the backend. That is Windsurf's lane.
3. **Apple and Google sign-in need reconfiguring** against the new auth URL and callback
   addresses. External, fiddly, not automatable.
4. **Everyone gets logged out.** The stack signs tokens with a different `JWT_SECRET`, so
   existing sessions won't validate. Passwords carried over, so people can log back in.
5. **Nobody is backing this up.** Cloud Supabase did it invisibly. Here it's yours, and
   there is currently no backup job at all.
6. **The keys have been pasted into a chat.** Regenerate before this stack ever holds real
   user data.

## How the switch would work, when it happens

Change in `~/findez/.env`: `SUPABASE_URL` → `http://localhost:18000`, plus the new anon and
service role keys. Restart `findez`. **No application code changes** — `supabase-py` talks
to PostgREST, and that is exactly what this stack runs.

Reverting is the same edit backwards. Keep cloud Supabase alive until well after the
switch.
