# FindEZ test suite

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

### Restock planner and stock confirmation

`restock_planner_test.dart` covers migration of old thresholds/checks without
inventing quantities, untracked belongings, explicit zero thresholds, concurrent
edits, malformed data, failed disk saves/cache rollback/draft retry, account
isolation, persisted orders, individual item selection, quantity-only arrival
writes, duplicate pending actions, server quantity bounds, lost-response retry
without double addition, item opt-out without deletion, failed reads, shared
view/edit permissions, and the actual Find banner's immediate ordering update.
Phone-sized and 320pt/2.6x Light/Dark cases retain the shared Bold Text policy.
The optional `FINDEZ_VISUAL_QA=true` Dart define renders phone-sized sample
screens to `/private/tmp/findez-restock-{dark,light}.png` using the Mac system
font; these are widget renders, not native acceptance.

All 292 mobile tests with coverage and clean analysis pass locally, including
18 restock regressions. Run mobile analysis and the full test suite with coverage. Before public
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

### App-wide Bold Text hierarchy

`app_typography_test.dart` verifies rendered RichText and EditableText weights:
app and framework supporting text/inputs use 500 and headings/buttons use 600
with Bold Text enabled, in both themes. Switching off restores normal body
weights and caps previous heavy emphasis at 600. Text semantics, layout options,
monospace styling, OS scaling and other accessibility flags are retained.
`appearance_widget_test.dart` changes the actual app root's OS preference and
app text size while retaining its Navigator and an unsaved form draft.

Read the actual Bold Text preference with `AppTypography.boldTextOf`; the
MediaQuery value below the policy is deliberately false to prevent Flutter from
replacing every requested weight with 700. Theme controls, editable fields,
input decorations and Markdown/selectable answers must use the shared policy.
`home_page_test.dart` retains Light/Dark 320pt regressions through 3.4x with
scrollable Space rows and reachable Review actions. Run the full mobile suite
with coverage and analysis (274 tests pass for the app-wide implementation).
Check the exact native binary across Home, Capture, Ask, Find, Profile, forms
and dialogs with Bold Text enabled; widget weights alone are not physical
visual acceptance. The user's build-52 approval covers Home only.

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

### Physical-memory first-launch onboarding

Local build 50 replaces the old inventory simulation with the four-screen
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

`mobile/test/ask_page_test.dart` includes camera/library selection, preview,
replace/remove, picker cancellation/permission errors, image-only default
questions, correct photo endpoint selection, safe failures, reset isolation,
trusted owner/origin checks, and narrow/large-text photo layouts. On an actual
iPhone, additionally check camera/library permissions, cancel/replace/remove,
identification, an owned product match, an uncertain Review result, follow-up
questions, and switching accounts. Native install/launch alone does not verify
these interactions.

## Profile navigation regressions

`mobile/test/profile_navigation_test.dart` covers the fifth circular Profile
destination, unchanged pill/order, every utility callback, actual shell routing
to account details/settings and back to Home, safe read/retry/save failures,
disposed late reads, malformed avatar-color fallback, separate account/settings
reads, a real Material ink surface for utility rows (including newer Flutter),
confirmed deletion cancellation with no request, and narrow/large-text
scrolling above the reserved navigation area. `home_page_test.dart` also locks
the five-tab order. Existing account APIs and billing behavior are not changed.

`mobile/test/home_navigation_test.dart` locks the icon-only presentation for
every selected tab, retained screen-reader names/selected state/tap actions and
long-press tooltip names. It checks the saved profile avatar selected and
unselected, centered icons, full destination touch targets of at least 44 points,
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
