# Pre-release checklist — fresh account pass

Run on a clean install with a brand-new account. Each item lists what
success looks like and the specific failure signature to watch for.

The failure signatures are not generic — they are the bugs actually
fixed on 2026-07-29. These are the most likely things to be
incompletely fixed or to regress.

You need: a second device or simulator, and a throwaway email.

**Note:** a new account is on the free tier — 3 spaces, 30 items,
1 active share, 20 AI chats/mo, 5 photo scans/mo, 10 barcode
scans/mo. Some steps below deliberately test those limits.

---

## 1. First run

Delete the app completely, reinstall, sign up with a new email.

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

Open the inventory tab. Switch to chat and back. Do that **six
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

This one is not a single check — watch the Render logs across the
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

## Result

Sections 2, 5, 6, and 7 are the release gates — each covers a bug
that silently corrupted data or leaked access. If any of those
fail, do not ship.

Sections 1, 3, 4, 8 are quality gates: a failure is visible and
annoying but not dangerous.

Section 9 needs a day, not a session.

Section 10 is a known-incomplete feature; record the behaviour and
move on.
