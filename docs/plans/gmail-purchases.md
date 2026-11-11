# Amazon purchases through Gmail

Status: deployed November 11, 2026 at 05:54:39 UTC from runtime `0da7747e`,
`feat/commerce-connectors`, PR388. Gmail imports remain disabled. User chose Gmail instead of forwarding; there is no receiving address,
Resend account, inbound webhook or company-mail integration in this change.

Each FindEZ user authorizes their own Gmail through a separate OAuth client in the
FindEZ Google Cloud project. Use only `gmail.readonly`. This permission
can read the mailbox; the application limits queries and body processing to US
Amazon order notifications. Do not describe the Google permission as Amazon-only.
The initial window is 90 days. This is not a complete Amazon purchase history.

## Implemented

- Connections UI: Gmail consent disclosure, account/status, refresh, disconnect,
  delete imported evidence, order quantities and reviewable email excerpts.
- Account/inventory-bound OAuth state, single-use exchange, PKCE, fixed Google
  hosts, server-only encrypted refresh tokens. Callback strips query parameters
  before asynchronous work and rejects account switches and duplicate keys.
- Scheduled filtered polling, bounded pages, persistent cursors, overlapping date
  windows, message/content deduplication and durable claims across workers.
- Text/HTML body parsing without attachment downloads or remote-image fetching.
  Unsupported bodies are visibly failed rather than blocking later messages.
- Existing agent gateway extracts structured lines with literal title evidence,
  conservative quantities and explicit purchase/shipping/delivery/return statuses.
  Model input is untrusted mail, tools disabled; no new AI provider is introduced.
- Private encrypted pending bodies, removed on successful/terminal processing or
  disconnect. Stored evidence remains actor-private until deletion. Neither inbox
  messages nor physical stock are mutated. No raw message or credential logging.
- Disconnect clears local credentials before attempting Google's revocation.
  Failed remote revocation is visible with instructions to revoke in Google too.

## Purchase semantics and FIND handoff

`GET /commerce/gmail?inventory_id=UUID` returns the current account, latest 1,000
message processing outcomes and grouped observations; `has_more` discloses truncation.
It requires editing permission and only returns the connecting actor's records.

Group only exact order-ID + ASIN matches across messages. Never sum delivery,
shipping or return emails into ordered quantity. Conflicting quantities or repeated
ASIN lines in one purchase email stay unknown; absent identifiers remain separate
review entries. A unit may be a multipack. Every group is `needs_review=true` and
`physically_verified=false`. No total ownership/availability is inferred.

Canonical inventory reconciliation and FIND chat binding belong to the parallel
foundation lane and are not implemented here. It must match/review these observations
against current stock before allocating, claiming ownership or increasing quantities.
Email status is source evidence, not proof of delivery/current possession.

## Server setup (deployed; activation pending)

Migration `20261111_purchase_email.sql` was applied after explicit user approval
and a fresh private backup. It adds two private RLS tables and three service-only
functions without modifying existing inventory quantities or merchant records.
RLS and denied client access were verified in production.

A new encryption key and `FINDEZ_COMMERCE_GMAIL_*` are installed through a private
server-only environment file, with Gmail disabled. Keep it disabled until callback
security, data handling and worker smoke checks pass. Merchant activation is independent.

Configure two separate systemd timers on the self-hosted API server, approximately
once per minute, using the same server-only environment and deployed Python venv:

```text
python -m app.services.commerce.purchase_email --mode poll --max-jobs 20
python -m app.services.commerce.purchase_email --mode extract --max-jobs 20
```

Working directory is the deployed backend. Set each service timeout to 12 minutes;
loops stop scheduling new work after 50 seconds, allowing an active job to complete.
Use separate services so model latency cannot block mailbox polling. Additional
worker instances can use the same durable queues. Monitor queued age, failed jobs,
poll age and Google quota responses before scaling. This is not a throughput SLA.

Default next successful poll is five minutes; pagination uses a shorter next poll.
Errors back off 15 minutes, reset stale page tokens and preserve the date window.
Extraction retries up to five times. After failure, bodies are discarded and the
UI reports incomplete coverage. A revoked grant requires reconnecting. Switching
mailboxes requires deleting previous Gmail evidence first to avoid identity mixing.

## Google and release requirements

Create/select the FindEZ Connect project; enable Gmail API. Create a dedicated **Web
application** OAuth client with exactly the initiating website's callback origin:
`https://www.findez.ai/connect/gmail/callback`. Do not alter the app's existing login
client or put secrets in frontend configuration. Keep test accounts explicit.

Gmail read-only is a restricted scope. Google's documentation requires verification
and a security assessment for server-side storage/transmission of restricted data.
Testing access is not public approval. Before activation, verify privacy disclosures,
deletion behavior and the configured gateway's retention/no-general-model-training
handling against Google's user-data requirements. The existing gateway client
retains conversation state upstream; its transport must use validated HTTPS and
its retention/deletion behavior must be verified before sending real Gmail data.
Never claim review is complete.

- [Gmail scopes](https://developers.google.com/workspace/gmail/api/auth/scopes)
- [OAuth web-server flow](https://developers.google.com/identity/protocols/oauth2/web-server)
- [Gmail search filtering](https://developers.google.com/workspace/gmail/api/guides/filtering)
- [Message retrieval](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.messages/get)

The existing Caddy callback Referrer-Policy override also affects this route. Extend
the edge no-referrer/no-store and query-free logging rules to Gmail; Nginx special logging now covers all three callbacks and was verified with synthetic
values. The separate Caddy change is still required before a real OAuth round trip.
See `commerce-edge-proxy.md`. No live Gmail has been read.

## Verification

Local full backend/API-doc suite: 1,698 tests plus ten subtests passed; full web:
358 tests in 48 suites passed. Focused Gmail/commerce/extraction: 73 passed.
TypeScript, changed-file ESLint and a compile-only webpack build pass. The compile used synthetic environment values and substituted fonts; its output must not be deployed. The empty disposable PostgreSQL17 fixture
applies both migrations twice and passes 47 assertions, including state replay,
cross-actor denial, duplicate intake, disconnect versus late refresh and RLS.
Production database and customer data were not used in that fixture.

Production-source overlay and database rehearsal now passed; see the release
receipt below. Real Google OAuth, worker scheduling, real-mail parsing quality and
physical-inventory reconciliation remain unverified. Do not deploy a local compile
fixture or call this available to customers yet.

## Google setup receipt

Created **FindEZ Connect**, project ID `findez-connect`, number `757329840369`,
under `findezai@gmail.com`. Creation was verified in Cloud notifications and the
project dashboard. No billing trial, paid service or mailbox access was enabled.
Gmail API activation was verified with Status: Enabled in the API details page.
OAuth consent configuration was created after explicit user approval of Google's
User Data Policy: FindEZ Connect, external/testing, support findezai@gmail.com,
developer contact info@findez.ai. The user then authorized continuing with the
prepared credential creation and private backend storage. Created Web application
client **FindEZ Gmail Purchases**, with the sole redirect URI
`https://www.findez.ai/connect/gmail/callback`. Saved only `gmail.readonly` in Data
Access and verified `findezai@gmail.com` in the test-user list. No mailbox grant
was authorized. The client JSON was copied to server staging, verified by digest,
and protected with mode 0600 inside a mode 0700 directory. The disabled environment
file and new encryption key were installed during the approved deployment.
A duplicate downloaded JSON remains in the local Downloads folder: sandbox
restrictions prevented tightening its permissions. Remove that duplicate manually
after confirming the secure copies; never paste its contents into chat.
Project: https://console.cloud.google.com/home/dashboard?project=findez-connect


## Prepared server release — November 11, 2026

Runtime commit `0da7747e`; private staging `/home/ubuntu/findez-gmail-20261111`.
Migration `20261111_purchase_email.sql`, SHA-256
`eb05ea9e5b7f2f872163ecc33a5d44e77f54c46f0b744e5926e7d5314f8e9eef`.
It adds `commerce_gmail_accounts`, `commerce_purchase_emails`, and service-only
`findez_gmail_manage`, `findez_gmail_job`, `findez_purchase_email_job`.

A fresh production snapshot restored into a disposable, network-isolated database
passed both migration applications. All 112 pre-existing tables retained their
row counts/content hashes; existing functions, columns, policies and permissions
were preserved. The two new tables have RLS and deny anonymous/authenticated
access. Only the service role can execute the new functions. Production was not
modified, and the rehearsal container was removed.

The candidate overlays the actual running source, preserving 578 unrelated source
files. Staged backend commerce/Gmail tests and the three focused web suites passed.
A real production webpack build passed with the server environment and fonts;
build ID `RcNBViqziH5UrZOXd8NAj`. Loopback checks returned 200/no-referrer/no-store
for Shopify, Amazon and Gmail callbacks, plus 307 for anonymous Connections.
The temporary HTTP process was stopped. An initial test collection failure was
caused by the staging PYTHONPATH and was corrected before these passing checks.

Private receipts: `rehearsal.json`, `validation.json`, `http-smoke.json`,
`release-manifest.private.json`, `preserved-source.private.json`. Credentials and
raw logs are excluded from source control. The configured gateway uses HTTPS;
its upstream retention/deletion and training policy still require verification.

Deployment was explicitly approved and completed at 05:54:39 UTC. Live hashes were
rechecked, a fresh backup taken, the exact migration applied and grants verified.
The scoped backend overlay and staged web build are live with **Gmail disabled**.
Polling workers have not been started.
Keep previous source/service configuration for rollback; on failure restore those
and retain the additive empty private schema instead of dropping user data.
Public activation is a separate gate after proxy/log protection and data-handling
checks; Google restricted-scope verification is required before broad release.


## Deployment verification

API/database/web health returned 200; the public Gmail endpoint rejected anonymous
requests with 401. The public Gmail callback returned 200/no-store, while Caddy
still replaces no-referrer with same-origin. Anonymous Connections redirects to
sign-in with 307. Signed-in Safari verified the new Amazon purchases card, its
mailbox/AI disclosures, disabled Connect Gmail button and no connected account.

The API service loads `/home/ubuntu/findez-gmail-20261111/gmail.env` via
`/etc/systemd/system/findez.service.d/zz-commerce-gmail.conf`; effective process
configuration was checked without exposing values. The web service's existing
`zz-commerce.conf` now targets `/home/ubuntu/findez-gmail-20261111/candidate/frontend`.
Private rollback files/database backup are in `deployment-backup/`; receipts are
`deployment.json` and `callback-logging.json`. Nginx configuration validation and
reload passed, with synthetic Gmail parameters/referrers absent from callback logs.
No mailbox grant, polling, email import or physical-stock write occurred.


## Dashboard discoverability — deployed November 11, 06:01:37 UTC

Runtime `65618ca3` adds an Amazon & Shopify card above the Tools grid and a visible
Connections shortcut in organization/personal world navigation. The card carries
the Tools inventory selection into `/inventory/connect`; the shortcut opens the
card without assuming an inventory from another organization.

The live world dashboard is newer than this commerce branch. Its existing source
was preserved: `scripts/commerce_dashboard_overlay.py` makes two guarded changes
to `world-tools.tsx` and `world-navigation.ts` in a fresh live-source candidate,
which also receives the two new commerce-dashboard-card files. Apply that overlay
when porting this branch to the current world UI; do not replace live dashboard
files with the older branch. This preserves 572 unrelated frontend files.

TypeScript, changed-component ESLint and the real production webpack build pass.
Build `Taahjb8fsWD206UgC85Jy` deployed from
`/home/ubuntu/findez-connect-dashboard-20261111/frontend`; the web service override
now points there. Private `manifest.private.json`, `deployment.json` and
`zz-commerce.before` preserve the review/rollback receipt. API/database and Gmail
activation are unchanged. Signed-in Safari verified the card visually, followed it
to the correct inventory's Connections screen, then verified the sidebar shortcut
and left the dashboard card open. Connect Gmail remains disabled.
