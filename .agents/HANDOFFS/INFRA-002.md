# INFRA-002 handoff

## Task ID and status

- **Task ID:** INFRA-002
- **Status:** Blocked. Read-only production checkout inventory is complete; unique
  server work is identified but not yet preserved in Git.
- **Agent:** Claude Code (took over from Codex on 2026-09-23)
- **Worktree:** `~/dev/findez-agent-context` (shared context only). Production was
  inspected over `ssh findez`, read-only.
- **Branch:** `docs/agent-context`
- **Compared against:** `origin/main` at `d2accf3` (2026-09-22)

## Objective

Reconcile the dirty production checkout at `/home/ubuntu/findez` so normal
pull-based deployments can resume, without losing unrelated production work.

## Work completed

### Earlier (Codex, landing verification)

- Production landing source is byte-identical to `origin/main`. Public HTTPS, the 17
  landing assets, and the `/product` and `/robotics` 308 redirects were verified.
  No landing redeploy was needed.

### This session (read-only inventory)

Production checkout facts:

- Branch `main`, HEAD `1d9d5d8` (2026-08-30). `1d9d5d8` is an ancestor of
  `origin/main`, which is 226 commits ahead. There is no stash.
- 190 dirty paths: 69 modified, 5 deleted, 116 untracked.
- `findez` runs uvicorn from `/home/ubuntu/findez/backend` using
  `/home/ubuntu/findez/.venv`. It was last started at 2026-09-23 02:08 UTC, so the
  dirty working tree is the running code.

Method: each dirty file was hashed on the VM with `git hash-object`, without `-w`,
and `git --no-optional-locks`, so nothing on the VM was written. The hashes were then
compared locally against `origin/main` at the same path and against every historical
blob of that path on `origin/main`.

#### 1. Already in `origin/main`: 178 of 190 paths

- **170 byte-identical** to `origin/main`. This covers all FIND, agent-gateway,
  API-key, Team, notification, push, Project Kit, landing, and web-app files,
  migrations `020`–`034`, `024_profile_identity.sql`, `config.py`, and
  `email_delivery.py`.
- **5 deletions** also deleted on `origin/main`:
  - `backend/app/services/openai_service.py`
  - `frontend/src/app/dashboard/page.tsx`
  - `frontend/src/app/favicon.ico`
  - `frontend/src/app/shopping-list/page.tsx`
  - `frontend/src/components/site/dashboard-client.tsx`
- **3 superseded.** Each production blob is an older version already committed on
  `origin/main`, which changed it later:
  - `backend/tests/test_agent_gateway.py`, matching `bc00922`
  - `backend/tests/test_api_key_authentication.py`, matching `e201f50`
  - `docs/api_key_api.md`, matching `e201f50`

  These files only matter for tests and docs.

#### 2. Unique server/production work: the transactional-email feature

Written on the VM around 2026-08-29 20:35–20:46 UTC, never committed, and deployed
live:

| Path | State | Blob |
|---|---|---|
| `backend/app/api/routes/email.py` | untracked | `69f8f285c0b5e06a9c0d280a785997d1604f4c09` |
| `backend/app/services/email_service.py` | untracked | `bd23303e9f1e74df707a5eb4bcf9a2753f7f9169` |
| `backend/supabase/migrations/014_transactional_email.sql` | untracked | `c34e2d6e796f88a54e5aa1e4743670fd7fb33322` |
| `backend/tests/test_email_service.py` | untracked | `5cbe8e054ce5ee055ff5672f9b69c1d17c6c117c` |
| `backend/app/api/routes/sharing.py` | modified | `dd2e68005116b27d404fe1f62cc5acb76833a04c` |
| `backend/app/api/router.py` | modified | `ce107a4cf89dfbb6fc9bdf4651b60a682a040fea` |

What it does:

- `POST /email/send`: authenticated, 10/minute, requires an `Idempotency-Key`.
  Templates are `team_invitation` (owner-verified `share_id`) and `custom`.
- `email_service.py` sends over server-side SMTP settings and records audit rows in
  `public.email_deliveries` (pending/sent/failed, unique per user and idempotency
  key).
- Production `sharing.py` replaces the `origin/main` Resend-based
  `POST /sharing/{share_id}/invite` with this SMTP service. That is its only
  difference from `origin/main`, which still uses `resend` and `RESEND_API_KEY`
  there.
- Production `router.py` differs from `origin/main` only by two lines: the
  `email_router` import and `include_router`.

Live state:

- The `public.email_deliveries` table exists in the production database and has
  zero rows.
- The journal shows only GET probes of `/email/send` on 2026-08-29 (405/404), with
  no successful sends.

`origin/main` separately has a simpler SMTP helper, `email_delivery.py`, which
`teams.py` uses. The two implementations overlap and have not been reconciled.

**Risk:** aligning the checkout to `origin/main` without preserving this work would:

- remove `/email/send`;
- move Space email invites back to Resend, which will likely fail on the
  self-hosted stack if `RESEND_API_KEY` is unset;
- leave `email_deliveries` in the live database with no repository migration. The
  production file name `014_...` also collides with `origin/main`'s
  `014_verified_parts_catalog.sql`.

#### 3. Unclear or needs a decision

- **`backend/.env.example`** (blob `251168493a6cab95ae598e35f30f8a916b2b7f74`).
  Production still has `OPENAI_API_KEY`, `OPENAI_MODEL`, and `OPENAI_VISION_MODEL`,
  which `origin/main` removed. It also documents `BREVO_SMTP_HOST`, `_PORT`,
  `_USERNAME`, `_PASSWORD`, `SMTP_FROM_EMAIL`, and `SMTP_FROM_NAME`, which
  `origin/main`'s template lacks. Secret-bearing fields are empty; only non-secret
  defaults are filled. Keep the SMTP key names when preserving the email work, and
  drop the OpenAI keys.
- **Five macOS AppleDouble files** (`._*`, 163 bytes, header `00 05 16 07`) are
  copy artifacts, not work:
  - `frontend/src/app/home/._page.tsx`
  - `frontend/src/app/inventory/._page.tsx`
  - `frontend/src/components/site/._home-inventory-client.tsx`
  - `frontend/src/components/site/._usage-onboarding-client.tsx`
  - `frontend/src/lib/._api.ts`

  They are safe to discard later, with approval.

#### Production files older than `origin/main`

31 paths changed on `origin/main` since `1d9d5d8` are clean at the old version on
production. Almost all are tests, `integrations/findez-mcp`, and scripts. The only
runtime-adjacent items:

- `spaces_repo.py`: docstring-only change.
- Migration `024_space_delete_cascades_items.sql`: already applied; the live
  `items_space_id_fkey` is `ON DELETE CASCADE`.

Production runtime therefore matches `origin/main` except for the email feature.

#### Outside the Git working tree (preserve; never commit)

- Gitignored environment files hold secrets and must survive any checkout change:
  - `.env`
  - `.env.cloud-rollback`
  - `.env.save`
  - `.env.save.1`
  - `.env.selfhosted`
  - `.env.selfhosted.bak-rotate`
  - `frontend/.env.production`
- Sibling release and backup directories under `/home/ubuntu/findez-*` were not
  inventoried.

## Files changed

- Application files: none
- Production files: none. No writes, restarts, pulls, resets, or cleanups.
- Shared context:
  - `.agents/ACTIVE_WORK.md`
  - `.agents/CURRENT_STATE.md`
  - `.agents/HANDOFFS/INFRA-002.md`

## API or database changes

None. Only read-only `SELECT` queries were run: `to_regclass`, the
`email_deliveries` count, and the `items_space_id_fkey` definition.

## Tests and checks performed

- Production git state via `GIT_OPTIONAL_LOCKS=0`: status, HEAD, stash list, and
  hashes.
- Blob comparison of all 190 dirty paths against `origin/main` and its history.
- Diffs of `router.py` and `sharing.py` against both `origin/main` and `1d9d5d8`.
- Key-only diffs of `.env.example`, with values masked.
- systemd unit inspection, journal grep for email routes, and read-only database
  checks.

## Decisions made

- No preservation commit, VM backup, or cleanup was performed. The task was scoped
  to a read-only inventory.
- The transactional-email feature is the only unique production application work.

## Remaining work

1. Preserve the email feature in Git (see Exact next step).
2. Decide how `email_service.py` and `origin/main`'s `email_delivery.py` should
   converge.
3. Take an off-checkout backup of the dirty tree and the ignored `.env*` files on
   the VM before any alignment. This requires explicit approval.
4. With approval, align the production checkout to `origin/main` plus the preserved
   email branch. Keep `.env*`, remove the `._*` artifacts, verify migrations,
   restart, and smoke-test `/health`, `/health/db`, invites, and the web app.

## Blockers

- The unique email work exists only on the VM's disk and in the live database.
- Aligning the checkout needs owner approval because it changes running production
  code.

## Exact next step

On a new branch from `origin/main` (for example
`infra/preserve-prod-transactional-email`), in an isolated worktree:

1. Copy the six production files byte-for-byte using read-only `ssh findez cat`.
2. Verify each copy with `git hash-object` against the blobs in the table above.
3. Rename the migration to the next free number (`035_transactional_email.sql`). It
   is already idempotent (`if not exists`) and the table exists live.
4. Add the SMTP key names to `backend/.env.example`.
5. Run backend tests and open a PR for review.

Do not modify production during this step. Once that PR merges, production's email
files will match `origin/main` and the checkout can be aligned safely under
Remaining work items 3–4.
