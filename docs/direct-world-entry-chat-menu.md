# Direct entry and web chat sources

October 24, 2026. Web-only branch `feat/direct-world-entry-chat-menu-20261024`,
based on `2ffa0c7`. No backend, schema, or mobile changes.

## Behavior

Normal signup/signin enters `/worlds`, which validates current memberships before
opening the actor's remembered organization or Personal. With no remembered
choice, a single organization opens directly; no organizations or multiple
organizations opens Personal. The sidebar dropdown switches organization and
remembers a choice only after the world directory has authorized it. Membership
lookup failures are retryable and never grant access from a cached preference.
Invitation/recovery destinations remain explicit. Landing prompts survive auth
and appear in chat for review, without being automatically sent.

Organization creation, rename, deletion, leaving, membership and workspace
management remain available. The directory lives at `/settings/organizations`,
linked from Settings and the organization dropdown. `/organizations` redirects to
chat; its legacy creation intent redirects to Settings. Existing organization
detail/people/settings links continue to work.

The organization chat plus menu follows the current mobile source menu:
- Auto Extract: attach a photo in explicit extraction mode; Send creates a durable
  capture draft through the existing model/scanner pipeline.
- Attach: Photo library, Take photo, Choose files. Normal photos use normal chat
  recognition. PDF/TXT/Markdown text is extracted by the existing server and
  attached to the next message, with excerpt labeling and existing size limits.
- Inventory tools: CSV/XLSX import and camera/manual barcode lookup produce drafts.
  Existing parser and barcode service are reused; no new model parsing layer.
- Add context: Spaces, Items, Projects, Documents and notes. Search and pagination
  use the existing authorized inventory source API. Connections opens the working
  Claude/ChatGPT setup documentation. Google/unfinished connectors stay hidden.

Capture cards allow selection, name/quantity/detail edits and destination choice
before explicit Save. Edits use server revisions. Lost receipts require refresh;
retries use the same durable capture. Duplicate matches require explicit consent.
Partial batches show actual saved/review/failed counts. Uncertain observations
remain in the existing review queue. Attachments and context are cleared on chat
changes and remain actor/world scoped. A sidebar New chat action waits while an
import is in flight so a committed draft cannot be discarded before its receipt.

## Validation and limits

Tests cover auth handoff, revoked/stale membership, actor switching, prompt
retention, mobile menu actions, delayed context responses, strict source payloads,
ordinary photos versus Auto Extract, capture events surviving answer errors,
import-without-model behavior, explicit saves, duplicate consent, receipt failures
and double-click prevention. Local validation: 556 tests in 76 suites passed; TypeScript passed.
Production webpack build passed. Lint reports zero errors and the same 53
existing warnings. Server build and activation receipts follow below.

The inspected deployed `world_chat.py`, `chat_sources.py`, and `chat_capture.py`
SHA-256 hashes match the current API worktree. No server API changes are needed.

Browser visual verification for this revision is unavailable: computer-use reports
`cgWindowNotFound` for both Chrome and Safari. Isolated fixture code was prepared,
but no visual pass is claimed. Real signed-in production AI/save and physical
camera acceptance are not covered by mocked component/transport tests.

No new environment variables or provider setup. Existing server auth, API,
scanner/model and barcode configuration apply. Text attachments and CSV parsing
add no model call themselves; asking about them uses existing chat usage. Auto
Extract and barcode lookup incur existing provider/plan usage. No new services or
subscriptions are provisioned. Files are limited to 10 MB; PDF support is text
extraction, not OCR; context is limited to eight sources/four files/48,000 combined
file characters. Capture saving uses existing batches of up to 200 selected rows.
Browser Take photo behavior depends on the device; desktop normally offers a file
picker. Live camera scanning needs HTTPS and user camera permission.

## Manual acceptance

1. Sign in normally: open the last authorized organization, or Personal, without
   an organization directory. Switch organization, sign out, sign in again.
2. Repeat with a new account and with an account whose remembered membership was
   revoked. Confirm no inaccessible organization's data appears.
3. Submit a landing prompt, complete auth, and confirm its exact text is in chat.
   Check invitation and password recovery links retain their intended flows.
4. Open Settings > Organizations and the sidebar dropdown. Create/manage only a
   disposable organization; confirm existing organization settings are reachable.
5. Plus > Attach > Photo library: choose a fixture photo and send a question.
   Confirm thumbnail and normal chat recognition. Auto Extract should instead
   show a draft that does not save until its destination and Save are confirmed.
6. Attach a text PDF/TXT/Markdown file and each type of authorized context. Check
   chips, removal, queries, empty/error states and inventory switching.
7. Import a small CSV/XLSX and scan/enter a known barcode using disposable data.
   Edit draft, choose destination, confirm once, and inspect saved/review counts.
   Retry a lost response on the same draft; do not start a second import.
8. At desktop and narrow widths, check all nested menus, keyboard Escape/focus,
   source dialogs and capture cards in both themes. Change accounts/organizations
   with open context or chat drafts and confirm previous data does not remain.

## Release

Runtime `18f3b06e612ae80512bbe60c41edb45dcab3b198`, PR193, is live.
All five CI jobs passed in run `40135129405`. Server production build passed.
Build ID: `CGFdjEkOiFJ8kmwO5iqVl`.
Live directory: `/home/ubuntu/findez-web-releases/direct-entry-20261024/frontend`.
Rollback directory: `/home/ubuntu/findez-web-releases/organization-world-20261024/frontend`.
Receipt: `/home/ubuntu/findez-web-releases/direct-entry-20261024/deployment-receipt.json`.

Candidate and public live checks verified 23 route statuses, protected world
redirects and six brand assets. Settings uses the shared streaming layout: its
signed-out HTTP 200 shell contains the Next.js sign-in redirect and no management
content; the check verifies this instead of incorrectly expecting only HTTP 307.
Preserved 361 unrelated source/public files and the backend service PID. Only the
web service restarted. No Vercel deployment was requested or used.
