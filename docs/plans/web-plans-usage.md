# Web plans and usage — October 26, 2026

## Behavior

Shared Free/Plus/Team cards serve /pricing, the account introduction and /settings/plans. Team includes **10 people** at the user-approved unchanged $29/month or $299/year; Plus remains $9.99/month or $99/year. Prices are planned USD display values. Paid actions remain disabled; no checkout, entitlement or quota configuration changes.

A verified account sees the skippable introduction on its first ordinary world entry after this feature is installed. Continue with Free, Skip, Close and Escape dismiss it. A versioned Supabase user-metadata marker persists the dismissal across devices; this is UI state only and cannot grant access. The PUT uses the captured actor bearer. Local per-account dismissal prevents nagging after an offline failure, and a later mount retries synchronization. No saved-plan claim is made. Existing accounts without the marker see it once too. Unverified accounts defer to the existing verification flow. Explicit query/hash handoffs defer this optional introduction. Nothing redirects or replaces an ongoing conversation.

The sidebar Upgrade link opens the authenticated account Plans & usage route without inventory query scope. Real /me/limits item and Space counts show account-owned records, not organization totals. Pilot chat/scan counters are bypassed by the existing backend, so the UI labels these Not metered rather than showing misleading zeroes or fabricated history. Nonpilot snapshots use server allowances and UTC reset dates, preserving legacy Pro/Team labels rather than claiming a new subscription. Refresh, bounded reads, errors, malformed values and account changes are handled explicitly.

## Scope and limitations

No migrations, payment SDKs, provider products, backend, model hosting, native code or production configuration changes. Existing early access stays free, without enforced plan quotas or an automatic cutoff. The prior mobile binary still has its old five-member display catalog; synchronize that in a separate mobile release. The unfinished feat/web-subscriptions lane remains untouched and its undeployed /subscriptions endpoints are not used.

No usage-history graphs: the current API lacks a reliable pilot AI history. /me/limits has existing best-effort counter reads that can return zero on database failure; the web cannot distinguish those responses from a genuine zero. Historical metering, verified billing status, checkout/portal and new quota enforcement require a separately tested backend/payment rollout before launch.

## Validation

620 Jest tests in 85 suites passed with coverage. TypeScript passed. ESLint: zero errors, 52 pre-existing warnings. New regressions cover shared prices and annual totals, ten Team members, unavailable purchases, pilot counters, server caps, legacy tiers, malformed values, failed reads/retry/refresh, late account responses, logout, account-scoped sidebar URLs, dismissal persistence, offline sync, unverified/foreign accounts, direct prompt handoffs and Escape.

Safari visual checks used the actual components with fictional data in a temporary local route (removed before commit): desktop light/dark, yearly comparison, welcome dialog, and 390px responsive light/dark. A cramped Not metered label was corrected and rechecked. These fixture checks do not establish live account/backend integration; deployment and authenticated receipts are recorded separately.

## Deployment

Build a separate self-hosted Next.js candidate using existing production public configuration. Verify touched-file baseline hashes against the active store-privacy-20261025 release, retain previous release, run the five CI gates, and smoke-test public/authenticated routes and metadata persistence with a disposable account. Publish by switching only findez-web's working directory; retain service override rollback. No Vercel deployment, production database migration, payment activation or App Store submission is part of this release.

## Delivered

Runtime `9d39948a65cf2aa613e17bbcbf22dfe94a2bbcfe` is live at `plans-usage-20261026/frontend`, build `bhC0HsnhcOvcIhc4TXAep`. All five CI gates passed in run 40420785743 (PR242). Production build passed on retry after a transient existing homepage Google-font download error. Twenty-seven staged and live route checks passed. Seven real-auth checks passed on staging and public HTTPS, including account-only plans access, live early-access usage and fresh-read dismissal persistence; synthetic accounts were deleted and customer records were not used.

Safari confirmed live public monthly/yearly prices, ten Team members and the protected route's sign-in redirect. Signed-in component layouts were reviewed in local fixtures; authenticated server behavior was verified by HTTP because Safari had no signed-in session. No claim of a live signed-in Safari click-through is made. Prior release/source retained for rollback; backend PID unchanged. Only old regenerable build caches were cleared to make disk space. No database migration or payment activation. Machine-readable receipt: `web-plans-usage-receipt.json`.
