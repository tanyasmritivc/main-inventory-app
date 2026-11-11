# Amazon purchases through Gmail

Status: implementation candidate in `feat/commerce-connectors`, PR388. Not deployed
or enabled. User chose Gmail instead of forwarding; there is no receiving address,
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

## Server setup (pending)

New migration `20261111_purchase_email.sql` adds two private RLS tables and three
service-only functions. It does not modify existing items, merchant records, roles
or commerce functions. Production schema changes require separate explicit approval
under AGENTS.md; prior approval covered only the earlier commerce schema.

Configure the existing encryption key plus `FINDEZ_COMMERCE_GMAIL_*` from
`backend/commerce.env.example`. Keep Gmail disabled until credentials, migration,
callback security and worker smoke checks pass. Merchant activation is independent.

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
the edge no-referrer/no-store and query-free logging rules to Gmail; the currently
deployed Nginx special log location covers Shopify/Amazon only. Do this before a real
OAuth round trip. See `commerce-edge-proxy.md`. No live Gmail has been read.

## Verification

Local full backend/API-doc suite: 1,698 tests plus ten subtests passed; full web:
358 tests in 48 suites passed. Focused Gmail/commerce/extraction: 73 passed.
TypeScript, changed-file ESLint and a compile-only webpack build pass. The compile used synthetic environment values and substituted fonts; its output must not be deployed. The empty disposable PostgreSQL17 fixture
applies both migrations twice and passes 47 assertions, including state replay,
cross-actor denial, duplicate intake, disconnect versus late refresh and RLS.
Production database and customer data were not used in that fixture.

Production-source overlay/rehearsal, real Google OAuth, worker scheduling, real-mail
parsing quality and physical-inventory reconciliation remain unverified. Do not
deploy a local compile fixture or call this available to customers yet.

## Google setup receipt

Created **FindEZ Connect**, project ID `findez-connect`, number `757329840369`,
under `findezai@gmail.com`. Creation was verified in Cloud notifications and the
project dashboard. No billing trial, paid service or mailbox access was enabled.
Gmail API activation was verified with Status: Enabled in the API details page.
OAuth consent configuration was created after explicit user approval of Google's
User Data Policy: FindEZ Connect, external/testing, support findezai@gmail.com,
developer contact info@findez.ai. No OAuth client secret has been created or copied.
Project: https://console.cloud.google.com/home/dashboard?project=findez-connect
