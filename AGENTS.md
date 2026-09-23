# FindEZ agent entry point

Use this file as the short entry point for any coding agent working in this
repository. Detailed history and landmines remain in `CLAUDE.md` and test commands
remain in `TESTING.md`.

## Read before changing code

Read these files in order:

1. `.agents/PROJECT.md`
2. `.agents/ARCHITECTURE.md`
3. `.agents/CURRENT_STATE.md`
4. `.agents/DECISIONS.md`
5. `.agents/ACTIVE_WORK.md`
6. Relevant files in `.agents/HANDOFFS/`, if any
7. `CLAUDE.md`, especially the sections relevant to the requested area and its
   Landmines section
8. `TESTING.md` for the checks and release gates that apply

Then inspect the current code and git state. Shared context is an index, not a
substitute for source inspection. When a document and the code disagree, stop,
verify the current behavior, and update the stale document as part of the work.

## Working rules

- Preserve existing routes, data, and behavior unless the task explicitly changes
  them.
- Keep each change scoped to the requested system. Do not change backend behavior
  to solve a frontend-only task, or modify mobile to solve a web-only task.
- Check `.agents/ACTIVE_WORK.md` and `git status` before editing. Only one agent
  should modify a given area at a time. Use a separate branch or worktree when
  another change is active.
- Legacy fixed assignments to Windsurf, Claude, or VS Code are historical. Current
  ownership is task-based and recorded in `.agents/ACTIVE_WORK.md`.
- Mobile is the source of truth for item presentation. Shared web experiences
  should follow established mobile field order and semantics.
- Distinguish current implementation from planned work in code, comments, and
  documentation. Do not present a proposal as a deployed capability.
- The production database is not reconstructed by numbered migrations alone.
  Read the schema baseline and verify the live schema before relying on uncertain
  columns or policies. Apply required migrations before deploying dependent code.
- Keep secrets out of source, logs, command output, screenshots, and handoffs.
- Raise user-facing API errors. Never expose internal exceptions or swallow a
  failed write.
- Do not blindly pull or reset the production VM checkout. It has carried
  unrelated local work. Inspect and preserve it before deployment.
- Commit and push completed changes. Use one implementation lane per pull request.

## Finish the work

- Run the relevant checks from `TESTING.md`, including physical-device checks when
  native behavior is affected.
- Update `.agents/CURRENT_STATE.md`, `.agents/ACTIVE_WORK.md`, or `.agents/TASKS.md`
  when the material project state changes.
- Add a concise entry to `.agents/DECISIONS.md` when an architectural or product
  decision would otherwise be easy to reverse accidentally.
- Create a task-specific file in `.agents/HANDOFFS/` only when another agent must
  continue unfinished work. Include scope, branch or commit, completed work,
  remaining work, validation, and blockers.
- Report what changed, why, checks run, deployment status, and any remaining risk.
