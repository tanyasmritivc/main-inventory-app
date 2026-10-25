## October 25 — Wordmark balance deployed (PR216)

Runtime `04f883b3c8b8567e12bbc2ab1974163d2bc228d2` is live at findez.ai. The Petals mark is 20% smaller beside unchanged lettering in light/dark and landing wordmarks. All five CI jobs passed (40217806792); production build `nvXSrYN7RI1ah94eeMZ_i`, 22 staged/live route checks and public SVG hash/live browser verification passed. Active release: `/home/ubuntu/findez-web-releases/wordmark-balance-20261025/frontend`; rollback: `petals-20261025/frontend`. Five obsolete webpack caches were cleared after ENOSPC; source and compiled rollback releases remain intact. Backend process preserved.

## October 25 — Smaller web wordmark symbol

User requested better balance between the Petals symbol and FindEZ lettering. Branch `fix/web-wordmark-balance` reduces only the three runtime web wordmark symbols by 20%, keeping lettering, right-edge spacing and vertical center fixed. Scoped ESLint, 26 sidebar tests and local browser inspection pass. Deployment pending CI and production build.

## October 25 — Petals website deployed (PR215)

Runtime `a6f5d37c78ffdb995e13eada62a8318134ff04be` is live at findez.ai. All five CI jobs passed in run 40216797751. Production build `uScVgYDkdk9XdlwXrH-Iw`; 22 staged and 22 live routes passed. Public metadata and a live browser check confirm the new wordmark/favicon. Previous release and backend process preserved. Active directory: `/home/ubuntu/findez-web-releases/petals-20261025/frontend`; rollback: `/home/ubuntu/findez-web-releases/remove-search-20261024/frontend`. No schema or backend changes.

## October 25 — Petals release authorized

The user subsequently requested TestFlight delivery and website deployment. This supersedes the brand prompts’ local-only restriction. Public App Store submission remains explicitly held. Preparing the web Petals release with the existing production configuration.

## October 25 — Petals brand v4 (frontend, local only)

Branch `web-brand-v4` applies the supplied v4 brand kit to logos/icons and theme tokens. Validation and the complete file list are in `frontend/design/brand-v4/IMPLEMENTATION.md`. The latest prompts say not to push/deploy; no release or TestFlight upload was performed. Backend, schema, env and deployment configuration are untouched.

## October 24 - Duplicate Search navigation removed (PR213)

Web runtime `2e9c0af0dbe66ee21f0c887cf520b744b74953c9` is deployed. Search was
removed from the shared organization/Personal sidebar; New chat is the only chat
entry. Existing URLs remain compatible. All 566 web tests, TypeScript, scoped
lint, production build and all five CI jobs (40167973852) passed. Twenty staged
and twenty live route checks passed; signed-in browser refresh visibly showed
New chat, Spaces, Tools and Workspaces with no Search link. Previous release and
backend process were preserved. Build: `-Ox8Rrh0-m9OKbw7XroCX`. Release/rollback:
`/home/ubuntu/findez-web-releases/remove-search-20261024`; prior release:
`/home/ubuntu/findez-web-releases/theme-audit-20261024/frontend`.

## October 24 — search and browser brand refresh

Deployed self-hosted web runtime a52b1537566ca2957f0ef68c69d3aff2c57cf29c (PR #201), build uPMr9qe7iEphZ4ferX3iR, at /home/ubuntu/findez-web-releases/search-brand-20261024/frontend. All five exact-runtime CI checks passed in 40148047062. Local 558 tests, TypeScript and changed-file lint passed without new warnings. Production build and 13 staged/live route checks passed. Public-domain verification confirmed exact homepage/social title, FindEZ site name, five icon links matching canonical files, valid structured data, Pricing title/canonical, and Pricing in sitemap. Previous web release and backend PID were preserved. See docs/plans/search-brand-20261024.md. On October 24, at the user’s request, Search Console accepted https://findez.ai/sitemap.xml (Success, submitted and last read October 24, 5 discovered pages). Homepage URL Inspection confirmed the page is indexed; Request indexing then confirmed “Indexing requested” and addition to the priority crawl queue. Search result artwork/title refresh and sitelink/knowledge-panel display remain controlled by Google and unverified.

## October 24 — clearer drafts and correct photo quantities (web)

Runtime `45af6f290acc42db67a1a899e96cc10398f364e0`; PR #198; all five exact-runtime CI checks passed in run 40146412757. Self-hosted website published at /home/ubuntu/findez-web-releases/draft-flow-20261024/frontend. Build ID byC8d2bvI6dGs1MUmdh6L. Eight staged and live routes returned 200; the API process and previous web release were preserved. See `docs/plans/draft-flow-20261024.md`. Bottom navigation remains unchanged; no schema migration.

## October 24 — Chat activity and current echo branding live (PR196)

Runtime d537e3018a194c6e44765cfdf55690085567325a is live on the self-hosted website.
Actual activity has a two-second left-to-right soft shine and expandable history;
Reduce Motion shows static text. Light/dark appearance and disclosure were checked
in a local component preview. Text captures are labeled Inventory draft.
The user's latest ZIP round/ artwork and matching standalone app-icon-*-2.svg
are canonical. Browser/touch/social/legacy assets and metadata versions are updated;
all 15 live public assets match the supplied exports. Search caches refresh separately.

557 tests /77 suites, TypeScript, scoped lint (3 existing warnings), production
server build and eight route checks pass. All five runtime CI jobs passed
(40143400021). Build 7YIcfO0FBtR_GUUnTaHy7 is active. Old web release preserved and
backend PID unchanged by publication. No auth/navigation/database changes.
See docs/chat-progress-web-20261024.md and docs/brand-echo-current-20261024.

## October 24 — Direct organization entry and chat sources live

Web PR193 (`feat/direct-world-entry-chat-menu-20261024`), runtime `18f3b06`, is
live on self-hosted web. Ordinary sign-in/signup enters the last authorized world
or Personal; organization management lives in Settings. The web plus menu reuses
mobile's deployed sources, file, barcode and durable capture APIs. Imports and
extraction require reviewed saving. No Google/unfinished connector placeholders.

Local: 556 tests / 76 suites, TypeScript and webpack build passed; lint zero errors
and 53 existing warnings. All five CI jobs passed on runtime (40135129405).
Server build `CGFdjEkOiFJ8kmwO5iqVl`, 23 route statuses, world/settings auth redirects
and six brand assets verified. Preserved 361 unrelated files and backend PID.
No schema/backend/mobile changes. Browser visual acceptance blocked by
`cgWindowNotFound`; real signed-in AI/save and physical camera remain unverified.
See `docs/direct-world-entry-chat-menu.md` for exact manual checks and receipts.

## October 24 - Organization chat and direct Space items live

Web-only PR192, branch `feat/organization-workspace-chat-20261024`, runtime
`7077b2f`, is live on self-hosted web. Organization selection opens New chat,
Spaces, Search and Tools using the deployed mobile `/worlds` API. Space links open
editable items directly; legacy dashboard/chat links redirect after authorization.
Management tools and earlier private inventory chats remain available. History and
drafts stay actor/world-scoped; organization scope does not expand access.

All five CI gates passed (40123190890); final web CI: 532 tests / 71 suites.
TypeScript, local and production-configured server builds passed. Lint has no new
errors; preserved existing agent approval route has its original hooks warning.
Build `cKvXUqYCWc3CAo3M7VXGS`: 21 route statuses, world auth redirects, six brand
assets and 349 unrelated files verified. Backend PID unchanged; no mobile/schema
changes. Fictional desktop/light/dark/narrow-layout and item-edit visual checks
passed. Signed-in production AI/write round-trip remains unverified. See
`docs/organization-world-chat-web.md` for details and manual checks.

## October 24 — Desktop organization navigation

Web-only `feat/desktop-organization-shell-20261024`, based on `1699f86`.
Adds an authenticated organization selector to the existing sidebar, default
expanded desktop navigation, consistent page spacing and directory card hierarchy.
Personal, all workspaces, creation and invitation actions reuse existing routes.
No feature removal, permission changes, backend, database or Flutter edits.
508 web tests / 66 suites, TypeScript, production build pass; lint has zero errors
and the same 52 baseline warnings. Browser review uses isolated fictional fixtures,
never customer writes. Narrow-screen review passed. Preserved live account
verification and organization settings from `2afb817`. All five CI gates passed (40120059401). Runtime `4b879d9` / PR191 is live
on self-hosted web, build `XAq7FeqLtoueYFUgAFjOs`. 21 route statuses and six
brand assets verified; preserved 360 unrelated files and the backend PID.
See `docs/desktop-organization-shell.md` for scope and verification.

## October 24 — Direct landing prompt to authentication

User superseded the public demo: Send now navigates immediately to signup with
the bounded original prompt. A 160ms composer fade runs during navigation; no
preview modal, example inventory, or artificial wait. Reduced motion skips the
fade. Existing signup/signin/onboarding/Ask prompt retention stays intact.
Live runtime `33543a7` / PR190, branch `fix/landing-direct-auth-20261024`.
483 tests / 62 suites, TypeScript and production builds passed; ESLint 0 errors
and 52 existing warnings. All five CI gates passed (40117394503). Self-hosted
build `QbQGQXxQY5zOUd7kkZfdp` preserves 362 unrelated files and the backend PID.
Twelve route statuses and six brand assets verified. Live browser Send opened
signup directly with the original prompt; no account was created. Earlier
prompt-preview delivery below is historical.

## October 24 — Public prompt preview live on self-hosted web

Runtime `ad13f91515e42f5bfc89a337ff818e50a07cd77e` / PR183 is live from
`/home/ubuntu/findez-web-releases/prompt-preview-20261024/frontend`, build
`cHXcB07Do-U3qk0tvDwjj`. Includes previous Blue Echo branding. Prompt submission
morphs into an interactive, explicitly unsaved demo, then carries the original
request through signup/setup to an editable Ask draft. Local parsing and labeled
examples only; no anonymous AI call or inventory write. All five CI gates passed,
488 local web tests passed, build/TypeScript passed. Twelve live route statuses,
six assets, 357 unrelated files and unchanged backend PID verified. Live mobile
preview/signup handoff inspected. See `docs/landing-v3/PROMPT_PREVIEW.md`.

## October 23 — Landing v3 live on self-hosted web

User authorized deployment. Homepage implementation `cf29d1f` on `feat/landing-v3`
(PR #180) is live from `/home/ubuntu/findez-web-releases/landing-v3-20261023/frontend`.
Build ID `8xw5tjSXdVhKej4STQ101`; production build and public HTTPS route/asset checks
passed. Preserved 366 unrelated files and existing server configuration; only the
web service working directory changed. Backend/database/mobile unchanged.
Previous connector release retained for rollback. Self-hosted only; no Vercel
activation. Validation, browser advisory, limits and rollback: `docs/landing-v3/README.md`.

## October 22 — Connector release live; beta 114 uploaded

User approved migration 079 and activation. Migration/backend/web are live; Google
and unfinished connectors remain hidden. Apple acknowledged 1.1.1 (114), delivery
b5637833-5240-4f71-b04b-e48c0ddf238d. Processing, tester availability and physical-device acceptance
were not polled/verified. No public App Store submission.

API runtime 595f269 (PR #176), mobile bc426f2 (PR #175), web f7bac21 (PR #174).
All five CI gates passed in each lane. Full local suites: 1,409 Python tests and
10 subtests, 799 Flutter tests (one optional skip), 478 web tests. Six native iOS
cases passed, screenshots inspected. Full-data rehearsal preserved all 91 existing
tables; live synthetic CSV/XLSX/BOM/replay/isolation checks passed and both accounts
were removed. Deployment preserved 109 unrelated API and 348 web files. No paid
SDKs/new model calls; no Google configuration needed. See
`docs/plans/connectors-phase1-20261022.md` for files, limits and exact test steps.

## October 22 — Connector imports and compact cards (web)

Implementation prepared; migration 079 and activation approved in this session.
Google and all unfinished connectors remain hidden. CSV/XLSX and file BOM review
reuse the shared backend. Existing outbound assistant setup remains available.
Native light/dark screenshots inspected; 799 mobile tests and six native cases
passed, 478 web tests passed, TypeScript/lint and Flutter analysis clean.
Release/build114 not yet delivered. See docs/plans/connectors-phase1-20261022.md.

## October 19 — organization leave/removal update published

Approved migrations 069/070 and matching API/web changes are live after fresh
backup and passing health/access checks. Apple acknowledged signed 1.0.9 (97);
processing, TestFlight availability and device acceptance remain unverified.
Admins cannot remove the organization Owner; removal offers keep/move or delete
choices. The web item expansion omits duplicate headings. No unrelated Dashboard
changes or founder-account testing. See
`docs/plans/organization-removal-choices-20261019.md` for exact evidence.

## Current brand favicons published (2026-10-18)

Web runtime f087a84 (PR126) is live from
/home/ubuntu/findez-search-icons-20261018/candidate/frontend. The Google result
icon is the website favicon. The prior source advertised only SVG and root
/favicon.ico returned 404; Google's current supported list omits SVG. This was a
separate compatibility gap missed by the preceding search-copy pass.

The existing approved native 1024px mark is exported unchanged in design as PNG 96,
ICO 16/32/48 and Apple-touch PNG 180. Metadata declares stable raster icon URLs and
the public publisher logo points to PNG. Legacy SVG remains accessible. Native and
public App Store artwork already use the current mark; no app icon redesign,
backend/database/native code, Dashboard or customer-data changes.

All 365 web tests/48 suites, types, scoped lint and the actual preserved production
build pass. All five CI gates pass on f087a84, run39184358123. Isolated and final
both-host checks verify exact asset bytes, MIME, dimensions/ICO frames, normal
browser and Googlebot-Image access, declared icon links, search metadata/canonical,
public identity JSON-LD, protected product routes and retained Google ownership/
invitation association files. All 265 unrelated runtime/public files are preserved.

The accepted homepage reindex request remains in Google's priority crawl queue;
it was not repeated merely to accelerate it. Actual Google favicon replacement
is external and remains unverified. Stable icon URLs should remain. Private
release receipts: /home/ubuntu/findez-search-icons-20261018. See
docs/plans/search-favicon.md. TestFlight91 remains the prior native upload.

## Public search positioning published (2026-10-18)

Web source `303bd45` (PR125) is live from
/home/ubuntu/findez-search-positioning-20261018/candidate-current/frontend.
Title/search/social descriptions now use FindEZ AI and AI memory for the physical
world. Factual public identity JSON-LD and truthful sitemap dates match that
positioning. The download page copy is aligned. Preserve the current landing
renderer and Dashboard. All 261 unrelated runtime/public files are retained,
including concurrent invitation AASA and account-deletion changes. Source guards
halted stale activation before service changes; the final candidate was rebuilt
against the newly deployed runtime. No backend/database/native code changes.

All 365 branch web tests/48 suites, TypeScript, scoped ESLint, the preserved
production-configured build and browser/Googlebot/canonical/JSON-LD/sitemap/
robots/auth checks pass. All five CI gates pass on `303bd45` (run39174991125).
Both public hosts pass final HTTP checks, including the approved verification
file and the latest invitation association file. No customer QA writes.

The user approved Search Console owner verification for the signed-in account,
completed Google reauthentication, and Google auto-verified the HTML file.
Sitemap submission shows Success with 4 discovered pages. Homepage URL Inspection
showed indexed and then confirmed Indexing requested / priority crawl queue.
Do not repeat the request to try to accelerate Google. Search snippets and AI
Overview refresh/wording remain external and unverified. Keep the HTML proof file.

Apple's live US 1.0.7 listing already had memory-focused copy; Google's source
snapshot still showed older 1.0.6 workshop copy. Updated live 1.0.7 promotional text
and saved the 1.0.8 draft name FindEZ AI, subtitle AI memory for your things and
current-capability description. No App Store submission/release/build-selection
change. Private Apple/Search Console receipts:
Documents/FindEZ/AppStore/search-positioning-20261018. Server release manifests/
health receipts are in the corresponding findez-search-positioning directory.
This is public marketing/indexing delivery; TestFlight91 remains the previously
acknowledged native binary. See docs/plans/public-search-positioning.md.

## Chat actions and profile photos — delivered (2026-10-18)

The user approved "Apply 057 and publish build 91." Migration 057 is applied after
a fresh private database backup. API `65c90d4` and web `bee5088` are live. Public health
and database checks return 200; invalid-session Chat and anonymous private-photo
requests return 401. The deployment preserves 87 unrelated Python and 227 unrelated
web runtime source files. No customer QA writes or existing record rewrites.
Private activation receipts: /home/ubuntu/findez-chat-actions-release-20261018.

Chat can prepare item additions/deletions for explicit review and confirmation.
Service-only atomic receipts enforce current role/scope, stale-record protection,
limits, rollback and idempotent retries. Model-written replies use paced fades;
active mobile Chat hides the main header/navigation while keeping Back available.
Older clients receive ordinary model-written guidance until upgraded. The gateway
still batches a text event; upstream token-by-token delivery is not claimed.

The saved Settings photo appears in People, task assignees/creators, file
attribution and activity. Replacements/removal refresh correctly. Circular preview
supports drag, pinch zoom, zoom controls and Reset before explicit Use photo;
preview/export share the same crop and output 512px PNG. Cancel never uploads.
Dashboard content/layout, current inventory permissions and private photos remain.

Validation: 1,032 Python tests plus 10 subtests; 365 branch web tests/48 suites,
types and scoped lint; 651 Flutter tests with coverage and clean analysis.
The one compiled-production-config gate is separately enabled and passes.
Both-theme crop pixels/gestures, Settings, People/task refresh and Chat action
checks pass. SQL replay, real concurrent confirmation/revocation,87-table isolated
restore preservation and synthetic configured-model add/delete probes pass.
All five CI gates pass for API 39170702187, web 39170702070, mobile 39170880574.
The actual preserved web runtime builds/types and route smoke pass; its full
suite retains18 unrelated failures in five older signup/API-key/landing/legal/
account-deletion fixture suites. Do not change unrelated runtime to hide these.

Apple acknowledged signed production 1.0.8 (91), source `79b9abe`, delivery
c6cab1f6-1254-4395-87f7-9e449ad60d18. IPA SHA256:
aa4d26c06fb2a89cbe8ec3bbecee844c063de43a1bb2695e022ddbe0e2242647.
Strict signature, all 31 archive +31 export device executables, production defines
and main.dart target, archive preservation and Apple validation pass. Artifacts
and acknowledgment: Documents/FindEZ/AppStore/1.0.8-build91. Original 90 binaries/
Apple receipts remain intact;91 includes 90's 96b00d3 terms/config source fixes.
Stop at upload acknowledgment: processing/tester availability were not polled;
physical-device acceptance remains pending. Public App Store submission is held.
PRs120/119/121 contain Chat; stacked PRs123/122/124 contain photo consistency/crop.
This receipt supersedes earlier candidate/pending delivery notes below.

## Streaming and focus delivered (2026-10-18)

API17a60ac/webec14cee are live with 89 unrelated Python and 223 unrelated web runtime files preserved. 1,004 Python +10 subtests; 347 web tests/types/lint; 631 Flutter tests/analysis and rendered-pixel checks pass. All five CI gates pass on PRs110/111/112; all five also pass for focus PR113 (run39161964797). The existing branch landing Google-font build/preview failure is outside this change; the preserved actual live candidate builds/types and route smoke pass. The upstream gateway still batches a single SSE text event; client chunk fades/pacing handle that without scripted text.

Apple ACK88: e65c5314-3ab3-4eb1-92d8-290abf9dce21, sourcef440717, IPA83663dd3560322c6c60ce079f978f8681967ba6184608b8db4f6d72f75e89f54. Apple ACK89: 0bdf5216-4d6a-42d8-8e87-d859b16954a0, source4bfe0ff, IPA2cba9bb716e6b52c8f604f99fac995935fe991c6545c9a18ed6c071379fca26a. Both signed/Apple-validated, 31+31 device executables checked, signed archives preserved in Documents/FindEZ/AppStore. Processing/tester availability unverified and not polled; physical-device acceptance pending; public App Store held. No schema changes for streaming/focus.

## Chunked Chat delivery and fades prepared (2026-10-18)

347 web tests, TypeScript and scoped lint pass on Next 16.3.8. Production candidate build pending; branch build hit an unrelated Google font loader error.

web lane uses incremental model events with paced UI chunks, stable earlier text and Reduce Motion. Tool arguments stay private; tool preambles reset before the final answer. Completion never dumps a queued suffix. No model/provider/config/schema changes, scripted successful answers or Dashboard changes. The current gateway probe returned one SSE text event (436 characters; first text 1.374s, total 1.378s), so upstream token granularity is not claimed. Photo fixes/056 and beta87 are already delivered. Release/physical-device acceptance for streaming remains pending.

# October 18 Capture return — live

Approved matching capture release3908580 is live from
/home/ubuntu/findez-capture-release-20261018/web-candidate/frontend. Complete saves
return to Items filtered to the Space in the same inventory. Two hundred twenty-six
unrelated runtime files are preserved, including independent landing work;
Dashboard stays unchanged. Branch full345 tests/types/lint/build and all five CI
gates39156877889 pass. The actual preserved candidate builds and public/protected
route checks pass. Its old landing section-ID assertion is stale for the existing
live renderer; Capture/auth/navigation tests pass. This task does not change that
landing renderer. Production signin healthy; no customer QA writes.

# October 18 Capture return — prepared, not activated

Branch fix/web-scan-save-return-20261018. After complete clear/Review receipts,
Capture returns to Items filtered to the saved Space in the selected inventory.
Partial drafts remain retryable. Full345 web tests, TypeScript, changed-file lint
and production webpack build pass in the unpublished server candidate, with final
scoped capture checks after the Space query refinement. Backend owns private
crop-first/original-second gallery retention. Live web remains eccccc1; pending
matching API/migration056 activation. Dashboard content/layout is unchanged.

# October 18 permissions, private photos and Account — delivered

This entry supersedes the prepared/active rollout notes below. The user approved
"Apply 054/055 and publish the fixes." Migrations 054/055 were applied atomically
after a fresh private backup; backend, web and gateway rules are live. Inherited
Editor stays Editor, deliberate custom/No access remains authoritative, and
administrative access does not silently expose restricted contents. Source is
API b0c04e3 (Python runtime 1c2280c), web eccccc1, mobile 9cec0bc. PRs 102/103/104.
No Founder Dashboard is included; customer Dashboard content/layout is preserved.

Authorized teammates retain photo access through authenticated app requests;
copied URLs grant none. A follow-up accepts existing trusted-origin //storage
locators and rebuilds the two SQL expression indexes. All 16 existing photos are
recognized, 28 authorized member/photo pairs have 0 lookup failures, and an actual
authorized backend Storage download validates as an image. Old public links all
return 404; anonymous application photo requests return 401. No photos, locators
or customer membership/invitation data were rewritten for QA.

The initial gateway template rewrite missed real entrypoint substitution and
briefly prevented startup. The original was restored; the corrected fragment-only
insertion preserves original template bytes and passes all 7 actual-entrypoint
isolated HTTP privacy cases. Gateway/auth/health/database checks pass. Deployments
preserve 79 unrelated Python and 242 unrelated web source files. Private backups,
manifests and live receipts: /home/ubuntu/findez-permission-release-20261018.
Final web: /home/ubuntu/findez-web-releases/permissions-url-compat-20261018/frontend.

Mobile main-page account controls now open the existing compact Profile hub in an
opaque Account Scaffold with safe AppBar/back navigation. Profile editing and
Settings are separate destinations. This fixes the transparent previous-page
overlay and status-bar clipping without changing Dashboard content. Light/Dark
widget checks cover opacity, top insets, navigation and actual private Image
requests; test-font captures are synthetic, not native/device acceptance.

Completed validation: Python 901 + 10 subtests, web 344/46 suites plus types/build
(lint 0 errors, 54 existing warnings), Flutter 623 with coverage and clean analysis,
latest 25 focused profile/Review/photo cases, SQL replay/matrix, two real concurrent
revocations, and the isolated production restore preserving values across 86
tables. Runtime CI is green: API 39115338261, web 39115340558, mobile 39115340763.
No completed regression checks were repeated after push/build.

Apple acknowledged signed production TestFlight 1.0.8 (85), delivery
6a197534-7e09-453d-a1fa-efe1bf9adeec. All 31 archive/export executables are iOS device code;
strict signatures, production configuration/main target and Apple validation pass.
Private IPA and archive: Documents/FindEZ/AppStore/1.0.8-build85. Beta85 supersedes
acknowledged beta84, which missed legacy photo locators and the Account fix.
Older mobile builds need beta85 for private photo/crop loading. Processing and
tester availability were not polled; physical-device acceptance remains pending.
Public App Store submission remains held. Documentation receipts need no binary.

# October 17 web dashboard cleanup

Recently added and Spaces use contained responsive panels with consistent rows
and empty states. Existing scoped data/search/actions remain; viewers receive no
create prompts. 327 Jest tests, TypeScript and error-free changed-file lint pass.
Production webpack build passes; aafcbd5 is live on the self-hosted web service.
285 unrelated sources are preserved; public/auth checks and signed-in Safari
populated/empty visual review pass. Mobile/backend unchanged in this lane.
See docs/plans/web-dashboard-cleanup.md.

# October 17 interactive mobile setup

First-run onboarding now builds a persistent native canvas world. Team/personal
choices are local until auth, then an account-bound provisioner reuses existing
create APIs and opens the new inventory dashboard. Selection steps advance on
tap; typed names use Done; the empty organization hint is e.g. FindEZ AI.
Personal recap remains Personal / Only you. Provider-first auth follows the
user's later Wispr reference; existing auth handlers are unchanged. Optional
settings questionnaire is preserved separately. Default appearance is already
light and explicit stored choices remain honored. No backend/web/schema or
inventory-dashboard/Space interior changes. Migration 053 remains separately
pending. Baseline 466 tests; final full Flutter suite 506 pass, final focused
motion/onboarding 20 pass after a palette-only correction; analysis clean.
Both iPhone 16e paths recorded at normal speed, keyboard/restart/back/custom and
auth variants visually reviewed. Debug overlay worst UI 59.89 ms / raster 28.804 ms;
strict 16 ms and physical OAuth/email/VoiceOver acceptance are not claimed.
Apple acknowledged TestFlight 1.0.8 (78), source 269f1f0, delivery
5f203ae7-9cdd-437f-b149-eb9383f5241b. Processing/tester availability unverified;
no polling or post-push/build regressions. Full file list, motion audit,
API retry limits and comparison artifacts: design/onboarding-a/IMPLEMENTATION.md.

# October 17 catalog write permissions candidate

Branch fix/catalog-write-permissions-20261017, clean start 16eb6a1. Audit F01/F07
patch adds candidate migration 053 and two service-only catalog transactions.
Anonymous/signed-in direct writes are denied; verified details and equivalent
barcode ownership are protected; lookup responses/private inventory edits stay
compatible. 817 backend passes, 321 SQL PASS notices and real concurrent races
pass. Fresh dump restored with grants in a network-isolated database; migration
and replay preserve all public/auth rows and unrelated objects. Production 053
activation awaits separate approval. Patch 07c6d62 is pushed in draft PR 91. Apple
acknowledged TestFlight 1.0.8 (77), delivery cd2e3a2c-3ca2-4d2c-a2dd-cf6d8f1967ef.
Processing/tester availability unverified; no polling or repeated regressions.
Native code unchanged; prior 466 Flutter passes/analysis reused. GPU/FIND/web untouched.
See docs/plans/catalog-write-permissions.md for all files and rollout boundaries.

# October 16 simplified web inventory sidebar

Apple acknowledged TestFlight 1.0.8 (76), source d3109b3, delivery f8d15676-774f-4d88-9468-d0044da2db33. Native UI unchanged; processing/tester availability not checked. Web sidebar is published and visually verified.

Review is grouped under Your world. Restock, Lent items, Project kits, Smart
collections and Labels are removed from the shared web navigation and command
list; the empty Organize group disappears. Existing routes/data are preserved.
324 web tests, TypeScript, changed-file lint and a normal production webpack build
pass. Five old route-selection cases disappear with the removed entries; the
existing sidebar assertion now checks Review's group and absent links. Live
signed-in Safari visually confirms the exact sidebar. Self-hosted web release:
/home/ubuntu/findez-web-releases/web-sidebar-simplify-20261016/frontend. Its one-file
overlay preserves 285 unrelated source files, including the homepage. Public/auth
checks pass, no schema/backend/customer-data change. Mobile UI is unchanged;
beta76 is a standing-instruction delivery increment, reusing the prior 466 Flutter
passes. No checks repeated after push/build; stop at Apple upload acknowledgment.

# October 16 extraction overlay fix

Owned root-dialog cleanup replaces the mismatched local pop in in-Space photo
upload. Success/error removes exactly the progress route; departing Space routes
cannot receive stale confirmation. Four nested-navigation regressions and the full
466 Flutter tests pass; analysis is clean. No backend/web/schema changes in this
stage. Beta74 was acknowledged (0ebf355, 9106117d-0272-4d90-a140-687db472ee06);
Apple acknowledged TestFlight 1.0.8 (75), runtime 7ec84bb, delivery 2b18a905-cc65-4659-a391-20737ab6ed7e. Processing and tester availability remain unverified; no polling. Existing crop/notification changes remain.
No processing polling or post-push/build regression reruns. Manual iPhone camera,
background push and fresh email acceptance remain pending. Details and all files:
docs/plans/capture-progress-fix.md.

# October 16 per-item scan crop fix

The reviewed adapter now uses the documented item-ID crop endpoint when no URL
is supplied, and reads bbox as x/y/width/height in the stored image frame. Crops
remain independent of confidence and are persisted before job deletion; source
images and Review safeguards are retained. Missing crops fall back to scaled
boxes without discarding detections. The Review and Space toolbars also expose
the notification bell. 814 backend tests plus six subtests, 462 Flutter tests and
clean analysis pass. One-file backend overlay is live with 91 unrelated files
preserved, health 200 and missing-auth scan 401. No schema or customer-data writes.
Apple acknowledged TestFlight 1.0.8 (74), runtime 0ebf355, delivery 9106117d-0272-4d90-a140-687db472ee06. Processing/tester availability remain unverified and were not polled. Real new-camera/device acceptance is pending. Existing
records with missing geometry require a fresh scan. See docs/plans/capture-crop-fix.md.

# October 16 notification and reliability follow-up

Approved migration 051 fixed intermittent workspace creation (legacy UUID codes
violated the existing alphabet check); 052 adds a service-only confirmed invitation
recipient lookup with current sender permission. Both restored-schema rehearsals
and composed SQL pass. Reviewed backend overlay is live; 87 unrelated backend
files preserved. No customer mutations or notifications performed for QA.
Mobile now has a direct inbox bell on primary authenticated routes, badge refresh,
explicit phone-alert setup/test, account-bound registration cleanup and cold-tap
retention. Physical background delivery remains unverified. Ask planning no longer
becomes a literal saved-item search; provider selection and authorization unchanged.
Web auth recovery/resend is published; a fresh real email-link success remains
unverified. 802 backend tests plus six subtests, 329 web and 462 Flutter tests pass; analysis
is clean. Apple acknowledged TestFlight 1.0.8 (73), runtime d212f95, delivery cc0229a0-325c-42f4-90e2-04deec6a302d. Processing and tester availability remain unverified; no polling. Actual iPhone background delivery and fresh email-link success remain manual acceptance. See docs/plans/notification-reliability.md.

# October 16 deletion completion and account pages

Same hierarchy lane, includes workspace controls from 5d5f530. Approved migration
050, reviewed API/cleanup worker and Auth-first Edge handler are live. Explicit
purge preserves empty-only default and shared references; account ownership is
checked before deletion; borrower history remains. Web settings now have separate
category pages, compact layout/menu and persistent visible account navigation.
786 backend tests plus six subtests, 322 web tests, 457 Flutter tests, static
analysis, composed SQL, restored-schema rehearsal and normal production builds
pass. Public/auth/schema/hash rollout passes; no customer deletions for QA.
Final signed-in visual review and beta72 delivery are being completed.
See docs/plans/deletion-completion.md for files, receipts, limits and rollback.

# October 16 hierarchy flow production activation

Lane feat/hierarchy-navigation-20261016 replaces organization/workspace navigation
on both clients and preserves all inventory dashboard/Spaces code. New inventory
is always visible for authorized users; organization switcher entries are real
places; web workspace URLs open Inventories. Both clients add rename/delete menus.
Deletion is owner/admin-only, exact-name, empty-content-only, transactional and
audited. Tanya explicitly approved migration 049 and publication. Private backup
and live-schema restore rehearsal passed; 049 and one reviewed backend runtime
file are deployed. Public/local health/DB health pass, invalid/missing sessions
are denied, direct anon/authenticated RPC execution is denied. No customer
records changed for QA. Web runs web-hierarchy-20261016, preserving unrelated
source and the homepage. Authenticated read-only Safari shows the actual new
directory and Rename/Delete menu. Real writes/cross-client acceptance is pending.

Checks before push: 780 backend, 305 web, 448 Flutter tests; final 33 focused
mobile tests, composed SQL through 049, analysis, TypeScript and changed-file
ESLint pass. Native visual evidence is synthetic, saved in
design/hierarchy-navigation/out. Apple acknowledged TestFlight 1.0.8 (71),
runtime 9bec964, delivery f40d86ad-2880-424d-8aa7-c5e2fb2d8e9b.
PR #90. Processing/tester availability and physical acceptance remain pending;
no processing polling or post-push/build regression reruns.
Details, complete file list, rollback and manual acceptance:
docs/plans/hierarchy-navigation.md.

# October 16 account memory activated on self-hosted production

Tanya explicitly approved migration 048 and the reviewed backend after the source
implementation and TestFlight 70 upload. Migration 048 committed and systemd
findez restarted with the 12 reviewed backend files from runtime 967ab48,
including the PR #88 retrieval dependency. The production Git checkout remains
on main 98597c3 with selective overlays; it was not pulled, reset or cleaned.
Unrelated backend files match their preserved predeployment copies.

Fresh database/runtime backups are private on the VM at
/home/ubuntu/findez-memory-release-20261016. The actual public/auth/extensions
backup restored in a network-isolated disposable container and migration 048
passed there before live activation. Live read-only metadata confirms RLS,
owner-read grants, no anonymous reads/client mutations, service-only RPC and old
collector write guards. Real anonymous PostgREST requests to all five private
memory/history/log tables are denied (42501); local/public health and database
health are 200; memory GET/export/POST reject missing and invalid sessions (401).
No customer records were output or changed for QA. Backup remains on the same
server disk; off-host disaster recovery is not established by this deployment.

The earlier unsafe PUBLIC true memory grants are fixed in production. This does
not establish whole-product security or authenticated device acceptance. Build
1.0.8 (70), runtime 967ab48, was already uploaded successfully; no new binary or
Apple processing poll for this activation/documentation receipt. Web Memory
controls are now published after the normal production-configured webpack build
passed on the server with real fonts. Only the three reviewed Memory UI files
were overlaid; all other source, including the homepage, was preserved.
Source checks remain 772 Python, 302 web, 444 Flutter tests and clean static checks;
no regression-suite reruns after push/build. Live rollout checks are separate.
The web service runs web-account-memory-20261016. Candidate/public pages pass;
signed-out Settings emits the existing server sign-in redirect without protected
controls. Logged-in save/forget and cross-device acceptance remain pending.
See docs/plans/account-memory-implementation.md for evidence, rollback and gaps.

# October 16 assistant retrieval beta delivery

Active lane `feat/assistant-grounded-retrieval-20261016`, starting
HEAD `3e3e095`, implementation `1c44e5e`. The latest user instruction authorizes commit/push and a new
TestFlight build using completed checks, with no post-push/build reruns.
Adds bounded selected-inventory read capabilities, recorded-field answers,
conversation-bound follow-ups, linked document metadata/current notes/events,
guarded conditional literal edits and safe handoffs for unsafe chat writes.
An HTTP test exposed inventory scope loss before SSE consumption; the local fix
retains validated inventory/actor and effective owner across stream/deferred work.
No provider/model selection, FIND transport, schema, dependencies or client UI
change. 127 synthetic dataset cases; 727 full Python tests plus six subtests,
296 web tests, 434 Flutter tests, clean Flutter/TypeScript analysis, 29 connector
tests and the bundle check/test pass. Live providers, storage/RLS, two-client and
physical-device acceptance remain unverified. See
`docs/plans/assistant-grounded-retrieval.md` for mapping, evidence, changed files,
security gates and ordered next steps. Apple acknowledged signed TestFlight 1.0.8 (69), delivery
`dce3e75e-aaba-4994-b609-5953086d88b6`. Production archive/export succeeded;
no post-push/build checks or processing wait per user instruction. Artifacts and
receipts: `Documents/FindEZ/AppStore/1.0.8-build69`. PR #88. Processing and tester
availability are unverified. No backend deployment or schema changes.

# October 16 mobile place flow follow-up

Build 67 retained old organization, workspace management and Search routes. The
build 68 source updates organization/workspace/settings styling, returns to the
workspace home on organization workspace selection and limits Search to the
selected workspace's inventories. A production-connected iPhone 16e simulator
confirmed the new organization and Search screens, workspace selection, real
Tasks/Files responses, and Space Create/Cancel without blank navigation. No
customer data was written for QA. 434 Flutter tests pass with coverage; 29
focused organization/home/hierarchy tests pass after the final accessibility
change; static analysis is clean. All five exact-runtime CI jobs pass on
`1345ba7` (run `38981201657`), including 434 Flutter, 565 backend and 296 web
tests. The signed 1.0.8 (68) IPA passed Apple validation and Apple acknowledged
upload `72770f34-21ab-4514-bcc8-7b22ac97b299`. Strict package checks verified
the production entry/configuration, both signatures, fonts and 31 iOS-device
executables. IPA SHA-256:
`a63e0a051220bf305a3813f8e45a87242478cc3a2b029c9c63cffed506471e4d`.
Receipts, IPA and archive are in `Documents/FindEZ/AppStore/1.0.8-build68`.
Apple processing and tester availability are pending; no wait per Tanya's request.
No public App Store submission or backend/web/schema change.

# October 16 mobile place home delivered to TestFlight

PR #87 on `feat/mobile-place-switcher-20261016`, runtime `9b66023`. Apple
acknowledged FindEZ 1.0.8 (67), delivery
`8b0f89b7-a938-47fd-804a-c525d6bb7964`. Apple validation passes. All five exact-runtime
CI jobs pass: 430 mobile, 565 backend and 296 web tests, PostgreSQL permissions and
AI connectors. Local full Flutter coverage and static analysis pass. Strict app
and Share Extension signatures, production origins, bundled fonts, fixture
exclusion and all 31 device-platform native executables pass. The first cached
simulator-library package was rejected locally and never uploaded; clean rebuild
passed. Receipts, archive, IPA, checksums and verifier are preserved in
`Documents/FindEZ/AppStore/1.0.8-build67`. IPA SHA-256:
`633886e4d737f8b25fe55b8364f88c4e74e48beba7e413b3e9037ea959645ffb`.
Processing/group availability is pending; no processing wait per Tanya's request.
No public App Store selection/submission, web/backend/schema publication or
customer QA writes. Physical acceptance remains separate.

Workspace home and grouped place switcher replace the root Your world drilldown.
Account preferences restore authorized Personal/workspace context before home;
API inventory sessions remain independent. People contains Leave. The reported
blank space-creation screen is reproduced and fixed at the nested-dialog navigator.
Four iPhone 16e fake-data screenshots and two reference pairs are in
`design/workspace-switcher/out/`; native preference restore survived relaunch.
The isolated simulator visual entry intentionally does not serve real Tasks,
Files or inventory content; it must not be mistaken for functional acceptance.
See `design/workspace-switcher/IMPLEMENTATION.md` for files, limitations and tests.

# Current state

## October 16 mobile hierarchy beta uploaded

Apple accepted TestFlight upload 1.0.8 (66), runtime
`8dc9fdd4ad505e0e60f926e1510d1ae4573e143f`, PR #85. Validation and upload
both report no errors. All five exact-runtime CI gates pass (`38873503994`).
Signed app and ShareExtension are 1.0.8 (66); all 31 native executables target iOS
devices, signatures/profiles, production origins/anon key and supplied brand
assets are verified. Durable IPA, archive, checksums and receipts are in
`Documents/FindEZ/AppStore/1.0.8-build66`. IPA SHA-256:
`cf4a48231f5e83e46a7aa1931a07b0abb4680eb5abed3c8b98542963635a2e62`.

Tanya requests TestFlight uploads after completed mobile changes and explicitly
does not want to wait once Apple acknowledges upload. Processing, internal group
assignment and installability have not been verified for 66; the saved
`testflight-delivery.rb status`/`assign` helper can check/assign later. Physical
camera, real email and two-client acceptance remain pending. No public App Store
selection/submission or backend/database deployment. Approved updater-cache
cleanup freed about 3 GB and the native build completed; the earlier disk-space
build blocker below is resolved.

## October 16 mobile hierarchy source implementation

Branch `feat/mobile-inventory-context-20261016` adds the existing web hierarchy to
Flutter without changing backend, database, website, dependencies or native
configuration. Your world -> Personal or organization -> workspace -> inventory
replaces the old Teams shell entry. Existing Team records remain workspaces.
Inventory-scoped Home/Capture/Ask/Find, documents, item/Space edits, imports,
membership/recipient consent, restricted-directory access requests, permitted
rename/delete/leave and shared physical locations use current authenticated APIs.
Account-bound immutable clients, Navigator disposal, partitioned caches and late
response guards keep selections separate. Stored selection IDs are reauthorized;
transient permission-refresh failures preserve drafts with Retry, while confirmed
denial retires the inventory views. Import destination retries do not change the
normal remembered inventory.

409 Flutter tests pass (1m46s) and `flutter analyze --no-pub` reports no issues.
75 targeted backend route/service tests and 59 web compatibility tests pass;
their external I/O is stubbed. All five CI gates pass on implementation `a49f03d`
(run `38872280350`), tracked in draft PR #85. The full parity/file matrix is recorded in
`docs/plans/mobile-hierarchy-parity.md`. The later beta upload is recorded above.
Device camera/universal links,
actual invitation delivery and signed-in web/mobile round trips remain acceptance
gates using disposable accounts. Do not claim production security or physical
acceptance from adapter/widget tests or a successful TestFlight upload.

## October 15 organization actions published

PR #84 runtime `a21ea8d05c77d7328340000271a106d2d8d5a85e` is live on backend
and website with additive migration 047. Organization owners have a compact
three-dot menu with Rename and Delete on directory cards and selected
Workspaces/People pages. Deletion requires the exact current name, current owner
membership and no attached workspaces, including unassigned workspaces. The
service-only database function serializes concurrent workspace creation and
records a durable audit before removing the empty organization, its memberships
and invitations. It never cascades through workspaces or inventories. Personal,
workspace/inventory Rename and the approved homepage remain unchanged.

565 backend tests plus six subtests, 296 web tests, TypeScript, lint (zero errors;
existing warnings remain), production build and all five CI gates
(`38856358205`) pass. Isolated PostgreSQL fixtures check owner permissions, stale
names, blocked nonempty deletion, membership/invitation cleanup and audit/replay.
Three concurrency cases verify both workspace-creation race orders and duplicate
deletes. The live migration transaction preserves all existing public-table rows,
policies, table permissions and existing routine definitions/ACLs. No customer
records were renamed or deleted for QA. Real-component desktop/390px light/dark
checks pass. Signed-in live Safari verifies directory and selected-context menus,
prefilled Rename and disabled-until-confirmed Delete dialogs, using Cancel only.

Build `3hd1z4zQK8kaRdhzoIf3X` runs from
`/home/ubuntu/findez-web-releases/web-org-actions-20261015/frontend`.
Twelve public routes, 23 protected routes, 12 API authentication guards, 57 assets
and backend/database health pass. Original environment and 1,993 previous static
assets are preserved. Private preview and isolated QA database are stopped after
verification. Release receipts and runtime rollback backups are in
`/home/ubuntu/findez-org-actions-20261015/`; non-sensitive copies are in
`Documents/FindEZ/Releases/organization-actions-2026-10-15/`. Roll back the web to
`web-landing-lab-fade-20261015/frontend` and restore the prior collaboration.py
from runtime-backup if needed; keep additive migration 047. No main-branch merge,
mobile update or dependency change is implied by this selective release.

## October 15 approved Lab homepage published

PR #83 runtime `4caa38c32db198555436dd449d521b12eb6cfd43` publishes the
approved Lab design at `/`. Developers, iOS App and session-aware Get
started/Dashboard are the only header actions. Plans, Developers, iOS App,
Privacy, Terms and Contact remain at the very bottom with the copyright.
The main header moves at half page scroll speed while smoothly fading out. At
66px of page scroll it has moved 33px upward and is fully transparent/inert;
returning to the top restores visibility and keyboard access. Reduced motion
uses normal scrolling without the fade. The top announcement banner is removed. `/lab` preserves the original prototype layout and noindex.
The supplied waitlist remains explicitly confirmation-only, without persistence
or an API request. No backend, mobile, database or dependency changes.

288 web tests, TypeScript, changed-file lint and production webpack build pass.
Desktop/390px browser checks verify all retained links, no horizontal overflow or
console errors, scrolling header, absent announcement, waitlist and reduced
motion. Prior publication passed all five CI jobs (`38852281637`);
the fade follow-up is tracked on PR #83. Live verification passes 12 public
routes, 17 protected routes, 23 homepage assets and backend health. Chrome
confirms the published homepage and navigation. Original production source,
environment and prior static chunks are preserved.

The prior homepage-only build `nGSlTwykEqoUG8MlgI06u` is retained at
`/home/ubuntu/findez-web-releases/web-landing-lab-fade-20261015/frontend`.
Receipts and rollback configuration are in
`/home/ubuntu/findez-landing-lab-fade-20261015/`. Immediate rollback target:
`web-landing-lab-scroll-20261015/frontend`, build `JmfJ7pLKgby6LCYTjV_e3`.
The pre-Lab homepage is retained at `web-workspace-hub-20261015/frontend`, build
`hcDimgZUPWFa_3Kt4HoD6`. No merge into main is implied by this selective release.

## October 15 workspace hub and directory published

PR #81 runtime `5a2bc5540cc87f9cb43b5e60bd7b7f6be0fa204b` is live with
migration 046. Team workspaces open an Overview with the directory, assigned open
tasks, permission-filtered inventory activity and current administrator access
requests. Workspace navigation distinguishes Overview, Inventories, People,
Locations, Tasks, Files, Activity and Settings. Personal remains a direct chooser.
Inventory navigation shows Dashboard, Capture, Ask, Items, Locations, Documents,
existing utilities, Activity and Inventory settings within the selected scope.

Directory visibility is separate from inventory access. Current members discover
names and approved descriptions by default; counts require content access. Managers
can hide inventories from members without access. Restricted visible entries lead
to viewer-access requests, with explicit administrator approval, cancellation,
seven-day expiry, membership/authority checks, audited decisions and replay
protection. A request grants nothing. Existing recipient invitation consent and
content authorization remain. Workspace physical hierarchy administration remains
owner/admin-only; ordinary members use permitted inventory locations.

550 backend tests plus six subtests, 276 web tests, TypeScript, changed-file lint,
production build and all five CI gates (`38845755335`) pass. Isolated SQL and
simultaneous approve/approve, approve/cancel, approve/decline tests pass. Restored
copy rehearsal and live migration transaction preserve all original public-table
values and policies, creating no requests or grants. Desktop/390px light/dark
actual-component previews pass. Live signed-in Safari confirms Overview →
Inventories → scoped dashboard/navigation and existing count. A further settings
UI inspection was interrupted by CUA `failedToCreateImageDestination`; settings
behavior is covered by component/API tests. No customer records, memberships,
visibility settings or requests were changed for QA.

Web build `hcDimgZUPWFa_3Kt4HoD6` runs from
`/home/ubuntu/findez-web-releases/web-workspace-hub-20261015/frontend`.
Twelve public routes, 29 protected web routes, 17 API authentication guards and
four CSS assets pass; API/database health are good. Receipts and runtime rollback
backups are in `/home/ubuntu/findez-workspace-hub-20261015/`; non-sensitive receipts
are mirrored at `Documents/FindEZ/Releases/workspace-hub-2026-10-15/`. Rollback web
target is `web-creator-rename-20261015/frontend`; retain additive migration 046 if
rolling back runtime. Temporary VM preview and isolated restored-copy database
have been removed. No native app change or upload in this lane.

Remaining planned work: discussions/threads/mentions, richer task-resource links,
workspace AI, calendar/check scheduling, group permissions and enterprise features.
Access-request decisions are currently managed in Overview/People, without new
email/push notifications; the separate member invitation email/code/inbox remains.

## October 15 creator rename published

PR #80 runtime `905923aabaed03d402f73646236a7323b3485151` is live on backend
and website. Organization/workspace owners have Rename on choice cards and
selected-context pages; inventory creators can rename while retaining current
access, alongside existing inventory manager rights. Backend checks ownership
and current access before name-only writes. Stable IDs, scope, memberships and
contents are preserved; Personal remains a fixed context. No migration or mobile
change.

537 backend tests plus six subtests, 268 web tests, TypeScript, changed-file lint,
production webpack build and all five CI gates (`38841525417`) pass. Safari
actual-component desktop/390px light/dark checks pass. Signed-in live Safari
opens/cancels all three Rename dialogs with prefilled current names; no customer
records changed. Twelve public routes, 27 protected web routes, 14 API auth guards
and four CSS assets pass; backend/database health are good. Web build
`zWHbnBwBtqr3dslkvsMpa` runs from
`/home/ubuntu/findez-web-releases/web-creator-rename-20261015/frontend`.
Receipts: `Documents/FindEZ/Releases/creator-rename-2026-10-15/` and
`/home/ubuntu/findez-creator-rename-20261015/`. Backend runtime backups and previous
web drop-in are retained there; temporary release preview is stopped.

## October 15 recipient consent published

PR #79 runtime `8592a4d556352155cee7c619dd6c592a7cc6c7c9` replaces immediate new organization and
workspace membership, and newly granted inventory access, with recipient-bound
pending invitations. Email links, 12-character codes and Notifications open an
explicit Accept/Decline review. Sender cancellation, seven-day expiry, verified
email matching and acceptance-time authority/parent checks are enforced in new
migration 045. Existing memberships/role edits remain. The old immediate-grant RPC
is private and its replacement rejects new membership without consent. Existing
Space/Team code joins still require their established explicit Join action.

528 backend tests, 262 web tests, TypeScript and changed-file lint (zero errors,
one existing warning) pass. Disposable PostgreSQL verifies consent, wrong and
unverified recipients, signup after invitation, email changes, cancellation,
expiry, decline, replay after revocation, sender revocation and changed parents.
Concurrent acceptance/decline/cancellation produces one consistent decision and
at most one membership/audit. All five CI gates (`38837898405`), production build,
restored-copy migration rehearsal and live migration 045 pass. Original public
rows/policies and all existing memberships are preserved. Web build
`zS9LXpYxW5C_txX1tIPK5` runs from
`/home/ubuntu/findez-web-releases/web-invitation-consent-20261015/frontend`.
12 public routes, 27 protected web routes, 11 API auth guards and four CSS assets
pass. Signed-in Safari verifies Invite/Cancel, Notifications and invalid-code
handling; desktop/390px actual-component light/dark review/delivery previews pass.
Production email configuration is verified; actual customer email delivery was
not used as a probe. No customer invitations or membership changes were made for QA.

Receipts: `Documents/FindEZ/Releases/invitation-consent-2026-10-15/` and
`/home/ubuntu/findez-invitation-consent-20261015/`. That remote directory retains
`runtime-backup` and `previous-web-rebuild.conf`. Runtime rollback must retain the
consent schema/guard; the old runtime then cannot add new members immediately.
An initial runtime rollback caused by the legacy Teams redirect check was resolved;
the corrected publication passed without reapplying migration 045. Mobile source
and binary are unchanged; new organization/access invitations use web review links.

## October 15 contextual navigation published

`fix/web-context-navigation-20261015` separates context selection from management.
Organizations expose Workspaces/People; selected workspaces expose inventories,
people, locations, board, documents and activity. Inventory navigation contains
inventory workflows; account navigation no longer offers unscoped inventory tools.
Selection uses quiet cards and creation dialogs, and inventory-name breadcrumbs
open the selected dashboard. Existing team board/files are reused as scoped panels.
Inventory access settings are separated into People, Permissions, Locations and
History. Original backend authorization and APIs are unchanged.

PR #78 website runtime `5d9906f71e3dcc1eb0aadb98890876a33b1c0c15` is live.
Build `Xcfmg3hf5pyC4pQjI61SC` runs from
`/home/ubuntu/findez-web-releases/web-context-navigation-20261015/frontend`.
253 web tests, TypeScript, changed-file lint, production webpack build and all
five CI gates (`38832789463`) pass. Desktop and 390px actual-component Safari
previews verify both themes and creation dialogs. Signed-in live Safari verifies
organization/workspace choice, separate People/Locations/Board/Documents/Activity,
the existing 60-item inventory, inventory access tabs, contextual command menu,
inventory-name breadcrumb, browser Back and refresh. No customer records or
permissions were changed during verification.

11 public routes, 27 authentication guards and three CSS assets pass. Production
configuration and 1,431 prior static assets are preserved; backend/database/mobile
are unchanged. Receipts: `Documents/FindEZ/Releases/context-navigation-2026-10-15/`
and `/home/ubuntu/findez-context-navigation-20261015/`. Web rollback uses that
remote directory's `previous-web-rebuild.conf`. Existing-account membership tools
remain; automatic invitation emails and organization billing are still unfinished.

## October 15 organization and inventory access published

PR #77 runtime `5462d87010f4bc62baf57c5adc21bd8fc8574e15` and migration 044
are live on backend and web. Website build `9OGfGZwNlW6RtjMWJf1ee` runs from
`/home/ubuntu/findez-web-releases/web-organization-access-20261015/frontend`.
Entry: `/organizations`; Personal and independent existing workspaces remain
available. Organizations contain assigned project workspaces; inventories have
explicit inherited/restricted access, member overrides, shared physical-location
attachments and scoped audit history. Existing workspace roles remain `legacy`
until an administrator explicitly saves a new access policy. No demo rows or
inferred organization associations were added to production.

Validation: 516 backend tests plus six subtests, 243 web tests, TypeScript,
changed-file ESLint, production webpack build and all five CI jobs
(`38828116889`) pass. PostgreSQL fixtures cover Acme's 12/6-member client project,
25-member FTC robotics, differing inventory roles, direct DB/legacy-route denial,
revocation, shared locations and recorded-location audit evidence. Restored-copy
rehearsal and locked production migration compare all original public-table values
and policies; all preserved. Live checks: 11 public pages, 20 protected routes,
seven API authentication guards and read-only queries across 25 existing inventories.
Signed-in Safari verified Organizations → existing FTC workspace → its 60-item
inventory → Access and history. Actual-component light/dark 390px previews pass.

Receipts/backups: `/home/ubuntu/findez-organization-access-20261015/` and local
`Documents/FindEZ/Releases/organization-access-2026-10-15/`. Runtime rollback uses
`runtime-backup`; web rollback uses `previous-web-rebuild.conf`. Additive schema
can remain during a runtime rollback because original access is preserved.
Existing-account member assignment works; invitation email delivery, organization
billing and physical-tree reparenting are not part of this release. Mobile keeps
its existing navigation, with server-side restrictions also protecting old routes.

## October 15 centered Ask page published

PR #76 website runtime `80ba01b557dc38e5f24dc8d0472c39be2c56bb28` is live.
Ask uses a centered empty state and composer with a faint static sage/lavender
gradient in both themes. History opens in a bounded dialog; user prompts sit in
right-aligned neutral bubbles, and FindEZ replies remain on the left. Existing
photo, streaming, draft, source and inventory behavior is preserved.

All 238 web tests, TypeScript and all five CI jobs pass (38822672148). Changed-file
lint has zero errors and three existing warnings. Actual-component Safari
previews verify desktop centering, 390px light/dark prompt bubbles and 390x500
history dialogs. Live public/authentication checks pass; a signed-in visual
recheck was unavailable because the existing Safari session had expired.

Build `yM8utqb1HXdG80bVkcZYW` runs from
`/home/ubuntu/findez-web-releases/web-ask-centered-20261015-r2/frontend`.
11 public routes, 20 authentication guards and three CSS assets pass, preserving
production configuration and 1,304 prior immutable assets. Backend/database are
unchanged. Receipts: `Documents/FindEZ/Releases/ask-centered-2026-10-15/final`.
Rollback: `/home/ubuntu/findez-ask-centered-20261015-r2/previous-web-rebuild.conf`.

## October 15 workspace hierarchy published

PR #75 is live: Workspace (Personal or Team), then Inventory, then dashboard.
Physical Spaces belong to inventories. Home, capture/import, Find, Assist/history,
documents, Review, activity, lending, kits and purchase plans retain inventory
context. Account settings and billing remain global. Existing mobile/API routes
remain compatible; the new chooser is website-only.

Website runtime `eb67ce1120128a14ffcd369458cd268187dd62d0`, build
`PTR7zEZHl_uHR-Ay09uw3`, runs from
`/home/ubuntu/findez-web-releases/web-workspace-inventories-20261015-r2/frontend`.
Backend runtime `eb3eee0c0232c7433b25f05541737cc766b134cb` and migration 043
are live. All original values across 21 tables were preserved inside the locked
migration transaction. Historical records with removed account owners keep their
owner IDs; the NOT VALID owner foreign key enforces new writes without rewriting
those records. Documents remain private. No customer records were created for QA.

511 backend/API-doc tests, 237 web tests, TypeScript, PostgreSQL isolation and
record-preservation checks pass. All five CI jobs pass for final runtime in run
38702261152. Desktop/narrow and light/dark previews pass. Signed-in live Safari
verifies Personal and Team dashboards, refresh, scoped capture destinations,
private documents, separate Assist history, selected-Team administration and the
corrected Space toolbar. 11 public routes, 20 protected routes and three CSS
assets pass; 1,241 prior assets and production configuration are retained.

Receipts: `Documents/FindEZ/Releases/workspace-inventories-2026-10-15`.
Remote base record: `/home/ubuntu/findez-workspace-inventories-20261015`;
backend backup: `backend-backup-r2` beneath that record. Final web rollback:
`/home/ubuntu/findez-workspace-inventories-20261015-r2/previous-web-rebuild.conf`.
Runtime rollback retains the additive database schema. Payments remain disabled.

## October 14 original imported fields published

PR #74 runtime `bd1c8a1` preserves ordered original Excel/CSV/JSON source fields
and maps each sheet independently, preventing distinct source rows from merging.
Web and mobile source show Imported details with exact named headers, duplicate
and unnamed positions, nested JSON and empty/zero/false values. Read-only
verification retains all source values in 295 rows across the supplied workbook.
459 backend/API-doc tests, 225 web tests, TypeScript, changed-file lint and Flutter
analysis pass; all five exact-source CI jobs pass (38686833571), including full
mobile tests and PostgreSQL migration checks. Local mobile tests initially ran
out of disk; generated-cache cleanup was completed and a rerun was interrupted.
Migration 042 and three hash-guarded backend files are live, preserving existing
items and unrelated source. The isolated website build `dY0WQXameBIfVROypzxBZ`
at `web-import-columns-20261014/frontend` passes 11 public routes, 17 auth guards
and three CSS checks, preserving configuration and 1,122 prior assets. Receipts
and rollback are in `Documents/FindEZ/Releases/import-columns-2026-10-14` and
`/home/ubuntu/findez-import-columns-20261014`. Existing items were not reimported;
previously discarded fields cannot be recovered automatically. Mobile support is
committed and CI-verified but is not in the existing TestFlight build 65.

## October 14 Settings and navigation correction published

PR #73 runtime `7b44165` is live. Settings Plans/legal links use full-width text
rows, Developer icons stay with labels, and Appearance stays compact. The top
page-navigation dialog resets the independent utility translate, fits short
viewports, keeps its input visible above scrolling results, removes repetitive
section captions and returns keyboard focus on close. 224 web tests, TypeScript,
changed-file lint, production build and all five CI jobs pass (38685597933).
Safari verifies both themes and desktop/390px layouts. Live build
`D-x-qQyJQDdszMNcrtfXh` at `web-settings-navigation-20261014/frontend` passes
11 public routes, 17 auth guards and three CSS asset checks, retaining 1,064 old
assets and production configuration. Backend is unchanged. Receipts and rollback
are in `Documents/FindEZ/Releases/settings-navigation-2026-10-14` and
`/home/ubuntu/findez-settings-navigation-20261014`.

## October 14 website clarity published

PR #72, runtime `65226c5a49557a62298b8b9eb499c72a4b8d32f0`, is live on
the existing self-hosted website. The user selected open layouts with quiet
dividers: remove the repeated toolbar title, first FindEZ navigation caption,
duplicate Collections/Space headings, repeated Team tab headings and extra
Project kits Space prompts. Recent items and Spaces use open rows; filters and
secondary actions are lighter, inputs have consistent spacing, Labels tabs are
separated and Review photos no longer fill the page. Contracted/expanded sidebar
states work, with the user's original pinned preference restored after checking.

223 web tests, TypeScript and the production webpack build with actual production
configuration pass. Existing lint warnings remain; all five exact-runtime CI
jobs pass in run `38683070099`. Actual-component fixtures cover light/dark and
narrow layouts; signed-in Safari checks cover the screenshot routes and loaded
inventory. Public release checks cover 11 public routes, 17 protected route
guards and three workspace CSS files. Build ID is `bSG_l1U3Nn-HPx_vC7FHX` at
`/home/ubuntu/findez-web-releases/web-clarity-20261014-r3/frontend`.

The service switch preserves its production environment, unrelated dirty checkout
and 1,006 previous immutable assets. Rollback drop-in is
`/home/ubuntu/findez-web-clarity-20261014-r3/previous-web-rebuild.conf`; the first
release record also retains the original October 12 rollback. Receipts and hashes
are in `Documents/FindEZ/Releases/web-clarity-2026-10-14`, with final delivery in
`published`. Backend process/start time are unchanged; no database changes or
customer inventory writes were made. Pending web branding, pricing and capture
client preparation are included. Pricing remains planned, paid purchasing is
disabled, Shopify remains disabled and newer backend capture receipt/identity
semantics remain a separate deployment. Mobile/TestFlight state below is unchanged.

## October 14 guided tour limited to first installation

Lane `fix/first-install-tour` adds an installation-scoped, durable claim before
any automatic tour display. Existing authenticated/legacy installations migrate
to consumed state. Interrupted starts, backgrounding, sign-in flags and account
changes cannot restart it; opening personal/shared Spaces no longer launches a
second tour. Selected navigation destinations retain spotlight keys so the first
step correctly highlights Home. Setup answers and first-Space creation remain
independent. All 375 mobile tests with coverage pass and Flutter analysis is clean.
TestFlight 1.0.8 (65), runtime `8fbfacd84b1773f9332f55df6be1cc1049c550fb`, is
uploaded, VALID and IN_BETA_TESTING for both existing internal groups. All five
exact-runtime CI jobs pass. The signed app/ShareExtension versions match, all 31
native executables target iOS, production configuration/brand assets are verified,
and Apple validation passes. Simulator upgrade, Space entry and cold restart stay
quiet with the existing session/data retained. IPA, archive, checksums and receipts
are in `Documents/FindEZ/AppStore/1.0.8-build65`.

Vinod's existing private group contains build 65 and only the intended tester, but
external review submission returns Apple's 422
`ENTITY_UNPROCESSABLE.ANOTHER_BUILD_IN_REVIEW`: build 64 is WAITING_FOR_REVIEW.
Build 65 remains READY_FOR_BETA_SUBMISSION, so Vinod cannot install it yet. Retry
the saved private beta helper's `prepare`, then `status`, after build 64's review
finishes. Do not claim 65 is awaiting its own review or already available externally.
Public 1.0.7/build 59 and unselected draft 1.0.8 are verified unchanged. Shopify
stays disabled, no production backend/web deployment occurred, and physical phone
acceptance remains pending.

## October 14 launch reliability candidate and planned pricing UI

Lane `fix/launch-find-reliability` preserves individual captured objects instead
of aggregating names. Owner-bound retry identities, database read-back receipts
and indexed outcomes prevent duplicate retry quantities and silent batch loss.
Both clients keep unconfirmed drafts. Web capture/review requests bind to the
initiating token and ignore late results across accounts. Mobile stops disposed
multi-step saves. Photo ASK exposes identifier/name evidence, unknown quantities
stay unknown and result locations are labelled recorded, without fabricated
physical confirmations. The user defers image-similarity work because FIND source
is unavailable; the live API inspection exposes no such endpoint.

The public `/pricing` page and mobile Settings -> Plans now compare the requested
five tiers with monthly/yearly prices. They are explicitly planned, with paid
controls unavailable and current entitlements unchanged. No live payment link is
invented. Stripe subscription checkout, StoreKit purchase/restore/verification,
new tier enforcement and commercial configuration remain unfinished. Legacy
robotics pricing UI is replaced; its backend is not reactivated or repurposed.

Validation: 455 backend/API-doc tests and six subtests, 223 web tests, TypeScript,
changed-file lint (three existing Assist warnings), clean Flutter analysis and
362 mobile tests with coverage pass. The fictional-config production web build
passes with webpack caching temporarily disabled for disk space; source config
is restored. Safari renders the pricing comparison locally. The arm64 native
simulator app is rebuilt/installed and Plans is checked in Light/Dark, including
annual pricing and navigation back. Light is restored with Plans open. No
customer inventory or answers were written. No migration, production deployment, new TestFlight
binary or public submission. See
`HANDOFFS/2026-10-14-launch-readiness.md` for verified capabilities and release gates.

## October 14 app-wide neutral controls, orange bottom navigation

The user expands this lane to all mobile UI accents and confirms orange should
remain only in bottom navigation. Shared action/selection roles are neutral;
navigation has separate orange tokens. GlassFab uses a grey frosted surface
with a readable icon and quieter shadow. Primary/filled/elevated controls,
category/appearance pills, chat controls, onboarding/tour accents, Teams icons
and invite surfaces inherit neutral styles. Decorative owner badges are also
neutral. Supplied brand artwork, accepted Home counts and semantic statuses
remain. Native iPhone 16e checks cover Find, Space filters/Add menu, Teams,
chat and onboarding, with Space/Teams/onboarding checked in both themes.
The final arm64 debug build is installed; Light mode is restored and Find is
open for review. No inventory/answer saves or chat submissions were made.
Flutter analysis is clean and all 357 mobile tests with coverage pass. A final
parallel run stalled during tooling cleanup; a clean serial rerun passes in full.
Proof is in `Documents/FindEZ/Design/mobile-colors-2026-10-14` using the
`*-neutral-controls-*-native.png` filenames. No new TestFlight upload or public
submission; TestFlight remains build 64.

## October 14 neutral Capture and Find selectors installed in simulator

The user confirms the two requested controls are Scan Barcode/Auto Extract and
Spaces/Teams. Both now use neutral grey glass with primary-text labels/icons;
navigation palette and motion are retained. Existing FrostedSurface handles blur
and the solid high-contrast fallback. Analysis and all 357 mobile tests with
coverage pass. A full arm64 iOS Simulator build is installed and launched on
iPhone 16e (iOS 26.2), replacing the older installed preview. Capture, both Find
selection states and the accepted Home numbers/hints are visually verified.
Proof is in `Documents/FindEZ/Design/mobile-colors-2026-10-14`. This is a local
debug app, not another TestFlight delivery; TestFlight remains build 64.
The user finds Capture's first grey pill too heavy. A Capture-only refinement
lightens its tint and outline and keeps both labels at regular weight. Analysis
and all 357 tests pass again. The rebuilt app is installed and Capture is
visually checked in both themes, then returned to Light mode for review.
Proof: `capture-soft-grey-glass-native.png` and
`capture-soft-grey-glass-dark-native.png` in the same design folder.
Initial native builds hit disk exhaustion. Generated compiler cache and the
temporary build-64 verification extraction were cleared after the durable
release IPA/archive hashes were reverified. Release artifacts and app data are
preserved. Wait for further page instructions; no broad palette pass.

## October 14 Home-only number colours and smaller placeholder

`feat/mobile-color-accents` in `dev/findez-mobile-color-accents` is based on
`3a36026`. The user rejects coloured card fills and scopes this pass to Home.
Only decision numbers use mustard (identifying), purple (to buy), maroon
(out of stock) and forest green (lent), including zero; unknown values remain
neutral dashes. Cards and labels retain the neutral baseline. The white search
field has a 14pt regular grey hint and 17pt entered text; suggestions use 12pt
regular grey text. Other-page experiments are removed from the candidate.
Analysis and all 357 existing mobile tests with coverage pass. All four number
colours and the hint meet 4.5:1 contrast in both themes. The running iPhone 16e
debug simulator is refreshed through Flutter attach/hot restart, and Home is
visually verified with native fonts/icons. Native proof is in
`Documents/FindEZ/Design/mobile-colors-2026-10-14/home-numbers-light-native.png`.
No new binary is uploaded: TestFlight remains 64. Wait for the user's next-page
instructions; no broader palette or layout pass is authorized.

## October 14 backend fixes live; mobile 64 delivered to internal TestFlight

`fix/capture-review-save-boundary` in
`/Users/tanyasmritivictorcharles/dev/findez-capture-save-boundary` is based on
punctuation record `722b5c0`. New mobile/web Capture requests use `preview_only`;
the backend returns signed, account-bound previews without creating Review
rows. Explicit Save persists uncertainty with its original photo/evidence and
retry-safe identity. Chat photo analysis no longer writes Review at all.
All 438 backend/API documentation tests and six subtests, 212 web tests,
TypeScript, changed-file lint (existing warnings only), 357 mobile tests and
Flutter analysis and the placeholder-config production web build pass. Runtime
`19089e9` in Draft PR #68 passes all five CI gates (`38551614029`). Before
deployment, eight existing backend hashes matched the baseline and both new
helpers were absent. The exact combined ten-file backend bundle, patches and
manifest are in `Documents/FindEZ/Releases/capture-save-boundary-2026-10-14`.
The user authorizes deployment. The ten backend files are selectively deployed
with guarded hashes and backups at
`/home/ubuntu/findez-capture-fixes-20261014.1ztxtg/backup`; unrelated checkout
files are hash-verified unchanged. Service/database health pass, and missing
session/invalid integration-key requests return 401. Read-only production checks
verify reply punctuation, real preview signing, owner binding and the signed
save route without database writes or FIND/model calls. Deployment/live receipts
are beside the source bundle. No migration or historical Review deletion was
performed. New chat/photo behavior is live; updated web source is not deployed
and older Capture clients keep the old contract.

Mobile 1.0.8 (64), runtime `8001b13`, is VALID, APP_STORE_ELIGIBLE and
IN_BETA_TESTING in both existing internal groups, Testers and Internal Pilot
Findez AI, verified at 04:54 PDT October 14. All five exact-runtime CI gates
pass (`38554740296`), along with clean signed archive/export, production
configuration, supplied assets, strict app/extension signatures and all 31
native device-platform checks. Apple validation/upload and processing complete
without errors or warnings, delivery `3dc129af-4c32-48f7-a69d-d55c9e97cdef`.
Receipts, archive/IPA and the phone checklist are in
`Documents/FindEZ/AppStore/1.0.8-build64`. IPA SHA-256:
`a14d1d143abb399f37871fe8fbb16b712d3147d643572bbf0f4d0ac5bd28e393`.
Build 64 enables preview-only extraction and explicit Save with the deployed
backend. No build-64 simulator or physical-device acceptance is claimed;
repeat camera/library upload-cancel-Home, photo chat, explicit Save/retry and
account isolation on a phone. TestFlight 63 remains available with its legacy
Capture contract. Public 1.0.7 stays selected on 59; draft 1.0.8 remains
unselected with manual release. Public App Review and Shopify remain held.

The user subsequently requests build 64 for an existing external tester.
`Vinod Private Testing` contains only that tester, has no public link, and has
build 64 assigned. At 05:08 PDT October 14, beta submission is
WAITING_FOR_REVIEW/WAITING_FOR_BETA_REVIEW, with automatic notification enabled.
Apple rejects a repeat invitation as ALREADY_ACCEPTED; no new invitation was
sent and external build-64 availability is not yet claimed. Existing internal
access continues, the broader External Pilot group has not received 64, and
public App Store selection/release type remain unchanged. Targeted receipts
and the delivery helper are in the build-64 release folder.

## October 14 chat punctuation candidate

Backend-only `fix/ask-response-punctuation` is based on mobile release record
`1604e68`. A shared instruction and reply formatter remove em dash punctuation
from new text, photo, project and document chat replies before emission and
persistence, including legacy EEZY. User messages, tool data, inventory and
answer source/navigation snapshots are unchanged. Existing history is retained.
All 426 backend/API documentation tests and six subtests pass. Runtime `3b1c824`
in Draft PR #67 passes all five CI gates (`38548331842`). Preflight matched four
existing live hashes and confirmed the new helper absent. The exact
five-file bundle, patch and hash manifest are preserved in
`Documents/FindEZ/Releases/chat-punctuation-2026-10-14`. This change is live in
the combined backend deployment above; no migration or new binary is needed.
Shopify remains paused and public App Review remains held.

## October 14 build-63 internal TestFlight delivery

Build 1.0.8 (63) is VALID, APP_STORE_ELIGIBLE and IN_BETA_TESTING in both existing
internal groups, Testers and Internal Pilot Findez AI. Final runtime `8abe3cc`
on `feat/mobile-submission-polish` (PR #62) passes analysis, all 353 mobile tests
with coverage and all five CI gates in `38543470459`. Clean signed archive/export,
production configuration, supplied assets, strict app/extension signatures and
all 31 native device-platform checks pass. Apple validation/upload succeeds;
delivery `81fcc8ae-92f0-4d05-9dd0-e4a0a492e0c1` is COMPLETE without errors/warnings.
Group access and updated test notes are verified at 02:56 PDT October 14.

The beta includes Home Account access and four core tabs, stable regular/medium
weights independent of OS Bold Text, focused chat, concise import, plain setup X,
compact tour, spring navigation, supplied branding and Light default. Neutral
Appearance, inventory/scan choices and scan/QR/import/sharing/save actions use
`GlassControl`, preserving callbacks, busy/disabled states and high contrast.
The native preview caught RawChip's opaque canvas covering the glass outline;
a local transparent canvas fixes it. Light/Dark choices now render continuously.

Native build/install/launch, Home/Account routing, image-backed captures,
Light/Dark Appearance, plain-X setup and empty Ask are observed on iPhone 16e
(iOS 26.2). Automated text entry/paste could not submit a native chat prompt;
active chat/Back/stream acceptance still needs the final phone binary. Other
physical accessibility, camera/barcode, voice, provider auth, APNs, share handoff,
account isolation, full tour/import and store-artwork checks remain pending.
The simulator app is restored to Light; no inventory or setup-answer writes
were performed. No production deployment or schema change is part of this lane.

Durable archive/IPA, verifier, receipts, CI/tests, native screenshots and phone
checklist are in `Documents/FindEZ/AppStore/1.0.8-build63`. IPA SHA-256:
`d9fe4c008add1fd5f35e65fe5cc37bb58bca2596ec759cd8a1a1c62e2b8a6dea`.
The validated pre-glass candidate was never uploaded and is preserved in
`1.0.8-build63-before-glass`. Public 1.0.7 remains selected on 59; draft 1.0.8
is unselected with manual release. Public submission is held. Shopify stays
paused, preserved separately and excluded from this launch.

## October 14 launch excludes Shopify

The user pauses Shopify and keeps it for a later release. Preserve its separate
source lanes, draft PRs and development app/store. This mobile release lane
contains no Shopify client feature or backend configuration. Do not bring its
connector, linked physical-memory UI, owner edits, merchant guide or migrations
042 through 045 into the current launch. Resume Shopify only on a new user request.

## October 14 Home account control and lighter typography in source

Latest continuation moves Profile out of the pill, leaving four core destinations:
Home, Capture, Ask and Find. A small Home header control opens Account and its
existing utilities, with a Back route to the retained Home. Avatar edits and
live unread counts use the same owner-bound store/notifier; late count responses
cannot undo an inbox read. Four-tab indicator geometry preserves the existing
spring, stretch, fixed icons and reduced-motion behavior. Chat focus stays intact.

Shared typography now keeps body and inputs at 400 and caps emphasis at 500,
independent of OS Bold Text. Theme controls, AppText, editable fields and answer
styles use that policy. The old per-screen bold overrides and stored OS-weight
preference are removed. Larger Text, app text size, semantics and other
accessibility settings remain. The changed typography regression fails before
the fix; local full suite passes all 349 tests with coverage and analysis is
clean. Actual-widget Home renders are byte-identical with Bold Text on/off in
Light/Dark; Account and four-tab layouts are also checked. These changes are delivered in internal build 63. Physical acceptance remains
pending. No production or public submission change; Shopify stays excluded.

## October 14 focused chat and concise spreadsheet import in source

Latest mobile-only continuation on `feat/mobile-submission-polish` adds a minimal
spreadsheet ready view and conversation focus within the existing shell. A sent
message hides the pill; pinned Back restores the previous tab without replacing
ChatPage or losing its draft, conversation ID or streamed reply. Re-entering Ask
resumes that conversation, and New chat restores tabs and the empty prompt.
Import validation, processing, failures and actual result counts remain intact.
The original focus regression fails before the fix. Light/Dark, retained request/
draft, reset, previous-Find return, keyboard/large-text and pinned-scroll checks
are in `mobile/test/chat_focus_test.dart`. Local analysis and all 350 mobile tests
with coverage pass; the full local suite uses `--concurrency=1` after the parallel
run stalled and was stopped. Final build-63 source passes all five CI gates.
Actual-widget sample renders cover both themes, with narrow/large-text import
layouts, preserved in Documents/FindEZ/AppStore/mobile-polish-20261014.
These changes are delivered in build 63. Physical chat/import acceptance and
public review remain pending; Shopify stays paused and excluded.

## October 13 mobile pre-submission polish in source

Lane `feat/mobile-submission-polish` in `dev/findez-logo-light-default`, based on
delivered build-62 context `fdec959`, implements the user's latest mobile requests:
no questionnaire wordmark, an accessible plain small X, omission of pictureless/failed
Home thumbnails, compact frosted tour cards with a light scrim, and simple Ask
copy. One navigation pill slides and stretches up to 1.4 while the surface pulses
to 1.06 over 350 ms. Icons and touch targets stay fixed. Reduce Motion cross-fades
without scaling/stretch; high contrast uses solid surfaces.

The supplied October 13 logo ZIP replaces mobile wordmark/mark/icon assets byte
for byte, regenerates native icon sizes, and updates shared web branding. Light
is the default for missing/invalid appearance preferences; saved choices remain.
All 346 mobile tests with coverage and clean analysis pass. All 211 web tests,
TypeScript and production webpack build pass. Sample Light/Dark tour and navigation
renders pass. Exact source `7317590` passed all five CI gates in `38514764506`
(draft PR #62). The subsequent plain-X correction passes 26 onboarding tests.
The iPhone 16e iOS 26.2 native simulator build/install/launch passes; actual Light
questionnaire shows the small X with no background circle or wordmark. The initial
disk failure was recovered by user-approved removal of generated task caches.
These changes are included in internal build 63. Physical acceptance is pending;
no App Review submission or production deployment is performed.

Six iPhone and six iPad screenshots from the supplied ZIPs are COMPLETE in the
1.0.8 en-US draft, in supplied order with verified source MD5 checksums and image
dimensions. Durable assets, manifests and upload receipts are in
`Documents/FindEZ/AppStore/screenshots-20261013`. Version 1.0.8 remains
PREPARE_FOR_SUBMISSION, manual release, with no build selected. The optional
wide creative header is separate from these screenshots. Separate Shopify source
lanes remain disabled, unshipped and paused for a later release; the production
schema is unchanged.

## October 12 setup questions, guided tour and concise Auth delivered

- Runtime `346d9ae`, draft PR #59 stacked on #58, replaces promotional onboarding
  with four optional questions: use, inventory types, goal and collaboration.
  The final user reference is followed with centered FindEZ typography, full-width
  icon choices without radio circles, restrained glass and finite reduced-motion
  transitions. Auth has one heading, inventory copy and optional work-detail
  expansion; identity, provider, recovery and signup eligibility/Terms gates remain.
- Account-bound local pending answers sync after sign-in. Confirmed saves, visible
  retry, serialized edits and Profile → Setup questions are implemented. Migration
  041 stores the latest owned answers in `onboarding_responses`, separate from
  inventory/Teams, with owner reads, backend-only writes, integration-key exclusion
  and auth-account deletion cascade. Operator queries are in
  `docs/onboarding-answers.md`; no admin UI or tracking provider is added.
- Migration/API and public privacy disclosure are live. Backup/database dump,
  composed dirty-router preservation and deployment receipts are under
  `/home/ubuntu/findez-onboarding-20261012`. Active web release is
  `/home/ubuntu/findez-web-releases/web-onboarding-questions-20261012/frontend`;
  unrelated source/config and 813 prior static assets are retained. Public Privacy
  has the October 12 date; unchanged Terms retain October 11. Dedicated review
  account save/read/idempotency and owner-override rejection pass; only its newly
  created QA answer row was removed, restoring its initial state.
- The actual six-step spotlight tour uses concise target-specific instructions,
  opaque theme cards, adaptive measured layout and real Next/Back/Skip controls.
  All 338 mobile tests with coverage and clean analysis pass. Native iPhone 16e
  iOS 26.2 questionnaire completion, selected/multiple-choice accessibility and
  Light/Dark/Auth screenshots pass. All five exact-source CI jobs pass in
  `38346877463`, including 419 backend, 211 web and PostgreSQL isolation checks.
- Clean signed 1.0.8 (62) archive/export, production configuration (actual
  `PREVIEW_ONBOARDING` disabled), strict app/extension signatures, all 31 native
  device executables and Apple validation pass. Upload
  `3ab7200b-5045-499f-accb-2d5f4f7b6f2c` is COMPLETE without errors/warnings;
  build 62 is VALID, APP_STORE_ELIGIBLE and IN_BETA_TESTING. Both existing internal
  groups and saved test notes are verified at 21:49 PDT October 12. Durable IPA,
  archive, receipts, verifier, screenshots and phone checklist are in
  `Documents/FindEZ/AppStore/1.0.8-build62`. IPA SHA-256:
  `ed2721cb8a610a9604e1fb5e9e5bc28264d4ff08ad81fb42628867ec2f259017`.
  Released 1.0.7 (59), manual/unselected 1.0.8 and requested name/subtitle are
  verified unchanged. Physical phone acceptance remains deferred; public App Store
  submission remains held. The build-61 introduction below is historical and
  superseded; the simulator is left on the clean Dark sign-in preview.

## October 12 general inventory categories and walkthrough

- Category source `2384bbd`, draft PR #57 stacked on #56, passes all five CI jobs
  in `38312460669`. 398 backend tests, 211 web tests, TypeScript/changed-file
  ESLint, 319 mobile tests with coverage, clean analysis and disposable PostgreSQL
  category/permission checks pass. Migration 040 is live, preserving all five
  Teams and the existing plan constraint. Five selected backend files are deployed;
  the live Team document access guards are retained in the composed workspace file.
  Backup, migration and verified hashes are in
  `/home/ubuntu/findez-categories-20261012`. API/database health and unauthenticated
  Team-create 401 pass; no real Team or inventory is created for QA.
- Web categories and truthful Space-delete confirmation are live from
  `/home/ubuntu/findez-web-releases/web-inventory-categories-20261012/frontend`.
  Server 211 tests and production webpack build pass. Candidate/public checks
  verify 17 actual authenticated pages, six redirects, public legal documents,
  16 current static assets, exact integration downloads, production origins and
  category bundle markers. All other live source/config is preserved, including
  three unrelated styling files; 758 previous static files remain available.
  Restore `previous-web-rebuild.conf` from that release and restart only the web
  service for rollback.
- GitHub About, README, mobile setup, current product context, learning guide,
  legacy EEZY prompt and customer Team copy describe homes, businesses, labs,
  teams and industry. Editable App Store 1.0.8 has the exact requested name,
  subtitle and broader description; no public review submission or build selection
  is made. Categories are descriptive and do not change plans/access.
- `fix/onboarding-light-dark`, based on `2384bbd`, simplifies the four local
  onboarding examples, shortens copy, removes diagram clutter and uses explicit
  Light/Dark contrast and general inventory examples. All 319 mobile tests and
  clean analysis pass; rendered pages in both themes and 320pt layouts through
  3.4x text are checked. Native iPhone 16e iOS 26.2 compilation and walkthrough
  interactions pass in Light/Dark, including completion and persisted restart.
  All five CI jobs pass on runtime `86669ee` in `38314482069`. Apple validation
  rejects its first 1.0.8+61 export because `objective_c.framework` contains
  simulator slices (90087/91169). The failed signed package and receipts are
  preserved in `Documents/FindEZ/AppStore/1.0.8-build61-validation-rejected`.
  The clean replacement on runtime `5acd4c7` passes all five CI jobs in
  `38336413029`, strict app/extension signatures, production configuration and
  device-platform checks for all 31 Mach-O executables. Apple validation/upload
  pass without errors; delivery `f6a6c33f-7c34-4091-8df7-1c4ebf35e274` is accepted
  at 19:27 PDT October 12. Apple processing is COMPLETE without errors/warnings;
  build 61 is VALID, APP_STORE_ELIGIBLE, nonexpired and IN_BETA_TESTING. Both
  existing internal groups are verified at 19:31 PDT and test notes are saved.
  The clean archive, IPA, checksums, receipts, verifier
  and phone checklist are preserved in `Documents/FindEZ/AppStore/1.0.8-build61`.
  IPA SHA-256 is `527205291de7a52f6c1fff593a7f15acaffa7abc11e9eb830916e6b33c2c22c3`.
  Physical acceptance remains deferred. Released 1.0.7 (59) and manual/unselected
  1.0.8 draft states are verified unchanged after delivery; requested name/subtitle
  remain saved. The historical gateway proposal now explicitly defers to the
  deployed architecture and covers homes, businesses, labs, teams and industry.

## October 12 Space deletion and review lifecycle candidate

- `fix/deleted-space-review-refresh`, based on delivered build 60, adds migration
  039: pending identifications gain an owned stable Space link, cascade when the
  Space is deleted, and retain that link across rename/location edits. Existing
  matching owned records are bound; unassigned records and other users remain
  separate. Full PostgreSQL 17 permissions/documentation suite plus lifecycle,
  foreign-owner and failed-transaction regressions pass in a disposable container.
- Mobile confirms the delete response, invalidates old Find/cache reads, removes
  the deleted Space locally and refreshes Home. A failed review refresh shows an
  unknown count instead of retaining a known-obsolete value. All 317 mobile
  tests with coverage and clean analysis pass, including actual-shell Light/Dark,
  failed deletion/refresh and delayed warmup cases. Web confirmation copy now
  describes the existing destructive behavior accurately. All five exact-runtime
  CI jobs pass on `e3bb2f6` in `38310437658` (draft PR #56). Migration 039 is live;
  its cascade FK and both triggers are verified, all 83 pending records remain,
  and six owned matching records are bound. Database health passes. The private
  pre-migration backup and exact applied SQL are in
  `/home/ubuntu/findez-space-review-20261012`. No new native binary is yet delivered;
  web confirmation copy will deploy with the broader category lane.
- Read-only production schema confirms missing review-Space linkage and zero
  ambiguous names. The user's privately identified account still has Robot Room
  and six pending records, so these are not automatically purged as orphans.
  Migration backfill will associate them with that Space; the next confirmed
  deletion removes them. No real user Space or inventory is deleted for QA.

## October 12 TestFlight delivery and public release status

- The user authorized upload and internal TestFlight delivery. Apple reports
  App Store 1.0.7 selected build 59 as `READY_FOR_SALE`, release type `MANUAL`.
  The US storefront confirms 1.0.7, released `2026-10-12T01:59:13Z`. No public
  release or review-selection action is performed by this delivery lane.
- Apple validation rejected the original 1.0.7 (60) package with closed-train
  `90186` and version `90062` errors after approval of 1.0.7. Only
  `mobile/pubspec.yaml` changes to 1.0.8+60 in runtime `a6ea4c5`. Signed archive
  and export pass; strict app/ShareExtension signatures, unexpired App Store
  profiles, disabled debugging, production API/auth/APNs, anon-role client key
  and compiled feature markers are verified. All five runtime CI jobs pass
  in `38302159412`; original candidate simulator checks apply to identical code.
- Apple validation and upload pass without errors. Delivery
  `87711752-2586-445c-a2a5-ebc12e7b4b94` was accepted at 13:17:03 PDT October 12.
  Apple processing is `COMPLETE` without errors/warnings; the build is `VALID`,
  `APP_STORE_ELIGIBLE`, nonexpired and `IN_BETA_TESTING`. Both existing internal
  groups (`Testers` and `Internal Pilot Findez AI`) include 60, and its test notes
  are saved. Released build-59 selection/release type are verified unchanged.
  The durable package, receipt, script, checksums, phone checklist and report are
  in `Documents/FindEZ/AppStore/1.0.8-build60`. IPA SHA-256 is
  `ab3a606d28932f5d581b2ba3497733c5db9b711a1d5869b5dcc473b3b80401b1`.
  The rejected 1.0.7 artifact remains preserved in its original prepared folder.
  Physical acceptance is deferred by the user; TestFlight availability does not
  prove physical delivery,
  browser legal links, camera/library/voice or account-change behavior.

## October 11 mobile notification candidate

- Prepared on `fix/mobile-notification-permissions` based on legal deployment
  `5b21899`. Existing OS permission can reconnect on launch/resume; a new prompt
  only follows the inbox's Enable action. Denied permission points to Settings.
  Native registration has a 30-second bound and cannot overwrite an outstanding
  result; Dart serializes it and rejects account changes before device writes.
  Device requests capture auth headers. Logout stops OS delivery and clears
  delivered/pending alerts; the next registration reassigns the device token.
- Inbox opening no longer marks everything read. Explicit reads re-fetch,
  preserve newly arriving unread events, retain rows with visible failure copy,
  validate server counts and refresh on visible/resumed timers. Shell counts
  consume fresh snapshots and invalidate late responses. Shells are keyed by
  user and old routes close on account changes. Local stock refreshes no longer
  request permission without a chosen threshold/reminder action. Feed rows are
  plain, with meaningful unread state and no decorative dividers/test button.
- All 312 mobile tests with coverage, clean analysis, Swift parse and native
  simulator compilation pass. Candidate version is 1.0.7 (60), with verified
  production API/auth inputs and no onboarding preview. The user asked to prepare
  it and will test physically later; `devicectl` currently reports the iPhone
  unavailable. Actual camera/library/voice, browser legal links, APNs delivery
  and account-change/foreground/background acceptance are not claimed as passed.
  Signed archive and App Store export completed before interruption. October 12
  verification confirms strict app/ShareExtension signatures, unexpired App Store
  profiles, disabled debugging, production APNs/auth/API, public anon-role client
  key, canonical legal/inbox markers and new native registration handlers in the
  compiled app. All five runtime CI jobs pass on `37c5055` (`38210945770`), draft
  PR #55 stacked on #54. Durable IPA/checksums, verification script/JSON, phone
  checklist and legal/privacy follow-up report are saved in
  `Documents/FindEZ/AppStore/1.0.7-build60-prepared`. IPA SHA-256 is
  `4f07de9e189809ef219a9cf9aa5558cd8a16a1231184b6be188882f7e5c208bc`.
  Existing default launch-image asset warning remains; the native storyboard
  uses the FindEZ text wordmark. No Apple validation/upload/submission occurred
  for 60. Physical checks remain deferred by the user; do not present this local
  package as a TestFlight delivery or change build 59's review selection.

## October 11 canonical legal pages and mobile links

- Web source `1e6a8b3` is live from
  `/home/ubuntu/findez-web-releases/web-canonical-legal-20261011/frontend`;
  draft PR #54 is stacked on notification PR #53. All five CI jobs pass on
  `d459df3` (`38209066849`), which adds the native signup Material correction
  needed by the newer Flutter CI version; its web source is identical.
  Privacy and Terms now share readable public layouts, current factual content,
  working section links and canonical URLs. Mobile opens those HTTPS documents
  in the browser with retry/copy fallback. Redundant public feature pages redirect
  to their actual authenticated tools; the old mega menus are removed.
- Only essential authentication and requested feature storage are in use. The
  informational cookie notice can be dismissed without accepting Terms or
  enabling tracking. No analytics or advertising provider is installed. Signup
  requires an eligibility/Terms acknowledgment and stores a timestamped receipt
  in user metadata. This is an attestation, not verified age or immutable legal
  evidence; sign-in OAuth can still create an account after the continuing notice.
- Official California registry lookup on October 11, with the user's CAPTCHA
  authorization, confirms AI ROBOTS INC (4578465), Active, filed March 16, 2020,
  principal and mailing address 887 Poppy Ct, Sunnyvale, CA 94086. No private
  agent information is published. The legal contact is info@findez.ai.
- Read-only deployed Edge function inspection confirms document/image cleanup
  and ordered owned-row deletion with failure propagation. Its SHA-256 is
  `e55c0a6df8bdaf0102fc6fdf7db048ee0739630117cc6fe81e41c21b067896c1`.
  No real account was deleted. Failed deletion can partially complete; UI and
  notice no longer imply that failure leaves all data untouched.
- Known limits are disclosed: inventory photos have link-accessible public URLs,
  a legacy photo-processing connection is unencrypted, and logs/backups do not
  have a verified comprehensive retention schedule. The user's October 4
  withdrawal of FIND transport changes is preserved. Text changes do not fix
  these engineering issues. Private image access, TLS, retention/processor audits
  and a documented privacy-request/breach procedure remain follow-up work.
- Counsel should review minor/guardian and school agreements, country-specific
  eligibility and data-transfer requirements, legal bases and processor terms,
  consumer remedies, liability limits and effective assent. Worldwide Apple
  availability and a 13+ checkbox do not establish worldwide compliance. Relevant
  primary guidance: [FTC schools and COPPA](https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions),
  [FERPA vendors](https://studentprivacy.ed.gov/resources/responsibilities-third-party-service-providers-under-ferpa),
  [EU children's safeguards](https://commission.europa.eu/law/law-topic/data-protection/information-business-and-organisations/legal-grounds-processing-data/are-there-any-specific-safeguards-data-about-children_en),
  [ICO storage exceptions](https://ico.org.uk/for-organisations/direct-marketing-and-privacy-and-electronic-communications/guidance-on-the-use-of-storage-and-access-technologies/what-are-the-exceptions/).
- Web: all 210 tests, TypeScript, changed-file ESLint and production webpack
  build pass. Safari verifies readable Privacy/Terms, section navigation,
  notice dismissal and absence of the old menus. All 301 mobile tests with
  coverage and clean analysis pass, including legal-link and signup gates;
  native camera/library/voice and
  push acceptance are required for a future binary. Build 59 App Review is held
  unchanged; this lane does not upload or resubmit it.
- Server build and 210 tests pass. Candidate/public checks verify both legal
  documents, canonical URLs, five redirects, 18 sign-in guards, static assets,
  exact API docs, production origins, headers and zero production dependency
  vulnerabilities. Both services are healthy; 702 previous static files are
  retained. Source manifest and rollback drop-in are beside the release. Safari
  confirms the deployed Privacy layout and absence of the old menus.

## October 11 notification inbox refresh

- Web runtime `0189a17` is live from
  `/home/ubuntu/findez-web-releases/web-notification-refresh-20261011/frontend`,
  draft PR #53 stacked on #52. Read state and bell snapshots stay in sync;
  stale requests and sender-document broadcast echoes are invalidated, visible
  inboxes refresh on focus/poll, and failed refreshes retain rows with an error.
  Read writes re-fetch instead of assuming no new events arrived.
- All 203 web and 380 backend/API-doc tests, TypeScript, webpack builds and five
  CI jobs pass (`38204481906`). ESLint has no errors and one generation-ref
  warning. Safari verifies a fictional update's unread marker and bell clear
  together. Production schema/APNs configuration checks are read-only; no actual
  push was sent. Physical APNs delivery and native permission/read races remain
  for the later mobile lane; existing App Review submission is preserved.
- Candidate and public title/headers, 18 page guards, static assets, exact API
  reference and production origins pass. 622 previous static files are retained;
  dependencies and all other live source stay unchanged. Restore the release's
  `previous-web-rebuild.conf` to the existing drop-in and restart only the web
  service for rollback. No backend runtime or schema is changed.

## October 11 professional web polish

- Runtime `6960b2d`, draft PR #52 stacked on #51, is live from
  `/home/ubuntu/findez-web-releases/web-professional-polish-20261011/frontend`.
  AI-only Source Sans 3, safe Markdown, collapsed Sources, plain history,
  message-scoped pending status, reduced decorative chrome, actionable Home
  attention counts, contextual pipe titles and remembered desktop pinning are
  delivered. Existing app fonts and routes are retained.
- All 195 web tests, TypeScript, webpack builds and five CI jobs pass
  (`38203294862`). Changed-file ESLint has no errors; existing warnings remain.
  Production dependency audit reports zero known vulnerabilities. Safari verifies
  dark/light replies, Sources, pin resizing, Home/settings/feed appearance and
  narrow navigation isolation. Local content was fictional, not recognition QA.
- Candidate and public HTTPS checks verify title/headers, 18 guarded pages,
  static assets, exact API docs and production origins. Unrelated live global
  CSS/dialog/import styling is preserved and 527 previous static files retained.
  Both services are healthy. Restore the release's `previous-web-rebuild.conf`
  to the existing systemd drop-in and restart only `findez-web` for rollback.
  Notification behavior and canonical legal/mobile content remain separate lanes.

## October 11 Ask photo reply clarity

- Shared backend runtime `fefcfe9` is deployed for web/mobile photo chat. Replies
  group duplicates, summarize stock and uncertainty once, skip generic unknown
  name matches and omit noisy categories. Scenes with several labels and no
  product identifiers use validated selection of up to three existing subject
  labels, with a bounded optional request and deterministic fallback. The
  original FIND evidence and Review records remain authoritative; this is not a
  guarantee of recognition accuracy or a rewrite of saved conversations.
- All 376 backend/API documentation tests and all five exact-runtime CI jobs pass
  (`38195426179`). Live synthetic-label consolidation took 4.66 seconds. Deployed
  hashes match; the configured `https://findez.openstack.ftctools.com` API passes
  health/database checks and rejects unauthenticated photo requests with 401.
  Backups and verification are in `/home/ubuntu/findez-ask-photo-20261011`.
  Draft PR #51 is stacked on #50. No client binary, web rebuild or migration is
  needed. New-photo user acceptance remains unverified.

## October 8 App Review corrections

- Apple rejected 1.0.7 (58), submission
  `2b777948-f7bd-46b3-bf43-9a2e60074361`, on October 7 with 2.1 AI information
  questions and 2.3.10 non-iOS screenshot status bars. Confirmed in the signed-in
  App Store Connect submission page. Public manual-release status is preserved.
- `fix/app-review-build58`, based on `669dde0`, prepares a policy-only candidate
  59. The developer confirms model inference runs on their servers. Current
  backend source and non-secret process settings route to their FIND and agent
  gateway, without OpenAI runtime/fallback. Submitted 58's mobile policy and Terms
  still contained obsolete OpenAI text. The replacement describes self-hosted
  photo/language processing, optional Apple Speech audio transcription, and
  separately configured external API assistants. Runtime AI behavior is unchanged.
- Native build-58 iPhone 17 Pro Max and iPad Pro 13-inch (M5) captures use the
  existing review account's five sample records. No inventory data is modified.
  One typed sample Ask returns the correct Space and quantity through the live
  service. Screenshots and review reply are preserved under
  `Documents/FindEZ/AppStore/1.0.7-review-fix`; originals remain preserved. All six
  iPhone captures are 1320x2868 and all six iPad captures are 2064x2752. Media
  Manager confirms every smaller family inherits the primary sets with zero
  separate uploads. Both native Ask tests return the correct Space and quantity.
- Runtime `68fbe55` passes Flutter analysis, all 296 tests with coverage,
  formatting and all five shared CI jobs (`37866116183`). Candidate 59 compiles
  for the simulator, opens the corrected policy date, and its compiled debug and
  release text contains the new disclosures without the obsolete OpenAI copy.
  Signed archive and App Store IPA export pass strict signature, App Store
  profile, non-debug, production API/auth and push checks. IPA SHA-256 is
  `f955090596197783cf3818b396c5ee040928f4f9f002630611cea08123e78296`.
- Draft PR #50 is stacked on #49. The durable folder contains the IPA, response
  draft, all 12 PNGs, screenshot ZIP, native policy first-page capture and
  verification records. Initial disk-space failures were recovered by approved
  rebuildable cache/dependency cleanup; all task-booted simulators were stopped.
  The user's continuation authorizes delivery of the prepared correction package.
  Apple validation passes without errors; upload accepted at 18:08:32 PDT,
  delivery `4c3ff9ff-6310-48cb-91ff-79c89af796d3`. All twelve native screenshots
  replace the original primary sets, pass Apple's COMPLETE processing and match
  their source checksums/order. App Store Connect verifies iPad's six direct
  screenshots and the inherited native iPhone set; no other direct sets exist.
  The four-answer AI clarification is sent and visible in Messages (2) at
  18:09 PDT. Apple processing is VALID/APP_STORE_ELIGIBLE, nonexpired, with
  encryption declaration false and internal state IN_BETA_TESTING. Build 59 is
  selected for 1.0.7 and the existing submission was resubmitted at 18:19:39 PDT
  October 8; both submission/version are WAITING_FOR_REVIEW. Release type is
  MANUAL. Physical-device acceptance has not been repeated; public release
  remains held. All five CI jobs also pass on docs head `28f8ffe` in run
  `37867707683`. Durable selected-build, upload-processing and resubmission JSON
  plus the guarded delivery script record the completed actions.

## October 8 landing copy and returning-user navigation

- Implemented on `fix/landing-dashboard-link` in
  `/Users/tanyasmritivictorcharles/dev/findez-web-navigation`, based on `f36ca25`.
  The user explicitly authorizes these landing edits after the interior release.
  The chatbot/database hero paragraph is removed without replacement. Signed-in
  landing visitors receive Dashboard linking to `/home` from server-verified
  identity, then browser session events keep the link current. Shared marketing
  desktop/mobile actions also replace signup/sign-in with Dashboard.
- All 184 web tests with coverage, TypeScript, changed-file ESLint and production
  webpack builds pass. Safari verified the live anonymous hero without the removed
  copy and signup action, then fictional local signed-in landing and desktop/mobile
  marketing Dashboard actions opening Home. The previous live browser session had
  ended; no new production login or data write was made. Final CI evidence is
  recorded on draft PR #49, stacked on the navigation branch.
- Deployed runtime `a4d1fc1` runs from
  `/home/ubuntu/findez-web-releases/web-landing-dashboard-20261008/frontend`.
  Candidate/live HTTPS checks verify the requested paragraph is the only landing
  visible-text removal, anonymous signup, all 18 workspace guards and exact API
  JSON. The production environment, 220 other source/config files, original dirty
  checkout, backend process, existing collection colors and prior static assets
  are preserved. Restore this release's `previous-web-rebuild.conf` to the existing
  systemd drop-in, reload systemd and restart only `findez-web` to roll back.
  Landing animation/assets, interior source, backend, mobile and schema are
  unchanged. Existing workspace server guards still authorize data.

## October 8 web navigation follow-up

- Implemented on `fix/web-navigation-hover` in
  `/Users/tanyasmritivictorcharles/dev/findez-web-navigation`, based on `5473694`.
  The earlier uncommitted temporary checkout was gone and was restored from the
  committed web rebuild. Workspace routes now share one persistent shell; each
  page still verifies authentication and keeps its existing URL and parameters.
- Content skeletons replace the full-page Opening message. Desktop navigation
  expands from 72px to 232px on mouse entry, collapses on exit, and overlays the
  page without changing its position. Keyboard labels, tooltips, reduced motion
  and the narrow focus-trapped drawer remain. Home/profile links close the drawer.
- All 181 web tests with coverage, TypeScript, changed-file ESLint and local and
  production webpack builds pass. All five runtime CI jobs pass in run
  `37861622831` on `0cc9f44`. Safari verified fictional local navigation and slow
  reads, then all 18 actual sidebar destinations, live Home data, hover/exit,
  stationary content and public API docs with theme cleanup. This was read-only;
  inventory, membership, key creation and profile saves were not tested by writes.
- Deployed runtime `0cc9f44` runs from
  `/home/ubuntu/findez-web-releases/web-navigation-hover-20261008/frontend`.
  Preflight verified all 18 anonymous workspace guards, public pages, preserved
  landing visible text and exact API JSON. Live HTTPS checks pass. The existing
  Smart Collections heading colors are retained as a recorded runtime override.
  Production environment, dirty original checkout and backend process remain
  unchanged. Prior static assets are retained. To roll back, install this release's
  `previous-web-rebuild.conf` over the existing `web-rebuild.conf` drop-in, reload
  systemd and restart only `findez-web`. Release manifests, build/preflight and
  activation records are beside the deployed frontend. Draft PR #48 is stacked
  on #47's web branch to keep the follow-up diff scoped.

## October 6 authenticated web rebuild

- `web/mobile-parity-rebuild` in `/private/tmp/findez-web-rebuild`, based on
  submitted build-58 record `1e36998`, rebuilds the web interior around the
  current mobile behavior. Draft review targets `release/appstore-build58`;
  targeting the old `main` would include unrelated stacked mobile changes.
- Permanent desktop labels, grouped feature links, searchable navigation,
  a narrow-screen focus-trapped drawer, mobile mark and a real-data Home make
  existing capabilities easier to reach. Spaces remains the actual flat
  personal/shared model; Teams retains its separate membership model.
- Find details follow mobile field order and include permission-aware personal,
  shared and Team photo galleries. Capture has full manual fields and JSON
  spreadsheet import. Existing review, lending, kits, labels, Team utilities,
  notifications, API keys and public documentation remain reachable.
- Ask handles text/photo streams, public answer context, confirmed conversation
  IDs and visible interrupted/save failures. Documents and notes use existing
  upload/rename/link/storage routes with retained failed drafts. Account changes
  discard stale responses and clear private views in rebuilt clients.
- Restock requires item opt-in, separates To buy from On order and confirms an
  absolute arrival count before clearing an order. Lost-response retries reuse
  the saved count. Personal/shared/Team stock uses existing permission-checked
  routes; viewers cannot write stock. Purchase plans remain account/browser-local
  and do not sync with mobile purchase plans or another device.
- Scoped `workspace.css` affects only interior classes. Landing source, its
  styling/assets, public API/downloads, backend, mobile, schema, billing and FIND
  are unchanged. Existing API documentation matches the mounted public router,
  so no contract regeneration was required. New form copy avoids em dashes.
- Local final checks: all 176 web tests across 24 suites with coverage,
  TypeScript, changed-file ESLint (0 errors, 38 warnings) and production webpack
  compilation/prerender pass. Shared exact-head CI status is recorded on the PR.
  Native Safari checks used a fictional local API: desktop Home/navigation, Ask
  query handoff and sources, Find/details/photos, document failure/draft retention,
  Restock ordering/arrival, Settings, 390px Home/drawer and manual Capture fields.
  No production inventory or membership was mutated. Light/Dark theme logic is
  covered by tests; this browser pass observed the device's dark theme.
- Deployed to the existing self-hosted Ubuntu server at `www.findez.ai` on
  runtime `afea356`. `findez-web` runs from
  `/home/ubuntu/findez-web-releases/web-mobile-parity-20261006-live/frontend`
  through its existing Caddy/nginx proxy and production environment. Backend
  service `findez` is unchanged and both services are active. Vercel and Render
  are retired hosting targets and were not used for this deployment.
- The dirty VM checkout was preserved. The isolated release overlays only this
  lane's frontend changes plus the reviewed theme-provider dependency; it keeps
  the VM's unrelated import success colors and all 160 other staged files,
  including deployed public assets/styles/configuration. Production build,
  self-hosted bundle origins, static assets, anonymous guards, HTTPS public
  pages, original landing visible text and exact public API JSON are verified.
- Native Safari observed actual Home data, Documents, Restock and Settings.
  Profile fields and the saved header/sidebar photo load correctly. Legacy
  pending signup completion is bounded to one attempt per account per mounted
  shell to prevent USER_UPDATED recursion and profile API throttling. Save stays
  disabled until profile loads; photo uploads use the backend's `photo` field.
  No inventory or membership was mutated during these checks.
- Previous builds and immutable assets are retained. Deployment, preflight and
  activation JSON records live beside the release. To restore the original web
  build, remove only this task's
  `/etc/systemd/system/findez-web.service.d/web-rebuild.conf`, reload systemd
  and restart `findez-web`; preserve the existing network drop-in.
- Ignored local fixture/environment/build output was excluded. Full live
  multi-account, file upload/storage and collaboration acceptance was not
  repeated and is not claimed. Purchase plans remain browser-local.

## October 5 App Store submission

- The user's final instruction authorizes checking the current mobile app and
  submitting to Apple, superseding the earlier screenshot hold. FindEZ AI
  1.0.7 (58), runtime `9657aed`, was submitted at 2026-10-06 06:06:37.722 UTC
  (October 5, 11:06 PM PDT). Both the version and submission report
  WAITING_FOR_REVIEW. Submission ID: `2b777948-f7bd-46b3-bf43-9a2e60074361`.
- Manual release is preserved. Existing public 1.0.6 (17) remains available
  during review; Apple approval does not automatically publish this update.
- Six supplied 1320x2868 iPhone screenshots and six supplied 2064x2752 iPad
  screenshots are uploaded in order, COMPLETE, with matching original MD5s.
  Earlier draft artwork was backed up before replacement. Original supplied
  screenshots and logo assets were not edited.
- Description, subtitle, promotional text, keywords, release notes and review
  instructions are saved and verified without em dashes. Copy follows the
  supplied AI-memory-for-the-physical-world vision while advertising only the
  current Capture, Ask, Find, sharing and personal-device purchase planning.
- The reviewer account signs in and loads eight live read endpoints. Six
  consecutive inventory reads consistently return five sample items. Public
  support/marketing and privacy URLs return 200. All five exact-runtime CI jobs
  pass in run `37412454402`, including mobile analysis and coverage tests. The
  existing release manifest records 296 mobile tests and Apple/signature checks.
- This pass observed populated simulator Home and Spaces. Further native UI
  automation became unavailable. Full physical-device acceptance was not
  repeated and is not claimed. No inventory, membership, runtime, backend,
  schema, billing, native lifecycle or FIND transport change was made.
- Submitted text/checks are in `appstore/metadata.json` and
  `appstore/submission.json`. Durable original artwork and records are at
  `/Users/tanyasmritivictorcharles/Documents/FindEZ/AppStore/1.0.7-build58`.

## Earlier October 5 simulator preparation

- The earlier user instruction paused immediate Apple submission and asked for a newly
  built simulator so they can capture current screens and recreate artwork.
- App Store 1.0.7 now selects valid/eligible build 58, with MANUAL release and
  PREPARE_FOR_SUBMISSION. Description, release notes and review instructions are
  saved without em dashes. The dedicated review account signs in successfully.
- Supplied iPhone and iPad ZIPs were inspected and extracted without editing.
  Their UI differs from the release source, including Mark as taken. No new
  screenshots have been uploaded and no review submission has been created.
- Simulator runtime source is `9657aed`, the exact source of TestFlight 58.
  The ARM64 Debug build succeeded after approved cleanup of regenerable caches
  corrupted by disk exhaustion. Production API/Supabase configuration and public
  anon role match the release environment; source remains unchanged and clean.
- Build 1.0.7 (58) is installed and launched on iPhone 17 Pro and iPad Pro 13-inch
  (M5), both iOS 26.2. Installed bundle metadata confirms 58 on both. Actual SDK
  screen captures verify populated Home on iPhone and onboarding on iPad.
  Native UI automation became unavailable, so final screen verification used
  the iOS Simulator SDK screenshot command. This is simulator verification, not
  a physical-device acceptance pass. The user can take fresh captures with Save
  Screen or Command-S. No inventory or membership edits were made.
- Simulator app is retained at
  `/private/tmp/findez-build58-simulator-cache/Build/Products/Debug-iphonesimulator/Runner.app`.
  Signed release archives, IPAs and manifests are preserved. Public release and
  screenshot upload remain pending the user's replacement artwork.


Last reviewed on 2026-10-05 during scoped launch-blocker fixes.

## Restrained mobile accents and monochrome Teams (October 5)

- `fix/mobile-accent-consistency` in `/private/tmp/findez-accent-consistency`,
  Draft PR #46 stacked on restock PR #45 (`64c4e47`), delivers internal TestFlight
  build `1.0.7 (58)` on runtime `9657aed`. The user rejected build 57's orange
  Teams list as too orange and requested this page black and white. Create,
  Join and Team-row icons now use neutral foreground; the selected Teams
  segment and bottom-nav highlight are neutral while this page is active.
  Team Documents icons are also neutral, retaining distinct file-type glyphs.
- Other main screens and the Team workspace retain restrained orange action/
  selection roles from build 56: original Signal for filled primary actions,
  readable orange foreground derivatives and 8% selected-control tints in
  Light/Dark. Surfaces and most text remain neutral. Genuine warning/error/
  success meanings, supplied logos, photos and personal avatar colors remain.
  Active purchase counts retain orange with To buy/On order labels and cart/
  delivery icons; zero counts stay neutral. Stock writes, purchase persistence,
  permissions, routes, layouts and shared typography are retained. No backend/
  web/schema/billing/FIND/native lifecycle change.
- Clean analysis and all 296 mobile tests with coverage pass, including existing
  large-text, navigation, save/error, stock and brand-contrast regressions.
  Both themes' actual-shell previews of the five tabs and populated Teams list
  -> workspace -> Documents pass with stubbed data. The complete monochrome
  list/segment/nav and all document glyphs were visually inspected; switching
  to another tab restores its standard shared brand styling. Build 56's earlier
  Team preview covered only its workspace and missed the separate list palette.
- All five exact-source CI jobs pass on `9657aed` (`37412454402`). Signed archive/
  export, deep strict signature, packaged production configuration/public anon
  credential, original SVG/native icon checks and Apple validation pass.
  Apple validation reports no errors at 21:14:19 PDT October 5. Apple accepted
  delivery `b9a53267-2cea-4d13-903f-a885f9e62351` with no upload errors at
  21:16:01 PDT October 5. Processing is COMPLETE/VALID with no errors/warnings;
  APP_STORE_ELIGIBLE, nonexpired and both internal groups (Testers and Internal
  Pilot Findez AI) are verified at 21:20:52 PDT.
- Final archive/IPA and manifest are preserved under
  `/private/tmp/findez-build58-native` and
  `/private/tmp/findez-build58-verification.json`. IPA SHA-256:
  `7673f09a77e21194ac41984b8f89f11f3f58bc7b9c581c3c6cd94da410053d4d`.
  Builds 56 and 57 remain VALID in both internal groups with native artifacts
  and manifests preserved under `/private/tmp/findez-build56-native`,
  `/private/tmp/findez-build57-native` and their matching verification JSON files. Build 57's initial missing-defines export was rejected before upload;
  the verified final IPA and source `6037389` passed all release gates. The
  user's TestFlight screenshot showed its orange list and rejected that density.
  Build 55 passed checks but was not uploaded after the palette request.
- The user chose final verification through TestFlight; physical build-58
  visual/stock/notification acceptance remains unverified. Public App Store
  review and publication remain held.

## Restock planner replacement (October 5)

- The user reported that Shopping List checked items still appeared as needing
  restocking in Find. Checkmarks only persisted an ordered selection; the old
  banner independently counted quantity against thresholds. Replace that mobile
  destination with a Restock planner on `feat/mobile-restock-planner` in
  `/private/tmp/findez-restock-planner`, based on build-53 record `3a08fd1`.
  Build `1.0.7 (54)` is available internally; Draft PR #45 is stacked on
  typography PR #44. The compact follow-up candidate is `1.0.7 (55)`.
- To buy and On order are separate, persisted states. Find/Space summaries,
  Home's To buy action, Ask's summary and the shared Space Restock tab use the
  same purchase rules. Mark ordered immediately stops requesting that purchase;
  it does not change physical stock. Editable quantities, Move to To buy,
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
  action/dialog checks pass. All five exact-runtime CI jobs pass for `98f019e`
  (`37406983954`). Signed archive/export, strict signature, packaged production
  configuration/public anon credential and supplied-logo checks pass. Apple
  validation reports no errors. Apple accepted delivery
  `99fa3764-17eb-4d95-95c9-d02a518324d9` with no upload errors at 20:09:15 PDT
  October 5. Processing is COMPLETE/VALID with no errors/warnings;
  APP_STORE_ELIGIBLE and both internal groups are verified. The user supplied a
  planner screenshot showing migrated 0 to buy / 8 on order.
  Final archive/IPA and verification manifest are preserved under
  `/private/tmp/findez-build54-native` and
  `/private/tmp/findez-build54-verification.json`.
  Final IPA SHA-256: `86f0c084a38542983ed4c4226db3ece8508df6cbdd8f6067a14bfedbbb8dbddb`.
  The user's earlier choice to check through
  TestFlight applies; no physical stock write or full device acceptance is
  claimed. Logo, shared typography, existing inventory data, billing, backend,
  web, database schema, FIND and native lifecycle are unchanged. Public App
  Store review/publication remains held.

- Build 55 addresses the user's wordiness and status-color feedback. The main
  screen contains counts, concise item/stock details and one main action per
  card; explanations move to Info, and editing/removal/back-to-buy actions move
  to each item's accessible menu. Legacy orders with unknown quantities omit
  that detail without inventing a count. Pending stock confirmation stays
  visible. Amber indicates To buy and blue indicates On order in Find and the
  planner; zero counts remain neutral, and labels remain readable without color.
  Purchase persistence, stock confirmation, account and permission rules are
  unchanged. Clean analysis and all 296 mobile tests with coverage pass, including
  22 restock regressions and Light/Dark large-text/contrast checks. All five exact-source CI jobs pass for `5d24797` (`37408858103`), as do
  signed archive/export, signature, configuration/logo and Apple validation.
  Build 55 was not uploaded: the user requested app-wide orange/white/black
  consistency during validation, and released build 56 now includes both changes.
  Artifacts/manifest are preserved under `/private/tmp/findez-build55-native`
  and `/private/tmp/findez-build55-verification.json`. Physical verification
  follows the user's TestFlight preference.

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

- The current US App Store release is FindEZ AI `1.0.7 (59)`, verified October 12
  as recorded above. The recovery history below concerns former public
  `1.0.6 (17)`. The recovery branch
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
