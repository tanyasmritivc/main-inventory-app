# Current state

Last reviewed on 2026-09-30 during the physical-memory TestFlight release.

## Working and deployed

- The self-hosted backend, web app, Supabase database, Auth, and Storage are the
  production architecture. `/health` and `/health/db` were verified healthy after
  the physical-memory backend and web deployment on 2026-09-30. Migration `036`
  is applied in production with RLS enabled; direct authenticated mutations and
  authenticated resolver execution are denied.
- The public landing page and authenticated Next.js workspace are in source and
  first-class routes. The old redirect-only web description in `CLAUDE.md` is stale.
- Mobile is a substantial iOS client with inventory, scan, Ask FindEZ, sharing,
  teams, projects, documents, check-outs, notifications, onboarding, and profile.
- Item photo galleries are deployed in the backend and included in TestFlight build
  31. FIND captures retain their crop or source photo, and personal, Team Space, and
  legacy Shared Space items can add, view, and delete up to ten photos.
- The live backend and web now persist uncertain FIND captures for Review and show
  structured, model-neutral scan evidence. The authenticated web workspace and
  public integration bundle were deployed and checked against the public host.
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
- Branch `feat/physical-memory-home-review` implements a Home/Capture/Ask/Find
  shell, model-neutral structured scan evidence, a durable Review queue, and
  conditional item thumbnails. Its backend, migration, and web are deployed.
  Builds 32 and 33 were rejected visually. The current Home matches the user's
  supplied reference with actual Spaces, four decision cards, and retained-photo
  captures. The user subsequently requested restoring the previous four-tab icon
  rounded pill; build 35 has uploaded, with analysis and all 34 Flutter tests
  passing, including embedded Ask composer spacing. All five CI test jobs passed
  on implementation commit `c4c95fa`. Apple processing completed with `VALID` and
  `APP_STORE_ELIGIBLE` status, and build 35 is available in both internal
  TestFlight groups.
- Fixed editor ownership rules in older documents are stale. Current work is
  assigned per task and coordinated through `.agents/ACTIVE_WORK.md`.

## Known limitations and risks

- FIND production transport currently uses a public plain-HTTP endpoint behind an
  explicit temporary allow flag because the private route was unreachable.
- FIND jobs are deleted after mapping. Uploaded source images and available object
  crops survive as item photos. Unresolved objects, public evidence, and review
  status persist. Masks, geometry, and training-quality
  correction events remain outside the durable data contract.
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
- Physical-memory build 32 passed Apple validation, uploaded and processed as
  `VALID` and `APP_STORE_ELIGIBLE`, and is linked to the two internal TestFlight
  groups. It installed and launched on the paired iPhone as `1.0.7 (32)`. The user
  rejected its crowded Home layout; later build 33 was also rejected visually.
- Build 33 (`1.0.7`) passed Flutter analysis, all 27 Flutter tests, signed archive,
  and Apple server-side validation. It uploaded on 2026-09-30, processed as
  `VALID` and `APP_STORE_ELIGIBLE`, and is linked to both internal TestFlight
  groups. Its signed release installed and launched on the paired iPhone, which
  reports `1.0.7 (33)`. Installation through the TestFlight app and hands-on
  capture, review, photo editing, and multi-account checks remain unverified.
  The public App Store release remains `1.0.6 (17)`.
- Build 34 (`1.0.7`) recreated the supplied Home and initially used the reference's
  text-only five-tab bar. Analysis, all 33 Flutter tests, signed archive, Apple
  validation, upload, and native physical-device install/launch passed. The user
  requested the previous four-tab icon navigation while upload was underway;
  build 34 is superseded by build 35.
- Build 35 (`1.0.7`) restores the user's exact floating rounded four-tab pill,
  keeps the reference-matching Home, and removes duplicate overlay-clearance
  padding from embedded Ask/Capture/Find. The scan evidence panel has its own
  Material ink surface for compatibility with the newer Flutter CI runner.
  Analysis, all 34 Flutter tests with coverage, all five CI jobs, signed archive,
  Apple server-side validation, upload, and native physical install/launch passed.
  Upload delivery ID: `58ec17b7-1985-4cce-a101-c487ac1d1c08` at 9:43 PM PDT on
  2026-09-30. Apple processing completed with `VALID` and `APP_STORE_ELIGIBLE`
  status; App Store Connect confirms assignment to `Testers` and
  `Internal Pilot Findez AI`, both internal TestFlight groups.
  Installation through the TestFlight app and the hands-on release checklist
  remain unverified. Existing default-launch-image archive warning is unchanged.
- Deployment notes and source agree on self-hosting, but older documents still name
  retired Render, Vercel, or cloud Supabase paths. Check live DNS and service state
  before a release.
