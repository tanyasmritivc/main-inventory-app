# Chat destinations and inventory picker - build 167

Chat import destinations use the current world directory rather than listing every account workspace. This covers CSV/Excel and parts-list imports opened directly or through Connections. Existing context sources and capture cards already use world-scoped endpoints. Inventory selection rechecks the workspace, organization, edit access and active account/world before opening Spaces; the import client retains that scope guard.

Personal uses its own directory, including independent workspaces. Non-chat, account-wide destination selection remains available. API-key setup and grants are unchanged.

More tools share a bounded, scrollable inventory sheet with inventory cards, workspace subtitles, a close control and safe-area padding. Long labels wrap at large text sizes. A result is discarded if the organization changes while the sheet is open.

Checks: destination regression tests cover organization-only reads, viewers, reparenting, revoked edit access, stale responses, Personal, unchanged unscoped behavior, scoped import handoff, both themes, large text, scrolling, selection and cancellation. World-shell tests cover each More tool's picker. Native audit: `flutter test integration_test/inventory_destination_audit_test.dart -d <simulator> --no-pub --reporter expanded`.

Build 167 is prepared for TestFlight. Full-suite, native, signing and upload results will be recorded in the delivery receipt. Physical-device acceptance remains separate. Backend, web, schema and public App Store submission are outside this change.
