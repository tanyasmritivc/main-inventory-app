# Ask-first mobile world — 1.1.0 (100) delivered

The app starts at Ask with an organization pill and profile avatar, a quiet
orange/peach backdrop, rounded translucent composer and Ask / Spaces / More tabs.
First-time copy invites users to create their inventory world; existing inventory
gets retrieval-focused copy. Active conversations hide the global header and tabs;
Back returns to the landing state while preserving the conversation and draft.

The organization pill changes the world conversation scope. History remains
private to its author. Ask can propose inventories and Spaces, then reviewed item
changes through the separate organization-chat API. Camera and photo library
attach observations; barcode and spreadsheet entry retain explicit writable
inventory/Space destinations. Voice uses the existing speech input. Structure
creation and item addition are separate reviewed actions; no existing customer
content is recreated, moved or deleted by this redesign.

Spaces lists authorized locations across the selected world. More retains access
to Overview, Review, Projects, documents/notes, lent items and workspace/team
management. Profile and account settings remain reachable. Explicit invitation
links keep their target; normal authentication opens Ask. No web-layout changes.

## Checks

- 710 Flutter tests pass; the one normally skipped release configuration test was
  explicitly enabled with production defines and passed separately.
- Flutter analysis: no issues.
- 14 new native iOS simulator cases pass, including safe areas, narrow phones,
  iPad, large text, keyboard, light/dark themes, capture choices, tabs, durable
  review receipts and HTTP/SSE chat focus/Back/draft retention.
- Full existing native regression suite: 161 cases pass on iPhone 16e / iOS26.2.
- Simulator screenshots reviewed for Ask in both themes, Spaces and More.
- Companion API: 1,199 Python tests plus 10 subtests, SQL/replay and a disposable
  production-copy rehearsal preserving all original values across 90 tables.

The focused test caught and fixed a real Flutter state-loss bug when the global
header disappeared. A stable content key now retains the Chat element. Organization
restoration must finish before the client can issue requests, and stale clients
are rejected after organization/account changes.

All QA used synthetic identities. No testing used the excluded founder account.
Simulator coverage does not verify physical camera/microphone, actual OAuth/email,
provider capacity, background notification arrival or overnight session retention.

## Release dependency

Build 100 requires the companion API and reviewed migration 073. Migration 073
requires explicit production authorization. Prepare/sign/validate the candidate,
then apply 073 and publish the API before delivering the mobile build. Existing
App Store build 99 submission remains untouched. No public submission of 100.

Apple validation reports 1.0.9 is already approved and its release train is closed.
The identical candidate is therefore version1.1.0/build100; the earlier
1.0.9/build100 validation failure is preserved, and was not uploaded.

## Final delivery

Runtime58411f5, PR148; all five CI jobs pass in run39543694110. Companion
API runtime34af900 / PR147 passed all five CI jobs in39543052610. User explicitly
approved migration073 and TestFlight100; 073 and the four-file API overlay are
live after fresh backup, healthy API/database checks, denied anonymous world/photo
access and preservation of99 unrelated Python files. No customer QA writes.

Signed1.1.0(100) passed strict signing,32 archive and32 exported device executable
checks,24 privacy manifests, matching app/extension versions, production HTTPS
anonymous configuration and Apple validation. Apple acknowledged upload with
delivery `cb293add-bf18-49c1-89e1-24692f195964`. IPA SHA256:
`87f215f963ef6d42b192978d41ab787887d1718c3baeaa18fd07f7506a9012b6`.

Artifacts, screenshots, logs, receipt and device acceptance flow are preserved at
`Documents/FindEZ/AppStore/1.1.0-build100`. Processing/availability were not polled;
physical-device acceptance is pending. No public App Store submission of100.
