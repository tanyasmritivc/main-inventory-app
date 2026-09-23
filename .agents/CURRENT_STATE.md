# Current state

This file contains material current project state only. Active ownership belongs in
`ACTIVE_WORK.md`, continuation details belong in `HANDOFFS/`, and history belongs in
Git. Replace stale facts instead of appending a running diary.

Last reviewed against `main` at `8979f40` on 2026-09-22.

## Working and deployed

- The self-hosted backend, web app, Supabase database, Auth, and Storage are the
  production architecture. `/health` and `/health/db` were last documented healthy.
- The public landing page and authenticated Next.js workspace are in source and
  first-class routes. The old redirect-only web description in `CLAUDE.md` is stale.
- On 2026-09-23, the production landing source matched `origin/main`, `findez-web`
  was active, public HTTPS returned the expected landing markup and metadata, all 17
  referenced static assets returned 200, and `/product` and `/robotics` returned 308
  redirects to `/`. No landing redeploy was required.
- Mobile is a substantial iOS client with inventory, scan, Ask FindEZ, sharing,
  teams, projects, documents, check-outs, notifications, onboarding, and profile.
- OpenAI runtime code has been removed. FIND serves photo analysis and the private
  agent gateway serves language tasks.
- A real production parts-bin smoke test returned 18 mapped FIND items with scan
  evidence. A later client-lifecycle fix is on `main`.
- The scoped integration API, API key management, public API docs, local Claude
  Desktop MCP extension, ChatGPT Actions assets, and OpenCode MCP configuration exist.
- Automated backend, frontend, Flutter, connector, and PostgreSQL RLS checks run in
  CI through the commands documented in `TESTING.md`.

## Active development

- A separate local branch, `mobile/flutter-uiscene-migration`, contains committed
  and uncommitted iOS lifecycle work in the Podfiles, Xcode project, and
  `AppDelegate.swift`. Its owner and release status are not recorded in the repo.
- Durable capture evidence and a review queue are not implemented. The web `/review`
  route states this explicitly.
- Fixed editor ownership rules in older documents are stale. Current work is
  assigned per task and coordinated through `.agents/ACTIVE_WORK.md`.

## Known limitations and risks

- FIND production transport currently uses a public plain-HTTP endpoint behind an
  explicit temporary allow flag because the private route was unreachable.
- FIND jobs are deleted after mapping. Object crops, masks, geometry, unresolved
  objects, and correction signals do not survive as structured records.
- Photo scans can take tens of seconds. The documented production smoke completed,
  but user reports include scans timing out or appearing stuck.
- The production VM checkout is at `1d9d5d8` with extensive modified and untracked
  backend and frontend work, even though the deployed landing files match
  `origin/main`. A blind pull, reset, or full checkout replacement can destroy work.
- Numbered migrations alone do not reconstruct the database. The schema baseline
  and live verification are required.
- Three physical release gates remain documented: Google sign-in, Apple sign-in,
  and APNs delivery on a real iPhone. Password recovery also needs a fresh-link
  device check.
- Offline inventory is not implemented. The mobile cache is memory-only.
- Low-stock thresholds are stored on one device and do not sync.
- Two Stripe route families are mounted. The live webhook source and iOS payment
  strategy must be settled before changing pricing or shipping paid digital access.
- Backups are restore-checked on the same disk. Off-machine backup is not implemented.
- The broader AI grounding path can still rely on bounded previews and remembered
  facts outside the explicit inventory knowledge tool.

## Release status requiring verification

- `mobile/pubspec.yaml` declares `1.0.7+21`. `CLAUDE.md` last confirms TestFlight
  build 19 as valid; source history contains later build work, but current App Store
  Connect availability is not proven by the repository.
- Deployment notes and source agree on self-hosting, but older documents still name
  retired Render, Vercel, or cloud Supabase paths. Check live DNS and service state
  before a release.
