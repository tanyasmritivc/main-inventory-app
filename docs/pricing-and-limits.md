# FindEZ — pricing and usage limits

A starting point, not a verdict. The tier structure and the cap
*shapes* are grounded in what the code actually costs to run. The
specific dollar figures are judgement calls that should be tested
against real users before they harden.

---

## What actually costs money

Read from the code, not assumed:

| Feature | Model | Relative cost |
|---|---|---|
| AI chat | `gpt-5-mini` (`settings.openai_model`) | low |
| Memory extraction (per chat msg) | `gpt-4o-mini` | very low |
| Search query parsing | `gpt-4o-mini` | negligible |
| **Photo scan / extract_from_image** | **`gpt-4o` vision** | **high** |
| Spreadsheet import mapping | `gpt-4o`, once per import | moderate, rare |
| Barcode lookup | Go-UPC + `gpt-4o-mini` fallback | negligible |

The asymmetry matters. Chat is your differentiator *and* it is
cheap — be generous with it. Photo scanning is where a single
enthusiastic user can cost real money, and it is the only feature
that needs a tight leash.

This is why a single blanket "AI credits" number would be the wrong
design here. Cap the expensive thing; leave the cheap thing open.

---

## Tiers

### Free

Unchanged except where noted. The job of this tier is to prove the
product works on the user's own stuff, then run out.

| | |
|---|---|
| Items | 30 |
| Spaces | 3 |
| AI chat | 20 / month |
| Photo scans | 5 / month |
| Barcode scans | 10 / month |
| Spreadsheet imports | 2 / month |
| Active shares | 1 |

**One change worth considering:** 30 items is tight. A single
kitchen drawer is 30 items. A user who imports a spreadsheet hits
the wall before they have seen the product work, which converts
nobody — it just annoys them. 50 would let someone finish
cataloguing one real space.

Test this rather than assuming. If free users are churning at
exactly 30 items, that is your answer.

### Pro — $6.99/mo, $59.99/yr

Keep the price. It is normal for this category and the annual
discount (28%) is in the right range.

Replace `"limit": 999999` with real ceilings:

| | Monthly | Daily |
|---|---|---|
| AI chat | 1,000 | — |
| Photo scans | **300** | **30** |
| Spreadsheet imports | 20 | — |
| Barcode scans | unlimited | — |
| Items | unlimited | — |
| Spaces | unlimited | — |
| Active shares | unlimited | — |

These are set so that a genuine power user never sees them. 300
photo scans a month is ten a day, every day — far beyond normal
cataloguing. The daily cap of 30 is what actually stops scripted
abuse, because it bounds the damage to one day rather than one
month.

At the absolute ceiling a Pro user costs roughly $5–8 in OpenAI
against $6.99 of revenue. That is deliberately near break-even:
the cap exists to bound the tail, not to be reached. A realistic
heavy user (100 chats, 30 scans) costs well under a dollar.

### Team — new tier

The gap in the current model. An FTC team of 20 sharing one
inventory has no sensible way to buy today: either one person pays
personally, or everyone squeezes onto a single login.

| | |
|---|---|
| Members | up to 20 on shared spaces |
| Everything in Pro | per member |
| Photo scans | 300 / month pooled across the team |
| Admin | one billing owner, members join by code |

**Pricing shape matters more than the number here.** Two options:

- **$19.99/month** — familiar, recurring, easy to reason about
- **$99 / season** — FTC runs Sept–April; a coach expensing one
  line item for the season is an easier sell than a subscription
  they have to justify renewing, and it sidesteps summer churn

The seasonal option is the more interesting bet and the one your
market is most likely to respond to. It is also the one you can
validate with four phone calls.

---

## Enforcement — three layers

**1. Per-route rate limits (already built).** slowapi is in place
and the expensive routes are already covered:

```
/ai_command              20/minute
/ai_upload               10/minute
/extract_from_image      10/minute
/inventory/extract...    10/minute
/import/spreadsheet       5/minute
/search_items            30/minute
```

These are your burst protection and they are fine as they are.

**2. Quotas (needs the change).** `check_limit` currently returns
`{"limit": 999999}` for any Pro user — genuinely uncapped. Replace
with a `PRO_LIMITS` dict mirroring `FREE_LIMITS`.

The existing `usage_limits` table is keyed by month, which is the
right granularity for everything except photo scans. Those need a
daily counter as well.

**3. Fair use in the terms.** A clause reserving the right to
throttle abusive usage. This is the backstop for the case nobody
predicted, and it costs nothing to add.

---

## When a limit is hit

The difference between a good and bad experience here is larger
than the limit itself.

**Free user hits a cap** → upgrade sheet. This is the conversion
moment and it already works.

**Pro user hits a cap** → *not* an upgrade prompt. They already
paid. Show what reset looks like:

> "You've used today's 30 photo scans. Resets at midnight."

A paying customer who gets sold to when they hit a ceiling churns.
A paying customer who gets told when it resets waits.

**Never fail silently.** A quota rejection that renders as an
empty screen is indistinguishable from the app being broken —
which is the failure mode that already cost real debugging time on
this codebase.

---

## Implementation

Backend only. Roughly an afternoon.

1. Add `PRO_LIMITS` to `usage_service.py` alongside `FREE_LIMITS`.
2. `check_limit`: replace the `is_pro → 999999` branch with a
   `PRO_LIMITS` lookup. Unlimited features map to `None`, checked
   explicitly rather than by magic number.
3. Add a daily period alongside the monthly one in `usage_limits`
   (a `period_type` column, or a `YYYY-MM-DD` period string),
   applied only to `photo_scan`.
4. `increment_usage` writes both counters where both apply.
5. Return `resets_at` in the limit-exceeded response so the client
   can say when, not just no.
6. Mobile: distinguish free (upgrade sheet) from pro (reset time)
   in the 402/403 handler.

Team tier is a larger piece of work — billing owner, seat
management, pooled quotas — and is a v1.1 item. The Pro caps are
the part worth doing before launch, because uncapped Pro is a
live liability.

---

## What to validate before treating any of this as settled

- Ask three or four FTC coaches how they would want to buy, and
  what a team seat is worth to them. Monthly or seasonal.
- Watch where free users stop. If it clusters at 30 items, raise
  it.
- Instrument actual OpenAI spend per user for a month before
  finalising the Pro caps. The numbers above are reasoned from
  model choice, not measured from your bill.

The last one matters most. Every figure in this document is an
estimate until you have a month of real usage data, and that data
will be more persuasive than any framework.
