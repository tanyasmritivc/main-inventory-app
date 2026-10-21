# Ask-first mobile world — build 100 candidate

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
