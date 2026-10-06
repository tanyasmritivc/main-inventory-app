# Current state

Last reviewed on 2026-10-05 during scoped launch-blocker fixes.

## Restock planner replacement (October 5)

- The user reported that Shopping List checked items still appeared as needing
  restocking in Find. Checkmarks only persisted an ordered selection; the old
  banner independently counted quantity against thresholds. Replace that mobile
  destination with a Restock planner on `feat/mobile-restock-planner` in
  `/private/tmp/findez-restock-planner`, based on build-53 record `3a08fd1`.
  The new candidate is `1.0.7 (54)`; beta upload remains pending validation.
- To buy and On order are separate, persisted states. Find/Space summaries,
  Home's To buy action, Ask's summary and the shared Space Restock tab use the
  same purchase rules. Mark ordered immediately stops requesting that purchase;
  it does not change physical stock. Editable quantities, Back to to-buy,
  per-item removal, an inventory chooser and copying only the to-buy list are
  available. New post-capture planning chooses specific items rather than
  applying threshold 1 to every item in the category.
- Record arrival asks for the actual total on hand and saves only quantity
  through the existing authenticated personal/Team or membership-authorized
  shared-item route. Persist the absolute count before submitting, retain it
  after a failed/lost response, and finish the purchase only after confirming
  item ID and quantity. Explicit retry saves the same count without double
  addition. Shared viewers cannot save stock. A later drop below an explicit
  threshold reopens To buy; untracked single belongings are not automatically
  treated as low stock.
- Purchase planning and thresholds remain personal, account/device-local, with
  that scope disclosed in the planner. Inventory quantities sync through the
  existing API. Legacy thresholds and checked selections migrate without
  inventing historical order quantities; old account-scoped preferences remain
  as rollback copies. Failed preference writes restore the prior cache and
  surface a retry, malformed saved plans fail visibly, and stale account writes
  are rejected. Local restock notifications follow To buy and cancel evaluated
  ordered/removed items; native permission/delivery acceptance is unverified.
- All 292 mobile tests with coverage and clean analysis pass, including 18
  restock regressions. Phone-sized sample renders and Light/Dark 320pt/2.6x
  action/dialog checks pass. Signed build, exact-source CI and Apple
  validation/upload/availability remain pending. The user's earlier choice to check through
  TestFlight applies; no physical stock write or full device acceptance is
  claimed. Logo, shared typography, existing inventory data, billing, backend,
  web, database schema, FIND and native lifecycle are unchanged. Public App
  Store review/publication remains held.

## App-wide typography consistency (October 5)

- The user approved build 52 Home on the physical iPhone with Bold Text enabled,
  then requested consistent typography throughout the app. The same
  `fix/mobile-home-bold-text` lane in `/private/tmp/findez-home-bold-text`, based
  on release record `e123c22`, now implements the complete app-wide change for
  `1.0.7 (53)`; Draft PR #44 describes the final app-wide scope.
- Shared `AppTypography` and `AppText` retain San Francisco and existing font
  sizes, colors, layouts and semantics. With Bold Text enabled, supporting text
  and editable fields use Medium (500); headings, counts and emphasis use
  Semibold (600). Normal styling remains when off, with old 700-900 emphasis
  capped at 600. Intentional monospace code/status text remains monospace.
- The actual OS preference is retained in the inherited typography scope while
  Flutter's blanket 700 override is suppressed below it. All app-owned text,
  input decorations, selectable answers, Markdown and the nested date-picker
  theme use the shared policy. OS-composed text scaling and other accessibility
  preferences remain intact; live preference changes retain routes and drafts.
- All 274 mobile tests with coverage and clean analysis pass, including rendered
  weights for app/framework text and editable fields, real-root preference
  changes, retained drafts and Light/Dark Home at 320pt through 3.4x scaling.
  Build 53 signed archive/export, strict signature, production-config and supplied-logo checks pass. All five CI jobs pass on runtime `afc39ac` (`37398740825`), and Apple validation reports no errors. The exact signed app installed before the user elected to check it through TestFlight; native process launch and app-wide visual acceptance are unverified. Apple accepted the upload with no errors at 19:00:26 PDT on October 5;
  delivery `67e8af04-e91a-4157-aa8d-e758c3222d3b`. Apple processing is `COMPLETE`/`VALID` with no errors/warnings;
  `APP_STORE_ELIGIBLE` and assignment to Testers and Internal Pilot Findez AI
  are verified. The final signed archive/IPA and verification manifest are
  preserved under `/private/tmp/findez-build53-native` and
  `/private/tmp/findez-build53-verification.json`.
  Final IPA SHA-256: `69cf90f89bd2748016fdae6b406d84548f27e7ddac280d775e8a0f913961d6b8`.
- Historical Home-only build 52 (`d37eb49`) passed 270 mobile tests, analysis,
  all five CI jobs (`37393604316`), signed archive/export, production-config and
  supplied-logo checks, Apple validation, and native install/process launch.
  The user confirmed its Home appearance. It was not uploaded after the scope
  expanded; build 53 replaces that local candidate.
- Branding and all routes/data/actions are retained. No backend/web/schema/FIND,
  Stripe/billing or native lifecycle implementation changed. Public App Store
  review/publication remains held; the existing TestFlight request authorizes
  the updated beta and existing internal-group availability.

## Current TestFlight beta (October 5)

- The user explicitly requested the current mobile build on TestFlight and
  reaffirmed using the previously supplied logo. That instruction authorizes
  this beta upload; the public App Store review/submission hold remains.
- `release/testflight-current` in `/private/tmp/findez-testflight-current` is
  based on latest mobile head `671e304`, not the older build-29 Interior v2
  checkout. Runtime source is unchanged; release commit `15b6374` advances the
  version to `1.0.7 (51)`. It includes appearance/branding, Space icons,
  physical-memory onboarding, November pilot copy, and the cold Home-to-Space fix.
- Clean Flutter analysis and all 265 mobile tests pass locally. The underlying
  runtime `ab506f2` has all five CI jobs passing in `37385102041`. The signed
  archive/export passes, the final IPA contains the production compile-time
  configuration, and the Supabase credential is public anon rather than service
  role. Signature verification and Apple server-side validation pass.
- The exported package's brand assets match the committed originals. Its three
  SVGs match the supplied Downloads files except newline formatting, and the
  native icon uses the supplied orange/white mark flattened onto opaque Ink as
  already authorized by the branding lane. No logo was redrawn or generated.
- Apple accepted the upload at 17:01:18 PDT on 2026-10-05. Delivery ID:
  `c005740a-d226-4fcf-a9f6-149c3968939e`. Apple reports `COMPLETE`/`VALID`, `APP_STORE_ELIGIBLE`, and both existing
  internal groups (Testers and Internal Pilot Findez AI) are verified. Final IPA SHA-256:
  `cacb003d9c3f84e733c8a0137b1be499cfa7a8b1ce418af59308a9b30ad601c9`.
- The paired iPhone reports installed `1.0.7 (51)`, and native process launch
  passed after it was unlocked. This is not a TestFlight-app download, visual
  first-frame confirmation, fresh-install/auth check, or full physical acceptance.
  The existing default-launch-image warning and broader release gates remain.
- No backend/schema/FIND, Stripe/billing, public website, Apple screenshots,
  App Store draft selection, review submission, or public release was changed.

## Cold Home-to-Space correction (October 5)

- `fix/mobile-home-space-cold-load` in `/private/tmp/findez-home-space-fix`,
  based on `2758498`, reproduces the observed failure in the actual shell:
  Home is populated, Find registers its destination before its first inventory
  request finishes, and the Space route captures the still-empty list.
- Space navigation now waits for the confirmed inventory read (including an
  active refresh), deduplicates reads and route taps, and refuses a false empty
  destination after a failed read. Retry and genuinely empty Spaces remain valid.
  Exact Space IDs and complete Home inventories are preserved independently of
  Find filters. Late disposed/account-changed reads cannot open a destination.
- All 265 mobile tests with coverage and clean Flutter analysis pass. Five new
  regressions cover actual cold-shell navigation in Light/Dark, failure/retry,
  confirmed empty data, duplicate taps and disposed late reads. The cold-shell
  assertion failed against the original source before the fix.
- Runtime `ab506f2`, PR #42, passes all five CI jobs in `37385102041`.
- Separate backend PR #43 runtime `4ac3c56` deployed private document storage
  after all five CI jobs passed (`37385848403`). Disposable personal/Team
  upload/open/denied foreign access and membership revocation checks pass; all QA
  data removed. Item photos remain public, and processor retention unconfirmed.
- This is source-only, not a newly installed native binary or physical acceptance
  pass. Apple upload/submission remains held, FIND unchanged. The unrelated
  public item-image storage, legal publication and physical release gates remain.

## November pilot date and current launch verdict

- User requested free pilot through **November 1, 2026**, inclusive. The API
  notice, dormant web pricing copy and mobile fallback now use that date, with
  November 2 as the following-day plan copy. Lane: `fix/free-pilot-november1`
  in `/private/tmp/findez-pilot-november`, based on `19da889` / onboarding PR #39.
  `PILOT_MODE=true`, optional `PILOT_ENDS_AT` (still unset in production), public
  visibility flags, Stripe guards, limits and manual activation are unchanged.
  This does not schedule a cutoff, enable payments or charge users automatically.
  Mobile fallback and narrow-card wrapping are source-only for the next approved
  binary; no native build, phone install or Apple upload/submission was performed.
  Active clients receive the API notice on successful Profile refresh; offline
  clients intentionally retain cached values rather than changing their plan.
- All 350 backend/API-doc, 134 web and 260 mobile tests pass, with clean Flutter
  analysis, TypeScript and local web production build. Pilot card regressions
  cover API/fallback copy in Light/Dark at 320pt and 1x/2.6x/3.4x text, preserving
  the existing free tier and failed-read cache behavior. Connector tests, exact
  Desktop bundle check and standalone bundle smoke test pass with lockfile-local
  dependencies (the initial symlinked dependency check had nonhermetic notices).
- Only `backend/app/services/limits.py` and the unused
  `frontend/src/lib/pilot.ts` were selectively copied to production after exact
  pre-change hashes matched. Rollback copies and the isolated web build are in
  `/home/ubuntu/findez-pilot-november.1t5vaz` (private directory). Backend restarted;
  both services are active. The current dirty deployed frontend built successfully
  in isolation, but `/pricing` redirects to `/` and does not render this copy;
  preserve that redirect and existing live web artifact rather than adding a
  pricing screen. Environment-file hashes are unchanged, including FIND and
  billing configuration. A read-only nil-user deployed-service probe confirms
  the exact new notice and unlimited maxima; it creates no account/data. Public
  API and database health from the Mac return healthy. The server's requests to
  its own public API timed out; local service checks and independent public
  checks pass. Public `/pricing` still returns its existing 307 redirect.
- **Not yet ready for broad public launch or Apple submission.** Automated CI
  and simulator passes do not close the physical release checklist. Latest
  mobile feature source is local build-50-era work, while the last verified
  unsubmitted App Store draft selects build 46. The exact final release binary,
  accurate final screenshots and physical fresh-auth/photo/profile/Documents,
  offline draft protection, second-account revoke and real invitation acceptance
  remain outstanding. The cold Home -> Space issue now has a separately tested
  source correction above; final-binary/device acceptance remains outstanding.
- The original storage audit found both documents and item images public. The
  separate October 5 PR #43 deployment above made documents private; item images
  remain public and profile photos private. Public item-photo URLs remain a
  privacy/access concern after revocation. Legal PR #40 is still draft/unpublished
  and needs
  provider/deletion verification and final publication/mobile alignment. The
  user's no-current-customer-training clarification is not proof of all provider
  practices. The existing unencrypted server-to-FIND hop is also a retained,
  documented risk; the user explicitly withdrew changing it. Apple holds remain.

## App Store submission preflight

- The physical-memory introduction is implemented as local `1.0.7 (50)` on
  `feat/mobile-physical-memory-onboarding`, stacked on icon-picker PR #38
  (`bea71f5`) in `/private/tmp/findez-appearance`. Four branded screens teach
  physical memory, Capture/Review, Ask/Find and personal/shared Spaces using
  interactive, code-native sample graphics. Samples are explicitly local and
  do not create a Space, save inventory, request permissions or call APIs.
  Fresh signed-out launch shows onboarding before Auth; Complete/Skip saves
  only the confirmed completion flag. Returning sessions, completed installs,
  queued Space/Team invitations and replay/legacy signup state are preserved.
  Navigation/fade/sample transitions respect Reduce Motion and pages scroll
  independently above the pinned action at large text sizes.
  PR #39, runtime `f6782d3`, passes all 246 mobile tests with coverage, clean
  Flutter analysis and all five CI gates (runtime run `37265597966`, repeated
  on documentation head `ff15a5d` in run `37265970841`). Local targeted
  regressions pass; the final local full-suite compiler rerun stalled on the
  disk-constrained Mac and was stopped after CI passed. A prior local 245-test
  full suite passed before the final compact-answer layout adjustment.
  Native iOS simulator build 50
  passes and the final app is installed/launched locally. Simulator verifies
  sample object/capture/location/question/sharing changes, Dark and Light/Larger
  styling, retained sample location, visible normal-size Ask answer and replay
  returning to Profile. CUA mouse drags did not confirm native vertical scrolling;
  automated scroll/layout tests pass through 3.4x at 320pt. Physical touch,
  VoiceOver, fresh-install/auth and reduced-motion checks remain deferred.
  A follow-up native signed-out cold-launch check reset only the existing
  simulator's completion flag while it was stopped, without erasing app data.
  Build 50 showed the welcome introduction before Auth; all four sample steps
  worked, final Continue opened Auth, and a force-quit/relaunch stayed on Auth.
  Completion was restored to its original confirmed `true` through the UI.
  This is a reset-flag simulator check, not an App Store download or physical
  fresh-install/auth pass. Dark/Default preferences are retained; the simulator
  is now left on sign-in, with no credentials entered during this follow-up.
  No inventory/membership/document data, auth credentials,
  backend/web/schema/FIND, native lifecycle, App Store draft or Apple release
  was changed. Submission remains held; the separate cold Home-to-Space issue
  and broader release gates still apply.

- Optional personal Space icons are implemented as local `1.0.7 (49)` on
  `feat/mobile-space-icon-picker`, stacked on brand PR #37 (`1d49e27`). Tap the
  leading icon in personal/owned, joined/shared or Team Space lists to open a
  searchable 24-icon picker, with Automatic reset and explicit Save/Cancel.
  Choices are saved per account and stable Space/share ID on this device only;
  they survive rename/restart and do not change shared data or permissions.
  Confirmed-write, safe read/write failures, duplicate saves, stale account
  reads/writes, draft retention and disposal are guarded. The themed picker has
  one native handle, named selected semantics, 44pt icon targets and adaptive
  large-text columns. All 226 mobile tests with coverage, clean analysis and
  native simulator build pass. Simulator confirms search, Cancel/no save,
  immediate saved card icon, restart persistence and Dark/Light with Larger text.
  Inventory, memberships and documents are untouched. There is no backend/web/
  schema/FIND or native lifecycle change, phone install or Apple upload/submission.
  Physical accessibility/touch acceptance remains deferred; existing broader
  release gates and the cold Home-to-Space issue remain separate.

- The user authorized the supplied FindEZ brand on mobile and identified two
  duplicated grabbers in Edit item. Local `1.0.7 (48)` on
  `feat/mobile-brand-theme`, stacked on appearance PR #36 (`def3d3c`), uses the
  original outlined SVG wordmark and new native icon, exact light-brand tokens
  and readable dark counterparts. Retired decorative blue/purple gradients are
  removed; orange is reserved for the mark and promoted primary actions, with
  separate warning/success/danger roles. The PNG's transparent outer corners
  are flattened onto Ink for native icon generation; the original SVGs remain
  unchanged. Existing five-icon/56pt navigation, routes, preferences and writes
  are preserved. The system sheet grabber is now opt-in so the custom editor
  draws one handle; simple photo/Space pickers retain their single native handle.
  Protected item-info dismissal code is unchanged.
  All 203 mobile tests with coverage, clean analysis and the native iOS
  simulator build pass. Simulator verifies the single editor handle in both
  modes, larger text, live System mode, restart persistence, readable Space
  counts, all five tabs and Documents/item-info presentation. Physical
  camera/QR/accessibility/swipe checks remain deferred by the user's explicit
  simulator-only choice. Build 48 has not been installed on a phone or uploaded
  to Apple; the submission hold and live build/draft remain unchanged.
  A separate release check remains: after a cold launch, a Home Space shortcut
  displayed an empty item list although Home showed five items; opening that
  same Space through Find displayed all five. That routing code was not changed
  in this presentation lane. Investigate before a release, not by changing
  backend/schema/FIND as part of this task.

- The user explicitly renewed the Apple submission hold while requesting mobile
  Light/Dark/System appearance and text-size settings. Work is isolated on
  `feat/mobile-appearance-accessibility` in `/private/tmp/findez-appearance`,
  based on `df7e1d1`. Local `1.0.7 (47)` adds persisted device-local
  Light/Dark/System and Small/Default/Large/Larger text choices under
  Profile → Settings → Appearance. Default remains Dark with OS text scaling;
  other sizes compose with OS accessibility scaling, and OS bold text is honored.
  Legacy fixed-color presentation now adapts across mobile screens without
  recoloring photos, identity colors, camera imagery or printed QR output.
  Light foreground/semantic contrast and status-bar styling have regressions.
  Large-text fixes cover item-info fields, populated Space cards/restock notices,
  Capture controls and scrollable forms. Routes, drafts, five-icon/56pt nav and
  protected swipe dismissal remain intact. All 190 mobile tests with coverage,
  clean Flutter analysis and the local iOS simulator build pass. Simulator
  checks are complete; this is not a phone/TestFlight/App Store release.
  The user explicitly chose simulator checks for now, so physical appearance,
  camera/photo/QR and accessibility acceptance remain deferred. FIND, real
  inventory, native lifecycle and the App Store draft are unchanged.
  Item-info presentation/navigation was checked in the simulator; CUA mouse
  drag attempts did not dismiss it, so native swipe is not marked passed.
  The existing protected-swipe widget regressions still pass in both themes.
  The user chose raw app screenshots; the image-edit
  trial was rejected and no generated artwork was uploaded.

- User requested submission and authorized isolated QA accounts and a dedicated
  Apple review account. App Store `1.0.7` now selects build `46`, remains
  `PREPARE_FOR_SUBMISSION` with manual release, and has not been submitted.
  The public `1.0.6 (17)`, pricing, real memberships and Team-only AASA are
  unchanged. The next-release privacy URL is saved as
  `https://www.findez.ai/privacy`.
- The user subsequently asked to wait for their assets. Original
  `findez-wordmark.svg`, `findez-icon.svg`, `findez-mark.svg` and
  `findez-icon-1024.png` have now been supplied in their Downloads directory.
  All three SVGs are readable path-based assets; the wordmark uses outlines,
  not a font dependency. The PNG is 1024x1024 RGBA with alpha. No assets were
  modified or installed during the earlier build-46 preflight; mobile now uses
  local build-48 brand assets as recorded above. Six supplied `findez-appstore-1.png`
  through `findez-appstore-6.png` have now arrived in Downloads. All are
  1320x2868 PNGs without alpha, accepted iPhone screenshot dimensions. They are
  not uploaded: depicted phone UI differs from build 46's icons-only navigation
  and Profile destination, and image 5 includes a drawer-location diagram and
  `Mark as taken` action absent from the current mobile source. Apple guidelines
  2.3/2.3.3 require metadata to reflect the shipping app. Request corrected
  current-app captures or permission to revise the artwork; do not silently
  expand into a redesign or publish these as accurate build-46 screenshots.
  Existing release checks remain recorded separately; no submission occurred.
- The previous saved review login failed. Three new task-only accounts were
  created with confirmed emails; password sign-in passed for each. Dedicated
  review credentials were saved to Apple and re-read successfully, without
  logging secrets. Its inventory contains five sample items across Hardware,
  Tools and Electronics, plus an empty sample Space. This admin-created setup
  does not prove public signup/email-confirmation acceptance.
- Live API-only checks passed for recipient access to the five sample items,
  denial before joining, unrelated-account denial, view-only write denial,
  individual-member removal, share revocation, and revoked-code rejoin denial.
  No real account inventory or memberships were changed. These results do not
  satisfy the physical multi-account/invitation acceptance gates by themselves.
- The build-46 simulator app built, installed and signed in to the review
  account. All six Ask-to-Find cycles retained the two Spaces and their counts.
  The rename check failed: changing `Test Workshop` to `Main Workshop` showed
  `0 items` on the Space card, while all five entries remained accessible by
  Space ID inside it. An isolated live API reproduction at
  `2026-10-04T22:10:26Z` confirmed canonical Space count 5 and no old Space, but
  all five `/search_items` results still had the old location (zero new-location
  results). Production `spaces_repo.py` and `items_repo.py` match the inspected
  source byte-for-byte. The root cause was missing invalidation of the 60-second
  per-user inventory cache. The user then approved the scoped correction.
- `fix/release-cache-find-transport`, based on `2376d0f`, now invalidates only
  the affected owner's inventory after Space rename and cascade deletion,
  including failure paths without swallowing errors. Six hermetic regressions
  and all 349 backend/API-documentation tests pass. Only `spaces_repo.py` was
  selectively deployed after matching its original hash, preserving unrelated VM
  work and a mode-600 backup in
  `/home/ubuntu/findez-space-cache-backup-es4heqOb`. Backend and database health
  pass. The live QA rename at `2026-10-04T22:27:04Z` retained all five items,
  returned five new locations and zero old locations immediately, with no old
  Space. A subsequent build-46 simulator UI rename also immediately displayed
  `Sample Workshop / 5 items` and retained the empty Space. All-category behavior
  is covered automatically; broader physical/filtered acceptance remains open.
  The existing two database writes are not transactional; this fix invalidates
  stale snapshots and propagates failures, rather than claiming atomic rollback.
  Runtime `6027a87` is pushed in PR #35 against the release-record branch; all five
  CI gates pass (run `37240403382`). Live API-only access/revocation checks were
  repeated after deployment and again passed, including unrelated-user and
  read-only-write denial, member removal, revoked reads and revoked-code reuse.
- Updated screenshots are not uploaded; supplied new iPhone artwork needs
  current-app UI correction as noted above, and existing iPhone/iPad screenshots still
  show old navigation/Ask. Camera, profile/Documents, offline writes and real
  invitation acceptance remain unverified. iPhone Mirroring repeatedly reports
  the phone in use despite the user's lock confirmation. No real-account sign-out
  was performed in this preflight.
- Exact signed IPA hash remains
  `0c0bf3a0db16dc2603acf7576eae9ddb8713423b6d8bc5678624517209b65a0e`;
  all five CI jobs remain green on runtime `78404fa` (run `37033574121`).
  Regenerable Xcode compiler/intermediate caches were removed with approval to
  make the simulator build; source, signed archive/IPA and verified backups were
  preserved. The embedded ShareExtension still declares build 17 (Apple already
  marks main build 46 valid/eligible); native handoff remains unverified.
  Production FIND plain-HTTP transport remains a separate security limitation.
  No TLS correction was deployed: verified-certificate probes of
  `https://pipeline.findez.ai/health` fail with a TLS internal-error alert from
  both the Mac and the backend VM, including a TLS-1.2 probe. Current production
  settings still select HTTP with the explicit insecure allowance. Caddy runs on
  a separate operator-managed machine, not the accessible FindEZ VM. The user
  subsequently explicitly withdrew the transport change and instructed keeping
  the existing working connection unchanged. Preserve the FIND URL, HTTP
  allowance, key and proxy settings; do not continue this transport change
  without new authorization. No certificate bypass, credentials or images were
  sent in these probes, and photo extraction was not disabled. The unencrypted
  server-to-FIND hop remains a documented risk, not a completed security fix.
  Transport migration is no longer part of this release's requested work;
  the outstanding release checks and screenshots still remain.

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

- `fix/icon-only-mobile-nav`, based on released build 42, hides visible labels
  in the existing five-icon navigation pill (PR #33). Icons, touch targets,
  accessible names, profile avatar, routes and tutorial targets are preserved.
  Branding and screen content are unchanged; backend/web/native lifecycle files
  are not modified. Build-43 source `4adaea9` passes all 117 mobile tests with
  coverage, clean analysis and all five CI gates (run `36973804731`). Its signed
  app installed, reports 43, and launched; the user confirmed icons-only but
  rejected the appearance. The supplied screenshot shows the old tall pill and
  wide selected badge. Build 43 was not uploaded: Apple validation hit low disk
  and was stopped. Its archive/IPA are recoverable from the verified private
  server backup `/home/ubuntu/findez-preserved-build43.tar.gz` (683 entries,
  SHA-256 `d5a7e68f4bf61cef91910889c9b8f2155b799e8c0bd02c2c9811832dc71bdc34`);
  only the local copies were removed. The compact build-44 correction
  reduces visible navigation height to 56pt, keeps safe insets outside the pill,
  and uses a subtle circular selected indicator. All 117 mobile tests with
  coverage, focused glyph-loaded layout capture and clean analysis pass. The
  captured fake-data pill was inspected. Exact runtime `42f977c` passes all five
  CI gates (run `36976126350`). Signed build 44 installed, reports 44, and
  launched; the user approved the slimmer pill and circular highlight. Apple
  validation and upload passed (delivery `350a7049-8b9d-4654-bccc-722be9d53916`);
  processing is `VALID` / `APP_STORE_ELIGIBLE`, with both internal groups
  (Testers and Internal Pilot Findez AI) assigned. Production compile
  configuration matches the existing mobile environment without logging values.
  IPA SHA-256 is `0dbc24b0db6776679c9c8c073e471b496f5aff90c723a8117ae09111cc905949`.
  Signed build 44 is preserved in verified private backup
  `/home/ubuntu/findez-preserved-build44.tar.gz` (mode 600, 683 entries, SHA-256
  `3b196d02806bf20691a95aad4d7a46771770ba90f683c10ddf40fa5a0b44429d`).
  Build 42 remains recoverable from verified private server backup
  `/home/ubuntu/findez-preserved-build42.tar.gz` (683 entries, SHA-256
  `ba374f01046d82ce2b6c98b45e1213a190152cd827a8ff1f6a716c705b67ad6b`).
  At build-44 delivery the App Store draft still selected build 42. The current
  build-46 draft and submission hold are recorded above.

- `fix/item-detail-swipe-dismiss`, stacked on navbar PR #33, updates the shared
  item information panel used by personal, joined/shared and Team Spaces, not
  the separate Edit item form. Its content uses the draggable sheet's scroll
  controller: pulling down at the top closes, scrolling inside the body does
  not. Small pulls restore the full sheet and horizontal photo swipes stay in
  the gallery. Downward dismissal, Close, system Back and barrier dismissal
  share unsaved-note confirmation and confirmed autosave flushing; read-only
  access cannot write. Build 45/runtime `55dd4fd` passed all five CI gates
  (run `37032241160`), Apple validation, signed installation and launch, but the
  user reported an uneven exit. It was not uploaded. A regression reproduced
  late scroll-end events restoring the sheet to full height during route exit;
  build 46 keeps accepted dismissal latched until disposal. All 135 mobile
  tests with coverage and clean analysis pass, including 18 item-info tests and
  two animation regressions. Runtime `78404fa` passed all five CI gates
  (run `37033574121`). Signed build 46 installed, reports 46, and launched on
  the paired iPhone; the user confirmed a smooth Parts Room info-panel exit.
  Apple validation and upload passed; delivery
  `6d44ee23-5d42-4abb-a196-0df58223f415`. Apple processing completed with
  `VALID` and `APP_STORE_ELIGIBLE`; build 46 is assigned to both internal groups
  (`Testers` and `Internal Pilot Findez AI`). No external review/submission was
  started during that delivery. The public App Store release remains unchanged;
  the later build-46 draft selection and acceptance hold are recorded above.
  IPA SHA-256:
  `0c0bf3a0db16dc2603acf7576eae9ddb8713423b6d8bc5678624517209b65a0e`.
  Build 45 is recoverable from verified private backup
  `/home/ubuntu/findez-preserved-build45.tar.gz` (mode 600, 683 entries, SHA-256
  `7868dd3e8aa84baddff2f12f1cc4836b83be76ea4675e8a175d89a5f4ee1014e`).
  Signed build 46 remains local and is also preserved in verified private backup
  `/home/ubuntu/findez-preserved-build46.tar.gz` (mode 600, 683 entries, SHA-256
  `1e3d6a916af48c7795d2e1a754c8a6d12561a672e6e503f51e938623116a3133`).
  Its extracted IPA matches the signed/uploaded hash above.
  Redundant local build-42/45 archives and IPAs were removed with approval after
  backup integrity and extracted IPA hashes matched. Test caches were cleared
  and are regenerable. The original shared checkout and device data are untouched.
  Backend/web, API/schema, navbar and native lifecycle files are unchanged.

- `feat/workspace-invite-links`, based on released build 39, adds authenticated
  read-only Space/Team previews, explicit join consent, existing-owner links for
  joined/shared Spaces, and restart/account-safe mobile presentation. An optional
  account-first download handoff uses a private, expiring invitation pointer;
  downloading first still requires reopening the link. No membership is granted
  by the handoff. The public Team-only AASA remains unchanged while App Store
  build 17 is live. The reviewed backend/web are deployed, public backend/DB
  health pass, anonymous previews return 401, and all five CI gates passed on
  `47aa8ef` (PR #32). Build `1.0.7 (40)` is valid in both internal groups and
  installed/launched, but the signed-in user did not see its cold Team prompt.
  The application-only link library does not register scene callbacks. Build
  41 pins the scene-compatible library and minimum compatible auth adapter;
  the user confirmed its cold Team prompt and Space prompt from a real Safari
  tap. Final build 42 adds actor-bound membership requests so a queued request
  cannot use a switched account's token. Runtime source `0b4c207` passes all five
  CI gates (run `36969482272`), 343 backend/133 web/114 mobile tests,
  MCP/bundle checks, analysis, typecheck and production web compilation. The
  final web actor-binding files are deployed byte-for-byte with rollback output
  retained. Signed `1.0.7 (42)` passed Apple validation/upload, `VALID`
  processing and `APP_STORE_ELIGIBLE`; both internal TestFlight groups are
  assigned. Exact final archived app installed, reports 42, and launched. The
  user repeated cold Team and real Safari Space prompt confirmations on build
  42; nonexistent test codes added no membership. At that delivery App Store
  1.0.7 selected build 42 with manual release and release notes, in
  `PREPARE_FOR_SUBMISSION`. The current selection is build 46 as recorded above;
  it is not submitted/published. Fresh-install/account-confirmation continuity,
  real acceptance/revocation, additional platform/browser checks and the broader
  physical/security checklist remain before submission. The public 1.0.6(17)
  and Team-only AASA are unchanged.

  Build-40/41 archives and IPAs were removed locally only after private server
  backups passed gzip validation and each listed both artifacts (683 entries):
  `/home/ubuntu/findez-preserved-build40.tar.gz`, SHA-256
  `45ef01c99b682200645ab605805d13306787e38e27a98b44fd9eb70628e7c9b2`;
  `/home/ubuntu/findez-preserved-build41.tar.gz`, SHA-256
  `c0d2650597535615df2c371b767f9eb0be763a9e1e7397c775e9d1342b74dc68`.
  Build 42 is preserved in its verified private server backup above. The older
  build-39 originals were
  removed only after the private server backup passed gzip validation and listed
  both artifacts: `/home/ubuntu/findez-preserved-build39.tar.gz` (683 entries,
  SHA-256 `349809879acea986d541fe1c7c96b11dbdb6c1db73ec092efae52437cfaa4151`).
  Builds 36-38 remain recoverable from verified private server backup
  `/home/ubuntu/findez-preserved-builds36-38.tar.gz` (mode 600, SHA-256
  `e997c5fab2520bc49fdf7a6b76d96ca65096d53b894e17b5933fe3162b2d4caf`).
  Its SHA-256 matches the local tar; gzip validation passed, with 2,049 GNU tar
  entries (2,046 on macOS tar). Only the redundant local backup was removed.

- A production-dependency audit flags Next.js 16.3.4 under
  GHSA-vcvr-r3jv-pc5j, patched in 16.3.6. No `next/og` or `ImageResponse` usage
  exists in this source, so its vulnerable SVG-generation condition is absent.
  A separate minimal web patch and validation remain; do not report a clean
  web dependency audit from the invitation tests.

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
- Branch `feat/ask-grounded-reference`, based on build 35, recreates the supplied
  Ask reference without changing Home or the pill. It adds collapsed checked
  sources, authorized project-readiness rows, and saved public answer snapshots
  through migration `037`. Flutter analysis, all 46 mobile tests with coverage,
  and all 292 backend tests pass. The narrowly scoped backend and migration are
  deployed and healthy. Signed build `1.0.7 (36)` passed Apple validation,
  uploaded, and installed/launched on the physical iPhone. Apple processing is
  `VALID` and `APP_STORE_ELIGIBLE`, with assignment to both internal TestFlight
  groups confirmed. Failed conversation or
  snapshot writes now surface safe errors rather than silently losing history.

- Ask photo attachments are implemented on `feat/ask-fast-photo-questions` in
  `/private/tmp/findez-ask-reference` (a separate lane based on build 36). One
  camera/library image can be previewed/replaced/removed, sent with a question or
  the default identification/ownership question, and retained in saved answer
  context. Photo identification checks access-scoped inventory, labels possible
  matches honestly, and sends uncertain objects to Review without automatically
  adding inventory. The user cancelled text-speed work; it is excluded. All 327
  backend and 55 mobile tests, clean analysis, and all five CI test jobs pass on
  implementation `6944ed3` (PR #29 stacked on #28). The selected backend files
  are deployed and healthy; build `1.0.7 (37)` is valid and in both internal
  TestFlight groups. Native physical install/launch passed. Hands-on photo
  acceptance is not yet claimed.

- `feat/profile-nav-hub` adds the user's requested fifth circular Profile tab
  to the restored rounded icon pill. Profile groups account editing, settings,
  documents/notes, notifications, lent items and the app tour; duplicate utility
  header icons and Find's old More sheet are replaced by this destination.
  Existing account, billing, scanning and support actions are preserved. Home,
  Ask/photo attachments, text speed, backend and web are unchanged. All 66 Flutter
  tests with coverage, clean analysis and all five CI test jobs pass. Build 38
  is valid and available in both internal TestFlight groups. Native physical
  install/launch passed; full hands-on acceptance remains unverified.

## Known limitations and risks

- FIND production transport currently uses a public plain-HTTP endpoint behind an
  explicit temporary allow flag because the private route was unreachable.
  On October 4 the user explicitly instructed preserving this connection and
  withdrew the proposed TLS migration. Keep the risk visible without changing
  runtime configuration or representing it as encrypted.
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

- Build 36 (`1.0.7`) implements the supplied Ask reference: plain title/question
  card, collapsed "What it read", readable streamed answer, and grouped real
  quantity rows with missing/low/have badges. Home and the original four-tab pill
  are unchanged. Named project questions use authorized requirements and
  reservation-aware stock; unknown or ambiguous projects ask for clarification.
  No invented requirements, private reasoning, or internal provider/tool names
  are added to the public evidence contract. Saved snapshots use migration `037`
  and existing conversation RLS; safe errors report history-write failures.
  Flutter analysis, all 46 mobile tests with coverage, all 292 backend tests,
  PostgreSQL 17 ownership/constraint checks, and all five CI test jobs pass on
  implementation `f1204d8`; the final server safeguard is `44a2a14`.
  Signed archive, Apple validation, upload, and native physical install/launch
  passed. Delivery/build ID: `02154bba-e589-4447-b529-8e7331ddac9a`; App Store
  Connect uploaded date: 10:59 PM PDT on 2026-09-30. Processing completed with
  `VALID` and `APP_STORE_ELIGIBLE` status, and assignment to `Testers` and
  `Internal Pilot Findez AI` is confirmed. The deployed backend and public
  database health checks pass, unauthenticated Ask/history reads return 401, and
  deployed file hashes match the reviewed source. PR #28 is stacked on #27.
  TestFlight-app installation and hands-on keyboard, voice, source navigation,
  ambiguous-project, and multi-account checks remain unverified. The broader
  physical-memory vision and existing launch-image warning remain separate work;
  the public App Store release is still `1.0.6 (17)`.

- Build 37 (`1.0.7`) adds one camera/library attachment to Ask with preview,
  replace/remove, image-only default question, photo identification, strong
  identifier versus possible-name inventory matches, public saved photo context,
  and uncertain objects in Home Review. No attached object is automatically
  added to inventory. Text-chat speed, Home, Capture, FIND, and navigation are
  unchanged. Existing migration `037` stores the photo snapshot; no new schema
  was required. Uploads are validated/downscaled with metadata stripped; quota,
  conversation ownership, URL owner/origin and safe failure tests are included.
  All 327 backend and 55 Flutter tests with coverage, clean Flutter analysis,
  and all five CI test jobs passed on `6944ed3`. The signed final archive passed
  Apple validation, physical install/launch (installed `1.0.7 (37)`), upload,
  `VALID` processing and `APP_STORE_ELIGIBLE`. Delivery/build ID:
  `e671ac63-e931-48bc-ba52-655258142a9e`; uploaded 00:09:43 PDT on 2026-10-01;
  assigned to `Testers` and `Internal Pilot Findez AI`. Build-36 archive and IPA
  are retained under `mobile/build/ios/archive-build36` and `ipa-build36`.
  Four selected Ask backend files were deployed only after matching the build-36
  base hashes; backup: `/home/ubuntu/findez-backup-ask-photo-20261001.tar.gz`.
  Deployed hashes match, service/database health passes, unauthenticated photo
  requests return 401, and unrelated production changes are preserved. PR #29
  is stacked on #28. TestFlight-app installation and hands-on camera/library,
  matching/Review, follow-up and account-switch acceptance remain unverified.
  The existing public-HTTP FIND transport security limitation and default launch
  image warning remain; this is not a claim that the whole app is production-ready.

- Build 38 (`1.0.7`) adds the requested fifth circular Profile pill destination
  and utility hub, with separate account editing/settings and existing documents,
  notifications, lent items and app tour. Duplicate utility header icons and
  Find More are replaced by Profile. All 66 mobile tests with coverage, clean
  analysis and all five CI jobs pass on `b4aa726`; newer-Flutter Material ink
  compatibility is included. Apple validation, signed native install/launch,
  upload and `VALID` processing passed. Delivery/build ID:
  `f3fd1470-274e-4b93-be11-f9aba147546e`; uploaded 00:43:33 PDT on 2026-10-01;
  both internal groups are assigned. Build 37 archive/IPA are preserved in
  `archive-build37`/`ipa-build37`. PR #30 is stacked on #29. Home, Ask attachments,
  text speed, backend and web are unchanged. Hands-on acceptance remains
  unverified. The user subsequently reported cramped profile editing, missing
  overview avatars and old Documents styling; a scoped follow-up is required.

- Build 39 (`1.0.7`) follow-up is released on `fix/profile-documents-polish` in the
  existing `/private/tmp/findez-ask-reference` worktree: labeled profile editing,
  shared saved avatars in editor/overview/pill, correct image MIME uploads and
  matte Documents/note/link/rename flows. Private upload logs are removed;
  foreign URLs, stale account reads/draft writes and asynchronous document-link
  cache keys are guarded. All 94 Flutter tests with coverage and clean analysis
  pass, including 28 new failure/security/keyboard and note Back-autosave
  regressions. All five CI jobs pass on final implementation `6a0118e` (run
  `36958595854`); PR #31 is stacked on #30. Fake-data layout captures were
  inspected. Final signed archive, Apple validation/upload, `VALID` processing,
  `APP_STORE_ELIGIBLE` and assignment to `Testers`/`Internal Pilot Findez AI` are
  confirmed. Delivery/build ID: `8b7ff936-fefa-4ff1-8cd7-095c40aab00f`; uploaded
  20:11:17 PDT on 2026-10-01. The exact final app installed on the paired iPhone
  and reports `1.0.7 (39)`, but final launch was blocked by iOS `Locked`; user
  unlock was requested. An earlier superseded build-39 binary launched, not the
  final source, so do not report final launch as passed. Final launch,
  TestFlight-app install and hands-on photo/document/account-switch acceptance
  remain unverified. Build-38 artifacts are retained in `archive-build38` and
  `ipa-build38`. Home, Ask speed/attachments, Capture, Find, backend/web and
  existing settings behavior remain unchanged; no server deployment/migration
  was required. The public App Store stays `1.0.6 (17)` and existing broader
  FIND transport/native acceptance limitations remain separate work.
