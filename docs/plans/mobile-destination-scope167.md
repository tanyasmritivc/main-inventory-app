# Chat destinations and inventory picker - build 167

Chat import destinations use the current world directory rather than listing every account workspace. This covers CSV/Excel and parts-list imports opened directly or through Connections. Existing context sources and capture cards already use world-scoped endpoints. Inventory selection rechecks the workspace, organization, edit access and active account/world before opening Spaces; the import client retains that scope guard.

Personal uses its own directory, including independent workspaces. Non-chat, account-wide destination selection remains available. API-key setup and grants are unchanged.

More tools share a bounded, scrollable inventory sheet with inventory cards, workspace subtitles, a close control and safe-area padding. Long labels wrap at large text sizes. A result is discarded if the organization changes while the sheet is open.

Checks: destination regression tests cover organization-only reads, viewers, reparenting, revoked edit access, stale responses, Personal, unchanged unscoped behavior, scoped import handoff, both themes, large text, scrolling, selection and cancellation. World-shell tests cover each More tool's picker. Native audit: `flutter test integration_test/inventory_destination_audit_test.dart -d <simulator> --no-pub --reporter expanded`.

FindEZ 1.1.2 (167) uploaded to Apple, delivery `6fd7666a-a282-476a-bfa0-e5f1cf23331a`, runtime `742d291f8ccf9bd8ae4152175a3297b7c22a35f4`. All 1,276 mobile tests pass (one existing skip), 35 focused save checks, 20 final focused checks, 11 native destination checks and 20 final native extraction checks pass, with clean analysis and all five exact-source CI gates. Signed archive/export passed platform, signature, privacy, configuration, font and credential checks plus Apple validation. Processing/tester availability were not polled; physical-device acceptance remains with the user. Backend confirmation is deployed separately (PR295); web, schema and public App Store submission are unchanged. See `mobile-destination-scope167-receipt.json`.

## Explicit extraction confirmation

Photo extraction currently marks all GLM results as requiring review. The chat
save endpoint previously queued these even after the user pressed Save. Build167
adds an explicit Add to Space action, with an alternative to keep uncertain items
in Review. Chat sends `confirm_items: true` only on the explicit add action; the
backend freezes that choice with its existing idempotent save checkpoint. Original
model evidence remains in the draft. Missing quantities must be supplied before
adding, so an unknown count cannot silently become one. Photo confirmation follows
the same two-action wording and accepts checked identity details directly.

The additive backend contract is delivered separately on
`fix/capture-confirm-to-space`; old clients retain their current behavior. API-key
and integration scope remains unchanged. Existing Review entries are not moved.

## Apple version correction

Apple rejected 1.1.1 (167) during validation because version 1.1.1 was already
approved and its build train closed. The new TestFlight package is 1.1.2 (167).
No upload occurred for the rejected package; runtime feature code is unchanged.
