# Decisions

## 2026-10-08: Simplify landing copy and return signed-in visitors to Dashboard

The user's later landing-page request supersedes the earlier exclusion for these
two edits: remove the entire chatbot/database hero paragraph without replacement,
and show Dashboard linking to `/home` instead of top signup/sign-in actions for
signed-in visitors. Initialize the landing link from server-verified identity so
returning visitors see the correct first render; keep marketing links current
through Supabase browser session events. This is presentation, not an auth guard.
Existing per-page workspace verification remains authoritative. Preserve the
landing animation, remaining content, deployed interior and self-hosted release.

## 2026-10-08: Persist the workspace frame and reveal desktop navigation on hover

Put AppShell and its theme/profile state in `src/app/(workspace)/layout.tsx`.
Keep server authentication in every page, with the existing protected URL list.
Loading and retry boundaries replace only page content. The route group does not
change URLs and excludes marketing, authentication and public API documentation.

The user requested a compact desktop icon rail with smooth expansion on mouse
entry and collapse on exit. Reserve 72px for content and overlay the expanded
232px sidebar to avoid shifting the page. Keep labels available to keyboard
focus, retain link names/tooltips, respect reduced motion and preserve the
narrow-screen focus-trapped drawer. Avoid the old `is-hover-expandable` class,
which activates conflicting legacy global rules.

## 2026-10-06: Rebuild the web interior from actual mobile capabilities

Use submitted build 58 as the presentation and behavior authority. The supplied
desktop prototype guides hierarchy, spacing and navigation, but its future
features are not implemented or advertised. Keep all actual routes and developer
entry points accessible, and keep personal/shared Spaces and Teams distinct.
The user explicitly excluded the landing page: interior styles are scoped to
interior classes and public landing source/assets remain unchanged.

Web purchase planning follows mobile's opt-in, ordered and confirmed absolute
arrival semantics using existing stock routes. It remains account/browser-local;
do not imply shared orders or synchronization with mobile's local purchase plans.
Preserve a pending absolute stock count before a write so a lost-response retry
cannot double-add stock. Account-bound requests and keyed private views prevent
late responses from carrying another account's data into rebuilt clients.

No new backend contract or schema is needed. Preserve public API documentation
and downloadable integrations unchanged while their contract tests continue to
pass. Review this implementation against the build-58 record branch so unrelated
stacked mobile and landing changes do not enter the web PR diff.

## 2026-10-06: Deploy the web rebuild through existing self hosting

The user's hosting correction is authoritative: production remains the existing
Ubuntu VM, systemd `findez-web`, Caddy/nginx and self-hosted API/Supabase origins.
Do not route production work through Render or Vercel. Stage frontend changes in
an isolated release with actual production configuration, preserve the dirty VM
checkout and every unrelated deployed file, and switch only the web service's
working directory with a reversible drop-in. Preserve old immutable assets for
open tabs and verify original landing content and the public API contract.

## 2026-10-05: Make the Teams list monochrome after phone feedback

**Decision:** The user rejected build 57's orange Teams list as too orange.
Use black/white foreground for Create/Join/list icons and the selected Teams
segment; use a neutral bottom-navigation selection while this page is active.
Team Documents file icons are also neutral, with distinct file-type glyphs.
This is a scoped exception to the earlier brand-accent decision. Other main
screens retain the requested restrained orange roles; preserve photos, shapes,
routes, typography and all Team/file permissions and behavior.

## 2026-10-05: Use orange consistently and sparingly across mobile

**Decision:** Keep neutral black/white surfaces and text, with the supplied
Signal orange on primary actions and small destination/selection details across
Home, Capture, Ask, Find, Profile and Teams. Use an 8% tint for selected controls
and accessible orange foreground derivatives for small text in each theme.
Replace Team navigation's pastel category colors with this shared role,
including the Teams list, Create/Join icons and Team Documents file icons.
Use distinct file glyphs rather than a separate pastel for each file type.

**Restocking:** Active purchase counts use orange with explicit To buy/On order
labels and cart/delivery icons; zero counts stay neutral. This supersedes the
unshipped build-55 amber/blue purchase palette. Preserve semantic warning,
error and success colors where they describe actual outcomes, along with the
original logo assets, photos, avatar colors, typography and app behavior.

## 2026-10-05: Restock planning reflects purchases and confirmed physical stock

**Decision:** Replace disconnected Shopping List checkmarks with persisted To
buy and On order states. Ordering suppresses another purchase request without
changing stock. Record arrival requires a confirmed total on hand through the
existing inventory API; persist that absolute draft before saving so explicit
lost-response retries cannot add the same delivery twice. Stock alerts require
per-item opt-in, and removing a plan does not delete inventory. Preserve legacy
orders without inventing quantities. Planning remains account/device-local,
while inventory quantities sync; shared viewers cannot save stock.

**Presentation:** At the user's request, keep counts and one main action per
card on the planner. Put explanations in Info and secondary actions in the item
menu. Amber means To buy and blue means On order; zero counts are neutral.
Keep text labels, accessible actions, contrast and the shared Bold Text policy.
These colors apply to restock status, not the global brand theme. Pending stock
confirmation must remain visible until the save is confirmed.

Only decisions supported by current code or repository records belong here.

## 2026-10-05: Purchase progress and physical stock are separate

Replace the disconnected mobile Shopping List checks with explicit To buy and
On order states and a Record arrival action. Marking an order removes it from
actionable purchase counts, never inventing stock. Only arrival confirmation of
the actual total on hand updates inventory quantity through existing permission
checked routes. Persist an absolute count before the request so failed/lost
responses retain a safe explicit retry, and clear the purchase only after the
server confirms the item and count. The count is a snapshot confirmed by the
user, not an atomic increment or a reservation/partial-shipment system.

Keep planning account/device-local until a separate shared purchase system is
implemented, and disclose that scope. Migrate existing thresholds and ordered
checks, leaving unknown historical order quantities unknown. Do not clear real
inventory or add arbitrary stock to resolve existing alerts. Users can remove
irrelevant items or explicitly add a purchase. New capture follow-up chooses
individual items instead of bulk tracking a category at threshold 1. Shared
viewers may maintain their personal plan but cannot update stock. No new API,
database migration, billing or FIND change is required for this mobile lane.

## 2026-10-05: Shared mobile typography responds to iPhone Bold Text

The user approved the lighter Home hierarchy on build 52, then explicitly
requested it throughout the app. Keep San Francisco, existing sizes and layouts,
and intentional monospace code/status text. With the OS setting enabled, use
Medium (500) for supporting text and editable fields, and Semibold (600) for
headings, counts and emphasis. With it off, preserve normal weights while
capping old 700-900 emphasis at 600.

Use `AppTypography` at the app root and `AppText` for app-owned labels. Retain the
actual device preference in the inherited scope, exposed by
`AppTypography.boldTextOf`, while suppressing Flutter's blanket 700 override
below it. Adapt theme controls, fields/decorations, selectable and Markdown
answers, and nested date-picker themes consistently. Preserve OS-composed text
scaling, all other accessibility preferences, navigation and drafts; never
change the user's device setting. This supersedes the Home-only local policy.

## 2026-10-05: A registered Space destination is not a loaded inventory

Wait for Find's first or active inventory read before constructing the existing
Space item route. A failed read is a retryable error, not an empty inventory.
Deduplicate pending reads and route taps; ignore disposed/account-changed
continuations. Retain stable Space IDs, normal Find filters and complete Home
Space contents. This is a mobile loading correction, not a backend/schema fix,
new cache architecture or native lifecycle change.

## 2026-10-04: Physical-memory onboarding precedes authentication

On a fresh, signed-out installation, show the account-free introduction before
Auth. Complete or Skip persists only the confirmed `onboarding_completed` flag;
a failed save stays in the tour with a safe retry. Existing completed installs
and valid returning sessions keep their launch flow. Preserve queued Space/Team
invitations through onboarding and sign-in; never join automatically. Replaying
from Profile or Settings neither changes completion nor clears pending signup,
legacy Space drafts or invitation metadata.

Use four concise screens introducing physical memory, Capture/Review, Ask/Find
and personal/shared Spaces. The local examples change object, sample location,
question or sharing context without accounts, network calls, permissions or
inventory/Space creation. Retain old pending-first-Space handling for users who
already started the previous setup; the new tour creates no such draft. Both
onboarding entry-point classes now use the same introduction.

Use the original wordmark, monochrome code-native illustrations and Signal only
for the mark/primary action. Page transitions and finite sample animations honor
Reduce Motion, never auto-advance or loop. Scrollable pages and a pinned action
support OS-composed large text. Do not advertise proposed AR navigation, a full
memory graph or prediction as implemented. Build 50 remains simulator-only;
Apple submission and physical release checks remain held/deferred.

## 2026-10-04: Space icons are optional personal device preferences

Tap the leading Space icon to choose from a named, curated icon set or restore
Automatic. Keep the existing automatic defaults until an explicit Save icon.
The current Space/share APIs have no custom-icon field: this mobile-only feature
is account-scoped on this device, not an owner-wide change or cross-device sync.
Explain that scope in the picker. Store stable option names by account and Space
ID (legacy joined Spaces use a separate share-ID namespace), never by Space name
or font code point. Renaming does not lose the choice; the same Space ID in a
Team uses the same personal preference. Viewers may personalize without gaining
write permissions or changing another member's presentation.

Publish only confirmed local saves, preserve prior selection/drafts on failure,
and guard account changes, late reads/writes and disposal. Cancel does not save.
Use one native sheet handle, accessible named/selected choices and adaptive grid
columns for large text. Preserve the icon-only navbar and all inventory routes,
permissions, APIs/schema/backend/web/FIND. Build 49 is simulator-only; Apple
uploads/submission and physical release acceptance remain held/deferred.

## 2026-10-04: Mobile uses the supplied monochrome FindEZ brand

The user explicitly authorized mobile application of the provided brand guide
and original assets. This supersedes the earlier pixel-preservation constraint
for the Dark palette, not the device-local appearance/scaling behavior below.
Use exact light tokens and readable dark/status counterparts, never a global
filter on photos, identity colors or printed QR content. Signal is `#E8590C`;
it is not a warning, success or error color. Use Ink text on orange filled
actions for normal-text contrast. Neutralize retired blue/purple decoration and
brand gradients. Preserve the approved five-icon compact pill and all routes.

Keep the original outlined wordmark and chevron geometry; only reverse its Ink
to white on dark surfaces. Native icons flatten transparent corners onto Ink
before size generation rather than scaling or redrawing the mark. Custom sheets
own their grabber; native handles are explicit on simple pickers, never enabled
globally alongside a custom handle. Do not alter protected item-info gesture or
save semantics to solve the duplicate editor handle. Build 48 is simulator-only,
with physical acceptance and Apple release still held for later authorization.

## 2026-10-04: Mobile appearance is a device-local presentation preference

Keep the approved Dark/default-text experience until the user selects
Light/Dark/System or Small/Default/Large/Larger in Settings. Persist confirmed
preference writes locally; failed saves must retain the previous selection and
show a safe error. System mode follows live platform brightness. App text sizes
compose with the platform's scaler, including nonlinear accessibility scaling;
do not disable OS bold text or replace the user's accessibility settings.

Use adaptive presentation colors, not a global image filter. Photos, member
identity colors, camera imagery and printable black/white QR labels keep their
original appearance. Large text may expand cards and stack item-info values;
do not change their field semantics, routes, writes or protected dismissal.
The user explicitly holds Apple submission and chose simulator checks for now.
Build 47 is local-only; physical acceptance and any release require a later step.

## 2026-10-01: Invitation links require consent and an explicit install handoff

Opening a link previews a Space or Team after authentication; it never grants
membership until the recipient chooses Join. Forwarding a joined Space keeps
the existing owner's code and permission. Team invitation management remains
owner/mentor only. Codes are capabilities, not public inventory search keys.

The mobile inbox persists through restart and binds a presented invitation to
the signed-in account. The download page can save a versioned, 30-day invitation
pointer in private account metadata; signup stores it before email confirmation.
That pointer is untrusted and must be revalidated by the backend before joining.
No device fingerprinting, silent clipboard reads or pretend App Store deferred
links are used. Download-first users must reopen their link; account-first users
sign into the same account in the new app to get the prompt automatically.

Keep the existing Team-only AASA rules until a compatible Space-link handler is
released publicly. App Store build 17 cannot handle Space invitations: publishing
`/join/*` now would strand those users in the old app. TestFlight uses the web
landing and explicit custom-scheme/Safari banner fallback for Spaces. Publishing
an App Store update is a separate release decision, not part of a beta upload.
The user authorized preparing a manual-release App Store draft on 2026-10-01;
submission/publication and the subsequent AASA expansion remain separate gates.

The build-40 physical check exposed the old `app_links` 6.x callback mismatch
with the existing iOS scene lifecycle. Pin `app_links` to scene-compatible 7.0.0
for the current Flutter 3.41 toolchain; 7.1+ requires Flutter 3.44. Use the minimum
compatible Supabase Flutter adapter 2.12.1 (and its required lockfile updates),
not an unsupported dependency override or an unrelated latest-auth upgrade. Do not merge
the separate AppDelegate/Podfile lifecycle lane merely to fix link delivery.
Build 41 passed the user's cold Team prompt and real Safari Space fallback
checks. Build 42 retains that native fix and binds membership requests to the
account that pressed Join: neither Dio nor the web helper may substitute a later
account's token. Late responses must not navigate the switched account.

The October 1 production-dependency audit reports Next.js 16.3.4 in the range
of GHSA-vcvr-r3jv-pc5j (patched in 16.3.6). Source inspection finds no `next/og`
or `ImageResponse` usage, so the advisory's attacker-controlled SVG generation
condition is not present. Keep a separate minimal web security-patch lane; do
not call a dependency audit clean or mix a framework upgrade into native release
source without its own validation.

## 2026-08-22: Production is self hosted

**Decision:** Run the backend, web app, database, Auth, and Storage on the OpenStack
environment rather than Render, Vercel, or cloud Supabase.

**Reasoning:** Keep the product stack and data under project control and support the
private inference architecture.

**Implications:** Deployments and migrations are manual. Cloud Supabase is read-only.
Environment changes require service restarts, and Next.js public values require a
rebuild.

## 2026-08-30: Mobile leads item presentation

**Decision:** The iOS app is the source of truth for item field order and item
presentation. Web mirrors those semantics.

**Reasoning:** Mobile is the primary product client and the most developed inventory
workflow.

**Implications:** Do not redesign shared item concepts on web first. Preserve mobile
field meaning across platforms.

## 2026-08-30: Spaces are persistent records

**Decision:** Space operations use the Spaces API and `space_id`; deleting an owned
Space intentionally deletes its items.

**Reasoning:** Looping over item `location` strings caused split, orphaned, and stale
inventory.

**Implications:** Keep the legacy `location` value synchronized for compatibility.
Never reintroduce orphan-to-Unsorted deletion behavior.

## 2026-09-09: Public integrations use scoped API keys and RLS

**Decision:** External integrations use `/api/v1` with hashed, expiring, revocable
workspace or organization keys. They do not receive service-role access.

**Reasoning:** Team permissions, revocation, and least privilege must remain enforced
for assistant and automation clients.

**Implications:** MCP and Actions wrap the public API. They do not connect directly to
the database. Migration `034` and its PostgreSQL tests are part of the contract.

## 2026-09-19: FIND owns inventory photo understanding

**Decision:** Route single-item and multi-item photo analysis through the server-side
FIND pipeline.

**Reasoning:** Inventory capture needs segmentation, identification, OCR/barcode
evidence, and measurement rather than a general language model vision response.

**Implications:** Clients never receive the FIND key or call FIND directly. Current
jobs are temporary, so durable crops, geometry, review state, and training signals
require new persistence work.

## 2026-09-22: OpenAI is not a runtime dependency

**Decision:** Use FIND for photos and the FTCTools agent gateway for language tasks,
with no OpenAI SDK, key, model, or fallback in the application runtime.

**Reasoning:** The project uses its own inference pipeline and gateway while keeping
the existing authenticated application tool layer.

**Implications:** Keep FIND and the language gateway separate. Do not send inventory
images to the text-only tool path or silently restore an external fallback.

## Current coordination rule: one lane per pull request

**Decision:** A change should own one clear implementation lane and avoid concurrent
edits to the same area. Use a branch or worktree for isolation.

**Reasoning:** Several coding agents and local worktrees operate on this monorepo.

**Implications:** Register active work, inspect git state, keep changes scoped, and
write a handoff only when another agent must continue unfinished work.

## 2026-09-28: Recover the public App Store mobile baseline

**Decision:** Restore the complete mobile source from the live App Store release,
FindEZ AI `1.0.6 (17)`, and use that code for the next TestFlight build.

**Reasoning:** The current TestFlight line contains an unaccepted mobile rebuild.
The public release is the known product baseline the user asked to recover.

**Implications:** Commit `0bb4f01066ca8326e0bc807e8a790bf54bba935f` is the
mobile recovery source. The TestFlight artifact differs only in version/build
metadata. Keep later redesign work on its separate branch until it is explicitly
accepted.

## 2026-09-28: Keep item photo galleries backward compatible

**Decision:** Keep `items.image_url` as the primary item thumbnail and store
additional item photo references as `photo` records in `item_events`.

**Reasoning:** Existing mobile, web, barcode, import, integration, and sharing
paths already depend on the singular `image_url` field. The existing event table
was designed for item photos and supports a gallery without a production schema
migration.

**Implications:** New uploads become the primary thumbnail, deleting the primary
promotes the next photo, and scan-generated images remain compatible with older
clients. Photo access must use the owning user's item scope, including Team Space
and legacy Shared Space authorization.

## 2026-09-30: Uncertainty is Review state

**Decision:** Persist uncertain photo results in `capture_reviews`; create an
inventory item only after explicit user confirmation.

**Reasoning:** A guessed identity should not silently become a remembered fact.
Review must survive app restarts and work across mobile and web.

**Implications:** Clients read their own queue. The authenticated backend owns
mutations. Resolution is transactional and idempotent. Save flows require a
durable review identity for uncertain results.

## 2026-09-30: Evidence stays useful and implementation-neutral

**Decision:** Show identity, detection, text, barcode, measurement, assumptions,
warnings, and review reasons. Filter pipeline free text and infrastructure names
at the backend boundary.

**Reasoning:** Users need the evidence to correct an item without exposure to
changing implementation details.

**Implications:** Clients render only the public `scan_evidence` contract.

## 2026-09-30: Image-less inventory rows are text-only

**Decision:** Render a thumbnail only when `image_url` exists. Keep the existing
item photo gallery for adding and deleting photos on items from every source.

**Reasoning:** Empty thumbnail squares waste list space and look broken.

**Implications:** Photo captures retain their crop or source image. Barcode,
spreadsheet, and manual items can receive photos later from item detail.

## 2026-09-30: Home is a concise overview, not a second navigation menu

**Decision:** Match the user's supplied matte-dark Home reference: "My home",
one borderless Ask field, two real-item question suggestions, four "Needs a
decision" cards, retained-photo captures, and grouped persistent Spaces. Use
the previous floating rounded-pill four-tab icon Home / Capture / Ask / Find
navigation (30pt corners, inset 18pt, 70pt bar), per the user's
follow-up request; no separate Home app bar,
header gradient/divider, oversized greeting, or duplicate action tiles.

**Reasoning:** Duplicated actions and an oversized greeting obscured the user's
inventory. The bottom navigation must reserve layout space rather than overlay
content.

**Implications:** "Where things live" uses actual Space records, including empty
ones, and opens by exact ID rather than ambiguous names or legacy locations.
Cards use real pending Review, positive low stock, zero stock, and owned distinct
checkout counts; unknown reads show a dash, not a false zero. Use "out of stock"
instead of inventing physical missingness. Older photos use "Recent captures"
rather than claiming "Captured today". Documents, notifications, and profile
remain reachable through Find's More menu; bottom navigation reserves layout
space and does not overlay the list. Embedded Ask, Capture and Find must not add
the old overlay-clearance padding on top of that reserved space. The user-requested navigation restoration
supersedes the reference's text-only five-tab bar without changing Home content.

## 2026-09-30: Ask presents checked records, not internal reasoning

**Decision:** Match the supplied Ask reference with a plain question card,
collapsed "What it read", readable response, and one grouped set of actual
quantity rows. Keep the restored four-tab pill and Home unchanged.

**Reasoning:** Evidence should explain which accessible records informed an
answer without exposing provider names, private reasoning, or tool internals.
Project readiness cannot be based on invented requirements or stock.

**Implications:** The additive public `answer_context` contract contains only
bounded source labels/details and item quantities. Named project readiness uses
the same authorization and reservation-aware calculation as project kits;
ambiguous or unknown projects request clarification. Status badges are derived
from available versus required quantities, and duplicate requirements cannot
reuse the same units. Migration `037` saves this snapshot on assistant messages
under existing conversation ownership/RLS, so later history does not imply a
fresh stock check. Older answers without a snapshot have no fabricated trace.
General streaming, voice input, and existing inventory actions remain intact.
Conversation setup and snapshot write failures must surface a safe error;
missing/foreign conversation IDs are rejected instead of silently opening a new
thread. Optional memory retrieval remains best-effort and is not claimed as a
successful history write.

## 2026-10-01: Ask photos identify and compare, not silently add inventory

**Decision:** Ask supports one camera/library image per question, with a removable
and replaceable preview. Reuse FIND's existing extraction and verified catalog
enrichment, then compare only access-scoped inventory. Barcode or brand/part
identifiers can support a product match; names alone are possible matches, not
proof of ownership. Uncertain objects go to Home Review with their retained
source/crop photos. Photo questions never automatically create inventory items.
Read-only explanations have no mutation tools. Public photo snapshots use the
existing assistant `answer_context`; history URLs are reconstructed from an
owned generated storage path, and mobile validates the origin and owner before
loading them. Uploads are validated/downscaled and stripped of metadata, and
consume the existing photo/chat quotas. Text-chat speed and FIND behavior are
unchanged: the user explicitly withdrew the speed request.

## 2026-10-01: Profile is the fifth pill destination and utility hub

**Decision:** The user's explicit follow-up adds a circular Profile destination
after Home / Capture / Ask / Find in the existing inset rounded icon pill. This
supersedes the earlier four-tab decision without changing the approved Home or
Ask designs. Keep existing PageView indices and tutorial targets intact; Profile
is appended at page 4.

**Implications:** Move the old Find More destinations and duplicate notification
header icons into Profile. Group profile editing separately from settings;
retain existing scanning, subscription, support, legal, sign-out and confirmed
account-deletion behavior. Documents/notes, notifications, lent items and app tour
remain explicit existing destinations, not invented settings. The hub uses real
account data, safe read errors and stale-response/account guards. This is a
mobile-only navigation change, not a billing or backend redesign.

## 2026-10-01: Shared profile identity and scoped Documents polish

**Decision:** Use one shell-owned, memory-only, account-scoped profile snapshot
for the profile editor, utility hub and navigation avatar. Confirm writes before
updating it; invalidate stale reads and image cache on photo replacement/removal.
Profile editing is a labeled, scrollable form with one Save changes action,
validation, preserved drafts on failure and explicit discard. Keep the existing
account API and profile photo bucket/5 MB contract; multipart uploads must declare
their actual supported image MIME type.

**Scope:** Documents and its note/link/rename subflows adopt the existing matte
grouped design, retaining all authorized actions. Reject foreign document/photo
URLs, guard late responses and account changes, and do not log private upload
payloads. Capture document-link preference keys before asynchronous work. The
supplied Settings images are style guidance, not implemented training, retention,
offline, export or text-size controls. Home, Ask speed, Capture, web, backend and
native lifecycle work remain unchanged.

## 2026-10-01: Mobile pill uses icons without visible tab labels

**Decision:** Hide every bottom-navigation label, including the selected tab,
at the user's request. Retain the existing five icons and their order, selected
indicator, inset pill, saved profile avatar, routing and tutorial targets.

**Accessibility:** Keep the destination names in semantics and long-press
tooltips. Icons stay centered and the full destination remains a touch target;
removing painted labels must not remove screen-reader names or selected state.
This changes mobile navigation only, not branding or screen content.

**Screenshot correction:** The user rejected build 43's label-era proportions.
Use a 56pt visible bar and a small circular selected highlight rather than the
wide badge. Keep SafeArea outside the decorated pill so the inset does not grow
the pill; a parent that already consumes it must not add it a second time. This
supersedes the earlier 70pt labeled-bar height, retaining 44pt-or-larger targets.

## 2026-10-02: Swipe dismissal belongs to item information in every Space

**Decision:** Give the existing item-info panel coordinated downward dismissal
and content scrolling through the same controller, across personal, shared/joined
and Team Spaces. Keep the separate Edit item form unchanged. Retain the existing
visual handle and Close fallback, with an accessible dismissal action.

**Safety:** The modal's independent drag pop is disabled so it cannot bypass save
checks. Pulls from the top dismiss; a short pull restores the panel. Notes require
Save/Discard/Keep editing consent, pending photo/note saves keep the panel open,
and debounced purchase-source and low-stock changes are flushed before closing.
Failed writes preserve drafts and show safe errors. Read-only dismissal never
writes, and dispose never starts a new write under a potentially changed account.

**Animation:** Accepted dismissal stays latched until route disposal. A late
scroll-end notification must not restore height during the exit animation;
only canceled or blocked dismissal restores the sheet. Build 45's unlatching
caused a reproduced upward jump and must not be reintroduced.

## 2026-10-04: Space mutations invalidate the owner's inventory snapshot

**Decision:** Rename and cascade deletion clear the same per-user inventory cache
used by search and shared reads. Invalidate on failure too, because a preceding
database write may already have succeeded; propagate the error rather than
reporting success. Do not evict unrelated users or solve stale backend state by
changing mobile field grouping. Existing ownership predicates, API contracts and
schema remain unchanged. This cache fix does not make the two rename writes
transactional.

## 2026-10-04: Preserve the existing FIND connection

**Decision:** The user explicitly withdrew the proposed FIND transport change
after the connection review. Leave the existing server-to-FIND HTTP URL,
allowance, credentials and proxy configuration unchanged. No transport change
was deployed; do not keep pursuing proxy access or silently switch protocols
while preparing build 46 for submission.

**Risk:** This preserves functionality, not end-to-end encryption. Keep the
unencrypted server-to-FIND hop documented. A future TLS/private-route migration
requires new authorization and its own verification. Other release checks and
screenshots remain outstanding.

## 2026-10-04: Free pilot is advertised through November 1, 2026

**Decision:** November 1 is the final free-pilot day requested by the user;
following-day plan copy says November 2. Keep backend `/me/limits`, web pricing
copy and the mobile fallback consistent. API notice remains authoritative on
refresh; offline clients retain their cached notice until a successful refresh.

**Scope:** This is a date/copy correction, not activation of billing or automatic
expiry. Preserve the existing manual `PILOT_MODE` gate, optional informational
`PILOT_ENDS_AT`, public visibility flag, Stripe guards and plan limits. No exact
cutoff timezone or automatic switching was specified. Billing activation needs
a separate authorized release/check; users are not charged automatically.
The mobile fallback is source for the next approved binary, not a new Apple
upload. Apple upload/submission remains explicitly held.

### October 5, 2026: fresh screenshots before Apple review

The user withdrew immediate App Store submission and requested a newly built
simulator to capture current screens before recreating the supplied artwork.
Keep the manual draft on valid build 58 with its saved description, release
notes and review instructions. No em dashes are permitted in entered form text.
No supplied screenshots were uploaded or replaced. Submit only after this
screenshot task is resumed by the user; do not treat the earlier request to use
the ZIPs unchanged as the final instruction.
