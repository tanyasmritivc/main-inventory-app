# AGENTS.md

Read `CLAUDE.md` in this same directory first. It is the single source of truth for
this project — architecture, route surface, database state, landmines, and the
history of bugs that cost real debugging time. This file exists only because
OpenCode looks for `AGENTS.md` by name. **Do not duplicate `CLAUDE.md` here.**

## Non-negotiable boundaries

This repo is worked on by several different AI editors. Crossing lanes breaks things.

- `mobile/` — Flutter iOS app. **Windsurf's lane.**
- `backend/` — FastAPI Python. **Windsurf's lane.**
- `frontend/` — Next.js web. **VS Code + Claude's lane.**

**Only one tool touches a given directory at a time.** If you are asked to change
something outside the lane you were invited into, stop and say so rather than doing
it. A change made in the wrong lane is discovered days later, usually on a phone,
usually at the worst moment.

Never change backend code in response to a frontend request. Never change mobile
code in response to a web request. Mobile is the source of truth for how an item
is presented — the web follows mobile, never the reverse.

## Before you change anything

- **There is effectively no test coverage.** One default widget test. Regressions
  surface on a physical device, not in CI. Weight risk accordingly and prefer small,
  reversible changes.
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
