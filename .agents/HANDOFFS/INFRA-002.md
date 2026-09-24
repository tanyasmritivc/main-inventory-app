# INFRA-002 handoff

## Task ID and status

- **Task ID:** INFRA-002
- **Status:** Ready for review. The production-only email work is recovered,
  reconciled, tested, and committed locally. It is not pushed, merged, or deployed.
- **Agent:** Codex
- **Worktree:** `/private/tmp/findez-transactional-email`. Production was accessed
  read-only over `scp` and `ssh findez`.
- **Branch:** `infra/preserve-prod-transactional-email`
- **Commit:** `f48564f` (`Preserve transactional email service`)
- **Compared against:** `origin/main` at `d2accf3` (2026-09-22)

## Objective

Reconcile the dirty production checkout at `/home/ubuntu/findez` so normal
pull-based deployments can resume, without losing unrelated production work.

## Work completed

### Latest continuation (Codex, preservation branch)

- Created an isolated worktree from `origin/main` at `d2accf3`.
- Recovered all six production files byte-for-byte into local staging using
  read-only `scp` access. All recorded Git blob fingerprints matched exactly.
- Renamed the conflicting production migration from
  `014_transactional_email.sql` to `035_transactional_email.sql`.
- Reviewed migration 035 against migrations 001 through 034. Its table and index
  names are unique, its UUID and RLS patterns match the repository, and its
  recovered SQL does not conflict with the repository migration history. Because
  `create table if not exists` cannot repair schema drift, the live columns,
  constraints, index, and RLS state still require read-only comparison before any
  production migration or checkout alignment. No migration was applied.
- Reconciled the recovered audited service with `email_delivery.py`. The recovered
  service retains normalization, templates, rate limiting, idempotency, audit rows,
  and status transitions, but delegates provider delivery to the existing shared
  Brevo SMTP and Resend fallback transport.
- Preserved optional Message-ID delivery through the shared transport and added the
  Brevo and SMTP environment names to `backend/.env.example` without restoring
  retired OpenAI settings.
- Removed the now-unused direct Resend code in the Space invitation route and kept
  its recovered audited invitation behavior.

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

Before the preservation branch, `origin/main` separately had a simpler SMTP helper,
`email_delivery.py`, which `teams.py` uses. The two implementations overlapped and
had not been reconciled.

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

- Feature commit `f48564f`:
  - `backend/.env.example`
  - `backend/app/api/router.py`
  - `backend/app/api/routes/email.py`
  - `backend/app/api/routes/sharing.py`
  - `backend/app/services/email_delivery.py`
  - `backend/app/services/email_service.py`
  - `backend/supabase/migrations/035_transactional_email.sql`
  - `backend/tests/test_email_service.py`
  - `backend/tests/test_team_invitation_notifications.py`
- Production files: none. No writes, restarts, pulls, resets, checkouts, or cleanups.
- Shared context:
  - `.agents/ACTIVE_WORK.md`
  - `.agents/CURRENT_STATE.md`
  - `.agents/DECISIONS.md`
  - `.agents/HANDOFFS/INFRA-002.md`
  - `.agents/TASKS.md`

## API or database changes

- The local branch preserves authenticated `POST /email/send` and the audited Space
  invitation path.
- Local migration 035 records pending, sent, and failed deliveries by user and
  idempotency key. It was not applied to any database.
- Production received no API, database, configuration, or process changes.

## Tests and checks performed

- Recovered source fingerprints matched the six recorded production blobs.
- Focused email tests: 18 passed, with one dependency deprecation warning.
- Full backend suite: 188 passed and 6 subtests passed, with two dependency
  deprecation warnings.
- `git diff --check`: clean.

- Production git state via `GIT_OPTIONAL_LOCKS=0`: status, HEAD, stash list, and
  hashes.
- Blob comparison of all 190 dirty paths against `origin/main` and its history.
- Diffs of `router.py` and `sharing.py` against both `origin/main` and `1d9d5d8`.
- Key-only diffs of `.env.example`, with values masked.
- systemd unit inspection, journal grep for email routes, and read-only database
  checks.

## Decisions made

- `email_delivery.py` is the single provider transport. `email_service.py` owns
  audited orchestration and delegates delivery to it.
- Migration 035 preserves the exact recovered SQL under the next free migration
  number. The live table is empty, but its full schema must be compared before the
  migration is treated as applied in production.
- No VM backup, checkout alignment, deployment, or production cleanup was performed.

## Remaining work

1. Review local commit `f48564f`, then push and merge it only with explicit
   authorization.
2. Take an off-checkout backup of the dirty tree and the ignored `.env*` files on
   the VM before any alignment. This requires explicit approval.
3. With approval, align the production checkout to `origin/main` after the preserved
   email branch. First compare the live `email_deliveries` columns, constraints,
   index, and RLS state with migration 035. Keep `.env*`, remove the `._*`
   artifacts, verify migrations, restart, and smoke-test `/health`, `/health/db`,
   invites, and the web app.

## Blockers

- Commit `f48564f` is local only. It must be reviewed and merged before production
  can safely align with the repository.
- Backing up and aligning the checkout need owner approval because both affect the
  running production host.
- The live `email_deliveries` schema has only been verified for table existence and
  row count. Full read-only schema comparison remains required before deployment.

## Exact next step

Review commit `f48564f` in `/private/tmp/findez-transactional-email`. If accepted,
push the feature branch and open a pull request only after explicit authorization.
After it merges, obtain approval for an off-checkout production backup before any
checkout alignment, migration, restart, or smoke test.
