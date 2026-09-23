# FindEZ agent entry point

Use this file as the short entry point for any coding agent working in this
repository. Detailed history and landmines remain in `CLAUDE.md`, and test commands
remain in `TESTING.md`.

## Shared context ownership

The canonical shared context is maintained only from
`~/dev/findez-agent-context` on `docs/agent-context`. Feature worktrees must not
edit `AGENTS.md`, `CLAUDE.md`, or `.agents/` directly. A feature agent may prepare
handoff content, but canonical context updates must be applied through the context
worktree.

Record verified current facts only. Do not add speculative architecture, inferred
deployment state, or unapproved roadmap items.

## Bootstrap before changing code

Read these files in order:

1. `.agents/PROJECT.md`
2. `.agents/ARCHITECTURE.md`
3. `.agents/CURRENT_STATE.md`
4. `.agents/DECISIONS.md`
5. `.agents/ACTIVE_WORK.md`
6. `.agents/TASKS.md`
7. Relevant files in `.agents/HANDOFFS/`
8. `CLAUDE.md`, especially the sections relevant to the requested area and its
   Landmines section
9. `TESTING.md` for applicable checks and release gates

Then run `git worktree list`, inspect the current branch and status, and inspect the
actual source before acting. Shared context is an index, not a substitute for code.
When documentation and code disagree, verify the implementation before proceeding
and correct canonical context through the context worktree.

## Worktree and lane safety

- Check `.agents/ACTIVE_WORK.md` and `git worktree list` before modifying code.
- Do not edit files or areas owned by another active lane unless the owners have
  explicitly coordinated the overlap.
- Record ownership by task ID, agent, worktree or branch, status, dependencies,
  files or area, and handoff path.
- Use an isolated branch or worktree when the current checkout contains unrelated
  changes.
- Keep one implementation lane per pull request.
- Legacy fixed assignments to Windsurf, Claude, or VS Code are historical. Current
  ownership is task-based and recorded in `.agents/ACTIVE_WORK.md`.

## Handoff protocol

Use a stable task ID from `.agents/TASKS.md`. Store a handoff at
`.agents/HANDOFFS/<TASK-ID>.md` when another agent must review, deploy, unblock, or
continue the task. Do not create speculative handoffs.

Every handoff must include:

- task ID and status
- objective
- work completed
- files changed
- API or database changes, including none
- tests and checks performed
- decisions made
- remaining work
- blockers
- exact next step for the next agent
- branch, worktree, and latest commit when available

The receiving agent reads the handoff and inspects the actual code and git state
before continuing. A handoff reports work; it does not prove that code, deployment,
or database state matches the report.

### Lifecycle

1. **Task start:** Add or update the task in `.agents/ACTIVE_WORK.md`.
2. **Work:** Implement only within the registered lane and keep its status current.
3. **Blocked:** Update `.agents/ACTIVE_WORK.md` and write or refresh the handoff.
4. **Complete:** Finalize the handoff when another agent has a next action, then
   update material state and durable decisions in their canonical documents.
5. **Next agent:** Read the handoff, active work, worktree state, and actual code
   before acting.

## Working rules

- Preserve existing routes, data, and behavior unless the task explicitly changes
  them.
- Keep each change scoped to the requested system. Do not change backend behavior
  to solve a frontend-only task, or modify mobile to solve a web-only task.
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
- Commit and push completed changes unless the task gives different instructions.

## Finish the work

- Run relevant checks from `TESTING.md`, including physical-device checks when
  native behavior is affected.
- Update `.agents/CURRENT_STATE.md`, `.agents/ACTIVE_WORK.md`, or `.agents/TASKS.md`
  when material project state changes.
- Record durable architectural or product decisions in `.agents/DECISIONS.md`, not
  only in a handoff.
- Remove or close stale active-work entries when ownership or status changes.
- Report what changed, why, checks run, deployment status, and remaining risk.
