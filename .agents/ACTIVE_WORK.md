## October 26 - Memory, Upgrade modal and concise progress (active)

`style/web-memory-upgrade-progress` owns web-only Memory layout, sidebar plans dialog and grouped real activity updates. Preserve memory API, prices, early-access status, mobile and backend.

## October 26 - Chat cancellation, Tools and notification preview deployed

Runtime `18a0530` is live in `chat-navigation-20261026/frontend`, build `qxMijwbiTDVPZJvmLjBgU`. Stop cancels stalled readers and cannot turn into submit; quiet themed transitions replace bare text; Tools uses an inventory selector and icon grid; the bell opens a five-entry popover with no entrance animation and View all. 628 tests / 87 suites, TypeScript, ESLint (0 errors/52 existing warnings), five CI gates (40429097939), production build and 27 staged/live routes pass. Safari verified dark desktop Tools, notification preview/Escape/View all, two read-only answers and immediate Stop with draft restoration and no resubmission. Prior release retained. No mobile changes. Receipt: `docs/plans/web-chat-navigation-receipt.json`.

## October 26 - Web chat cancellation and navigation cleanup (active)

`fix/web-chat-and-navigation` owns Stop/SSE cancellation, quiet route transitions, Tools layout and the notification preview. Backend parser/capability fixes are isolated in `fix/api-group-tool-stream`. Mobile unchanged.

## October 26 — Baby-blue Upgrade button deployed (PR243)

Runtime `23d6c37` is live in `upgrade-blue-20261026/frontend`, build `ANGzqwqm9IXVTuPlT_7N5`. CSS-only baby-blue glass gradient, soft glow, restrained six-second sheen cycle, focus ring and reduced-motion fallback; original layout/link retained. Safari light/dark preview and live authenticated Upgrade-to-usage navigation verified. All five CI gates (40422960778), production build and 27 staged/live routes passed. Backend unchanged; preceding release retained. Receipt: `docs/plans/upgrade-blue-web-receipt.json`.

## October 26 — Baby-blue Upgrade styling (active)

`style/web-upgrade-blue` owns only the sidebar Upgrade CSS in `/private/tmp/findez-plans-usage`. Add a soft baby-blue glass gradient, restrained sheen, visible focus and reduced-motion fallback. Preserve dimensions, link behavior and pricing.

## October 26 — Web plans, sidebar Upgrade and usage deployed (PR242)

Runtime `9d39948` is live in self-hosted `plans-usage-20261026/frontend`, build `bhC0HsnhcOvcIhc4TXAep`. Shared Free/Plus/Team cards now cover public pricing, the skippable first-entry introduction and account Plans & usage. User selected **10 Team members** at unchanged $29/month or $299/year. Intro dismissal persists in account metadata; sidebar Upgrade opens real account-owned record/Space counts. Pilot AI usage correctly says Not metered; paid actions remain Coming soon and early access retains no plan quotas/automatic charges/cutoff.

620 web tests/85 suites, TypeScript, ESLint (0 errors/52 existing warnings), all five CI gates and the production build pass. 27 staged/live routes plus seven staged/public real-auth checks pass. Safari visual checks cover local desktop/narrow light/dark components and public HTTPS pricing; signed-in live checks used disposable-account HTTP. Backend unchanged and prior release retained. No migration, mobile binary or App Store submission. Existing mobile five-seat display requires a separately scoped update. Details/receipt: `docs/plans/web-plans-usage.md` and `docs/plans/web-plans-usage-receipt.json`.

## October 26 — Web plans and usage (active)

`feat/web-plans-usage` in `/private/tmp/findez-plans-usage` owns the web catalog, first-account plan introduction, sidebar access and authenticated usage page. Based on live privacy release fca454a. Preserve unfinished feat/web-subscriptions lane; its endpoints are not deployed. User approved 10 Team members at the same prices. No backend, schema, purchase activation or native release in this lane.

## October 25 — Compact chat controls and blue resource links deployed (PR238)

Runtime `b714ae6d8f35ffb3512cd4dd1900e55fdedabde9` is live in self-hosted `chat-controls-blue-20261025/frontend`, build `ihpWKFLtBpGhNnun92YBY`. Removed prompt editing, tightened the remaining action row, added clipboard fallback and clear confirmed-rating selection, and kept completed-response ratings usable during a new reply. Resource links now use scoped baby-blue glass pills; Safari visual review caught and corrected a global action-style override. Copy verified in Safari and Chrome; positive/negative ratings and persistence after reload verified with the Chrome test account. Customer inventory unchanged. All five CI gates passed (40273737914), 601 web tests and TypeScript passed, ESLint zero errors/52 existing warnings. Production build and 26 staged/live routes passed; prior releases and backend process preserved. Receipt: `docs/plans/web-chat-controls-receipt.json`. Mobile matching controls/photo flow delivered separately in TestFlight142, availability pending Apple processing.

## October 25 - Live chat progress deployed (PR234)

Runtime `d192ab3` is live in self-hosted `live-progress-20261025/frontend`, build `fG-Fp_63lHkB58BaIjdI5`. Existing chat progress now shows elapsed time, receiving-updates/last-update age and persistent second-attempt indication from real server events. No synthetic milestones or private reasoning. All five CI gates passed (40268610118), 598 web tests and TypeScript passed; ESLint zero errors/52 existing warnings. Production build and 26 staged/live routes passed. Chrome test-account chat verified live timing, completion and existing response controls. Prior auth-entry release remains for rollback. Backend activity events deployed separately; no mobile binary or schema change. Receipt: `docs/plans/live-chat-progress-web-receipt.json`.

## October 25 - Live chat progress

`fix/web-live-chat-progress` adds a compact elapsed/last-server-update line to the existing progress disclosure. Actual SSE status/delta/capture/model-activity events update liveness; a stale stream shows the age instead of pretending progress. Automatic retry remains visible as second attempt. Timers clean up when the request leaves the loading state. Requires additive backend activity events for continuous liveness during private model generation; no layout redesign or reasoning disclosure.

## October 25 - Direct signed-in web entry deployed (PR233)

Runtime `e5701fc0959b71c28493de6001ebae5782f19c28` is live in the self-hosted `auth-entry-20261025/frontend` release, build `8GSX23MO4oG1DIprR6hBU`. `src/proxy.ts` now executes session refresh and redirects active sessions from homepage/signin/signup into the existing app. Successful password sign-in/signup bypass stale route caches. Prompt, invitation and recovery handoffs remain. All five CI gates passed (40267225450), 595 web tests, TypeScript, production build and 26 staged/live routes passed. ESLint: zero errors/52 existing warnings. Thirteen real-session HTTP checks passed on staging and public HTTPS with disposable accounts cleaned up, including expired-cookie refresh; Chrome verified all three entry URLs open Personal chat. Backend unchanged, previous favicon release retained for rollback. Receipt: `docs/plans/web-auth-entry-receipt.json`. No mobile or schema change.

## October 25 — Browser and search favicon refresh deployed (PR232)

Published runtime `c12c0cebb30ab933cd4266d0d20f8b6985ac3686` to the self-hosted `petals-favicon-20261025/frontend` release, build `Lu2S6k09Rd9HS9ImuqiCa`. Root metadata now advertises stable Petals ICO/SVG, 96px PNG and 180px touch-icon URLs using the existing approved mark. All five CI gates passed (40265331908); 584 web tests and TypeScript passed, ESLint has zero errors/52 existing warnings. Production build and 26 staged/live routes passed. Both public domains advertise and serve the exact new icon bytes to crawler user agents. Safari tab visually confirms the new mark. Google Search Console accepted the homepage indexing request into its priority crawl queue; search icon refresh remains pending Google recrawl. Backend unchanged; prior response-feedback release retained for rollback. Receipt: `docs/plans/petals-favicon-web-receipt.json`.

## October 25 — Compact chat controls (not deployed)

## October 25 - Browser and search favicon cache refresh

The live root ICO and existing brand assets already contain the approved orange/white Petals mark, but Safari and Google screenshots show the prior logo. Advertise stable, brand-specific Petals ICO/SVG/96px PNG and 180px touch-icon URLs to avoid reusing older cached icon keys. Preserve existing URLs and all page layouts. Google recrawl timing remains external. Local web tests, TypeScript and ESLint completed; deployment verification recorded separately.

## October 25 — Chat controls deployed on the self-hosted website

Published runtime `3e1025f3ea8ae353d41f008f49317746eb8c2f1b` to `/home/ubuntu/findez-web-releases/response-feedback-20261025/frontend`, build `p3PYYDc0JiTVin8HQuocq`. Includes compact response/prompt controls, persisted ratings, Enter send/Shift+Enter newline, prompt clearing, canonical completion handling and confirmed creation copy. Production build and 22 staged/live route checks passed; public HTTPS chat correctly requires sign-in. All five CI gates passed (40254596435); 584 web tests and TypeScript pass, lint has zero errors and 52 existing warnings. Previous chat-card-json release retained for rollback. No Vercel deployment was used. Receipt: `docs/plans/response-feedback-web-receipt.json`.

Branch `feat/chat-message-controls` implements compact copy/rating/retry/timestamp
controls and prompt editing, Enter-to-send (Shift+Enter newline, IME safe), immediate
composer clearing, and verified “Created and saved” confirmation. Optional negative
feedback details stay collapsed until requested. Clients render canonical replies
only after completion and stop accepting late stream events. Feedback selection
requires the backend receipt; history restores ratings in one account-scoped batch.
Requires API lane `feat/response-feedback-api` and migration 082 before release.
584 tests pass; TypeScript passes; ESLint 0 errors/52 existing warnings; webpack
production build passes with fixture public config. No deployment authorized.

## October 25 - Chat confirmation fix deployed (PR228)

Runtime `9d38fb0` is live, build `RiqETwne2y6XdnkE3O8M1`.
All five exact-source CI gates passed (40248237158). All 577 Jest tests, TypeScript,
changed-file ESLint, production build and 22 staged/live route checks passed.
Creation and item card confirm/cancel now send application/json via the existing
account transport. No layout change or automatic confirmation. Reopen the existing
conversation after refresh to retry its original card. The observed 422s occurred
before any mutation. No customer inventory was changed by verification.
Rollback: `/home/ubuntu/findez-web-releases/prelaunch-20261025/frontend`.
Receipt: `docs/plans/chat-card-web-receipt.json`. Backend release is separate.

## October 25 - Pre-launch access delivered (PR220)

Runtime `b8e5cc80669397cbaf2e3ca1d615c65f9eb463ac` is live; all five exact-source CI gates passed in 40235348641.
Plan quotas and purchases remain off, with no automatic cutoff.
Rollback: `/home/ubuntu/findez-web-releases/no-offers-20261025/frontend`. No production schema change.
Production build, 22 route checks, staged Chrome visual review and public HTTPS notice checks passed. Previous release and backend were preserved. Build ID: xRWAplxSZtohI0lJ31L2E.
See `docs/plans/prelaunch-access-20261025.md`. Paid subscription integration remains separate and unfinished.

## October 25 - Pre-launch access (web)

Implementation lane `fix/web-prelaunch-access`. 574 Jest tests, TypeScript and changed-file ESLint passed.
Delivered; see the release receipt above and `docs/plans/prelaunch-access-20261025.md`.
Keep plan quotas and purchases off until explicit launch instruction.

## October 25 - Standard pricing only

User rejected promotional offers. Removed the student/robotics 50% discount from the plan comparison. Keep standard Free/Plus/Team prices and larger-team contact. No discounts are authorized. Deployed runtime `1f858e782a464ef5100646c664e44683723c1e7b`, build `E4TddXx2Nk6z1B-NC1Plp`. All five CI jobs passed (40221088292), 22 staged/live routes passed, and public browser refresh confirms the discount/eligibility link is absent. Source and rollback preserved. Receipt: `docs/plans/no-offers-web-receipt.json`.

## October 25 - Free, Plus and Team plan comparison (web)

User approved the proposed three-tier prices and asked for both apps to match,
with Stripe/Apple setup deferred. Plans are informational: $0, Plus $9.99/month
or $99/year, Team $29/month or $299/year for five people. Current access and
server quotas remain unchanged; purchases stay unavailable. See
`docs/pricing-and-limits.md` for exact allowances and future payment gates.
Runtime `76bfc93522a15093373c5c2326b5db6877b58791` is live at findez.ai/pricing (PR217). All five CI jobs passed (40219539019); production build `vaVkOWF9huJC5FyrffOPO`, 22 staged/live routes and public browser checks passed. Monthly/annual comparison and unavailable paid buttons verified. Backend and prior release preserved. Receipt: `docs/plans/launch-plans-web-receipt.json`. No public App Store submission.

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

## October 24 — web light/dark audit

Branch `fix/web-theme-audit-20261024`, web only. Corrects portal contrast, theme
storage/hydration, dialog viewport/layers/padding, notification wrapping/markers,
sidebar initials and memory controls. 566 tests, TypeScript, lint (zero errors)
and compile-only build pass. Runtime `8372ba003efa9fdffbae3dace11a38e59ef301c7`
deployed via PR #210 after all five CI jobs passed (`40163364154`). Production
build `4hZ7Go8y0odI48cwFbltq`, 20 staged/live route checks and signed-in live
theme/menu/notification verification passed. Previous release and backend preserved.
See `docs/plans/web-theme-audit-20261024.md`. No mobile/API/schema edits.

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

## October 24 - Direct account entry and mobile-parity chat menu

Released web-only `feat/direct-world-entry-chat-menu-20261024`, based on `2ffa0c7`.
Replace the post-auth organization directory with validated last-world/Personal
entry; keep organization management in Settings. Reuse deployed mobile chat source,
file and capture APIs for a compact plus menu. No backend/schema/mobile changes.
Runtime `18f3b06` / PR193 is live, build `CGFdjEkOiFJ8kmwO5iqVl`. All five CI
jobs passed (40135129405); 556 local frontend tests. Route/assets preservation
checks passed. Browser visual and real signed-in save acceptance remain manual.

## October 24 — Organization chat and direct Space items

Active web-only branch `feat/organization-workspace-chat-20261024`, based on
`5b18b11`. Organization chat reuses deployed `/worlds` API (mobile source of truth),
private world history, durable request IDs, reviewed creation and authorized
resource links. Spaces directory spans accessible inventories; item views retain
existing editing. Organization tools replace per-inventory dashboards. Older
inventory conversations remain available in Tools. No backend, database or mobile
changes. Released as runtime `7077b2f` / PR192, self-hosted build
`cKvXUqYCWc3CAo3M7VXGS`. All five CI jobs passed (40123190890), including
532 web tests. Live route/assets and preservation checks passed. Signed-in
production AI/write acceptance remains unverified; see
`docs/organization-world-chat-web.md`.

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

## October 24 - Public prompt preview delivered

Web-only branch `feat/landing-prompt-preview-20261024`, based on delivered Blue
Echo web runtime. Landing prompts now open an accessible, morphing, interactive
unsaved preview before signup. The original bounded request survives email/OAuth,
onboarding and existing-account sign-in, then prefills authenticated Ask. No
anonymous inventory writes or new model endpoint. Explicit item/count phrases
are parsed locally; contextual examples are labeled and never saved as facts.
Local checks: 488 tests / 62 suites passed, production build and TypeScript passed,
lint 0 errors / 52 unchanged warnings. Desktop 1440x900 and phone 390x844 preview,
filter/details and auth handoff inspected in Chrome. Runtime `ad13f915` / PR183
is live on self-hosted `findez-web`, build `cHXcB07Do-U3qk0tvDwjj`. All five CI
jobs passed (40064433580); 12 live route statuses and six asset bytes verified.
Preserved 357 unrelated files and backend PID. Live mobile preview and signup
request retention verified. See `docs/landing-v3/PROMPT_PREVIEW.md` for receipt,
limits and acceptance steps.

## October 23 - Blue echo web branding delivered

Self-hosted `findez-web` serves runtime `ccb15ac80a37438ca5b6726aac6a8e1cbc4337ed`,
PR182, build `E_0tL8htuWZYnnxCVcbL1`. Live directory:
`/home/ubuntu/findez-web-releases/brand-blue-echo-icons-20261023/frontend`.
Primary kit logos, browser/touch icons, search/social metadata and shared fonts
are live. Fixed icon version URLs refresh Chrome's cached old favicon on reload.
Ten route statuses and six exact asset hashes verified; backend PID unchanged.
All five CI jobs passed (run 40062624865). Local 472 web tests, TypeScript and
production build passed; lint retains 52 pre-existing warnings, no errors.
See `docs/brand-blue-echo/DEPLOYMENT.md`. Google recrawl remains external.

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

## Organization leave and removal choices — delivered (October 19)

Scoped web/API/mobile branches `feat/organization-leave-*-20261020` are prepared.
Admins cannot remove the organization Owner. Keep/move versus cascade deletion
replaces empty-first prerequisites; web item rows expand without repeated titles.
Use only synthetic test identities; the founder account is excluded from QA.
All CI lanes pass. User-approved migrations 069/070 and matching API/web are live.
Apple acknowledged signed build 97, delivery f7f277d6-3bda-4182-a4cd-1d27c3dc21d4.
Stop at acknowledgment: processing, tester availability and device acceptance
remain unverified. See `docs/plans/organization-removal-choices-20261019.md`.

## Organization access and inline item update — live (2026-10-19)

User approved “yes publish and apply 068.” Migration 068 and the reviewed web/API
release are live after a fresh private database backup. Admins access all resources
within their organization; only Owners delete the organization. Viewers remain
read-only. Inline item editing, original import fields and task/invite attribution
are published. Deployment source hashes, attribution columns, permission precedence,
API/database/site health and unauthorized photo/Chat checks pass.

Mobile 1.0.9 (96), implementation efd7209, is signed, Apple-validated and
upload acknowledged (ea38eaff-6bfa-4a30-8af2-6c65e2e43c4a). Processing/tester
availability is unverified. Includes full-photo zoom/pan and session restoration. All three CI lanes
pass; 670 mobile tests pass. Device acceptance remains pending.
See docs/plans/organization-items-update-20261019.md for evidence and receipts.

## October 19 email presentation refresh - deployed

Lane `style/email-design-20261019` / PR133, runtime patch `ab9ba26`, is live.
Five account templates and three sharing HTML bodies now use consistent FindEZ
branding and responsive email-table layouts. Exact wording, links, placeholders,
plain text, subjects and dynamic escaping are preserved. AST comparison verifies
all Python logic outside the HTML is identical. No mobile or web page changes.
Deployment preserved the current production API team-join fix and 426 unrelated
runtime files; no database/configuration changes. Local tests, previews and all
five CI gates passed (run39338571429).
Details and CI receipt: `docs/plans/email-design-20261019.md`.

## October 19 cross-device email links - deployed

Lane `fix/web-email-links-20261019` / PR132, runtime `6d34999`, is deployed.
Five existing Auth email flows now use `/auth/confirm` with a one-time token hash
in the fragment and explicit verification before redirect. OAuth retains PKCE.
User confirmed a fresh desktop-requested reset email opens the new-password form
on iPhone. 464 web tests, scoped lint, types, production build and isolated
GoTrue integration tests passed. CI receipt is recorded in
`docs/plans/web-email-links-20261019.md`. No mobile changes, customer password
changes, production database migrations or unrelated auth setting changes.
Existing emails retain their old links; request a new email after deployment.

## October 19 website launch audit — deployed

Web lane `fix/web-launch-audit-20261019` / PR131 is deployed through runtime commit
`54ed135`. Active service directory:
`/home/ubuntu/findez-web-review-compact-20261019/candidate/frontend`. Website 431 tests
in 54 suites passed; 40 API-documentation checks, 29 connector tests, packaged/live
connector checks, production types/lint/build and Safari acceptance passed.
Final compact Review runtime 54ed135 passed all five CI gates in run 39333092847.
The preceding b7d5a13 also passed all five gates.
Temporary QA keys/share revoked; synthetic inventories/workspace removed. No
mobile source/binaries or production database changes. Separately authorized
metadata and checkout-query fixes are live in PR130 (1,103 backend tests plus
10 subtests passed). The 670-item dashboard now loads without its checkout error.

The final UI pass clarified navigation, filters, headings, responsive tables,
Capture methods, document rows, totals and landing copy. Review now uses 25 compact
rows per page with one expanded correction; draft preservation is tested. Published layouts were
verified in Safari at desktop and 390px/820px. Details:
`docs/plans/web-ui-polish-20261019.md`.

Public launch remains conditional on encrypting the API-to-FIND HTTP processing
hop and verifying GPU performance/capacity. Dependency and live acceptance limits
are recorded in `docs/plans/web-launch-audit-20261019.md`. Preserve unrelated
production overlays; do not reset the VM checkout.

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

# October 17 unified permission policy

Active web lane fix/web-workspace-editor-20261017 from 406e36b.
Follow the user's Roles and Permissions Specification, preserve selected roles,
distinguish inheritance/custom content access from workspace administration,
protect destructive actions and ownership confirmation, and refresh changed
permissions automatically. Preserve dashboard content and auth. Backend/schema
and mobile use separate lanes. Verify light/dark and role matrices.

# October 17 web invitation refresh

Published web-only lane `fix/web-invitation-handoff-20261017`, clean ee1a684.
Preserve access invite codes through signup and add installed-app handoff,
validate decision/target receipts, align legacy invitation appearance with both
themes. Preserve current server grants, auth callback ownership and Team-only AASA.

# October 17 web dashboard cleanup

Active lane fix/web-dashboard-empty-state-20261017, clean base eab8962. User now
explicitly requests organizing the web inventory dashboard. Scope is contained
Recently added/Spaces panels, responsive spacing and permission-aware empty
actions; data, navigation and public homepage stay intact. 327 Jest tests pass,
TypeScript passes and changed-file lint has no errors. Production webpack build
passes; aafcbd5 is live, preserving 285 unrelated source files. Signed-in Safari
confirms populated/empty dashboards; public/auth checks pass. No schema/data
writes or post-push/build regression reruns. See docs/plans/web-dashboard-cleanup.md.

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

# October 17 catalog permission hardening

Active lane: fix/catalog-write-permissions-20261017, starting clean 16eb6a1.
User approved implementing the barcode database/backend fix. Scope is audit F01
and the related F07 verified-catalog overwrite, not other audit findings. Candidate
053 and two service-only catalog transactions are complete. 817 backend tests,
321 composed SQL PASS notices and real concurrent-write cases pass. Fresh private
dump restored with existing grants; applying 053 twice preserves all public/auth
row hashes and unrelated objects. Direct client table/column/RPC writes fail;
signed-in reads/backend transactions remain available. Production activation
awaits separate reviewed approval. Patch 07c6d62 is pushed in draft PR 91. Apple
acknowledged TestFlight 1.0.8 (77), delivery cd2e3a2c-3ca2-4d2c-a2dd-cf6d8f1967ef.
Processing/tester availability unverified; no polling or repeated regressions.
Native runtime unchanged, prior 466 Flutter passes/clean analysis reused.
Details/files/rollback: docs/plans/catalog-write-permissions.md.

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

# October 16 web sidebar simplification

Same lane, clean starting 22a0e27. Move Review into Your world and remove Restock,
Lent items, Project kits, Smart collections and Labels from the shared web
navigation list. Remove the now-empty Organize group. Preserve routes/data and
inventory dashboard behavior. Publish a checked one-file web overlay on the
self-hosted server. Follow standing push/release instructions with beta76 only
as a delivery-number increment; no mobile UI/backend/schema changes.

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

# October 16 extraction dialog ownership

Same lane, starting 0ebf355 while beta74 upload is pending. User screenshot shows
Confirm Items behind an Extracting items modal. The in-Space upload flow opens a
root dialog but pops the local nested navigator. Replace unscoped pops with owned
route cleanup in finally; keep the Space and confirmation routes intact. Test
nested navigation, failures and interruption; deliver checked beta75. No backend,
schema, confidence or inventory-layout changes in this stage.

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

# October 16 per-item scan close-ups

Same hierarchy lane, starting 258e39e. User reports full-scene thumbnails for
unknown/low-confidence detections. Verify against the existing FIND integration
contract: item crops use the item-ID endpoint and bbox is x/y/width/height in the
stored frame. Fix adapter persistence/fallback only, preserve confidence/review
rules, inventory UI, transport configuration and source image. No production
record backfill or customer photo scan for QA. Deliver checked backend and beta74.

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

# Workspace deletion visibility follow-up (October 16)

Same hierarchy lane, clean starting f6e492b. User reports missing workspace delete.
Reuse existing owner-only DELETE /teams/{id}; no backend/schema changes. Expose
workspace management on mobile home/settings and web header/directory cards.
Exact-name confirmation describes collaboration removal and physical inventory
retention. Preserve inventory dashboard/Spaces. Deliver checked web and beta72.

# Hierarchy navigation repair (October 16)

Active lane feat/hierarchy-navigation-20261016, based on dec9cf9. Replaces mobile/
web organization and workspace directories only; working inventory/dashboard/
Spaces remain unchanged. Always-visible creation, explicit organization cards,
focused workspace lists and authorized rename/delete menus are implemented.
Deletion uses reviewed migration 049, which rejects nonempty inventories and
requires current owner/admin plus typed name. Source checks: 780 backend, 305 web,
448 Flutter full suite; clean static checks and passing composed SQL. Native
visual/accessibility review is isolated. Web candidate build passes with real
production fonts/config. Tanya approved 049 and publishing; migration/backend and
web-hierarchy-20261016 are live with private backups and rollout health/auth checks.
Authenticated Safari confirms the new directory/menu without writes. Apple
acknowledged signed TestFlight 71 from runtime 9bec964 (PR #90). Processing,
tester availability and physical acceptance are pending; no processing poll. See docs/plans/hierarchy-navigation.md.

# Account memory production activation receipt (October 16)

Approved migration 048 and reviewed backend 967ab48 are live on the self-hosted
server, including the PR #88 dependency. Fresh backup restore/migration rehearsal,
public/local health, authentication denial, anonymous PostgREST denial and live
RLS/grant/trigger checks pass. Unrelated VM changes are preserved. Web controls
are published from web-account-memory-20261016 after a normal server production
webpack build with real fonts; only three UI files changed. Candidate/public
route and signed-out protection checks pass. Authenticated device/cross-client
acceptance is pending.
TestFlight 70 was already uploaded; no new binary for this activation receipt.
See docs/plans/account-memory-implementation.md and CURRENT_STATE.md. Older
entries below describe the source/beta state before this explicit approval.

# Active work

## October 16 account memory foundation

Lane `feat/account-memory-foundation-20261016`, based on `5ca4e97`. Tanya approved
stages 1-4 of `docs/plans/account-memory-foundation.md`. Source now includes typed
explicit preferences, private inventory location aliases, transactional receipts,
RLS/legacy-collector guards, grounded personalization and web/mobile controls.
772 Python tests plus six subtests, 302 web tests, 444 Flutter tests, static checks
and standalone/composed SQL including concurrent edits pass. A read-only live
metadata check found unsafe public legacy memory policy/grants; migration 048
subsequently closed them live after explicit approval. No customer records were
changed for QA. The normal server production webpack build passes with real fonts
and configuration; the earlier local fixture output was never published. Apple acknowledged signed TestFlight 70,
runtime `967ab48`, delivery `a4f9218f-38c5-405f-bb60-3de7c938bd3d` (PR #89).
No processing wait. Backend and web are activated; real two-client/device acceptance remains pending. Full files/risks/commands:
`docs/plans/account-memory-implementation.md`.

## October 16 assistant grounded retrieval

Active lane `feat/assistant-grounded-retrieval-20261016`, clean starting commit
`3e3e095`. Read `docs/plans/assistant-grounded-retrieval.md` for discovery,
baseline, stages and risks. Latest user instruction authorizes commit, push
and a new TestFlight build using completed checks, with no repeated post-push
or post-build checks. Preserve gateway selection, client chat contracts, authorization and
FIND transport. Local implementation adds scoped natural-language reads,
evidence/follow-ups, retained HTTP stream scope and caller-tool safety. 127
synthetic cases, 727 Python tests plus six subtests, 296 web tests, 434 Flutter
tests, static checks and connector/bundle checks pass. Review and live acceptance
remain separate; backend deployment is not part of the beta upload. Apple acknowledged build 69
(`dce3e75e-aaba-4994-b609-5953086d88b6`), PR #88; no processing wait. Full files, security limits
and remaining work are in the plan/report above.

## October 16 mobile workspace home and place switcher

Lane `feat/mobile-place-switcher-20261016`, based on mobile build 66. Mobile only:
replace root Your world with the supplied workspace home and grouped bottom-sheet
place switcher, bundled Geist fonts, account-bound last-place storage and
authorized restoration. Reuse current APIs, membership controls and inventory
session boundaries; preserve inventory, Tasks and Files screens. Move leaving to
People. Reference assets are in `design/workspace-switcher/`. Tests, iPhone 16e
comparison screenshots and a subsequent checked TestFlight upload are required.
430 full Flutter tests and analysis pass. The blank space-creation screen is
reproduced and fixed at the nested dialog navigator. Native visual comparisons
and cold restore pass with isolated data. Build 67 uploaded successfully after
all five CI gates, clean signed native package verification and Apple validation;
processing/group availability and physical acceptance remain pending.
No web/backend/schema publication. Xcode regenerable caches were cleared with
approval to recover native-build space; signed release artifacts are preserved.
Follow-up for build 68: the first delivery left old organization, management
and Search routes reachable. Those routes now use the place styling, and opening
a workspace from an organization returns to the home. Search shows only scoped
inventories. Production-connected iPhone 16e simulator navigation confirms the
new flow, real Tasks/Files loading and Space Create/Cancel without a blank page.
434 full Flutter tests and 29 focused tests pass; analysis and all five
exact-runtime CI jobs are clean. Apple validated and acknowledged signed
TestFlight build 68. Processing and tester availability are pending; no wait
per Tanya's request. The public App Store version was unchanged.

## October 16 mobile hierarchy TestFlight delivery

Apple acknowledged 1.0.8 (66), runtime `8dc9fdd`, on PR #85. All five exact-runtime
CI gates, signed package/production configuration/31 native executable checks and
Apple validation pass. Tanya requests uploads after completed mobile changes and
said not to wait after submission. Processing, group assignment and physical
acceptance remain unverified. Public App Store version selection and submission
were not changed; no backend/schema deployment. Receipts and the later
status/assign helper are in `Documents/FindEZ/AppStore/1.0.8-build66`.

## October 16 mobile hierarchy parity

Source implementation complete on `feat/mobile-inventory-context-20261016`.
Mobile-only organization/workspace/inventory navigation, consent and membership
management, physical locations and immutable scoped API clients replace the old
Teams shell entry while preserving backend records and personal inventory.
409 Flutter tests, clean static analysis, 75 targeted backend tests and 59 web
compatibility tests pass. All five CI gates pass for `a49f03d` on draft PR #85
(run `38872280350`). No backend, web, schema, native configuration or
production backend changes. The later build-66 upload is recorded above.
Native/device, real email and two-client acceptance remain
release gates. See `docs/plans/mobile-hierarchy-parity.md` for matrix, files and
the disposable-account test plan.


## October 15 organization actions menu

Completed and published PR #84, runtime `a21ea8d`, migration 047, build
`3hd1z4zQK8kaRdhzoIf3X`. Owner-only three-dot menus offer Rename and Delete on
organization cards and selected Workspaces/People pages. Delete requires the
exact current name and no attached workspaces, enforced transactionally with a
durable audit. Existing workspace/inventory controls remain unchanged. 565
backend tests plus six subtests, 296 web tests, TypeScript, lint with zero errors,
production build, isolated SQL/concurrency checks and all five CI gates pass.
Live signed-in Safari opens/cancels both dialogs and verifies context menus;
no customer QA writes. See CURRENT_STATE.md for release and rollback receipts.

## October 15 approved Lab homepage publication

Published at `/` on PR #83, runtime `4caa38c`, build
`nGSlTwykEqoUG8MlgI06u`. Retains only Developers, iOS App and session-aware
Get started/Dashboard in the header, and all six footer destinations at the
bottom. The header moves at half scroll speed and smoothly fades out after
moving half its height, restoring on return to the top. Hidden links are inert;
reduced motion uses normal page scrolling. The announcement banner is removed.
288 web tests, TypeScript, changed-file lint and production build pass. Desktop
and 390px checks verify retained links, no overflow/errors, scrolling header,
waitlist confirmation-only behavior and reduced motion. Live public/protected
routes, assets and backend health pass. `/lab` remains the original noindex
preview. Backend/mobile/database unchanged. See CURRENT_STATE.md for rollback.

## October 15 isolated Lab landing preview

Completed on `feat/landing-lab-20261015`, based on `2d8d3f7`. Approved ZIP
prototype ported to `/lab` with noindex, scoped fonts/CSS, direct DOM animation,
hero canvas and reduced-motion support. Homepage and live production unchanged;
private production preview forwarded to localhost:3000. Waitlist is deliberately
confirmation-only with no API request. Production build, TypeScript, lint and
287 web tests pass. All 46 desktop/mobile comparison pairs verified, with matching
geometry and only hero drift plus a few phone-frame raster edge pixels remaining.
No console errors or horizontal overflow. See
`frontend/design/landing-lab/VERIFICATION.md` for files, receipts and preview details.
Tanya subsequently approved homepage publication as recorded above.

## October 15 workspace hub and discoverable inventory directory

Completed and published PR #81 runtime `5a2bc55`, migration 046. Workspace
Overview, separate inventory navigation, approved directory metadata, hidden
inventories and recipient-initiated viewer requests are live. 550 backend/276 web
tests, TypeScript/lint, SQL/concurrent decisions, restored-copy preservation,
production build and all five CI gates pass. Live signed-in chooser/context flow
verified; no customer QA writes. Later collaboration phases remain planned.
See CURRENT_STATE.md for validation limits and rollback receipts.

## October 15 creator rename

Completed and published PR #80 runtime `905923a`, lane
`feat/creator-rename-20261015`. Organization/workspace owners and inventory creators
have name-only Rename controls with backend access checks; existing inventory
manager rights and all stable resource relationships remain. 537 backend/268 web
tests, TypeScript, lint, production build, all five CI gates and signed-in live
Safari dialog/cancel checks pass. No customer data changed for QA. No migration or
mobile change. See CURRENT_STATE.md for runtime and rollback receipts.

## October 15 recipient-approved membership

Completed and published PR #79 (`8592a4d`), migration 045, on lane
`feat/member-invitation-consent-20261015`. It replaces immediate new
organization/workspace membership and newly granted inventory access with pending
recipient-approved invitations, email review links, recipient-bound codes,
Notifications, Accept/Decline, expiry and sender cancellation. Consent is enforced
in the database-backed API, with existing memberships preserved and sender/parent
authorization rechecked on acceptance. No real invitations or
customer access changes during QA. All 528 backend/262 web tests, TypeScript,
lint, all five CI gates, production build, isolated/concurrent SQL checks,
restored-copy migration rehearsal and live signed-in Safari checks pass. Existing
memberships and public-table values/policies are preserved. See CURRENT_STATE.md
for runtime/rollback records and web-only invitation review behavior.

## October 15 contextual website navigation

Completed and published PR #78, runtime `5d9906f`, on lane
`fix/web-context-navigation-20261015`. Context selection and management are
separate; organization/workspace/inventory navigation and creation dialogs adapt
the user's reference to FindEZ. 253 web tests, TypeScript, changed-file lint,
production build, all five CI gates and signed-in Safari checks pass. Existing
routes, APIs, memberships and data are preserved. Backend/database/mobile are
unchanged. Release and rollback details are recorded in CURRENT_STATE.md.

## October 15 organization and inventory access

Completed and published PR #77, runtime `5462d87`, migration 044. Organizations,
workspace overviews, inventory-specific roles, physical-location attachments and
audit history are live. Original data and legacy permissions preserved. All five
CI gates, 516 backend tests, 243 web tests, restored-copy migration rehearsal,
production build and signed-in Safari checks pass. See CURRENT_STATE.md and
`docs/plans/organization-inventory-access.md` for scope and remaining limitations.

## October 15 centered Ask FindEZ

Completed and published PR #76, runtime `80ba01b`, with centered Ask content,
static light/dark gradient, history dialog and right-aligned neutral user bubbles.
238 web tests, TypeScript, lint (zero errors), all five CI jobs and responsive
Safari previews pass. Live route/assets checks pass. Existing Safari login had
expired before the signed-in recheck. Backend/database unchanged; release and
rollback details are recorded in CURRENT_STATE.md.

## October 14 workspace and inventory selection

User explicitly authorizes planning and executing a website-wide hierarchy,
illustrated by Supabase organization/project pickers. Lane
`feat/web-workspace-inventories-20261014`, based on import runtime `bd1c8a1`,
owns: choose personal or Team workspace, choose inventory, then its dashboard.
Keep physical Spaces inside inventories and keep account/profile/billing global.
Scope Home, capture/import, Find, Assist context/history, documents, Review,
activity, lending, kits and browser purchase plans. Preserve existing ownership
and permissions; backfill source associations into default inventories without
deleting/reimporting customer data. Add an authorized server-side inventory API
boundary and ensure stale responses, caches, photo proofs and IDs cannot cross
inventories. Existing mobile and integration contracts remain compatible.
Implement two quiet selection pages, visible workspace/inventory switching and
context-preserving navigation. Validate different inventories, different members,
view-only roles, writes/reads, forged IDs, refresh/back and narrow layouts before
release. Import PR #74 runtime `bd1c8a1` is published with migration 042.
Completed and published October 15. Backend `eb3eee0` plus migration 043 and
website `eb67ce1` are live. Original values across 21 tables preserved, including
removed-owner legacy records. 511 backend/API-doc tests, 237 web tests, TypeScript,
SQL isolation/preservation checks and all five final-source CI jobs pass. Live
Safari confirms scoped navigation, capture, documents and Assist histories.
Release receipts and rollback paths are recorded in CURRENT_STATE.md.

## October 14 preserve uploaded inventory columns

Lane `feat/import-original-columns-20261014`, based on `7b44165`, owns durable
original column names and values for Excel/CSV/JSON imports, per-sheet mapping,
and imported details on mobile and web. The supplied workbook has 280 populated
rows in Sheet1 and 15 in a different Timing Belts layout, including unnamed
columns containing data. Preserve ordered duplicate/unnamed headers and structured
JSON values. Add an additive item snapshot column only after live-schema checking;
keep ordinary capture/CRUD and sharing permissions unchanged. Do not reimport or
modify existing customer inventory as verification. Settings/navigation PR #73
continues its separate exact-source release checks.

## October 14 Settings and navigation popup layout correction

Lane `fix/web-settings-rows-20261014`, based on `fc20f3a`, owns the user's
Settings screenshot follow-up. Text-only links inherit a three-column icon grid,
putting Plans/legal labels in its 32px icon column. Normalize link rows to a
flexible content column plus a trailing chevron, group existing Developer icons
with their labels, and keep Appearance compact. Preserve all routes, actions and
account state. All 223 web tests, TypeScript and Settings lint pass. Actual
component previews verify all sections in both themes and desktop/390px widths.
The top navigation popup also resets the independent utility translate, stays
inside short viewports, scrolls results beneath its visible input, removes repeated
section captions and restores trigger focus on close. Use the existing isolated
website release process. Published runtime `7b44165` after all five exact-source CI gates, 224 web tests,
TypeScript, changed-file lint, actual-config production build and Safari
short/narrow/both-theme previews. Live build `D-x-qQyJQDdszMNcrtfXh` uses
`web-settings-navigation-20261014/frontend`, preserves production configuration
and 1,064 prior static assets. 11 public routes, 17 auth guards and three CSS
assets pass; backend unchanged. Receipts/rollback are in the matching local
release folder and `/home/ubuntu/findez-settings-navigation-20261014`.
The user additionally requests durable
original spreadsheet columns across backend, mobile and web; that work follows
in a separate implementation lane.

## October 14 website clarity live

Lane `release/web-launch-20261014`, based on `4e71506`, is complete in PR #72.
Runtime `65226c5` removes repeated shell/Collections/Space titles and the redundant
FindEZ section caption. Open rows, quiet dividers, simpler filters/secondary
actions, consistent spacing and bounded Review photos replace crowded containers.
Teams uses its visible tabs for section identity, Project kits has one Space
prompt and Labels tabs have proper spacing. Sidebar contraction is verified and
the original pinned preference restored. Routes, actions and permissions remain.
223 web tests, TypeScript, the actual-config production build and all five
exact-runtime CI gates pass (`38683070099`); lint has existing warnings only.
Both-theme/narrow component fixtures and signed-in Safari pages are checked.
The live web service now uses `web-clarity-20261014-r3/frontend`, build ID
`bSG_l1U3Nn-HPx_vC7FHX`. Public checks cover 11 routes, 17 protected route guards
and three workspace CSS assets; 1,006 old static assets remain for open tabs.
Production configuration and the dirty VM checkout are preserved. Backend PID
and start time are unchanged. Receipts, source hashes, build log and rollback
records are in `Documents/FindEZ/Releases/web-clarity-2026-10-14/published` and
`/home/ubuntu/findez-web-clarity-20261014-r3`. Shopify and public Apple submission
remain held; pricing is planned UI with paid purchases unavailable. Supporting
backend reliability work is not deployed by this web-only lane.

## October 14 one-time guided tour fix and TestFlight preparation

The user authorizes an updated TestFlight beta, then requires the intermittent
returning-user tour bug fixed first. Lane `fix/first-install-tour` is based on
`89b1bb9`. Replace per-account signup/rearm triggers with one installation claim,
consumed before display. Migrate existing installs to quiet state, cancel delayed
starts on disposal/account changes, and remove later automatic Space tours.
All 375 mobile tests with coverage and five runtime CI gates pass; analysis is
clean. Native upgrade/Space/cold-restart checks pass. TestFlight 1.0.8 (65) is
VALID and available to the two existing internal groups. Vinod's existing private
group is assigned, but Apple rejects 65's external review submission while build
64 is WAITING_FOR_REVIEW. Retry the saved build-65 helper's `prepare` and `status`
after 64 finishes; 65 is READY_FOR_BETA_SUBMISSION, not externally available yet.
Runtime source is `8fbfacd`, PR #71. Durable signed IPA/archive/receipts are in
`Documents/FindEZ/AppStore/1.0.8-build65`. Public App Store selection is verified
unchanged, Shopify remains held and no production backend deployment occurred.

## October 14 launch reliability candidate

Lane `fix/launch-find-reliability`, based on `3543cb7`, fixes name-only capture
aggregation, silent limit truncation, unsafe retries and web/mobile partial draft
loss. Real saved receipts and account-bound requests preserve capture identity.
ASK exposes match evidence and recorded-location semantics with unknown counts.
The user explicitly defers visual-similarity work because FIND source is absent;
Shopify stays disabled. Five-tier web/mobile pricing UI is planned only. Stripe,
StoreKit purchases/restores, verified entitlements and new limits remain unbuilt.
455 backend/API-doc tests, 223 web tests, 362 mobile tests with coverage, analysis,
TypeScript and the fictional-config web build pass. The native arm64 simulator
build passes; Plans, annual prices and back navigation are checked in both themes
and Light is restored. No production migration/deployment or Apple upload/submission.
See `HANDOFFS/2026-10-14-launch-readiness.md` for the capability audit and next gates.

## October 14 app-wide neutral UI accent refinement

Lane `feat/mobile-color-accents` now covers the user's app-wide accent request:
all shared action/selection roles are neutral grey/glass; bottom navigation
retains dedicated orange tokens. Floating plus buttons, Space filter pills,
Teams invite/icons, chat, onboarding/tour and default button styles follow the
same roles. Brand artwork and accepted Home number colours remain. The final
arm64 simulator app is installed, with native checks in both themes and Light
restored on Find. Analysis and all 357 mobile tests with coverage pass.
Screenshot proof is in the existing mobile-colors design
folder. No customer writes, TestFlight upload or public submission.

## October 14 two neutral glass selectors complete locally

The user explicitly confirms Capture's Scan Barcode/Auto Extract selector and
Find's Spaces/Teams selector. Neutral grey selection glass replaces their
orange fills and orange selected foregrounds. Existing motion, callbacks,
navigation palette and high-contrast fallback remain. Analysis and all 357
mobile tests with coverage pass. A complete arm64 native simulator app is now
installed and running, including the accepted Home changes. Native Capture,
Spaces, Teams and Home are visually verified; screenshots/receipt are in
`Documents/FindEZ/Design/mobile-colors-2026-10-14`. The older attach-only preview
was not persistent across relaunch; the new installed app addresses that.
Capture's initially heavy grey pill is subsequently softened on user feedback:
lighter tint/outline and regular label weights, with high-contrast fallback
retained. Analysis and all 357 tests pass again; the updated installed app is
visually checked in light and dark themes and left on Capture in Light mode.
Native proof uses the `capture-soft-grey-glass` filenames in the same folder.
No new TestFlight upload or public submission. Wait for further directions.

## October 14 Home-only colour correction complete locally

Lane `feat/mobile-color-accents` in `dev/findez-mobile-color-accents`, based on
`3a36026`. The accepted scope is Home numbers only: mustard identifying,
purple buying, maroon out of stock, forest green lent. Cards/labels stay neutral;
search hint is smaller regular grey (14pt), with regular grey suggestion text
(12pt) and full-size typed input (17pt). Unknown counts retain neutral dashes.
Rejected card fills and other-page experiments are removed from the candidate.
Analysis, all 357 existing mobile tests with coverage and both-theme colour
contrast pass. Home is visually checked on the actual iPhone 16e debug simulator
after attach/hot restart, using the existing native shell. Proof is in
`Documents/FindEZ/Design/mobile-colors-2026-10-14/home-numbers-light-native.png`.
No new TestFlight upload or public submission. Wait for next-page directions.

## October 14 backend fixes live; mobile 64 internal TestFlight delivery complete

Lane `fix/capture-review-save-boundary` in
`/Users/tanyasmritivictorcharles/dev/findez-capture-save-boundary`, based on
`722b5c0` from punctuation PR #67. Capture previews are local to the client and
carry a bounded 24-hour signature binding owner, identity, source key, original
FIND evidence and photos. A new authenticated POST saves a preview into existing
`capture_reviews`; editable identity fields cannot replace signed observations
or photos. Duplicate saves reuse one source key, handled records cannot revive,
and tampering, another account or expiry fail before a queue write. Mobile/web
preserve proof through edits/confirmation and save only after the explicit action.
Old saved reviews keep PATCH/resolve/dismiss; extraction without the new flag
retains old-client compatibility. Chat photo questions no longer create reviews.

Local validation passes 438 backend/API documentation tests and six subtests,
212 web tests, TypeScript, changed-file lint with existing warnings only, 357
mobile tests, clean Flutter analysis and a production web build with fictional
configuration. Runtime `19089e9` in Draft PR #68 passes all five CI gates
(`38551614029`). Preflight matched eight existing backend file hashes and
confirmed both new helpers absent. The combined ten-file
backend bundle, patches and manifest are in
`Documents/FindEZ/Releases/capture-save-boundary-2026-10-14`. Web uses
the installed dependencies from an identical lockfile, with a gitignored local
node_modules symlink. Local build configuration is fictional and must not ship.
The user authorizes deployment. The ten backend files are selectively deployed
with guarded hashes and rollback backups at
`/home/ubuntu/findez-capture-fixes-20261014.1ztxtg/backup`. Unrelated checkout
files are verified unchanged. Service/database health, missing-session and
invalid-key 401s, reply punctuation, real preview signing, owner binding and
the signed save route pass without database writes or FIND/model requests.
Receipts are beside the source bundle. No migration or historical Review
deletion was performed. Updated web source is not deployed.

Mobile 1.0.8 (64), runtime `8001b13`, passes all five exact-source CI gates
(`38554740296`), clean signed archive/export, production configuration/assets,
strict signatures and all 31 native device-platform checks. Apple validation,
upload and processing complete without errors/warnings. Delivery
`3dc129af-4c32-48f7-a69d-d55c9e97cdef` is VALID/APP_STORE_ELIGIBLE/
IN_BETA_TESTING in Testers and Internal Pilot Findez AI with saved test notes,
verified at 04:54 PDT October 14. Durable receipts, archive/IPA and phone
acceptance checklist are in `Documents/FindEZ/AppStore/1.0.8-build64`.
The new binary uses preview-only extraction and the signed Save route.
TestFlight 63 stays available with the legacy Capture contract. No build-64
simulator or physical pass is claimed. Repeat physical camera/library
random-photo/cancel/Home, photo chat, explicit Save, retry and owner isolation
on build 64, plus the outstanding native service and accessibility checks.
Public App Store selection/release type are verified unchanged; public
submission and Shopify remain held.

Build 64 is also submitted to TestFlight beta review at the user's request for
one existing external tester. The private `Vinod Private Testing` group has
only that tester, no public link and build 64. Status at 05:08 PDT October 14
is WAITING_FOR_REVIEW/WAITING_FOR_BETA_REVIEW with automatic notification
enabled. The tester previously accepted FindEZ's invitation; Apple returns
ALREADY_ACCEPTED to resend, so no new invitation is claimed. External access
needs Apple approval. Receipts and the helper are in the build-64 release folder.
Existing internal groups stay available, the broader external pilot group is
unchanged, and public submission stays held. Do not grant App Store Connect
roles or remove/recreate the tester to bypass review.

## October 14 chat punctuation prepared

Backend-only lane `fix/ask-response-punctuation` in
`/Users/tanyasmritivictorcharles/dev/findez-chat-punctuation`, based on `1604e68`.
Shared response instruction and output normalization cover normal/streamed
text chat, deterministic project replies, photo explanations, document/image
upload replies and legacy EEZY. Normalization happens before session/history
persistence; it does not change user messages, tool payloads or source records.
Runtime `3b1c824` in Draft PR #67 passes all five CI gates (`38548331842`), all
426 local backend/API documentation tests and six subtests. The added tests
check emitted/final/session consistency and preservation of tool data, Unicode,
newlines, source labels and input. Preflight matched four live hashes and
confirmed the new helper absent. The exact five-file bundle,
patch and hash manifest are in
`Documents/FindEZ/Releases/chat-punctuation-2026-10-14`.
This is live in the combined deployment above; no schema, FIND, auth, frontend
or mobile source changes belong to punctuation. Existing history,
TestFlight 63 and held public submission remain as recorded below.

## October 14 build-63 internal TestFlight delivery complete

Final runtime `8abe3cc` on `feat/mobile-submission-polish` (PR #62) is delivered
as 1.0.8 (63) to both existing internal groups. Analysis, 353 mobile tests with
coverage, all five exact-source CI gates (`38543470459`), clean signed export,
production configuration/supplied assets, app/extension signatures, 31 native
device executables and Apple validation/upload pass. Apple delivery
`81fcc8ae-92f0-4d05-9dd0-e4a0a492e0c1` is COMPLETE without errors/warnings, and
63 is VALID/APP_STORE_ELIGIBLE/IN_BETA_TESTING with saved test notes at 02:56 PDT.

Includes Home Account/four tabs, light weights independent of OS Bold Text,
focused chat, concise import, supplied logo/Light default, setup X, compact tour,
spring navigation and neutral glass controls. Native Home/Account, image-backed
captures, Light/Dark glass choices, setup and empty Ask are checked; the inner
chip canvas is transparent to retain continuous glass outlines. Native typed
chat, full tour/import and physical accessibility/native-service acceptance are
still pending through the final TestFlight binary. No real inventory/setup writes
or global phone preferences were changed. User-authorized generated cache cleanup
resolved disk pressure, preserving source, signed packages and supplied assets.

Durable release records are in `Documents/FindEZ/AppStore/1.0.8-build63`.
The earlier validated candidate remains preserved and was not uploaded. Public
59, manual/unselected draft 1.0.8 and Shopify's separate paused source are
verified unchanged. Public App Review remains held; Shopify is excluded.

## October 14 Home account entry and stable light typography

Delivered in build 63 on `feat/mobile-submission-polish`. User removes the
Profile tab, moves its entry to the top of Home and requires stable light weights
regardless of iOS Bold Text. The pill now has Home/Capture/Ask/Find with four-tab
spring geometry. A small Home control opens Account, preserving profile editing,
settings, documents, notifications, lent items and setup questions. The same
profile store and live notification notifier serve both Home and Account; late
badge reads remain fenced. Shared body/input weights are 400 and emphasis caps
at 500; only automatic weight changes are suppressed. Text size and other
accessibility preferences remain. Shopify stays paused; no API/schema, native
lifecycle, production or Apple submission changes.

## October 14 spreadsheet clarity and focused chat

Delivered in build 63 from `feat/mobile-submission-polish` in
`dev/findez-logo-light-default`. User requests fewer import-page words/icons and
conversation focus after sending, in the existing screen. The import ready view
now shows the destination, Choose file and format/size limit. Existing picker,
validation, import, retry, partial-result reporting and navigation are retained.
MainShell uses ChatPage's message state to hide its pill during conversations.
Pinned Back returns to the previous tab without resetting the same ChatPage,
messages, draft or in-flight stream. New chat restores the normal Ask navigation.
No backend/API/schema, Shopify, production or Apple submission changes.

## October 13 mobile pre-submission polish

User requests an unbranded questionnaire header with an accessible X, exclusion
of pictureless imports from Home captures, a compact translucent guided tour,
350 ms spring navigation with fixed icons and Reduce Motion cross-fades, and
simpler Ask presentation. Source lane `feat/mobile-submission-polish` in
`dev/findez-logo-light-default` continues the authorized supplied logo and
Light-default changes from build 62. Existing source branding edits are preserved.
No App Review submission or production change is performed. Screenshot ZIPs are
uploaded and checksum/order verified in the 1.0.8 draft. The user's latest October
14 instruction pauses Shopify and excludes it from this launch. Preserve its
separate source, draft PRs and test resources; keep them disabled and unshipped.
Do not continue Shopify work until the user asks to resume.

## October 12 clarified tutorial and onboarding questions

The user identifies the six-step in-app spotlight tutorial, then requests useful
onboarding questions recorded for the operator. They choose intended use,
inventory types, primary goal, and working alone/with others, with production
database storage first. Current lane `feat/onboarding-questions` includes the
adaptive tutorial (`92d5f9a`), a four-question optional setup replacing demo
slides, account-bound pending answers, confirmed-save retry and Profile editing.
Migration 041 adds owned `onboarding_responses` with account-deletion cascade,
owner-only reads and backend-only writes; no Team/inventory data is generated.
419 backend, 211 web and 338 mobile tests pass; PostgreSQL isolation/validation,
clean analysis, native questionnaire completion and Light/Dark/Auth screenshots
pass. Production migration/API and privacy disclosure are selectively deployed
with private backups; authenticated save/read/idempotency/owner checks pass and
the new review-account QA row is removed. The user’s final outlined-choice
reference is implemented without radio circles or a decorative badge. Auth is
concise, with optional work-detail expansion and preserved signup eligibility.
All five exact-runtime CI jobs pass on `346d9ae` in `38346877463`. Clean signed
1.0.8+62 passes signatures/configuration, all 31 native device executables and
Apple validation/upload. Upload `3ab7200b-5045-499f-accb-2d5f4f7b6f2c` is COMPLETE
without errors/warnings; build 62 is VALID/APP_STORE_ELIGIBLE/IN_BETA_TESTING and
both existing internal groups/test notes are verified at 21:49 PDT October 12.
This lane is complete. Durable release records and the deferred phone checklist
are in `Documents/FindEZ/AppStore/1.0.8-build62`. Public 1.0.7 (59), manual/unselected
1.0.8 and requested metadata are unchanged. Physical acceptance remains deferred,
public submission held, and unrelated live VM work preserved. The older build-61
introduction is superseded and did not correct the spotlight tutorial.

## October 12 requested sequential updates

The user requests: exact App Store name `FindEZ: AI Inventory` and subtitle
`AI item recognition & search`; deletion of Space-owned Home attention/review
entries; broader inventory positioning and alphabetized/custom team categories;
and a cleaner first-launch walkthrough in Light/Dark. Name/subtitle are saved
in the editable 1.0.8 App Store draft (metadata requires a new approved version).
Build 60 is already delivered to both existing internal TestFlight groups.

Completed lane `fix/deleted-space-review-refresh`, based on `6a406e8`, in the
existing mobile-notifications checkout. Production review rows have only a
location string, so pending identifications survive Space deletion. Home/cache
also need immediate mutation invalidation. Migration 039 binds owned matching
reviews to a stable Space ID with cascade deletion and rename synchronization;
unassigned reviews and other owners remain separate. Mobile invalidates old
reads and refreshes Home after confirmed deletion without fabricating a count.
All 317 mobile tests/coverage, clean analysis and full disposable PostgreSQL 17
permissions/lifecycle checks pass. All five exact-runtime CI jobs pass on
`e3bb2f6` in `38310437658`, draft PR #56. Migration 039 is deployed with verified
cascade FK/triggers, unchanged pending count and healthy database. The mobile
fix awaits the combined next binary; web copy deploys with the next lane.
The web delete confirmation also describes item/review deletion accurately.
The user identifies deleted
Robot Room and provides their account privately for a targeted existing-entry
repair; do not write that email or private row snapshots to repository context.
Their Robot Room still exists with six pending records, so do not purge them as
orphans. Binding them to the current Space lets its next deletion remove them.
Completed lane `feat/inventory-team-categories`, based on `e34b37b`, adds 29
alphabetical general inventory group categories with a bounded persisted custom
label, neutral create forms and shared display labels. Migration 040 precedes
backend/client deployment. Existing program keys, licensing and access stay
compatible. README, current product context, learning guide and the legacy EEZY
prompt describe homes, businesses, labs, teams and industry. Focused backend,
mobile Light/Dark failed-draft and PostgreSQL checks pass; full checks/deployment
pass. All five CI jobs pass on `2384bbd` (`38312460669`, draft PR #57).
Migration 040, selected backend files and isolated web release are deployed;
private backups/verified manifests and web rollback remain available. Public
checks pass without creating real data. Current lane `fix/onboarding-light-dark`
from `2384bbd` simplifies the four local examples in both themes while preserving
Skip/Back/replay/invitation/launch state. All 319 tests, clean analysis and rendered
Light/Dark/narrow/large-text checks and native walkthrough completion/restart
pass. All five CI jobs pass on `86669ee` (`38314482069`). Apple validation catches
a cached simulator `objective_c.framework` in the first signed 1.0.8+61 export;
the rejected package/receipts are preserved. Clean runtime `5acd4c7` passes all
five CI jobs in `38336413029`, strict signatures, production configuration and
device-platform checks for 31 native executables. Apple validation/upload pass
without errors at 19:27 PDT October 12; delivery
`f6a6c33f-7c34-4091-8df7-1c4ebf35e274` is COMPLETE without errors/warnings.
Build 61 is VALID, APP_STORE_ELIGIBLE, nonexpired and IN_BETA_TESTING; both
existing internal groups and saved test notes are verified at 19:31 PDT.
This delivery lane is complete. Durable archive/IPA, verifier,
receipts and deferred phone checklist are in `Documents/FindEZ/AppStore/1.0.8-build61`.
Public App Store submission remains held; released 59 and the manual/unselected
1.0.8 draft, including requested metadata, are verified unchanged after delivery.
Physical phone acceptance remains deferred by the user.

## October 12 build-60 TestFlight delivery

The user authorizes TestFlight upload/internal-group delivery with phone testing
still deferred. Apple has approved/released 1.0.7 (59); the US storefront confirms
1.0.7 and ASC reports `READY_FOR_SALE` with selected 59 and manual release type.
The original 1.0.7 (60) validation fails because that train is closed. Runtime
`a6ea4c5` changes only version metadata to 1.0.8+60. All five CI jobs in
`38302159412`, signed archive/export, strict app/extension signatures, App Store
profiles and production configuration checks pass. Apple validates and accepts
upload `87711752-2586-445c-a2a5-ebc12e7b4b94` at 13:17:03 PDT.
Apple processing is COMPLETE without errors/warnings. Build 60 is VALID,
APP_STORE_ELIGIBLE, nonexpired and IN_BETA_TESTING. Both existing internal groups
include it and the test notes are saved; public build-59 selection/manual release
type are verified unchanged. Phone acceptance remains deferred. No
App Store selection, review submission or public release change is authorized.
Durable artifacts are in `Documents/FindEZ/AppStore/1.0.8-build60`.

## Native notification permission and read state (October 11)

Sequential lane `fix/mobile-notification-permissions` in
`/Users/tanyasmritivictorcharles/dev/findez-mobile-notifications`, based on
`5b21899`. Existing OS authorization reconnects without a launch prompt; the
inbox has an explicit Enable action and denied permission links to Settings.
Registration is serialized, bounded natively and guarded against an account
change. Device writes capture authentication. Logout stops OS delivery and clears
alerts; next registration reassigns the server token to the authenticated user.
The app does not issue a server token-delete request during offline logout.
Inbox reads are explicit, re-fetch after a successful write, keep rows on failure,
refresh while visible/resumed and publish validated account-scoped counts. Shell
generations prevent late badge reads from undoing inbox writes. The auth gate
keys the shell by account; old routes close on account changes. Local stock
refreshes no longer trigger the first permission request; setting a threshold
remains the explicit reminder action. Decorative feed cards/dividers and the
test-push toolbar action are removed.

All 312 mobile tests with coverage and clean analysis pass, including a delayed
shell-count regression; Swift parses and native simulator compilation succeeds
with production defines. Candidate is 1.0.7 (60). Signed archive/export and
October 12 package verification are complete: strict main/extension signatures,
App Store profiles, production configuration/APNs and compiled feature markers
pass. All five runtime CI jobs pass on `37c5055` in `38210945770`, draft PR #55.
IPA SHA-256 is `4f07de9e189809ef219a9cf9aa5558cd8a16a1231184b6be188882f7e5c208bc`.
The durable package in `Documents/FindEZ/AppStore/1.0.7-build60-prepared` includes
verification JSON/script, checksums, phone acceptance checklist and the requested
legal/privacy follow-up report. Apple server validation/upload/submission are not
performed. The user explicitly chose preparation now and physical testing later
because the connected iPhone is unavailable. Keep camera/library/voice, public
legal links, actual APNs delivery/tap/badge and logout/relogin acceptance pending.
Do not upload or replace pending App Review build 59 without release authorization.

## Canonical legal and permissions (October 11)

Sequential lane `fix/canonical-legal-pages` in
`/Users/tanyasmritivictorcharles/dev/findez-canonical-legal`, based on `a67260e`.
Prepared web Privacy/Terms, informational cookie notice, simple public navigation,
legacy page redirects, signup acknowledgment and honest deletion-failure copy.
Mobile links open the same public documents; purpose strings describe actual
camera/library/voice uses and unused location/save-photo declarations are removed.
Official registry verifies AI ROBOTS INC (4578465), Active, filed March 16, 2020,
887 Poppy Ct, Sunnyvale, CA 94086. Current facts, legal-review priorities and
engineering limitations are recorded in CURRENT_STATE. Web 210 tests, TypeScript,
changed-file ESLint, webpack build and Safari public-page checks pass. All 301
mobile tests with coverage and clean Flutter analysis pass. Web `1e6a8b3` is live
from `web-canonical-legal-20261011`, draft PR #54; all five CI jobs pass on
`d459df3` (`38209066849`), whose web source is identical and whose signup checkbox
has its own Material layer for the newer Flutter CI version. Server build/tests,
public guards/redirects/assets/docs/origins and Safari pass. 702 old static files
are retained with a rollback drop-in. No new native binary, push-delivery
acceptance or Apple submission is claimed yet.
Mobile notifications remain the next scoped lane. Preserve pending build 59.

## Notification refresh and read state (October 11)

Sequential second lane: `fix/notification-refresh` in
`/Users/tanyasmritivictorcharles/dev/findez-notification-refresh`, stacked on #52.
Web bell counts consume account-scoped inbox snapshots and invalidate pending
reads after writes; cross-tab invalidations trigger a fresh server read. Inbox
refreshes on focus/visibility and every 30 seconds while visible, preserves rows
during refresh/failure, validates payloads, and re-reads after marking read so a
new event stays unread. Empty copy explains the Team feed. Tests cover failed
reads/writes, account switches, stale badge responses and new events during reads.
All 203 web tests and 380 backend/API-doc tests pass; TypeScript and ESLint have
no errors (one intentional generation-ref warning). Web webpack compilation
passes with the fictional local environment. Safari confirms a successful read
clears both the unread dot and bell immediately. Broadcasts carry a source ID
to avoid invalidating the sender document twice. Runtime `0189a17` is live from
`web-notification-refresh-20261011`, draft PR #53 stacked on #52. All five CI jobs
pass (`38204481906`); server build/tests and public guards/assets/origins/headers
pass, with zero production dependency vulnerabilities and 622 old static files
retained. A rollback drop-in and source manifest are beside the release.
No backend runtime, schema or native files are
changed. Seven focused notification backend/APNs tests pass.

Read-only production checks confirm recipient/read/activity/push tables and
APNs configuration/key file availability. No push message was sent; neither
configuration nor mocked APNs payload tests prove physical delivery. Native
auto-permission prompts, inbox badge/read races and physical push acceptance must
be addressed with the later mobile permissions/link lane and a new binary.
Keep pending build-59 App Review unchanged until explicit release authorization.

## Professional interface, notifications and canonical legal pages (October 11)

User requests sequential completion: (1) Markdown and cleaner chat, (2) less
unnecessary web chrome/copy and lines, (3) tab titles with a vertical bar,
(4) a pinned sidebar that resizes the page, (5) working notifications,
(6) consistent, readable Privacy/Terms opened on the website from mobile,
(7) appropriate cookies/permissions and a concrete lawyer-review report,
(8) removal of redundant marketing dropdowns/pages from legal browsing.

Current lane: web-only `fix/web-professional-polish` in
`/Users/tanyasmritivictorcharles/dev/findez-web-professional-polish`, based on
`9073143`. Markdown is safely rendered with generated images/raw HTML disabled;
Sources collapse, history is unboxed, redundant copy/status is reduced, empty
states/list wrappers lose decorative borders. Tab titles are contextual and use
`|`. Sidebar has a keyboard-accessible pin, blank-area double click, remembered
preference and responsive frame sizing; the closed narrow drawer is inert.
The user explicitly corrected the font scope: keep the current app font, change
AI responses only. Source Sans 3 is self hosted for those responses. Next.js and
compatible dependency patches are applied; production npm audit reports zero
known vulnerabilities. Full web run passes 195 tests; TypeScript, changed-file
ESLint (no errors, existing warnings) and production webpack compilation pass.
Safari checks confirm Markdown, Sources, desktop pin resizing, clean Home and
notification/settings layouts. Home hides zero-work attention sections and
suggestion chips; pending reply status is scoped to its message during retries.
The web lane is deployed; no new native binary is delivered for this lane.

Fictional browser fixture: `/private/tmp/findez-web-polish-fixture.cjs` on
localhost:4109 (session 13259), production Next on 127.0.0.1:3017 (session 80626).
`frontend/.env.local` contains fictional local URLs only and MUST NOT be deployed.
Safari has an isolated `Ask | FindEZ` tab, verified bold/list rendering, source
disclosure, double-click pinning and page resizing. Do not alter real inventory.
The isolated server candidate is `web-professional-polish-20261011`. Preflight
hashes preserve 217 baseline files; its source archive excludes the local fixture
environment. Three unrelated live presentation files (globals.css, shared dialog,
spreadsheet import modal) are carried unchanged from the previous running release.
Collections uses the existing theme tokens to correct hardcoded dark-mode text.
Older live tests are replaced with the current repository tests, including the
previously missing review queue suite. Source manifest and rollback drop-in are
beside the candidate. Runtime `6960b2d` is live; all five PR-head CI jobs pass
(`38203294862`, draft PR #52, stacked on #51). Candidate and public HTTPS checks
verify title/headers, all 18 protected page guards, 16 static assets, exact API
reference and production origins with no fixture URL. Both services are healthy;
527 previous static assets are retained. Safari also verifies light-mode replies
and the 800px drawer's background isolation/open/close behavior. Notification
behavior and legal/mobile content remain the next lanes.

User confirmations: AI Robots Inc, registered in 2020 in Sunnyvale on Poppy Ct.
Official California registry details have now been verified as recorded above.
Serve countries where Apple permits availability; student accounts are 13+.
Analytics/advertising are not in use and no providers are selected. Cookie
disclosures must reflect actual essential storage; do not add trackers or fake
optional consent controls. Canonical mobile legal links/permission changes will
need a new iOS binary. Do not replace the pending build-59 App Review submission
without explicit release authorization. Remaining lanes: notifications, then
shared legal/content/permission controls and public navigation cleanup. Legal
accuracy needs primary-source research, factual data-flow audit, and specific
lawyer-review gaps; do not promise protection from all legal risk.

## Ask photo clarity (October 11)

User-requested fix for repetitive, confusing image replies in web and mobile.
Backend-only lane `fix/ask-photo-summary` in
`/Users/tanyasmritivictorcharles/dev/findez-ask-photo-summary`, based on `7de3913`.
The shared photo formatter groups duplicates, puts clear identifications first,
summarizes uncertainty and stock once, omits noisy categories and generic unknown
matches, and shows measurements only when requested. For noisy scenes without
product identifiers, the existing language gateway selects at most three coherent
main subject labels using validated indices; it cannot introduce an identity or
stock fact. The 12-second timeout and invalid/unavailable-response fallback keep
deterministic output available. Preserve the SSE/snapshot contract, access scope, Review
persistence and explicit inventory confirmation. Existing clients consume the
same text; no mobile binary or web rebuild is required. Focused photo tests pass
(60). Full backend suite passes (376), and all five exact-runtime CI jobs pass
on `fefcfe9` (`38195426179`). Draft PR #51 is stacked on #50. Both reviewed backend
files are deployed with original hash guards and backups in
`/home/ubuntu/findez-ask-photo-20261011`. Live consolidation with synthetic labels
returned a validated subject in 4.66 seconds; no source image or inventory data
was sent to selection. Both deployed hashes match, `findez` is active, and
public `/health` and `/health/db` return 200 on the configured API origin
`https://findez.openstack.ftctools.com`; unauthenticated `/ai_photo_question`
returns 401. The initial public check used the obsolete `api.findez.ai` hostname;
current-origin verification is recorded in `deployment.json`. Original dirty VM
work, both clients and the pending App Review binary are preserved. Genuine new
image recognition still needs user acceptance; saved conversations are not
rewritten, and consolidation does not guarantee every underlying identification.

## App Review clarification and native screenshots (October 8)

Continued on `fix/app-review-build58` in
`/Users/tanyasmritivictorcharles/dev/findez-app-review`, based on `669dde0`.
Apple rejected submission `2b777948-f7bd-46b3-bf43-9a2e60074361` for AI information
and non-iOS screenshot status bars. The developer confirms that FIND and agent
model inference run on their own servers. Source and running non-secret backend
configuration match that architecture. Optional Apple Speech transcription and
user-configured external API assistants are separate exceptions and must be
disclosed. Mobile Privacy Policy and Terms still named OpenAI in submitted 58;
the correction is prepared as candidate 59. Runtime AI, permissions and API
behavior remain unchanged. All twelve genuine build-58 iPhone/iPad captures are
verified using the existing review sample account, with no inventory writes.
Runtime `68fbe55` passes analysis, all 296 mobile tests with coverage, formatting,
native simulator compilation and all five shared CI jobs (`37866116183`). Native
59 opens with the corrected effective date; compiled debug and release text
checks verify all disclosures and absence of the obsolete OpenAI wording.
Signed archive/export, strict exported signature, App Store provisioning,
production API/auth and push configuration all pass. Durable IPA, draft response,
screenshots/ZIP and verification JSON are in
`Documents/FindEZ/AppStore/1.0.7-review-fix`; Draft PR #50 is stacked on #49.
Local storage interrupted the first builds; user-approved build/dependency/cache
cleanup recovered them. Original artwork, source, production and public release
are preserved. The user authorized continuing the prepared delivery. Apple
validation and build-59 upload pass without errors (delivery
`4c3ff9ff-6310-48cb-91ff-79c89af796d3`, 18:08:32 PDT). All six native iPhone and
six iPad screenshots are uploaded, COMPLETE and verified in order/checksum;
smaller sizes inherit these sets. The clarification is sent and visible in the
review thread at 18:09 PDT. Build 59 is VALID/APP_STORE_ELIGIBLE, nonexpired and
IN_BETA_TESTING. It is selected for 1.0.7, and the existing submission was
resubmitted at 18:19:39 PDT October 8. Submission/version are WAITING_FOR_REVIEW.
Manual release remains selected and public build 17 remains live. All five
docs-head CI jobs pass (`37867707683`, `28f8ffe`).

## Landing copy and returning-user navigation (October 8)

Implemented and deployed on `fix/landing-dashboard-link` in
`/Users/tanyasmritivictorcharles/dev/findez-web-navigation`, based on `f36ca25`.
Runtime `a4d1fc1` removes the hero's chatbot/database paragraph and replaces top
signup/sign-in actions with Dashboard for signed-in visitors. The landing uses
server-verified initial identity; marketing navigation follows browser session
events. All 184 web tests, TypeScript, lint and local/server builds pass. Safari
verified the live anonymous hero, fictional signed-in landing/desktop marketing
headers and mobile Dashboard opening Home. Final CI evidence is recorded on
draft PR #49, stacked on #48. Self-hosted release:
`/home/ubuntu/findez-web-releases/web-landing-dashboard-20261008/frontend`.
Interior source, animation/assets, API, backend, mobile, production environment,
original dirty checkout, existing collection colors and prior assets are retained.

## Web navigation and hover sidebar (October 8)

Completed and deployed on `fix/web-navigation-hover` in
`/Users/tanyasmritivictorcharles/dev/findez-web-navigation`, based on `5473694`.
Runtime `0cc9f44` uses a persistent workspace layout, per-page authentication,
content skeletons and smooth hover expansion/collapse over a stationary page.
181 web tests, TypeScript, lint, local/server builds and all five runtime CI jobs
pass. Safari read-only checks cover all 18 sidebar destinations, live data,
mouse/focus behavior and public docs theme cleanup. Self-hosted release:
`/home/ubuntu/findez-web-releases/web-navigation-hover-20261008/frontend`.
Original dirty checkout, backend, landing, API/docs and existing collection
heading colors are preserved. Draft PR #48 is stacked on the web rebuild.

## Web mobile-parity rebuild (October 6)

User-authorized authenticated web rebuild on `web/mobile-parity-rebuild` in
`/private/tmp/findez-web-rebuild`, based on submitted mobile build-58 record
`1e36998`. Mobile defines feature semantics; supplied desktop prototype guides
layout only. Preserve marketing, production data, public API contracts and docs.
Scope: desktop navigation, Home/Spaces/Find, grounded/photo Ask, account-local
Restock, item galleries, Documents/notes, existing collaboration/utilities, and
visible loading/retry states. Implemented and deployed to the existing self-hosted
server on runtime `afea356`; systemd `findez-web` uses isolated release
`/home/ubuntu/findez-web-releases/web-mobile-parity-20261006-live/frontend`.
The dirty original VM checkout and previous builds remain recoverable. All 176
web tests with coverage, TypeScript, lint with no errors and production webpack
build pass. Native Safari verified desktop and 390px flows with fictional local
data, then actual live Home/Documents/Restock/profile reads. Profile signup
recursion is covered by a regression. Public HTTPS/static/auth checks pass;
landing content and all public API/docs/assets remain preserved. Backend,
mobile and schema are unchanged. Draft PR #47 targets `release/appstore-build58`
to keep the diff web-only; exact-head shared CI is recorded on the PR. Full live
file-write, multi-account and collaboration acceptance was not repeated.

Update this file when work starts, changes owner, becomes blocked, or lands. Do not
list ideas as active work.

## Verified active work

The October 5 instruction authorized the original submission. FindEZ AI 1.0.7
(58) was submitted at 2026-10-06 06:06:37 UTC (October 5, 11:06 PM PDT), then
rejected on October 7 for AI information and non-iOS screenshot status bars.
Submission `2b777948-f7bd-46b3-bf43-9a2e60074361` remains rejected. The October 8
correction package above is prepared locally; manual release is preserved.

All six supplied iPhone PNGs and six supplied iPad PNGs are uploaded in order,
COMPLETE, and checksum-identical to the ZIP originals. Listing description,
subtitle, promotional text, keywords, release notes and reviewer instructions
follow the supplied physical-memory vision and contain no em dashes. Future
roadmap features are not advertised as implemented. Reviewer login, eight live
read endpoints, six consistent sample-inventory reads, website/privacy URLs and
all five exact-runtime CI jobs pass. Simulator Home/Spaces were observed; a full
physical-device acceptance pass was not repeated. Public version 1.0.6 (17)
remains available while the review correction is prepared. Runtime, backend, database,
billing, original logo assets, native lifecycle and FIND transport are unchanged.

| Work | Area | State | Dependencies and handoff |
|---|---|---|---|
| App Store review correction | Apple listing, screenshots and release records | October 7 rejection `2b777948-f7bd-46b3-bf43-9a2e60074361` was corrected and resubmitted October 8 at 18:19:39 PDT. Version 1.0.7 selects VALID/APP_STORE_ELIGIBLE policy-only build 59 (`68fbe55`), WAITING_FOR_REVIEW, manual release. | All twelve native screenshot replacements are COMPLETE and verified; the four-answer AI reply is sent October 8 at 18:09 PDT. Apple validation, upload, selection and resubmission are verified. Original artwork and release records are preserved in the durable AppStore folder; Draft PR #50 records the correction. Physical acceptance was not repeated. |
| Mobile accent consistency | `mobile/` shared brand accents, monochrome Teams list and Team file icons | Released build `1.0.7 (58)` on runtime `9657aed`, `fix/mobile-accent-consistency` in `/private/tmp/findez-accent-consistency`, Draft PR #46 stacked on PR #45 (`64c4e47`). Clean analysis/all 296 mobile tests with coverage, actual-shell Light/Dark palette/navigation previews, all five exact-source CI jobs (`37412454402`), signed export/config/logo/signature and Apple validation pass. Upload accepted with no errors at 21:16:01 PDT October 5 (delivery `b9a53267-2cea-4d13-903f-a885f9e62351`); COMPLETE/VALID/APP_STORE_ELIGIBLE, nonexpired and both internal groups verified at 21:20:52 PDT. | User rejected build 57's orange list and requested this page black/white. Create/Join/Team/file icons, selected Teams segment and bottom-nav highlight while Teams is active are neutral. Other main screens keep restrained brand accents. Artifacts/manifest: `/private/tmp/findez-build58-native` and `/private/tmp/findez-build58-verification.json`. Builds 56/57 remain VALID in both internal groups with verified artifacts preserved; 55 was not uploaded. Physical acceptance follows the user's TestFlight choice; public App Store remains held. No backend/web/schema/billing/FIND/native lifecycle change. |
| Restock planner replacement | `mobile/` purchase planning, inventory/Home/Space summaries and arrival stock confirmation | Implemented as candidate `1.0.7 (54)` on `feat/mobile-restock-planner` in `/private/tmp/findez-restock-planner`, based on released build-53 record `3a08fd1`; clean analysis and all 292 mobile tests/coverage pass. All five exact-source CI jobs (`37406983954`), signed archive/export/configuration/logo/signature and Apple validation pass on runtime `98f019e` (Draft PR #45). Uploaded at 20:09:15 PDT October 5; Apple processing is COMPLETE/VALID/APP_STORE_ELIGIBLE and both internal groups are verified. User supplied the build-54 planner screenshot and requested less copy; compact presentation and amber To buy/blue On order feedback are implemented for build 55 in this same lane. All 296 tests with coverage and clean analysis pass, including 22 restock regressions; all five exact-source CI jobs (`37408858103`), signed/config/logo/signature checks and Apple validation pass on `5d24797`. Build 55 is preserved but not uploaded after the user requested app-wide brand consistency; stacked brand PR #46 includes these changes in released build 56. | Explicit To buy, On order and Record arrival, editable quantities, per-item opt-out, inventory chooser and consistent counts replace disconnected checkmarks. Old thresholds/ordered selections migrate with account isolation; confirmed absolute stock saves retain safe lost-response retries. Planning remains account/device-local; real stock uses existing authenticated APIs. New logo/typography and unrelated flows are retained. No backend/web/schema/billing/FIND/native lifecycle change. User chose TestFlight verification; public App Store remains held. |
| App-wide typography consistency | `mobile/` shared typography, all screens/forms and regressions | Uploaded as `1.0.7 (53)` at 19:00:26 PDT October 5; all 274 mobile tests/coverage and analysis pass on `fix/mobile-home-bold-text` in `/private/tmp/findez-home-bold-text`, based on release `e123c22` | User confirmed iPhone Bold Text is enabled and supplied Cal AI as a typography reference. The user approved build 52 Home on the phone, then requested the same policy across the whole app. Build 52 was validated/installed and user-approved on Home but not uploaded; The complete app-wide replacement beta 53 is uploaded and draft PR #44 reflects that scope. Exact-source `afc39ac` has all five CI jobs passing (`37398740825`); signed archive/export, production-config/logo, strict signature and Apple validation pass. Native install completed, but launch/visual checks are unverified after the user chose TestFlight verification. Apple accepted delivery `67e8af04-e91a-4157-aa8d-e758c3222d3b` with no errors; `VALID`/`APP_STORE_ELIGIBLE` and both existing internal TestFlight groups are verified. Artifacts/manifest are preserved under `/private/tmp/findez-build53-native` and `/private/tmp/findez-build53-verification.json`. Apply supporting text Medium and headings/counts to Semibold without disabling OS text scaling or changing global accessibility preferences. Preserve logo, routes, API/schema/backend/web/FIND and native lifecycle. |
| Current TestFlight beta build 51 | `mobile/` release metadata and Apple beta upload | Uploaded on `release/testflight-current` in `/private/tmp/findez-testflight-current`, runtime/release commit `15b6374`, based on latest mobile head `671e304` | Includes branding, appearance, Space icons, onboarding, November pilot copy and the cold Home-to-Space fix. Analysis/265 tests, signed archive/export/configuration, supplied-logo verification, Apple validation/upload and native install/process launch pass. Apple processing is `VALID`/`APP_STORE_ELIGIBLE`, with both existing internal groups verified. No backend/schema/FIND, billing implementation or public App Store submission is part of this beta release; full physical acceptance remains open. |
| Cold Home-to-Space launch fix | `mobile/` inventory loading/navigation | PR #42 runtime `ab506f2` on `fix/mobile-home-space-cold-load` in `/private/tmp/findez-home-space-fix`, based on `2758498`. Actual-shell regression failed before the fix; confirmed reads, retry, true empty data and duplicate/disposal guards now pass. All 265 mobile tests/coverage, analysis and five CI jobs pass (`37385102041`). | Source-only; no new native install/device claim or Apple upload/submission. Exact Space IDs, filters, drafts and routes retained. Separate backend PR #43 deployed private documents with disposable access/revoke checks; item-photo privacy and legal publication remain pending. Preserve FIND and native lifecycle work. |
| Free-pilot date correction | Backend notice, dormant web copy and mobile pilot card | Implemented on `fix/free-pilot-november1` in `/private/tmp/findez-pilot-november`, based on onboarding head `19da889`. November 1, 2026 is the final advertised free-pilot day; following-day copy says November 2. Live backend notice and dormant web source copy selectively deployed with rollback copies. All 350 backend, 134 web and 260 mobile tests, Flutter analysis, TypeScript, web builds and connector/bundle checks pass. | Keep `PILOT_MODE`, public-pilot visibility, limits, Stripe guards, optional end-date configuration and manual activation unchanged. The existing `/pricing` redirect and web artifact are preserved. Mobile API/fallback/cache and 320pt Light/Dark card wrapping are tested through 3.4x; mobile fallback/layout remain source-only for the next approved binary. Dirty production work/FIND are preserved; Apple upload/submission remains held. |
| Physical-memory first-launch onboarding | `mobile/` onboarding presentation and launch gate | Implemented as local `1.0.7 (50)` on `feat/mobile-physical-memory-onboarding` in `/private/tmp/findez-appearance`, based on icon-picker PR #38 (`bea71f5`). PR #39, runtime `f6782d3`, passes all 246 mobile tests/coverage, clean analysis and all five CI gates (run `37265597966`, repeated on docs head `ff15a5d` in `37265970841`). Four concise branded screens, interactive local graphics and reduced-motion transitions; final native simulator build also passes. | Fresh signed-out installation shows onboarding before Auth; returning sessions, completion, invitation inbox and replay/legacy signup state are preserved. No sample inventory/Space writes, permissions, backend/web/schema/FIND or native lifecycle changes. Dark/Light/Larger and sample controls verified. Native signed-out flag-reset cold launch -> four-step completion -> Auth -> restart/Auth verified without erasing app data; original confirmed completion restored. Simulator retains Dark/Default and is left on sign-in. Physical touch/VoiceOver/fresh auth remain deferred. Apple uploads/submission remain held. |
| Personal Space icon picker | `mobile/` Space presentation/preferences | Implemented as local `1.0.7 (49)` on `feat/mobile-space-icon-picker` in `/private/tmp/findez-appearance`, stacked on brand PR #37 (`1d49e27`). Searchable 24-icon picker from the leading icons in personal/owned, joined/shared and Team Space lists. Account/stable-ID device-local choices, Automatic reset and explicit Save/Cancel; all 226 mobile tests/coverage, analysis and native simulator build pass. | Simulator verifies search, Cancel, confirmed card update, restart persistence and both themes/Larger text. Personal preference only, not synced or shared to other members. Permissions, API/schema/backend/web/FIND, nav and native lifecycle remain unchanged. Physical touch/accessibility acceptance deferred; no phone install or Apple upload/submission. |
| Mobile brand theme and duplicate sheet handles | `mobile/` presentation and assets | Implemented as local `1.0.7 (48)` on `feat/mobile-brand-theme` in `/private/tmp/findez-appearance`, stacked on appearance PR #36 (`def3d3c`). Supplied outlined SVGs/native icon, exact light tokens/readable dark roles, neutral legacy UI and single editor grabber. All 203 mobile tests/coverage, analysis and native simulator build pass. Simulator confirms Light/Dark/System, larger text, restart persistence and single handles. | Simulator only; no phone install or Apple upload/submission. Preserve five-icon nav, routes, drafts, API/schema/backend/web/FIND and separate native lifecycle work. Physical appearance/QR/photo/swipe gates remain. Cold Home-to-Space showed an empty list while Find-to-Space was populated; unchanged routing must be checked in a separate release lane. |
| Mobile appearance and text size | `mobile/` presentation/preferences only | Implemented as local `1.0.7 (47)` on `feat/mobile-appearance-accessibility` in `/private/tmp/findez-appearance`, stacked on `df7e1d1` / PR #35. All 190 mobile tests/coverage and analysis pass. Persisted Light/Dark/System and four OS-composed text sizes; adaptive screens and contrast/layout/save-failure regressions. Simulator verifies live appearance changes, restart persistence, large text and existing navigation/item-info presentation. | User chose simulator-only verification: no phone install or Apple upload/submission. Physical photo/QR/accessibility/swipe acceptance remains deferred; CUA mouse drags did not dismiss the simulator panel, while automated swipe regressions pass. No backend/web/schema/FIND or native lifecycle changes. Preserve icons-only navigation, data and routes. |
| Release backend cache correction | `backend/` Space cache and release records | Isolated `fix/release-cache-find-transport` in `/private/tmp/findez-ask-reference`, based on `2376d0f`. Cache-only PR #35, runtime `6027a87`, passes all five CI gates (run `37240403382`), six new regressions and all 349 backend/API-doc tests. Exact `spaces_repo.py` selectively deployed with rollback copy; health/database, live QA and build-46 simulator rename/count pass. Post-deploy API access/revocation also passes. | User explicitly withdrew the FIND transport change on 2026-10-04. No FIND runtime/configuration/proxy change was made. Preserve the existing HTTP route and allowance unless newly authorized; its unencrypted hop remains a documented risk. Keep mobile/API shapes/schema/real data unchanged. |
| App Store build-46 submission | App Store Connect and release records | Held on 2026-10-04 on release records based on PR #34. Draft selects valid/eligible 46, manual/unsubmitted; privacy URL and dedicated verified review login saved. Five test-only items seeded; API access/revocation and six simulator tab cycles pass. Initial rename failure was corrected and selectively deployed in the approved backend lane; immediate live/API and simulator counts now pass. | Updated screenshots, physical multi-account/offline/photo/profile/Documents, filtered rename and real invitation acceptance remain outstanding. Mirroring reports iPhone in use. Preserve public build 17, pricing, real data/memberships, Team-only AASA and separate lifecycle work. Do not fabricate privacy/legal answers or mark API/simulator results as physical passes. User excluded FIND transport changes; leave that connection unchanged and retain the known risk. |
| Swipe-down item detail dismissal | `mobile/` inventory sheet and regression tests | Released as `1.0.7 (46)` on PR #34, `fix/item-detail-swipe-dismiss`, stacked on approved navbar PR #33 in `/private/tmp/findez-ask-reference`. Build 45 was held and not uploaded after uneven-exit feedback. Corrected runtime `78404fa` passes all 135 mobile tests/coverage, clean analysis and all five CI gates (run `37033574121`). Exact signed 46 installed/launched; user-confirmed smooth Parts Room exit. Apple validation/upload passed; `VALID`, `APP_STORE_ELIGIBLE` and both internal TestFlight groups are verified. | Shared item-info panel in personal, shared/joined and Team Spaces, not Edit item. Coordinate top-of-content dragging with scrolling, keep dismissal latched during route exit, and preserve the layout and Close fallback. Guard unsaved notes and pending writes before dismissal. No backend, web, API/schema, branding or native lifecycle changes. Public App Store remains unchanged; the later draft selection and submission hold are recorded in the release row above. |
| Icon-only mobile navigation | `mobile/` shell navigation and tests | PR #33 on `fix/icon-only-mobile-nav`, based on released build 42. Build 43 was not uploaded; the user rejected its tall appearance. Compact build 44 passes 117 mobile tests/coverage, visual capture, clean analysis and all five CI gates on runtime `42f977c`. Exact signed 44 installed/launched and the user approved its appearance. Apple validation/upload passed; `VALID`, `APP_STORE_ELIGIBLE` and both internal TestFlight groups are verified. | Use a 56pt visible bar, circular selected highlight and safe-area spacing outside the pill. Preserve icons/order, accessible names, avatar, routes and tutorial targets. Builds 42-45 are recoverable from verified private server backups; 42 stays in TestFlight. The App Store draft has since advanced to 46 as recorded above. Branding, page content, backend/web and native lifecycle files are out of scope. |
| Space and Team invitation links | `backend/`, `mobile/`, invitation web pages | Implemented/pushed on `feat/workspace-invite-links` (PR #32, runtime source `0b4c207`); reviewed backend/web deployed and healthy. Final `1.0.7 (42)` is `VALID`, `APP_STORE_ELIGIBLE`, and assigned to both internal TestFlight groups. | 343 backend/133 web/114 mobile tests, MCP/bundle checks, analysis/typecheck, production web compilation and all five CI gates pass. Exact signed build 42 installed/launched; the user confirmed its cold Team and real Safari Space prompts, with no real membership changed. App Store 1.0.7 draft has since advanced to 46, still manual/unsubmitted. Fresh-install continuity, real acceptance/revocation and broader physical/security gates remain before submission. Keep Team-only AASA while public build 17 is live. Preserve separate lifecycle work. |
| Flutter UIScene lifecycle migration | `mobile/ios` | Local branch `mobile/flutter-uiscene-migration`; commit `30d5a5e` plus uncommitted changes in Podfiles, Xcode project, and `AppDelegate.swift` | Owner and release status are not recorded. Inspect that worktree before editing these files. Run Flutter analysis/tests, an iOS release build, and physical launch checks before release. |
| App Store recovery and item-photo release | `mobile/` and deployed item-photo backend routes | The public `1.0.6 (17)` source was recovered, build 30 was processed in its internal groups, and item-photo build `1.0.7 (31)` finished App Store Connect processing with `VALID` status on 2026-09-29. | Verify build 31 group assignment and install it from TestFlight. On a physical iPhone, check retained FIND photos plus camera/library add and delete against production. Do not mix the Interior v2 rebuild into this lane. |
| Physical-memory home and durable review | `backend/`, `mobile/`, and matching authenticated web review/home behavior | Branch `feat/physical-memory-home-review` in `/private/tmp/findez-physical-memory`, PR #27; migration `036` and backend/web are deployed. Reference-matching Home and the requested previous rounded four-tab pill are available as build 35 in both internal TestFlight groups. Analysis, all 34 Flutter tests, five CI jobs, Apple validation/processing, and native physical install/launch passed. | Preserve the recovered App Store baseline and separate UIScene worktree. TestFlight-app install and physical capture/photo/auth/revocation checklist remain before calling this production-ready. |
| Reference-matching grounded Ask | Mobile Ask presentation and its additive public answer context | Branch `feat/ask-grounded-reference` in `/private/tmp/findez-ask-reference`, PR #28 stacked on #27. Migration `037` and the selectively deployed backend are live. Build 36 is `VALID` and in both internal TestFlight groups; Apple validation and exact archived physical install/launch passed. All 46 Flutter and 292 backend tests, analysis, and PostgreSQL ownership checks pass. | Home and the previous four-tab pill are unchanged. Hands-on TestFlight install, keyboard/voice, source navigation, ambiguous-project and account-switch acceptance remain unverified. This step does not implement the future memory graph, document retrieval, purchase intelligence, or offline system. |

## Ask photo release

- `feat/ask-fast-photo-questions`, PR #29 stacked on #28, implementation
  `6944ed3`, in `/private/tmp/findez-ask-reference`: the photo-only follow-up is
  complete and the four selected backend files are deployed with exact build-36
  backups preserved. All 327 backend/55 mobile tests, clean Flutter analysis,
  and all five CI test jobs passed. Build `1.0.7 (37)` passed Apple validation,
  native physical install/launch, and processing (`VALID`,
  `APP_STORE_ELIGIBLE`); both internal TestFlight groups are assigned.
  Text-speed work was withdrawn and is excluded. Home, Capture, web, FIND, and
  the restored pill are unchanged. Hands-on camera/library, ownership/uncertainty,
  Review, follow-up and account-switch acceptance remain unverified. Existing
  FIND public-HTTP transport remains a separate security limitation.

## Profile navigation release

- `feat/profile-nav-hub` in `/private/tmp/findez-ask-reference`, based on the
  released build 37. Mobile only: add a fifth circular Profile destination to
  the same inset rounded pill; group account details, settings and existing
  utilities there. Preserve Home, Ask attachments/speed, Capture, Find inventory,
  tutorial page indices, API contracts, backend and existing account actions.
  Implementation, all 66 Flutter tests with coverage and clean analysis are
  complete, with all five CI test jobs passing on `b4aa726` (PR #30). Build
  `1.0.7 (38)` passed Apple validation, upload, `VALID` processing, both internal
  group assignment and native install/launch. Hands-on
  account/settings/camera and TestFlight-app checks remain unverified.

## Profile and Documents polish release

- `fix/profile-documents-polish` in `/private/tmp/findez-ask-reference`, based on
  released build 38. Mobile only: replace cramped account editing with a labeled,
  scrollable form and reliable save/photo actions; use the saved avatar in the
  Profile hub and pill; restyle Documents and its local subflows to the matte
  grouped design. Preserve document API/actions, Home, Ask speed/attachments,
  Capture, Find, settings behavior, backend/web and native lifecycle files. The
  Settings screenshots are visual guidance, not authorization for pretend
  training, retention, offline or export toggles. Implementation `6a0118e` and
  all 94 mobile tests with coverage/clean analysis pass; all five CI jobs are
  green on that exact source (PR #31, stacked on #30). Final build `1.0.7 (39)`
  passed signed archive, Apple validation/upload, `VALID` processing,
  `APP_STORE_ELIGIBLE` and assignment to both internal TestFlight groups. The
  exact final signed app installed and reports build 39. Its launch checks were
  blocked by the locked iPhone; an earlier superseded build-39 binary launched,
  which does not pass the final-binary gate. User unlock was requested. Final
  launch, TestFlight-app installation and hands-on photo/document/account-switch
  acceptance remain unverified. Build-38 archive/IPA are preserved.

## Known blocked product work

| Work | Blocker |
|---|---|
| FIND geometry and training corrections | Unresolved object records, public evidence, review status, uploaded source images, and available crops persist. Masks, geometry, and training-quality correction events still do not persist after FIND job cleanup. |
| Hosted MCP access for remote clients | Current MCP transport is local stdio. A hosted Streamable HTTP service and per-user authentication are not implemented. |

## Handoffs

No task-specific handoff is registered in `.agents/HANDOFFS/`. Current release
preflight evidence and blockers are in `CURRENT_STATE.md` and the release checklist.
# October 18 capture return — active

Lane fix/web-scan-save-return-20261018 from 8553ad4. Confirmed Capture saves return
to the inventory-scoped Items route; failed drafts stay for retry. Original photo
retention/order is API-owned; existing galleries remain private. Dashboard untouched.
