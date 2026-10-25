# FindEZ launch plans - October 25, 2026

These are the user-approved planned USD prices. This replaces earlier five-tier
and robotics-season proposals. It is a display catalog, not a billing entitlement.

| Plan | Monthly | Annual | Item records | People | Photo extractions/month | AI messages/month |
| --- | --- | --- | --- | --- | --- | --- |
| Free | $0 | $0 | 100 | 1 | 10 | 50 |
| Plus | $9.99 | $99 | 2,500 | 1 | 50 | 500 |
| Team | $29 | $299 | 10,000 shared | 5 | 200 shared | 2,000 shared |

All plans include unlimited Spaces. Plus includes low-stock reminders. Team adds
shared inventory, permissions and activity. Larger teams contact info@findez.ai.
Verified student/robotics teams are planned to receive 50% off Team, with manual
eligibility review. No discount checkout or entitlement is active.

## Usage definitions for launch

- Item limits count records, not quantity: 500 M3 screws in one record use one slot.
- One photo extraction is one input photo processed for inventory. The number of
  detected objects does not multiply usage. Failures and internal retries must not
  count when the future policy is implemented.
- AI messages are user requests, not streamed tokens, internal tool calls or retries.
- Team allowances pool across the team, not per member.
- Browsing, manual edits, barcode scanning and exports do not consume AI allowances.
- Downgrading or reaching limits must retain view/edit/export of saved inventory.
- Measure FIND GPU time, gateway capacity and retry costs before finalizing allowances.

## What this change does

Both client catalogs use Free/Plus/Team, show monthly and annual prices, and label
paid subscriptions Coming soon. Mobile Settings exposes the comparison while
legacy pilot/upgrade promotions remain hidden. Web Settings and legacy upgrade
entry points use the comparison; the legacy checkout link cannot initiate a charge.
Current server limits and access remain unchanged. No new payment SDK, purchase,
restore, webhook, entitlement grant, schema, billing product or production
configuration is introduced. Internal legacy pro flags are not renamed to Plus.

## Before accepting money

Bank details alone do not activate this product. Configure Stripe recurring prices
and Apple subscription products/agreements, implement provider-verified ownership,
renewal/cancellation/refund/restore and idempotent events, and unify server-side
Free/Plus/Team entitlements before enabling purchase buttons. Inspect the actual
production schema and approve required migrations separately. Replace legacy
one-time seasonal checkout at activation; do not reuse it for subscriptions.

Enforce capacity and successful-operation quotas atomically on the server, with
retry receipts and team-scoped pools. Preserve existing customers and data on
migration/downgrade. Sandbox-test purchase, restore, renewal, expiration, refund,
account switching, retries and failure recovery. Native purchase prices must come
from StoreKit; displayed USD estimates are not checkout prices. Paid access must
never depend on visiting a success URL or a client-only flag.

Public App Store submission is still held for the user's separate instruction.
