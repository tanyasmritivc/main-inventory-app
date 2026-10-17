# FindEZ test suite

## Grounded physical-memory questions

Run root `python -m pytest -q` and focus on
`backend/tests/test_physical_memory_questions.py` and
`backend/tests/test_assistant_tool_safety.py`. The reusable synthetic fixture is
`backend/tests/fixtures/physical_memory_questions.json`. It checks record IDs and
actual quantities/locations, bounded/likely matching, unknowns, linked document
metadata, saved notes/events, conversation ownership, viewer restrictions, failed
providers, unsafe commands and conditional/replayed edits. HTTP SSE tests verify
scope survives dependency cleanup, persisted source snapshots and refreshed facts.
Concurrency/cancellation tests check actor isolation and stream/background cleanup.
Existing Ask/photo/project/gateway suites remain required. Run the full web and
Flutter regressions, Flutter analysis, TypeScript and connector/bundle checks for
compatibility. See `docs/plans/assistant-grounded-retrieval.md` for exact commands,
127-case coverage, measured synthetic limits and manual production security gates.
Fixture latency is not a live provider/database latency result. Do not use
customer records or production database writes for this suite.

## Mobile organization and inventory parity

Run `flutter analyze --no-pub` and `flutter test --no-pub --concurrency=1` from
`mobile/`. `inventory_context_test.dart` exercises real authenticated API-client
routing with synthetic HTTP responses, viewer guards, account/selection races,
invalid parent contexts, offline restoration, refresh and cache isolation.
`hierarchy_page_test.dart` covers directories, role-dependent controls, consent,
restricted requests, inventory-admin review, create/refresh, location parents,
share-import selection, cold access-link handoff and readable viewer item details.
It also checks the scoped shell at 2.6x text without the old Teams segment.
Launch/tour tests retain pre-auth onboarding and one-time tour behavior after a
validated inventory opens. Optional `FINDEZ_VISUAL_QA=true` captures both phone
themes; that test uses the macOS system font and is skipped by normal CI.

Run the existing backend inventory/collaboration/consent/directory/rename/deletion
suites and the web boundary/navigation tests listed in
`docs/plans/mobile-hierarchy-parity.md`. No backend/schema/web code is changed.
These tests do not prove native camera/OAuth/universal links, actual email delivery
or a signed-in cross-client round trip. Complete the disposable-account device
plan in that document before publication. Run Flutter processes sequentially on
low disk space; native builds require more free space than the current machine.

For the mobile place switcher, run the full Flutter suite with coverage and the
focused `organization_place_flow_test.dart`, `workspace_home_test.dart` and
`hierarchy_page_test.dart`. The organization flow fixture checks authenticated
organization to workspace selection, scoped Search and inventory opening,
Tasks/Files/People/Activity navigation, creation refresh, failure/Retry, viewer
restrictions and large text. `space_creation_navigation_test.dart` checks the
nested Navigator with real scoped API requests; Cancel must leave the inventory
mounted. The iPhone 16e production-connected simulator must open the same routes
and Create/Cancel without blank navigation. Do not submit customer test writes
from that account. See `design/workspace-switcher/IMPLEMENTATION.md` for the
remaining disposable-account and physical-device checks.


## Organization actions menu and empty deletion

Run backend/web suites, TypeScript, changed-file lint and the production build.
`organization-actions` covers the icon menu, Rename, keyboard dismissal, typed
Delete confirmation, cancellation, errors, receipt validation, pending writes and
unmounts. Its scoped JSDOM helper supplies unsupported native top-layer selector
states for Floating UI; browser acceptance must use the real Radix menu.
`test_organization_delete.py` checks actor binding, errors and exact receipts.
The disposable SQL suite includes migration 047 and tests creator-only access,
stale names, unassigned attached workspaces, atomic membership/invitation removal,
audit retention and replay. Check simultaneous workspace creation/deletion and
duplicate deletes in isolation. Before publication, verify existing production
rows, policies and function ACLs remain unchanged by the additive migration.
Browser-check cards and selected organization menus at desktop/390px in both
themes. Live QA opens and cancels dialogs only; never delete customer records as
a release probe. Keep the homepage and workspace/inventory actions unchanged.

The repository has one automated test entry point for all three product surfaces:

```bash
make test BACKEND_PYTHON=backend/venv/bin/python
```

When a Python virtual environment is already activated, omit the override and run
`make test`. To install the backend test dependencies from a fresh checkout:

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -r backend/requirements-dev.txt
npm --prefix frontend ci
npm --prefix integrations/findez-mcp ci
cd mobile && flutter pub get && cd ..
```

## Test layers

| Layer | Command | Scope |
|---|---|---|
| Backend | `make test-backend` | FastAPI services, route behavior, auth, limits, search, imports, catalog, and notifications with external I/O stubbed |
| Web | `make test-frontend` | Next.js/TypeScript business logic and user-facing error behavior |
| Mobile | `make test-mobile` | Flutter model behavior and critical widget flows |
| AI connectors | `make test-integrations` | MCP handshake, inventory reads/writes, deletion rejection, safe failures, Actions contract, and packaged Desktop extension |
| All with coverage | `make test-coverage` | Produces backend XML, Jest coverage, and Flutter LCOV reports |

The unit suite uses placeholder credentials and must not make requests to production
Supabase, FIND, the agent gateway, Stripe, or other external services. Backend-wide environment and
import-path setup lives in `backend/tests/conftest.py` so tests do not mutate shared
modules during collection.

GitHub Actions runs these jobs independently on pull requests and pushes to
`main`. A change is green only when backend tests, web tests, AI connector tests,
`flutter analyze`, and Flutter tests all pass.

API integrations also have a PostgreSQL 17 CI job that executes
`backend/tests/sql/api_key_rls.sql` against an empty disposable database. It verifies
the real RLS policies and triggers, including cross-team isolation, write-only
updates, repeat imports, aggregate queries, revocation, Space detachment, and
Review queue ownership, backend-only mutations, transactional resolution,
idempotency, and photo preservation. Ask regressions also verify that saved
answer context belongs to the conversation owner, cannot be read or inserted
across accounts, accepts only assistant object snapshots, and cascades with its
owned conversation. To run locally, point the standard
`PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, and
`PGDATABASE` variables at an **empty test database**, then run:

```bash
psql -X -v ON_ERROR_STOP=1 -f backend/tests/sql/api_key_rls.sql
```

This SQL fixture creates its schema and test roles. Never run it against production.

The API usage regressions also cover exact-part quantity totals across pages,
record counts versus unit totals, numeric low-stock filters, and zero matches.
Python HTTP tests check stable bulk-import identities, duplicate rejection,
validation of every target workspace before a batch write, and independent
per-key standard/bulk request limits. These run automatically in the existing
backend and PostgreSQL CI jobs; no real API key is needed.

Space mutation cache regressions in `backend/tests/test_space_inventory_cache.py`
warm the real per-user cache against a deep-copying database stub. They verify
immediate all-category location refresh after rename, cascade deletion refresh,
foreign-owner isolation, unrelated-user cache preservation, blank-name rejection,
and cache eviction with propagated errors after failed mutations. They run in
the normal backend suite without credentials or network I/O. Live release checks
must still repeat the Space rename and filtered/unfiltered inventory flows.

## Public API documentation

The public `/docs/api` page and downloadable OpenAPI 3.1 reference use
`frontend/public/docs/api/openapi.json`. Generate it from the current mounted
integration router with:

```bash
make docs-api BACKEND_PYTHON=.venv/bin/python
```

`scripts/api_reference.py` owns the endpoint explanations, response shapes, and
examples. Request models, URL parameters, auth types, permission requirements, and
default rate limits are derived from backend code. Generation uses placeholder
configuration and never contacts a database or external service. Review the
generated diff when changing the API; do not edit the JSON directly.

`tests/api_docs` runs automatically with `make test-backend` and the existing Python
CI job. It fails on contract drift, missing errors, broken schema references,
invalid request examples, or HTTP response mismatches. Inventory I/O is stubbed;
database semantics remain covered by the existing PostgreSQL job.
The existing SQL entry point includes `tests/api_docs/semantics.sql`, so the
PostgreSQL job also runs documentation regressions for empty Spaces/Teams,
zero-quantity record counts, exact text matching, null inequality, and unowned
workspace reads. Web tests verify
public rendering, all navigation anchors, search, language selection, clipboard
success/failure, the downloadable link, and syntax of every generated shell,
Python, and JavaScript request example without executing requests. Those syntax
checks need `bash`, `python3`, and Node.js (available on the existing CI runner).

Before publication, build the web app, check `/docs/api` and
`/docs/api/openapi.json` without a session, and verify the link from Settings → API
keys and the public footer. The docs add no production API routes or migrations.

## Release testing

### Original import fields

`test_import_original_fields.py` verifies differently shaped worksheets, exact
CSV labels/spacing, duplicate/unnamed columns, JSON structures and save/reload
isolation. The PostgreSQL fixture applies migration 042 and checks JSON round
trips and invalid shapes. Web item-detail tests and mobile imported-detail
widget tests cover exact labels, zero/false/empty values, escaped content and
narrow large-text layouts. Use the supplied workbook read-only to verify both
sheets are represented; do not reimport into customer inventory for QA.

### First-install guided tour

`tour_install_test.dart` verifies the durable one-time claim, concurrent starts,
legacy installation migration, retained sessions and failed writes. Overlay
tests cover interrupted/reopened tours, stale signup flags and cancellation
during delayed startup. `onboarding_launch_test.dart` exercises real MainShell
navigation: the first spotlight starts at Home, background/resume dismisses it,
and a recreated authenticated shell stays quiet. Destination keys must resolve
for selected icons as well as unselected icons. Opening either kind of Space
must never trigger automatic guidance. Repeat on a fresh test installation and
an upgraded existing installation; preserve real user data during validation.

### Launch capture receipts and planned pricing

`backend/tests/test_capture_save.py` saves through the capture service and reads
through the real item repository against an isolated deep-copying store. It
covers same-named objects/variants/photos/locations, owner-bound retry IDs, lost
responses after commit, write failure, changed retry payloads, quotas, mixed
owners and explicit route receipts. It does not prove production database or
physical camera acceptance.

Web `scan-capture.test.tsx` checks partial draft retention, stable retry IDs and
late-account photo responses. Receipt tests on web/mobile reject malformed or
conflicting success indices. Ask regressions preserve unknown quantities and
allowlisted product matching evidence. An answer check timestamp is never a
physical confirmation timestamp.

`pricing-plans.test.tsx` checks the five prices/periods and unavailable purchase
controls. Mobile `plans_page_test.dart` covers annual prices and narrow 2.6x
layouts in Light/Dark. Pricing is preparation only: no real purchase, restore,
provider notification or new quota enforcement is exercised. Follow
`.agents/HANDOFFS/2026-10-14-launch-readiness.md` before enabling billing or shipping
this lane. Native release packaging must verify matching app/extension versions.

### Capture preview and explicit save

`test_capture_previews.py` verifies both extraction routes with preview-only
requests, the old-client contract, no queue writes during previews, signed owner/
identity/evidence binding, expiry, tampering, retry idempotency, handled-record
rejection and private-field exclusion. Photo Ask regressions reject Review side
effects. Mobile's `capture_preview_api_test.dart` exercises actual multipart
requests and authenticated POST-versus-PATCH behavior through a hermetic Dio
adapter; `scan_review_test.dart` checks proof retention, uncertainty routing and
failure propagation. Web API tests cover preview requests and explicit saves.
Run all surface tests, Flutter analysis, TypeScript, changed-file lint and web
build with fictional configuration. Do not deploy that build configuration.

Deploy backend support before the new web/mobile clients. Old mobile binaries
retain their original extraction contract, so the full Capture behavior needs
the updated binary. Before native release, upload and cancel a random photo,
return Home and confirm its Review count is unchanged. Repeat camera and library,
chat-photo uncertainty, explicit Save, interrupted/retried Save, edited identity,
retained photos, expiry and account switches. Only explicitly saved uncertainty
should appear in Needs identifying. Preserve existing Review rows; tests do not
authorize historical cleanup. Automated/API results do not prove phone behavior.

### Assistant reply punctuation

`backend/tests/test_chat_response_style.py` verifies that gateway replies with
U+2014 punctuation are normalized before sync, raw-event and SSE output and
session persistence. Check that deltas and the final answer agree while user
input, tool arguments/results and source labels remain unchanged. Document
summaries and legacy chat share the same instruction and formatter; Ask-photo
regressions include a model explanation that ignores the writing instruction.
Run the full backend/API documentation suite. This is server-side response
presentation and requires no schema migration or mobile binary. Do not rewrite
historical messages as part of this change.

### October 13 mobile submission polish

The October 14 continuation adds `chat_focus_test.dart` against the actual
MainShell, rather than a replacement navigation fixture. Verify focus only after
submission, absence of tab targets during chat, a pinned Back/New chat row,
previous-tab return, the same retained ChatPage state, an in-flight response and
draft surviving Back, conversation IDs on follow-ups and reset restoring tabs.
Repeat at 320pt with large text, keyboard and reduced motion. Scroll a long reply
and keep Back reachable. Sample import renders must retain a destination, Choose
file, format/size hint and Back in both themes without promotional icon rows.
The import picker, validation, errors and actual result counts are unchanged.

Run analysis and the complete mobile suite. The navigation tests verify the
350 ms spring, surface pulse, horizontal stretch, fixed icon centers, final
alignment, interrupted taps and reduced-motion cross-fades in both themes.
Retain four accessible destinations and the existing keyboard/safe-area layout.
Home regressions exclude pictureless and invalid import thumbnails, remove failed
image cards, preserve inventory quantities and use recent labels for older photos.
Test thumbnails use a local image HTTP stub, never a production image service.

The questionnaire tests retain all four answers and save/retry behavior while
checking an 18pt X within a full accessible touch target and no wordmark header.
Tutorial tests cover compact glass cards, safe placement, Next/Back/Skip,
completion and 3.4x text. Ask tests check the simple empty prompt and preserve
streaming, photos, sources, reset and account isolation.

Use `FINDEZ_VISUAL_QA=true` with the existing questionnaire/tutorial/navigation
tests for sample renders with loaded fonts. Template-height checks belong to
those renders; the default Ahem font is deliberately not a native font.
Inspect the actual native preview and verify Reduce Motion, rapid tab changes,
Light/Dark, VoiceOver, keyboard and failed-image refresh on the final TestFlight
binary. Widgets and simulator checks do not claim physical acceptance.

### Setup questionnaire and in-app guided tour

Run the full backend/web/mobile suites, analysis, TypeScript and changed-file
web lint. `onboarding_page_test.dart` covers four optional answers, multi-select
and custom labels, Back, Skip, retry, duplicate pending saves, replay editing,
account changes and 320pt Light/Dark through 3.4x text. The launch tests preserve
fresh setup/Auth ordering, completed installations and invitation handoff.
Normal-motion transitions resist repeated taps, reduced-motion changes settle
immediately, and assistive actions activate the icon choices. `auth_layout_test.dart`
checks sign-in providers, recovery, signup and optional work inputs in both themes
through 3.4x; `auth_eligibility_test.dart` retains the explicit email/Apple/Google
signup consent gate. Native previews use the actual `PREVIEW_ONBOARDING` define;
the production archive must omit it or set it to false.
`tutorial_overlay_test.dart` exercises actual controller targets, Next/Back/Skip,
missing Spaces, persisted completion and large text. PostgreSQL includes
`onboarding_answers.sql` for owned reads, backend-only writes, integration-key
exclusion, constraints and auth-account deletion cascade.

Migration 041 must precede dependent clients. Inspect native previews and build
the production IPA from clean generated files; verify every native executable's
device platform. Repeat physical setup/save/retry, VoiceOver, tutorial targets
and account-switch checks through the exact final TestFlight delivery. Simulator,
widget and API results do not constitute physical acceptance.

### iOS archive platform verification

Before validating an IPA with Apple, inspect every Mach-O executable in the
exported app, including nested frameworks and extensions. Use `xcrun lipo -archs`
to reject simulator architectures and `xcrun vtool -show-build` to confirm iOS
device platforms. An arm64 slice can still target the simulator, so architecture
alone is insufficient. Strict code signatures do not prove platform compatibility.
Build 61's first export included a cached simulator `objective_c.framework`;
Apple rejected it with 90087 and 91169. Preserve the failed package and receipts,
run `flutter clean`, then rebuild with the verified production defines and export
options. Do not patch or re-sign a rejected framework in the exported IPA.

### Canonical legal and native notifications

Run the full web and mobile coverage suites, TypeScript, changed-file web lint,
production webpack build and all five CI jobs. Mobile regressions cover explicit
signup acknowledgment, canonical link launch/retry/disposal, no inbox permission
prompt or automatic read, a new event during read, retained rows on failure,
account switches, serialized registration and a late shell badge response. Build
the native simulator and signed production candidate without changing review 59.
The user chose to test build 60 physically later. Before a public submission,
check external Privacy/Terms links; camera/library/voice choices and denial;
inbox Enable versus Settings after denial; real foreground/background APNs
delivery and tap; badge/read synchronization; and logout/relogin on the phone.
Use only the controlled review account/own device. Server APNs acceptance or
simulator results are not a physical delivery pass. No real inventory mutations
or account deletion are required for this lane's acceptance.

### App Review AI clarification and native screenshots

For the policy-only build 59, run Flutter analysis and the existing full mobile
coverage suite; all five shared CI jobs must pass on the PR head. Inspect the
corrected policy and Terms in a native simulator build. Preserve AI routing,
speech permissions, API contracts, lifecycle, appearance and production data.
Verify the signed archive/export and production configuration before upload.
Screenshots must come from the actual native iOS UI at Apple-supported sizes,
using the dedicated sample review account. Visually inspect each original PNG,
record dimensions/checksums, and inspect all device-size families in Media
Manager. Distinguish prepared assets from uploaded assets and a local reply
draft from a sent message. Simulator results do not constitute physical-device
acceptance.

### Landing copy and signed-in navigation

Run the full web coverage suite, TypeScript, changed-file ESLint and production
webpack build. `landing-page` verifies server-initialized Dashboard, anonymous
signup, public rendering when user verification fails, browser sign-in/out events,
desktop/mobile marketing actions and listener cleanup. Browser-check the hero
without the removed paragraph and Dashboard opening `/home` in an existing
signed-in session. Check anonymous initial HTML separately and keep public API
files, interior source and production data unchanged. All five CI jobs must pass
on the PR head before finishing.

### Persistent web navigation and hover sidebar

Notification follow-up adds failed-write and failed-refresh visibility, account
switch clearing, event-arrival-during-read and stale bell-response tests. All 203
web and 380 backend/API-doc tests pass. Recipient/read tests bind both queries and
writes to the authenticated user; team fanout persists deduplicated recipients
before enqueuing push. Production checks are read-only and confirm schema/APNs
configuration only. Physical APNs delivery remains a separate native release gate.

October 11 professional polish adds real Markdown safety/formatting coverage,
pin/unpin and stored frame preference, inert narrow navigation, message-scoped
pending status after a failed answer, and Home attention counts without zero
placeholders. All 195 web tests pass. TypeScript, changed-file ESLint (no errors)
and production webpack compilation pass. Safari fictional-data acceptance covers
bold/list rendering, closed Sources, pin resizing and cleaner Home/settings/feed
views. Source Sans 3 is limited to AI replies; current app fonts are preserved.
Optional trackers are not introduced. Server candidate checks must use production
origins and preserve unrelated live CSS/dialog/import styling and prior static
assets. Notification functionality and shared legal/mobile links are later lanes.

Run the web release checks below. The full suite has 181 tests in 24 suites.
Sidebar regressions cover desktop mouse entry/exit, touch-only behavior, all
existing destinations, narrow drawer isolation/focus and Home/profile closure.
Authentication inventory tests remove route-group folders when checking URLs;
all protected pages retain server guards and the middleware URL coverage.

Browser-check repeated tab changes, a slow route read and a failed page inside
the shared frame. Verify desktop expansion/collapse, icon tooltips, keyboard
labels, stable content position, reduced motion and the narrow drawer. Public
API documentation must remain public and leaving the workspace must remove its
theme. Use fictional local data or read-only production views.

### Authenticated web mobile parity

Run `npm run test:ci`, `npx tsc --noEmit`, ESLint on the changed TypeScript files
and `npm run build -- --webpack` from `frontend/`. The web suite now includes
176 tests across 24 suites. `restock-plan`, `ask-stream`, `workspace-boundaries`
and `workspace-flows` cover opt-in planning, order/arrival confirmation, persisted
absolute retries, failed storage, account switches, permission-aware photo paths,
document paths/notes search, failed draft retention, confirmed Ask conversation
IDs and incomplete SSE answers. Sidebar regressions cover all entry points,
one active destination, narrow-screen focus/background isolation and restoration.
`workspace-profile` covers delayed identity, loaded fields, the backend photo
field and one-attempt legacy signup completion after USER_UPDATED. Public landing
and API documentation tests remain in the full web suite.

Browser-check desktop and narrow layouts using disposable test data: Home counts
and query handoff, navigation search, Capture fields/import modes, item details
and gallery dialogs, document errors, and Restock order/arrival count changes.
Ordering must not change stock. Check failed/retried arrivals and shared viewers
before deployment. Purchase plans are per account/browser and do not sync with
mobile. Never use the user's real inventory as a write probe.

The October 6 local browser pass used fictional API data. Self-hosted deployment
then verified actual read views, saved profile/name/avatar, production webpack
build and bundle origins, anonymous guards, static assets, HTTPS public pages,
unchanged landing source/content and exact public API JSON. Both systemd services
remain active, with the original VM checkout and prior web builds preserved.
Full live multi-account, storage/upload and collaboration acceptance was not
repeated and is not claimed. All five GitHub CI jobs must pass on the PR head.
Use disposable accounts for further write acceptance; never probe real inventory.
The ignored local fixture environment and compiled output are not deployment
artifacts.

### Restock planner and stock confirmation

`restock_planner_test.dart` covers migration of old thresholds/checks without
inventing quantities, untracked belongings, explicit zero thresholds, concurrent
edits, malformed data, failed disk saves/cache rollback/draft retry, account
isolation, persisted orders, individual item selection, quantity-only arrival
writes, duplicate pending actions, server quantity bounds, lost-response retry
without double addition, item opt-out without deletion, failed reads, shared
view/edit permissions, and the actual Find banner's immediate ordering update.
Phone-sized and 320pt/2.6x Light/Dark cases retain the shared Bold Text policy.
Compact cards retain secondary actions in menus and the local-plan disclosure
in a reachable Info sheet. Both themes verify orange purchase-state labels,
neutral zero counts and at least 4.5:1 status contrast on the
tinted banner background.
The optional `FINDEZ_VISUAL_QA=true` Dart define renders phone-sized sample
screens to `/private/tmp/findez-restock-{dark,light}.png` using the Mac system
font; these are widget renders, not native acceptance.

Clean analysis and all 296 mobile tests with coverage pass locally, including
22 restock regressions. Run both checks against the final source. Before public
release, use the exact final TestFlight binary and a disposable inventory item:
plan a purchase, mark ordered, verify Find/Home counts and restart persistence,
record the counted arrival, verify server-backed quantity, test offline retry,
item removal, and shared viewer/editor behavior. Do not mutate the user's real
inventory as a release probe. Native notification permission, cancellation and
delivery require a physical check. Planning metadata is intentionally local to
the signed-in account/device; do not assert cross-device order synchronization.

### Cold Home-to-Space navigation

`home_space_loading_test.dart` runs the actual MainShell with ready Home data
and a deliberately pending lazy Find read in Light/Dark. The original source
opened a false empty Space before that read completed. Tests now require no
Space route until confirmed data, exact-ID/all-category contents despite stale
legacy location names, safe failed-read retry, real empty Spaces, no duplicate
routes and no disposed late navigation. The full 265-test mobile suite with
coverage and analysis pass. Before release, repeat cold Home -> Space and
Find -> Space on the exact final binary, including slow/offline reads and
account switching. Source/widget results are not a native physical pass.

### Stable light typography and OS Bold Text

`app_typography_test.dart` verifies rendered RichText and EditableText weights:
app and framework supporting text/inputs use 400 and headings/buttons cap at 500
in both themes, with identical weights when OS Bold Text changes. Text semantics, layout options,
monospace styling, OS scaling and other accessibility flags are retained.
`appearance_widget_test.dart` changes the actual app root's OS preference and
app text size while retaining its Navigator and an unsaved form draft.

The MediaQuery Bold Text value below the shared policy is false to prevent Flutter from
replacing every requested weight with 700. Theme controls, editable fields,
input decorations and Markdown/selectable answers must use the shared policy.
`home_page_test.dart` retains Light/Dark 320pt regressions through 3.4x with
scrollable Space rows and reachable Review actions. Run the full mobile suite
with coverage and analysis. Check the exact native binary across Home, Capture,
Ask, Find, Account, forms and dialogs while toggling Bold Text. Widget weights
and sample renders do not replace physical acceptance.

### Mobile appearance and text size

Run `flutter analyze --no-pub` and `flutter test --no-pub --coverage` from
`mobile/`. `appearance_controller_test.dart` covers all persisted theme/size
combinations, invalid stored values, read/write failures, duplicate pending
writes, disposal, nonlinear OS scaling, semantic contrast and adaptive brand
roles. `appearance_widget_test.dart` exercises the actual app root,
live System brightness, status-bar styling, OS bold text/scaling, route/draft
retention, pending/error UI and narrow choice wrapping.

The Home, Ask, Documents, profile editor, navigation and item-info tests run in
both themes at normal and large text. Populated Space tests additionally cover
320pt screens through 3.4x scaling, restocking notices, counts and reachable
creation actions. Existing photo, profile/document-save, invitation and protected
item-info swipe regressions remain in the full suite. These tests use stubbed
accounts/data; they do not perform production writes.

Local build 47 simulator acceptance verifies Light/Dark switching, System
mode following live iOS brightness, saved preferences after force-quit/relaunch,
OS accessibility text combined with Larger, status-bar/readable Home counts,
Capture label wrapping, populated Space layouts and item-info navigation.
The user requested simulator-only checks for now. Before a later release, repeat
on a physical phone: all five tabs, scrolling/keyboard with accessibility text,
Light/Dark/System and restart persistence, VoiceOver names/touch targets,
photo/avatar/camera presentation, printed QR scanability, Documents/profile forms
and item-info swipe/save protection. Do not infer physical passes from widgets
or simulator screenshots. That historical build-47 check did not authorize Apple upload. The October 5
request now authorizes TestFlight beta upload; public App Store review remains
held.

### Mobile brand assets and duplicate sheet handles

Build 57 uses shared orange action/selection/foreground roles across the main
screens and Team workspace. The build-58 follow-up makes the Teams list and
Team Documents icons monochrome at the user's request. Check the selected Teams
segment and bottom-nav highlight while that page is active, then verify other
tabs keep their shared brand roles. Existing brand tests additionally verify at
least 4.5:1 small-text contrast on Light/Dark neutral and 8% tinted surfaces.
Retain semantic stock/error/success colors, original supplied assets, profile
photos and member colors. Run analysis and the full mobile coverage suite;
verify all five tabs, the populated Teams list, Team workspace, each Team
Documents file-type glyph and compact restock cards visually in
both themes, then check the final native binary through TestFlight. Widget
renders do not prove physical visual acceptance or stock/notification behavior.

Local build 48 adds `brand_theme_test.dart`: exact guide tokens, separate stock/
error roles, Material color-pair contrast, resolved-child and inverted-control
contrast, outlined SVG geometry and ink-only reversal, opaque 1024px native
icon, flat primary actions and a single custom edit-sheet handle in both themes
at normal/2.6x text. The full 203-test suite includes navigation, drafts, failed
saves, avatar/Documents/invitation guards and protected item-info swipe tests.
Run the same analysis/full-suite commands above. Native iOS simulator build 48
passes; Light/Dark/System switching, live iOS brightness, restart persistence,
Larger text, all five tabs, Documents/item-info and single edit handles were
visually inspected. The simulator preferences were restored to Light/Default
and the simulator OS appearance to its original Dark setting. No inventory,
membership or document writes were made during this visual check.

Original SVGs are bundled under `assets/brand/`. To regenerate native icon sizes
from the supplied original PNG, run `dart run tool/prepare_brand_icon.dart
/absolute/path/to/findez-icon-1024.png`, then `dart run flutter_launcher_icons`.
The preparation step flattens alpha onto Ink and keeps the mark/padding intact.
Existing native lifecycle files are not part of this change.

Before release, repeat the physical checks above. Also investigate the observed
cold Home Space shortcut: Home showed five items but its Space opened empty;
the same Space opened populated through Find. No routing fix is included in
this brand-only lane. The user continues to hold all Apple uploads/submission.

### Personal Space icon picker

Local build 49 adds `space_icon_preferences_test.dart` and
`space_icon_picker_test.dart`. The full 226-test mobile suite with coverage and
clean analysis covers named-choice round trips, Automatic reset, stable IDs after
rename, device persistence, distinct account/Space/share keys, invalid stored
values, read retries without overwrites, confirmed/unconfirmed/throwing writes,
duplicate saves, pending-read/write account switches and disposal. Widget checks
exercise the real personal/joined and Team viewer lists: tapping the 44pt icon
opens only the picker, not a Space or editor, and requires no inventory mutation.
Search, Cancel, failed-save draft retry, selected screen-reader semantics and
320pt Light/Dark layouts at 1x/2.6x/3.4x with keyboard transitions are included.

Run `flutter analyze --no-pub` and `flutter test --no-pub --coverage` from
`mobile/`. Native simulator build 49 passes, with visual search, Cancel, immediate
card update, restart persistence, Dark/Light and Larger text checked against the
dedicated test account. Only personal device preferences changed during this
check; no inventory, document or membership write was performed. Choices do not
sync or change another member's icon. Before release, repeat physical touch,
VoiceOver selected names, keyboard/scrolling and persistence checks. Apple
uploads/submission remain held and broader release checks are not replaced.

### Historical build-50 physical-memory first-launch onboarding

This historical workflow is superseded by the setup questionnaire above and
the current user-authorized internal TestFlight release. Local build 50 replaces the old inventory simulation with the four-screen
account-free introduction. `onboarding_page_test.dart` exercises sample objects,
capture/review/location, grounded sample questions and personal/shared context;
Back/swipe retain choices and no Space draft or account data is created. Skip,
confirmed completion, failed-write retry, duplicate pending actions, disposal,
replay/legacy-state preservation, reduced motion and selected progress semantics
are covered. All pages are exercised at 320pt in Light/Dark through 3.4x text;
normal-phone sample answers must be visible without scrolling.

`onboarding_launch_test.dart` exercises the actual launch/auth gate with stubbed
auth and APIs: fresh launch -> onboarding -> Auth, Skip and persisted restart,
legacy completed installations, valid returning sessions and Space/Team links
queued before authentication. No invitation is automatically joined and no API
inventory read occurs during onboarding/Auth. Existing invitation/sign-in,
profile/document saves and protected item-info swipe tests remain in the suite.
Run `flutter analyze --no-pub` and `flutter test --no-pub --coverage`; use
`--concurrency=1` on a disk-constrained Mac. Native simulator acceptance is
recorded in `CURRENT_STATE.md`. Physical fresh-install/auth, VoiceOver, horizontal
swipe and reduced-motion acceptance remain deferred by the simulator-only choice.
No phone install, Apple upload/submission or backend/FIND change is authorized.

### Space and Team invitation acceptance

`backend/tests/test_invitation_links.py`, the invitation/auth Jest tests and
`mobile/test/invitation_test.dart` run in the existing suites. They verify
authenticated read-only previews, no automatic membership, active/expired and
rotated codes, strict URI parsing, repeated acceptance, owner/member forwarding,
Team role protection, account handoff before confirmation, blocked download on
save failure, restart/sign-in persistence, duplicate warm links, account-switch
dismissal, actor-token binding across queued requests, late-response isolation,
a different warm link queued behind an open prompt, and large-text layout.

Physical release checks are still required:

1. Open Space and Team links with the app cold, warm, signed out and signed in.
   Verify the named prompt and access level; Not now must create no membership.
2. Accept with a second test account, verify the destination and owner-selected
   permissions, then reopen. A third unrelated account must have no access.
3. Revoke a Space link or rotate a Team code while its prompt is open. Acceptance
   must fail safely; the recipient must not get inventory before membership.
4. With no app installed, create/confirm an account from the invitation landing,
   save the invitation, download, and sign into that same account. Verify the
   prompt. Download-first flow explicitly requires reopening the invitation.
5. Test Safari, Messages/email and an in-app browser. Spaces use the web/custom
   scheme fallback while App Store build 17 remains public. Do not broaden AASA
   until the compatible mobile handler is public. Universal links do not prove
   deferred installation, nor does a widget test prove native routing.
6. Confirm iPad share-sheet anchoring and Android custom-scheme reception on real
   devices. Android verified HTTPS routing/Play Store download are not shipped.

The account handoff is invitation metadata, not a new database grant. No database
migration is required; production table columns and both membership uniqueness
constraints must be verified before deploying the idempotent join changes.

The iOS scene-link dependency contract is guarded in `invitation_test.dart`.
Build 40's application-only linker passed Dart tests but failed the user's
physical prompt check. `app_links` 7.0.0 registers scene delegates; the first
compatible Supabase Flutter adapter (2.12.1) permits it without an unsupported
override. The user confirmed build 41's cold Team prompt and a real Safari
Space-link fallback prompt. Build 42 retains that native fix and adds actor-bound
request tests; its exact binary installed/launched and the user repeated both
prompt confirmations. The source-level guard
alone does not prove native behavior, and neither observed prompt proves fresh
App Store installation, real membership acceptance, or revocation.

The Claude Desktop extension and ChatGPT Actions import live in
`integrations/findez-mcp`. Run `npm ci` there once, then `make test-integrations`.
The operation allowlist contains eight inventory/key-identity operations and never
adds delete, key management, or arbitrary HTTP tools. Input schemas and the
Actions import are generated from the public API reference; `npm test` fails on
drift before running SDK client/server tests with stubbed HTTP.

`npm run build` validates the official MCPB manifest, bundles runtime dependencies, and
publishes `frontend/public/docs/api/findez-inventory.mcpb`. The packaged-process
test extracts that exact file to a temporary directory without `node_modules`,
connects an SDK client over stdio, checks tool discovery, and exercises item
creation using a network stub. `npm run test:bundle` must pass after packaging.
No live API key, assistant account, or production inventory is used by these tests.

After deployment, run `npm --prefix integrations/findez-mcp run check:deployment`.
This explicit read-only network check verifies the actual public destination,
database/key lookup (an unissued well-formed key must return 401, not 503), both
published schemas, and byte equality of the downloadable Desktop package. Health
alone missed the retired Render hostname on 2026-09-14. Authenticated live checks
must include workspace summaries: their parameterless SQL RPC still requires an
explicit `{}` in the Python PostgREST client's `rpc` call.

The Actions schema narrows pages and imports to ten items for ChatGPT payload
limits, requires an explicit page size, and marks creates/patches/imports as
consequential. Public web tests cover the setup anchors, copy controls, downloads,
permission guidance, and platform limits. Before releasing, verify the guide and
both downloads without sign-in. Final host acceptance requires installing the
extension in Claude Desktop and importing the schema into a private GPT with a
user-configured key; automated SDK checks do not replace those host UI checks.

Automation does not replace physical-device checks for OAuth, APNs, camera/barcode
scanning, share-extension handoff, or multi-account permissions. Before a release,
also complete `test-data/release-checklist.md`; its access-revocation and offline-write
sections are release gates.

## Grounded Ask regressions

`backend/tests/test_ask_presentation.py` covers authorized project matching,
ambiguous and unknown projects, revoked sharing, reservation-aware quantities,
duplicate requirement allocation, stock reductions, bounded public evidence,
SSE metadata persistence, and safe errors. It stubs the assistant gateway and all
external reads. Failed conversation setup or answer-snapshot writes must surface
a safe error, and a missing/foreign conversation ID must not silently become a
new chat. Project-readiness prose and status badges must come from the same
current requirements/stock calculation, not generated counts.

`mobile/test/ask_page_test.dart` covers fragmented UTF-8 streaming, old stream
compatibility, saved source snapshots, account-scope resets, collapsed sources,
reference result rows, text-only legacy answers, visible failures, follow-up
conversation IDs, reset/late-event isolation, and large-text/narrow layouts. It
also ensures generated Markdown images do not trigger third-party requests.
On a physical iPhone, additionally test keyboard/voice input, tab switching,
project-source navigation, an ambiguous project, and account changes. Automated
tests do not replace this hands-on acceptance check.

## Ask photo attachment regressions

`backend/tests/test_ask_photo_questions.py` covers authenticated multipart uploads,
10 MB/25-megapixel validation, metadata-stripping normalization, owned
conversations, quotas, current access-scoped inventory reads, strong identifiers
versus possible name matches, uncertainty into Review, no implicit inventory
changes, photo-history URL refresh, follow-up memory, bounded output, and safe
analysis/snapshot failures. External services remain stubbed. The existing
conversation snapshot migration and PostgreSQL ownership checks also cover photo
metadata; no new schema is required.

Photo clarity regressions also cover a noisy food/packaging scene with 637 saved
records, duplicate fragments without inflated stock/object counts, one inventory
summary and uncertainty explanation, generic unknown labels with no name matches,
clear results preceding uncertain ones, a six-type output limit, same-name
products with different identifiers, and measurements only when requested.
Noisy-scene consolidation tests verify representative labels, omission of related
fragments/background guesses, validated existing indices only, invalid/timeout
fallbacks, an empty coherent result, no private notes/URLs or inventory sent to
selection, unchanged product-identifier paths, and end-to-end service wiring.
Gateway tests verify that the 12-second optional timeout remains local to the
HTTP client and normal language requests retain their existing timeout.

`mobile/test/ask_page_test.dart` includes camera/library selection, preview,
replace/remove, picker cancellation/permission errors, image-only default
questions, correct photo endpoint selection, safe failures, reset isolation,
trusted owner/origin checks, and narrow/large-text photo layouts. On an actual
iPhone, additionally check camera/library permissions, cancel/replace/remove,
identification, an owned product match, an uncertain Review result, follow-up
questions, and switching accounts. Native install/launch alone does not verify
these interactions.

## Profile navigation regressions

Neutral glass controls reuse the existing frosted surface and preserve the
framework button's input/semantics behavior. Run `glass_control_test.dart` and
the existing Appearance save/failure/pending-choice regressions, then full mobile
coverage and analysis. Check Appearance selected theme/text size, import results,
scan confirmation, QR action buttons, sharing and save actions in both themes.
High contrast must disable blur and keep labels/selection readable. Use the
rebuilt native candidate for visual acceptance; a pre-glass IPA is superseded.

`mobile/test/profile_navigation_test.dart` covers the Home account control,
four core destinations, every utility callback, actual shell routing
to account details/settings and back to Home, safe read/retry/save failures,
disposed late reads, malformed avatar-color fallback, separate account/settings
reads, a real Material ink surface for utility rows (including newer Flutter),
confirmed deletion cancellation with no request, and narrow/large-text
scrolling without a navigation bar on Account. It verifies an old notification
read cannot restore an unread count after an inbox write, and Home drafts survive
the account/settings route. `home_page_test.dart` also locks the four-tab order.
Existing account APIs and billing behavior are not changed.

`mobile/test/home_navigation_test.dart` locks the icon-only presentation for
every selected tab, retained screen-reader names/selected state/tap actions and
long-press tooltip names. It checks four-tab spring/selection alignment,
centered icons, full destination touch targets of at least 44 points,
narrow/landscape layout, large text, circular selection and reserved safe-area
space outside the 56pt visible bar. Test both standalone navigation and the
actual app's parent-SafeArea arrangement: no doubled inset, stretched pill or
vertically displaced icons. Hidden
text remains in the semantic tree but must have zero paint opacity. Shell tests
tap the actual destinations rather than depend on painted labels.

To capture the compact pill with loaded icon glyphs and fake data:

```bash
cd mobile
flutter test --no-pub --concurrency=1 --dart-define=FINDEZ_VISUAL_QA=true test/home_navigation_test.dart
```

This writes `/private/tmp/findez-compact-nav-qa.png`; it does not replace the
physical-device visual check. Optional capture runs in the real async zone so
image rendering/file I/O cannot stall the normal widget test clock.

On a physical iPhone, check tab switching, profile editing and avatar selection,
settings persistence, documents, notifications/APNs links, lent items, support,
app tour, sign-out and account switching. Test delete confirmation with a
throwaway account only. Native installation/launch does not pass these hands-on
checks.

## Item-info swipe dismissal regressions

`mobile/test/item_detail_sheet_test.dart` tests the actual item-info buttons in
personal/Team `LocationItemsPage` and shared/joined `SharedInventoryPage`, in edit
and view modes. It verifies handle/top-content dismissal, normal mid-body
scrolling, small-pull restoration, horizontal gallery paging, accessible dismiss,
unsaved-note Save/Discard/Keep editing, failed-save draft retention, pending-save
protection, serialized purchase autosaves, low-stock flushing, read-only no-write,
pending return and safe return failures, late reads/reopening, Close/Back
protection, large text and keyboard insets. Animation regressions verify that
late scroll-end events do not restore accepted dismissal and that the actual
modal moves only downward throughout its exit. All
API calls use fake data and stubs; no production inventory is changed.

On a physical iPhone, open an item's info button in personal, shared/joined and
Team Spaces (not Edit item). Pull down on the handle/header and at the top of the
body. Verify a smooth downward exit to the same Space, without an upward jump
or re-expansion. Scroll a long panel both directions
and swipe gallery photos; these must not unexpectedly close it. With a throwaway
item, test note confirmation and pending/failed photo or autosave operations.
Keep Close as an accessible fallback. An install/launch is not a gesture check.

## Profile editor and Documents regressions

`mobile/test/profile_editor_test.dart` covers labeled fields, validation,
confirmed saves, duplicate-submit prevention, failed-save draft retention,
explicit discard, photo replace/remove failures, the 5 MB/MIME upload contract,
trusted owner/origin URLs, account and late-read isolation, shared overview/nav
avatars and narrow layouts with large text and keyboard insets.

`mobile/test/documents_page_test.dart` covers matte grouped Notes/PDFs/Images/Files,
content search, safe read/retry states, upload types, rename identity, deletion
confirmation/failures, summaries, item links/retry/failures, note Save/Back autosave and draft
retention, account isolation, rejected foreign URLs and large-text scrolling.
All external reads/writes are stubbed. No production account or document is used.

For optional macOS layout captures with the system font and fake data, run:

```bash
cd mobile
flutter test --no-pub --dart-define=FINDEZ_VISUAL_QA=true test/profile_editor_test.dart test/documents_page_test.dart --name 'labeled form saves|matte sections classify'
```

This writes layout-only PNGs to `/private/tmp/findez-profile-editor-qa.png` and
`/private/tmp/findez-documents-qa.png`; native fonts, permissions and photos still
require the physical-device checks in release-checklist section 11.

## Website workspace and inventory boundaries

Run the full backend and web suites and TypeScript before publishing this flow.
`test_inventory_journeys.py` exercises real HTTP routes with isolated storage:
member/viewer permissions, forged parents, capture persistence and retry identity,
private documents/conversations and more than 1,000 records.
`test_inventory_scope.py` covers query fences, review/photo proofs, private state,
concurrent streaming workers and gateway context. The web inventory transport and
navigation suites check stale responses/writes, account changes, chooser levels,
missing context, read-only access and legacy purchase-plan adoption.

The SQL entry point includes document storage and workspace fixtures. It must
pass on a fresh isolated PostgreSQL instance before migration 043 is published:
Space graph moves, kit reservations, Team removal, private conversation retention,
stable invitations, exact counts and legacy API-key writes must remain correct.
Use fictional component fixtures for desktop/narrow light/dark visual checks.
After release, verify signed-in chooser/navigation/refresh without writing to
customer inventory. Back up the live database and affected files, verify source
hashes, apply the additive migration before runtime, and retain rollback files.

## Contextual website navigation (October 15)

Run the full web coverage suite, TypeScript, changed-file ESLint and production
webpack build. `workspace-profile`, `inventory-navigation`, `collaboration-access`
and `team-categories` verify organization/workspace/inventory navigation, explicit
selection, creation dialogs, separate management destinations, failed drafts,
account changes, selected board/files panels and view-only document access. Keep
all five CI gates green before publication. Inspect organization and workspace
choice cards, People, Locations, inventory settings tabs and dialogs on desktop
and at 390px in both themes. Verify signed-in context switching, browser Back and
refresh, existing board/files and scoped inventory links without modifying
customer data or permissions. This release has no database or mobile changes.

## Recipient-approved collaboration invitations

Run `test_access_invitation_consent.py`, `test_notification_inbox.py` and the full
backend suite. The SQL entry point includes `member_invitation_consent.sql` after
the original organization fixtures: existing membership preservation, no grants
on send/preview/read, verified recipient binding, signup after invitation,
expiry/cancel/decline, stale-parent/sender rejection and replay after revocation.
Use a disposable network-isolated PostgreSQL instance for simultaneous
accept/accept, accept/decline and accept/cancel checks; assert one status and at
most one membership and acceptance audit. Never use customer accounts as probes.

Web `access-invitation-consent` covers explicit decisions, failed writes, account
switches, sign-in/code continuity, pending sender lists and email-delivery failure.
Run full coverage, TypeScript, changed-file lint, production build and all five CI
gates. Inspect review/delivery dialogs and notifications at desktop/390px in both
themes. Rehearse migration 045 against a restored production copy and compare all
original public rows and policies before applying it. Preserve the consent guard
if a runtime rollback is required. Do not send real invitation emails during QA.

## Organization, workspace and inventory renames

`test_creator_rename.py` exercises HTTP owner-only organization/workspace writes,
inventory creator access and revocation, manager compatibility, invalid names,
duplicate conflicts and unconfirmed writes. Names are the only changed fields;
forged ownership payloads do not alter relationships. Web directory regressions
cover creator-visible controls, confirmed refresh, failed drafts and account
switches during pending saves. Run full backend/web suites, TypeScript, changed-file
lint, production build and all five CI gates. Inspect cards/dialogs at desktop and
390px in both themes. Live QA opens/cancels dialogs only; do not rename customer
resources as probes. No schema or native behavior changes are required.

## Workspace hub and inventory discovery

The workspace directory exposes names and approved descriptions independently of
content access. Run `test_workspace_directory.py`, `workspace-directory-access`,
the full backend/web suites, TypeScript and changed-file lint. SQL fixtures include
`workspace_directory.sql`: hidden discovery/search, no counts or ownership leaks,
no grants from requests, viewer-only approval, cancellation, expiry, membership
revocation and approval replay. Rehearse migration 046 against a network-isolated
restored production copy and compare all original public rows and policies.
Use fictional desktop/narrow light/dark UI fixtures. Live checks are read-only;
do not submit real access requests or alter customer visibility for QA.

## Mobile workspace home and place restore

Run `flutter test --no-pub --concurrency=1 --coverage` and
`flutter analyze --no-pub` from mobile. `last_place_test.dart` verifies account
storage, server validation, stale response/write prevention, explicit link
overrides and revoked versus offline handling. `workspace_home_test.dart` verifies
grouping, counts, roles, callbacks, large text and People.
`space_creation_navigation_test.dart` reproduces the production nested-navigator
shape and checks actual inventory-scoped requests, Create, Cancel and viewer
restrictions. Root-only widget tests cannot detect the old dialog/root pop bug.
See `design/workspace-switcher/IMPLEMENTATION.md` for simulator evidence and
physical-device acceptance. Fake API screenshots do not prove production sync.
