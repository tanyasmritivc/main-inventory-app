# FindEZ pricing and usage limits

## Approved product decision, not deployed billing

The user confirmed this pricing structure on 2026-10-05. These prices and the
annual-first presentation supersede the earlier pricing hypotheses in this file.
Numeric usage limits, included member counts, and feature boundaries still need
an explicit decision and capacity validation. Entitlement readiness is in scope
for the current mobile rebuild; implementing Stripe and billing is a separate
milestone.

FindEZ serves individuals, small businesses, labs, factories, schools, makerspaces,
and robotics teams. Robotics is one use case within the broader product market.

## Settled plans

All prices are in USD. Annual prices are the full yearly charge.

| Plan | Monthly | Annual | Positioning |
|---|---:|---:|---|
| FREE | $0 | $0 | Individuals trying the basic FindEZ experience, with limited usage |
| PRO | $19 | $149 | Individuals and serious users who depend on FindEZ for belongings and projects |
| TEAM | $99 | $790 | Collaborative groups, including robotics teams, schools, and makerspaces |
| BUSINESS | $299 | $2,490 | Businesses, labs, factories, makerspaces, and larger shared environments |
| ENTERPRISE | Custom | Custom | Larger organizations with negotiated scale, requirements, support, or integrations |

Positioning describes the planned offer, not proof that every capability is ready:

- FREE introduces the basic experience with limited usage.
- PRO provides the full individual physical-memory experience.
- TEAM provides shared physical memory, multiple members, and shared spaces,
  objects, projects, and documents. TEAM is the featured tier in public pricing.
- BUSINESS supports larger shared physical-world environments. Its boundary from
  TEAM must be defined through included capacity and capabilities before sale.
- ENTERPRISE is negotiated. Custom support or integrations require delivery review
  before they are included in a contract.

## Annual-first presentation

Public pricing defaults to annual billing and offers a clear monthly toggle. Show
the complete annual charge, the comparison with twelve monthly payments, and the
savings. Any monthly equivalent must remain adjacent to "billed annually" and the
full yearly charge.

| Plan | Twelve monthly payments | Annual charge | Annual saving | Saving | Monthly equivalent |
|---|---:|---:|---:|---:|---:|
| PRO | $228 | $149 | $79 | 34.6% | $12.42 |
| TEAM | $1,188 | $790 | $398 | 33.5% | $65.83 |
| BUSINESS | $3,588 | $2,490 | $1,098 | 30.6% | $207.50 |

These savings compare the settled monthly and annual prices; they are not claims
about a previous sale price. Monthly billing remains available.

## Entitlement readiness and milestone boundary

These are requirements for the rebuild and later billing work, not completed
implementation:

- Preserve the five named tiers in the product contract: `free`, `pro`, `team`,
  `business`, and `enterprise`. Legacy `team_member` status needs an explicit
  compatibility mapping rather than being treated as a new commercial plan.
- Distinguish personal entitlement from access provided by a shared workspace or
  organization. Membership alone must not imply entitlement to every paid feature.
- Prepare client presentation for server-authorized capabilities and limits, with
  clear handling of unavailable entitlement data. Client caches are not authority
  for granting server access.
- Define member counts, inventory records, spaces, AI usage, storage, and pooled
  versus personal allowances before publishing a detailed feature comparison.
  Do not carry forward old numeric quota proposals as approved limits or promise
  unlimited usage without capacity validation.
- Keep checkout, payment collection, Stripe products and subscriptions, purchase
  verification, and billing lifecycle implementation in the separate billing
  milestone. That milestone must also settle the iOS purchasing path and verify
  renewal, cancellation, downgrade, and provisioning behavior.

## Current source differs from the approved offer

The inspected rebuild branch still has legacy billing and entitlement code:

- `backend/app/api/routes/billing.py` creates one-time seasonal purchases with
  `mode="payment"`. Its checkout plans are `ftc_season`, `frc_season`, and
  `district`, not these recurring subscriptions.
- `backend/app/api/router.py` mounts the billing router; the old `stripe_routes.py`
  router is intentionally not mounted. The earlier claim that both are mounted
  was stale.
- `mobile/lib/core/pro_status.dart` uses legacy free/pro/team-member status and a
  cached paid-status check. This does not establish readiness for all five tiers.
- `backend/app/services/usage_service.py` contains existing Free and Pro limits.
  Those values do not settle the new tiers' allowances.

Recording these prices changes documentation only. It does not configure Stripe,
Apple purchases, a public pricing page, runtime quotas, or production entitlements.

## December 31, 2026 ARR target

The user's target is $250,000 annual recurring revenue (ARR), equivalent to
$20,833.33 in monthly recurring revenue (MRR). Because annual billing is preferred,
use the actual discounted annual charge in annual-plan calculations.

One illustrative all-annual subscription mix is:

| Plan | Active paying accounts | Annual subscription value |
|---|---:|---:|
| BUSINESS | 80 | $199,200 |
| TEAM | 50 | $39,500 |
| PRO | 80 | $11,920 |
| Total | 210 | $250,620 |

This is $20,885 of monthly-normalized recurring revenue. It is target arithmetic,
not a validated acquisition forecast. Organizational accounts can include multiple
users, so account counts and registered or active user counts are separate metrics.

Alternatively, 101 BUSINESS annual subscriptions alone produce $251,490 ARR.
Fifty subscriptions in each paid tier at the monthly prices produce $20,850 MRR
and $250,200 ARR; that calculation must not be used for annual-plan buyers.

Count actual recurring subscriptions after discounts and churn. Free users,
trials, and one-time seasonal payments do not contribute to this subscription ARR
target. Annual cash collected is a separate measure from revenue recognized during
the year. See [Stripe's recurring-revenue definitions](https://docs.stripe.com/billing/subscriptions/analytics).
