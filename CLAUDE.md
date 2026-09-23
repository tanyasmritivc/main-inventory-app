# Claude Code guide for FindEZ

This file is the concise entry point for Claude Code. It is not a second project
knowledge base. The shared source of truth lives in `.agents/`.

## Start here

Before substantial work, read:

1. `AGENTS.md`
2. `.agents/PROJECT.md`
3. `.agents/ARCHITECTURE.md`
4. `.agents/CURRENT_STATE.md`
5. `.agents/DECISIONS.md`
6. `.agents/ACTIVE_WORK.md`
7. Relevant task files in `.agents/HANDOFFS/`, if any
8. `TESTING.md`

Read only the context needed for the task, then inspect the current source, git
status, recent commits, and affected tests. Repository documentation can lag code.
When code and documentation disagree, verify the implementation and correct the
stale shared context as part of the work.

Do not treat planned work in `.agents/TASKS.md` or a handoff as implemented. Confirm
routes, fields, migrations, services, and deployment state before relying on them.

## Coordination and scope

- Ownership is task-based. Historical fixed assignments to Windsurf, Claude, or VS
  Code no longer control who may edit a directory.
- Check `.agents/ACTIVE_WORK.md` and every worktree before editing. Do not overlap an
  active change in the same area.
- Use an isolated branch or worktree when the current checkout contains unrelated
  changes.
- Keep one implementation lane per pull request. Do not change mobile, backend, or
  frontend merely because another surface exposes a problem.
- Preserve routes, data, and behavior outside the requested scope.
- Mobile remains the source of truth for item field order and presentation. Web
  follows the established mobile semantics.
- Use ASCII punctuation in code, copy, documentation, and commit messages. Do not
  add em dashes or en dashes.

## Current system boundaries

Use `.agents/ARCHITECTURE.md` for the full current architecture. The boundaries most
likely to cause regressions are:

- `mobile/` is the Flutter iOS client.
- `frontend/` is the Next.js public site and authenticated web application.
- `backend/` is the FastAPI application and the only application layer that accesses
  inventory data through Supabase.
- FIND handles inventory photo segmentation, identification, OCR/barcode evidence,
  and measurement.
- The FTCTools agent gateway handles language and structured tool work.
- There is no OpenAI runtime dependency or fallback.
- `integrations/findez-mcp/` is a local stdio connector over the scoped public API.
  A hosted remote MCP service is planned work, not current infrastructure.
- Production is self hosted. Render, Vercel, and cloud Supabase are not production
  write paths.

## Coding guardrails

### All areas

- Inspect existing conventions before introducing files, abstractions, dependencies,
  or patterns.
- Never expose secrets in source, logs, tool output, screenshots, tests, or handoffs.
- Do not hide a failed write or report success before the server confirms it.
- If a client reveals a broken API contract, report and fix the owning layer rather
  than adding a misleading client workaround.
- Keep current implementation and future design clearly labeled.

### Backend and data

- Keep HTTP handlers thin when possible. Put data access in repository or service
  modules and register routers in `backend/app/api/router.py`.
- Raise `HTTPException` with user-facing messages. Central handlers scrub internal
  details, but routes must not deliberately expose them.
- Preserve both Supabase JWT verification paths: asymmetric JWKS tokens and the
  self-hosted HS256 secret path.
- Application service-role access must stay server-side. Public integration requests
  use scoped keys and RLS, not service-role reads.
- The numbered migrations do not fully reconstruct production. Read
  `backend/supabase/schema-baseline-2026-08-10.sql` and verify uncertain live fields
  or policies before changing database-dependent behavior.
- Keep FIND and the language gateway separate. Clients never receive either private
  credential, and inventory images do not go through the text-only tool path.
- Guard model tool calls against empty input and preserve authenticated, user-scoped
  tool execution.

### Mobile and web

- Never swallow a Dart write failure with an empty catch.
- Physical-device behavior cannot be proven by widget tests alone. OAuth, APNs,
  camera and barcode capture, share extensions, deep links, and signing need device
  checks when affected.
- Next.js `NEXT_PUBLIC_*` values are fixed at build time. Environment changes require
  a rebuild.
- Inspect the current theme and shared components before changing presentation. Do
  not revive historical palette or layout guidance from old handoffs.

## Testing

The complete automated entry point is:

```bash
make test BACKEND_PYTHON=backend/venv/bin/python
```

Use the active virtual environment instead when appropriate. Run focused checks
during development, then the relevant full surface checks before finishing. Follow
`TESTING.md` for backend, Jest, Flutter, MCP, PostgreSQL RLS, API documentation, and
release validation. Do not point test fixtures at production services or databases.

Documentation-only changes require at least `git diff --check` and validation of all
paths, commands, and claims they introduce.

## Deployment safety

- There is no automatic production deployment.
- Do not blindly pull, reset, or replace the production VM checkout. It has carried
  unrelated local work.
- Apply and verify required database migrations before restarting dependent code.
- Never print production environment files or secrets.
- Verify `/health` and `/health/db` after backend changes. Integration releases also
  need authenticated or intentionally invalid-key checks, because health alone has
  previously passed against the wrong host.
- A successful build or upload is not a completed native release. Record TestFlight
  or device verification separately.

## Shared context and handoffs

When work materially changes architecture, deployed state, active work, priorities,
or a durable decision, update the relevant `.agents/` file in the same change. Keep
updates concise and remove stale state rather than appending a historical diary.

Create a task-specific file in `.agents/HANDOFFS/` only when another agent must
continue unfinished work. Include:

- objective and exact scope
- branch, worktree, and latest commit
- files changed
- completed and remaining work
- tests and manual checks run
- blockers, deployment state, and rollback information

Commit and push completed work. Report what changed, why, validation performed,
deployment status, and any remaining uncertainty.
