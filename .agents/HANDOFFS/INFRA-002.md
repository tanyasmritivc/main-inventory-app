# INFRA-002 handoff

## Task ID and status

- **Task ID:** INFRA-002
- **Status:** Independently reviewed. Review fixes are committed locally. The branch is
  blocked on one owner decision: whether to keep the `/email/send` `custom` template.
  Nothing is pushed, merged, or deployed.
- **Agent:** Codex (implementation), Claude (independent review, 2026-09-23)
- **Worktree:** `/private/tmp/findez-transactional-email`. Production was accessed
  read-only over `scp` and `ssh findez`.
- **Branch:** `infra/preserve-prod-transactional-email`
- **Commits:** `f48564f` (`Preserve transactional email service`), then
  `eb77ae9` (`Fix transactional email review findings`)
- **Compared against:** `origin/main` at `d2accf3` (2026-09-22)

## Objective

Reconcile the dirty production checkout at `/home/ubuntu/findez` so normal
pull-based deployments can resume, without losing unrelated production work.

## Work completed

### Independent review (Claude, 2026-09-23)

Reviewed `f48564f` against `origin/main` at `d2accf3`, which was still current after
`git fetch`. Production was not accessed.

Verified correct:

- **Preservation.** The six staged originals in `/private/tmp/findez-prod-email-original`
  hash to the recorded production blobs. `router.py` and the migration match
  byte-for-byte. `email.py` and `sharing.py` differ only in formatting.
  `email_service.py` differs by formatting plus the intended transport delegation. No
  behavior was dropped.
- **Transport separation.** `email_service.py` has no SMTP or Resend code and owns
  templates, normalization, the idempotency lock, the audit row, and the hourly limit.
  `email_delivery.py` is the only provider transport. The optional `message_id` is
  backward compatible with `teams.py`. The recovered SMTP code used a 30 s timeout and
  explicit `ehlo`; the shared transport uses 15 s, and `smtplib` performs `ehlo`
  implicitly. That change is acceptable.
- **Router.** The router adds only the import and `include_router(email_router)`. The
  route has an `/email` prefix, so there is no path collision.
- **`.env.example`.** It lists only key names and non-secret defaults. `RESEND_API_KEY`
  is not listed; it is an optional fallback read from the environment.
- **Migration 035.** It is the next free number after 034, and its SQL is identical to
  the recovered production `014_transactional_email.sql`. The table and index names
  are unique. RLS is enabled with no policies, so access is service-role only. It has
  no foreign key to `auth.users`, which matches the recovered SQL; account deletion
  now handles cleanup. The live schema is still unverified (see Blockers).
- **Authorization.** The `team_invitation` template and `/sharing/{id}/invite` both
  require `team_shares.owner_user_id` to equal the caller. Error details are generic.
  Logs record only the recipient domain. `error_code` stores only the exception class
  name. The HTML escapes the share name and body, and CR/LF is removed from SMTP
  subjects.

Issues found and fixed in `eb77ae9`:

1. **Critical: every first send crashed.** The pinned `supabase==2.11.0` uses
   `postgrest` 0.19.3, where `maybe_single().execute()` returns `None` when no row
   matches. A mocked PostgREST 406/PGRST116 response confirmed this empirically.
   `existing.data` therefore raised `AttributeError` for each new idempotency key,
   before any delivery. **This also affects production today:** its dirty
   `sharing.py` routes Space email invites through this code, so they return 500.
   `/email/send` also returned 500 instead of 403 for a share the caller does not own.
   The tests did not catch it because their fake returned an object with `data=None`.
2. **Duplicate sends after an audit failure.** If the `sent` update failed after the
   provider accepted the message, the same `try` block marked the row `failed` and
   returned 503. A retry would then resend. Delivery errors and audit errors are now
   separate. A failed `sent` update is logged and the row stays `pending`, so a retry
   returns a duplicate. A failed `failed` update is also logged instead of replacing
   the 503.
3. **Account deletion left recipient PII.** `delete-user` did not remove
   `email_deliveries`, which stores third-party email addresses. It now removes those
   rows. The Edge Function must be redeployed after the table is verified in the
   target environment, because `deleteRows` fails on a missing table.
4. **Superficial tests.** The tests now use fakes that return `None` for a missing
   row. They cover:
   - first send
   - pending and sent idempotent replay without redelivery
   - retrying a failed delivery with the original Message-ID
   - the 30-per-hour limit
   - transport failure with no leaked details
   - an audit-update failure in each direction
   - the Space invite route's audited path and ownership check

   Against the original `f48564f` code, 6 of these tests fail. Against `eb77ae9`, all
   pass.

Not fixed. These are noted for the owner:

- **Blocker: the `custom` template.** `POST /email/send` with `template: "custom"` lets
  any signed-in account send arbitrary subject and body text from
  `noreply@findez.ai` to any address, up to 30 per hour per account and 10 per minute
  per IP. That is a phishing and spam vector against the sender domain's reputation.
  No web, mobile, or integration code calls `/email/send`, and production has never
  completed a send (bug 1). Removing it or restricting it (for example to the
  caller's own verified address) is a product decision. It was not changed.
- Reusing an idempotency key with a different payload returns the first result. The
  payload is not fingerprinted.
- A process crash between the `pending` insert and delivery leaves that key `pending`
  permanently.
- The hourly count is not atomic across concurrent keys. It can slightly exceed 30.
- The Space invite route uses a random idempotency key per call. A double tap sends
  two emails, as the legacy Resend route did. The route has only the default 60/minute
  IP limit, plus the shared 30/hour audit limit.
- A non-UUID `share_id` causes a PostgREST error, which surfaces as a scrubbed 500
  instead of a 400. The legacy route behaves the same way.
- `teams.py` Team invitations still call the unaudited transport directly. This is
  allowed by the existing decision.

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

Independent review, at `eb77ae9`:

- The recovered originals' `git hash-object` output matches all six recorded
  production blobs. Each was diffed against the committed file.
- An empirical `maybe_single()` check ran against installed `postgrest` 0.19.3 with a
  mocked 406/PGRST116 response. It returned `None`.
- Focused email and invitation tests: 27 passed.
- The same new tests run against the `f48564f` service and route: 6 failed, as
  expected.
- Full backend suite: 197 passed and 6 subtests passed.
- `git diff --check`: clean.

Earlier (Codex):

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

1. Owner decision on the `/email/send` `custom` template: keep, restrict, or remove.
   Apply the chosen change on this branch.
2. Push the branch and open a pull request only with explicit authorization. Merge
   after CI passes.
3. Because of review bug 1, production Space email invites currently fail with 500.
   Deploying the fixed service resolves this. Do not hot-patch the VM without approval.
4. Before deployment, take an approved off-checkout backup of the dirty tree and the
   ignored `.env*` files.
5. Before deployment, compare the live `email_deliveries` columns, constraints, index,
   and RLS state with migration 035 using read-only queries.
6. Align the checkout to `origin/main`. Keep `.env*`, remove the `._*` artifacts,
   restart, and smoke-test `/health`, `/health/db`, one real Space invite (expect a
   `sent` row), the web app, and a disposable account deletion.
7. Redeploy the `delete-user` Edge Function after the table is confirmed.

## Blockers

- The `custom` template decision described above.
- `f48564f` and `eb77ae9` are local only. Pushing and merging need authorization.
- Backing up and aligning the checkout need owner approval.
- The live `email_deliveries` schema has only been verified for existence and row
  count.

## Exact next step

Ask the owner whether `/email/send` should keep the `custom` template. Apply that
decision on `infra/preserve-prod-transactional-email` in
`/private/tmp/findez-transactional-email` and rerun the backend suite. Then push and
open a pull request, but only with explicit authorization.
