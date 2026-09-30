# Current state

Last reviewed on 2026-09-29 through the item-photo and TestFlight build 31 release.

## Working and deployed

- The self-hosted backend, web app, Supabase database, Auth, and Storage are the
  production architecture. `/health` and `/health/db` were verified healthy after
  the item-photo backend deployment on 2026-09-29.
- The public landing page and authenticated Next.js workspace are in source and
  first-class routes. The old redirect-only web description in `CLAUDE.md` is stale.
- Mobile is a substantial iOS client with inventory, scan, Ask FindEZ, sharing,
  teams, projects, documents, check-outs, notifications, onboarding, and profile.
- Item photo galleries are deployed in the backend and included in TestFlight build
  31. FIND captures retain their crop or source photo, and personal, Team Space, and
  legacy Shared Space items can add, view, and delete up to ten photos.
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
- FIND jobs are deleted after mapping. Uploaded source images and available object
  crops survive as item photos, but masks, geometry, unresolved objects, and
  correction signals do not survive as structured records.
- Photo scans can take tens of seconds. The documented production smoke completed,
  but user reports include scans timing out or appearing stuck.
- The production VM checkout is dirty and has been deployed by carefully copying
  reviewed files. A blind pull, reset, or full checkout replacement can destroy work.
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

- The public App Store release is FindEZ AI `1.0.6 (17)`. The recovery branch
  restores the complete `mobile/` tree from its matching release commit,
  `0bb4f01066ca8326e0bc807e8a790bf54bba935f`, with only the version metadata
  advanced to `1.0.7+30`.
- Recovery build 30 passed Flutter analysis and all 19 tests in the recovered
  suite. Its signed release installed and launched on a physical iPhone, where
  the installed app reported `1.0.7 (30)`. The exported IPA contains the
  production Supabase and API configuration and was delivered to App Store
  Connect at 11:23 PM PDT on 2026-09-28. Apple finished processing it and App
  Store Connect lists build 30 in the internal TestFlight groups. An install from
  TestFlight remains to be verified.
- Item-photo build 31 is FindEZ `1.0.7 (31)`. Its signed IPA contains the production
  API configuration, passed Apple server-side validation without errors, uploaded on
  2026-09-29, and finished processing with `VALID` and `APP_STORE_ELIGIBLE` status.
  TestFlight group assignment and a physical install from TestFlight remain to be
  verified; the camera/library add, gallery, and delete flows also need that device
  check against the deployed backend.
- Deployment notes and source agree on self-hosting, but older documents still name
  retired Render, Vercel, or cloud Supabase paths. Check live DNS and service state
  before a release.
