# Chat destinations and inventory picker - build 167

Chat import destinations use the current world directory rather than listing every account workspace. This covers CSV/Excel and parts-list imports opened directly or through Connections. Existing context sources and capture cards already use world-scoped endpoints. Inventory selection rechecks the workspace, organization, edit access and active account/world before opening Spaces; the import client retains that scope guard.

Personal uses its own directory, including independent workspaces. Non-chat, account-wide destination selection remains available. API-key setup and grants are unchanged.

More tools share a bounded, scrollable inventory sheet with inventory cards, workspace subtitles, a close control and safe-area padding. Long labels wrap at large text sizes. A result is discarded if the organization changes while the sheet is open.

Checks: destination regression tests cover organization-only reads, viewers, reparenting, revoked edit access, stale responses, Personal, unchanged unscoped behavior, scoped import handoff, both themes, large text, scrolling, selection and cancellation. World-shell tests cover each More tool's picker. Native audit: `flutter test integration_test/inventory_destination_audit_test.dart -d <simulator> --no-pub --reporter expanded`.

Build 167 is prepared for TestFlight. Full-suite, native, signing and upload results will be recorded in the delivery receipt. Physical-device acceptance remains separate. The additive backend dependency is deployed separately below; web, schema and the public App Store submission are unchanged.

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
