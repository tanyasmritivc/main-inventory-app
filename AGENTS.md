# AGENTS.md

Read `CLAUDE.md` in this same directory first. It is the single source of truth for
this project — architecture, route surface, database state, landmines, and the
history of bugs that cost real debugging time. This file exists only because
OpenCode looks for `AGENTS.md` by name. **Do not duplicate `CLAUDE.md` here.**

## Non-negotiable boundaries

Codex does all repo work across `mobile/`, `backend/`, and `frontend/`. The split by
tool is retired as of 2026-09-19. The discipline it protected is not.

- `mobile/`: Flutter iOS app.
- `backend/`: FastAPI Python.
- `frontend/`: Next.js web.

**One lane per pull request.** Work that spans layers ships as separate pull requests
in dependency order, backend before the frontend that consumes it. A change made in
the wrong place, or bundled with three others, is discovered days later, usually on a
phone, usually at the worst moment.

A prompt scoped to one lane says so on its first line (`BACKEND ONLY.`, `MOBILE ONLY.`,
`FRONTEND ONLY.`) and ends with what must not change. If a request does not name its
lane and the work would cross one, stop and ask rather than spanning it silently.

Mobile is the source of truth for how an item is presented. The web follows mobile,
never the reverse.

## Before you change anything

- Read `CLAUDE.md` and `TESTING.md` for current automated coverage and release
  checks, including real PostgreSQL tests for API key permissions.
- **The repo cannot rebuild its own database.** Eleven tables the code depends on
  have no `CREATE` in `backend/supabase/migrations/`. Do not assume a migration file
  tells you what the live schema is.
- **Read the Landmines section of `CLAUDE.md`.** Each entry is there because it cost
  someone a day. Several look like obvious code smells and are load-bearing.

## Working agreements

- Commit and push after every change.
- Raise `HTTPException` with user-facing messages only; `main.py` scrubs internals.
- Never swallow a write failure. `catch (_) {}` on a Dart write path means a user
  believes an action succeeded when it did not.
- If the API looks wrong from a client's perspective, say so — do not work around it
  in the client.
