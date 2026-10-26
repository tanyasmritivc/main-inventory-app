# Pre-release checklist — fresh account pass

Run on a clean install with a brand-new account. Each item lists what
success looks like and the specific failure signature to watch for.

The failure signatures are not generic — they are the bugs actually
fixed on 2026-07-29. These are the most likely things to be
incompletely fixed or to regress.

You need: a second device or simulator, and a throwaway email.

**Note:** production currently has `PILOT_MODE=true`; the free-pilot notice runs
through November 1, 2026 and active-pilot accounts have unlimited access.
The date is informational and does not automatically enable billing. Verify
`GET /me/limits` before testing caps; do not disable the production pilot for QA.
Section 8's cap checks apply to a controlled non-pilot test environment.
Outside pilot mode, a new account is on the free tier — 3 spaces, 30 items,
1 active share, 20 AI chats/mo, 5 photo scans/mo, 10 barcode
scans/mo. Some steps below deliberately test those limits.

---

## 1. First run

Delete the app completely, reinstall, sign up with a new email.

On Home, verify "My home", one borderless Ask field, up to two real-item question
suggestions, four decision cards, retained-photo captures, and grouped saved
Spaces (including empty ones). There must be no header gradient/divider, extra
icons, greeting, or duplicate Capture/Ask/Find action tiles. The icon Home /
Capture / Ask / Find / Profile navigation must be the inset rounded pill with
the previous selected-tab highlight and a circular Profile icon; it must reserve
layout space. Profile must open account editing, settings, documents/notes,
notifications, lent items and app tour. There must be no duplicate Find More
sheet or notification header icons. Repeat on a small screen and at larger text
size; Home and Profile must not overflow. Check profile read/save failures,
avatar selection/removal, settings persistence, support/legal links and sign-out.
Cancel account deletion and verify no data changes; confirm deletion only with a
throwaway account. Switch accounts and ensure no prior account details remain.

Review opens from "need identifying". Verify card counts against the live data:
positive low stock excludes zero stock, and lent out counts owned distinct items,
not checkout rows or teammates' items. Failed first reads show dashes and an
error, not fabricated zeroes. Each Space opens by its ID even if names differ only
in case. Photo captions open item details; no-photo items have no blank square.

Item information (opened with the info button, not the Edit item form) must
dismiss with a downward swipe at the top in personal, shared/joined and Team
Spaces, smoothly and without jumping upward or re-expanding during exit.
Confirm long-content scrolling and horizontal photo paging do not close
it. A short pull restores the panel. Unsaved notes require Save/Discard/Keep
editing; pending photo/note/document/return writes keep it open. Failed autosaves
preserve drafts, and read-only dismissal creates no write. Use a throwaway item
for mutation checks; Close remains a fallback.

**Pass:** onboarding runs, then the tutorial runs to completion.
Every step has something to point at, and "Skip" is visible and
tappable at every step.

**Watch for:**

- A dark screen with no card and no way out. That is the tutorial
  targeting a widget that does not exist — the exact case with zero
  spaces. Steps pointing at a space card should be skipped, not
  shown empty.
- "Skip" overlapping the icon underneath it — it should sit inside
  the tooltip card, not float over the app bar.
- On the chat step, the highlight ring should hug the input field.
  If it sits low or is too tall, the hole was measured before the
  layout settled.
- The keyboard appearing and refusing to dismiss.

---

## 2. Inventory loads and stays loaded

### Ask photo attachment acceptance

On a physical iPhone, use Ask's add button for both camera and library. Verify
permission denial and cancellation are safe; the preview can be removed or
replaced; sending a photo without text supplies an identification/ownership
question; and the sent photo remains visible. Check a known barcode/brand-part
match, a name-only possible match, no match, and an uncertain result that appears
in Home Review with its photo. No inventory item should be added merely by asking
about a photo. Send a follow-up about the object, try New chat during analysis,
and switch accounts; no prior account's photo or late response should appear.
Try a narrow device and larger text/keyboard. Native install/launch and widget
tests do not count as passing this hands-on check.

Open Find. Switch to Ask and back. Do that **six
times**.

**Pass:** the same spaces appear every single time.

**Watch for:** spaces appearing then vanishing on a later switch.
That was the empty-query LLM bug — the route invented a filter and
returned zero items. It was nondeterministic, so one or two
switches is not enough of a test. Six.

If it happens even once, stop and report it.

---

## 3. Adding items, three ways

Create a space called `Test Workshop`. Add one item each way:

- by hand via the add form
- via chat: `add 3 HDMI cables to Test Workshop`
- via scan (barcode or photo)

**Pass:** all three appear in the space, and the space card shows
**3 items**.

**Watch for:** the card showing a lower count than the list inside
it. That means `space_id` was not set on some items — a count query
by `space_id` misses anything that only has `location` text. The
hand-added and scan-added paths were fixed later than the chat one,
so those are the likelier culprits.

### Photo confidence and Review

Capture a clear object and an ambiguous group photo.

**Pass:** a clear object can be saved to Find with its crop or source photo.
Every uncertain object appears in Home → Review after an app restart and stays
out of inventory until confirmed. Review shows available identity and detection
confidence, visible text, barcode, measurements and assumptions, and a plain
reason for review. It never shows internal model, endpoint, or infrastructure
names.

Confirm one Review item and dismiss another. Confirmation creates exactly one
item on retry; dismissal creates none. An item with no photo has no empty
thumbnail tile. For photo, barcode, spreadsheet, and manual items, verify that
item detail can add and delete photos.

---

## 4. Empty spaces persist

Create a space called `Empty Test`. Add nothing. Leave the page, go
to chat, come back.

**Pass:** `Empty Test` is still there, showing "0 items".

**Watch for:** it disappearing. That would mean spaces are still
being derived from item locations rather than read from the spaces
table.

Also ask in chat: `how many spaces do I have`. `Empty Test` should
be included.

---

## 5. Rename — the one that corrupted data

Put at least 5 items in `Test Workshop` across two categories.
Rename it to `Main Workshop`.

**Pass:** one space named `Main Workshop` with all 5 items. No
space named `Test Workshop` remains.

**Watch for:** two spaces afterwards, the old name holding some
items and the new name holding the rest. That was the per-item
rename loop with swallowed failures. It should now be a single
`PATCH /spaces/{id}` call.

Repeat once with a category filter active before renaming — the
old bug only renamed the filtered subset.

---

## 6. Sharing and revoking — do not skip the revoke

On account A, share `Main Workshop`. On account B, join with the
code.

**Pass:** account B sees the items.

Now on account A, **revoke the share**. Then on account B, pull to
refresh.

**Pass:** account B can no longer see the space or its items.

**Watch for:** account B still having access. Revoke used to fail
silently — account A saw no error and assumed it worked. This is
the single most important check in this document, because a
failure here is invisible from the owner's side. Verifying from
account B is the only way to know.

Repeat for removing an individual member from the members list.

---

## 7. Offline behaviour

Turn on airplane mode. Attempt each of these:

- change an item's quantity from the scan sheet
- save a profile change
- revoke a share
- edit a purchase source in the item detail sheet

**Pass:** each shows a visible error. The quantity sheet stays open
rather than closing. The profile edit form stays open with your
input intact. The purchase source shows an inline "Not saved".

**Watch for:** anything that looks like it succeeded. A sheet that
closes, a form that resets, a silent no-op. That is the
`catch (_) {}` failure class — the user believes the action worked
when it did not.

---

## 8. Free tier limits

Still on the new account:

- create spaces until you hit **3** — the 4th should be blocked
  with the upgrade sheet
- add items toward **30**
- try a second active share — should be blocked

**Pass:** the upgrade sheet appears with an accurate message. No
partial writes.

**Watch for:** a limit enforced *after* a bulk operation has
already written rows, or an error that is not translated into the
upgrade sheet.

---

## 9. Backend health, over time

This one is not a single check — watch the production backend logs across the
whole session and for a day of normal use.

**Pass:** no `[Errno 11] Resource temporarily unavailable`, no
`Resource temporarily unavailable`, no `deque mutated during
iteration`, no `PGRST205`.

**Watch for:** endpoints beginning to time out together — search,
shares, and joined all failing at once. That is the connection leak
returning. It takes sustained use to appear, which is why a single
successful page load does not prove it fixed.

Use the AI chat heavily during this pass; that is the code path
that creates the most Supabase clients.

---

## 10. Spreadsheet import

Import `test-data/import-samples/01-clean-baseline.xlsx`.

**Pass:** 20 items land in the chosen space with correct names,
categories and quantities.

Then try `02-ftc-parts-gobilda.xlsx`.

**Watch for:** 1000 rows attempted instead of 26 (trusting
`max_row`), or 28 columns instead of 9. The importer currently
takes `rows[0]` as the header unconditionally, so `03` and `05`
are expected to fail — that is known, not a regression. Note what
happens so the behaviour is at least loud rather than silent.

---

## 11. Profile and Documents physical acceptance

On the exact new TestFlight build:

- Edit name and optional collaboration fields; check a long account email does
  not wrap awkwardly, and Save works above the keyboard with large text.
- Replace and remove the profile photo. Verify the same saved photo appears in
  the editor, Profile overview and bottom pill, including after relaunch. Cancel
  the photo picker and deny Photos permission; drafts must remain intact.
- Navigate back with unsaved profile changes and choose Keep editing/Discard.
  Interrupt a save or upload with connectivity failure; never show false success.
- In Documents, add/open/edit a note and upload/open an image and PDF. Verify
  search, rename, summarize, link/unlink and confirmed deletion. Cancel deletion
  and cause a failed write; the record and draft must remain available.
- Switch accounts/sign out while a profile read, photo picker, document read or
  note draft is open. Do not show the old account's content or submit its draft
  into the new account. Verify with throwaway accounts, not destructive actions
  against real user data.

Record hands-on results separately. Automated widget tests, layout PNGs and
native installation/launch alone do not satisfy this acceptance checklist.

## Result

### October 4, 2026 build-46 submission preflight

- User asked to wait for their release assets. Original icon, mark and outlined
  wordmark SVGs and a 1024x1024 RGBA icon PNG have arrived and were inspected
  read-only; none are installed. Six iPhone artwork PNGs have now arrived, all
  1320x2868 without alpha. Upload format passes, content accuracy does not: text
  navigation/More differs from build 46, and image 5 shows an unimplemented
  drawer-location diagram and `Mark as taken` action. Do not upload as-is or
  redesign the app without a new scope decision. Request real current-app
  captures or approval to revise the artwork while retaining its visual layout.
  Apple guidelines 2.3/2.3.3 require accurate app-in-use metadata. This does not
  pass remaining acceptance checks or authorize submission.
- App Store `1.0.7` selects valid/eligible build `46`, manual release,
  `PREPARE_FOR_SUBMISSION`; not submitted or public. Next-release privacy URL is
  saved and the new dedicated Apple review login was verified and configured.
  Three isolated, admin-created accounts are not evidence of public signup.
- Review account: five sample entries in three categories plus an empty Space.
  Six Ask-to-Find cycles pass on the build-46 simulator client. API-only checks
  pass for recipient visibility, unrelated-account denial, read-only edit denial,
  member removal, share revocation and revoked-code rejection. Physical
  multi-account and invitation UI checks remain outstanding.
- Section 5 FAIL: simulator rename `Test Workshop` -> `Main Workshop` left the
  Space card at `0 items`; all five entries remained inside by Space ID. A live
  API reproduction at `2026-10-04T22:10:26Z` renamed the same test Space again:
  canonical count stayed 5 and the old Space was absent, but all five search
  results retained the previous location. Matching production source confirms
  `rename_space` did not invalidate the 60-second inventory cache. No items were
  lost. The user approved a separate backend correction; rename and cascade
  deletion now evict only the owner's cache, also on failure without hiding errors.
  Six new hermetic regressions and all 349 backend/API-doc tests pass. Exact
  reviewed `spaces_repo.py` selectively deployed with a private rollback copy;
  public health/database checks pass. Live QA at `2026-10-04T22:27:04Z` returned
  five new-location results, zero old-location results, canonical count 5 and no
  old Space immediately. A build-46 simulator UI rename also immediately showed
  `Sample Workshop / 5 items` and retained the empty Space. Automatic tests cover
  all categories; physical/filtered acceptance remains open. Do not relabel the
  original failure or these simulator/API checks as a physical pass.
- Cache-only PR #35 runtime `6027a87` passes all five CI gates (run
  `37240403382`). Post-deployment live API-only sharing/revocation checks also
  pass again. Physical access/offline gates are not replaced by those results.
- Current store screenshots are outdated and have not been replaced; newly
  supplied iPhone artwork needs accurate current-app UI as described above. Offline
  writes, camera/photos, profile/Documents and actual invitation acceptance are
  not passed. Physical Mirroring repeatedly reports iPhone in use. No real user
  data was mutated and no new app version was submitted.
- Main build 46 is valid/eligible, but embedded ShareExtension build is still 17;
  native handoff is unverified. FIND's public-HTTP transport remains a separate
  security limitation. HTTPS probes fail with a TLS internal-error alert from both
  Mac and backend VM. The user subsequently explicitly withdrew the transport
  change and instructed preserving the existing connection; no FIND configuration
  or proxy change was deployed. Record its unencrypted hop as a known risk, not a
  passed security check. Transport migration is excluded from the requested
  release work. No keys/images were sent over HTTP during this preflight. The
  exact signed IPA and its verified backup are preserved.

### Space and Team invitation gates

Before App Store submission, repeat the invitation acceptance checks in
`TESTING.md` on the exact selected build. Check cold/warm URLs, signed-out
account creation, restart, decline and acceptance, revocation while a prompt is
open, joined-Space forwarding with the original permission, and account-first
download continuity. Use isolated throwaway accounts; never join or revoke a
real workspace merely to test. Download-first users must reopen their link.

Build 40's signed-in physical cold-link prompt check failed despite passing Dart
tests. On build 41 the user confirmed the cold Team prompt and a real Safari
Space link's “Open in FindEZ” prompt. A launch-only warm Space payload produced
no prompt; it was not a valid substitute for browser URL delivery. Final build
42 adds actor-bound requests and queued-link regression tests. Its exact signed
archive installed, reports build 42, and launched; the user confirmed the cold
Team prompt and Space prompt from a real Safari fallback tap on that binary.
These checks do not prove real acceptance,
revocation, Messages routing, or a fresh App Store install.

Release record: runtime source `0b4c207`, all five CI gates pass (run
`36969482272`), 343 backend/133 web/114 mobile tests plus MCP/bundle checks,
clean analysis/typecheck and production web compilation. Build 42 passed Apple
validation/upload, processing is `VALID` and `APP_STORE_ELIGIBLE`, and both
internal TestFlight groups are assigned. At that delivery the App Store 1.0.7
manual draft selected build 42. It now selects 46 as recorded above and remains
`PREPARE_FOR_SUBMISSION`, not submitted or public. The existing
placeholder launch-image warning remains a quality follow-up.

The App Store draft must remain manual and unsubmitted until the hands-on gates
pass and current screenshots/privacy/review information have been checked.
After the compatible version is publicly live, expand AASA to Space URLs and
repeat real Safari/Messages routing. Do not publish that association expansion
while public build 17 cannot handle it.

Sections 2, 5, 6, and 7 are the release gates — each covers a bug
that silently corrupted data or leaked access. If any of those
fail, do not ship.

Sections 1, 3, 4, 8 are quality gates: a failure is visible and
annoying but not dangerous.

Section 9 needs a day, not a session.

Section 10 is a known-incomplete feature; record the behaviour and
move on.
