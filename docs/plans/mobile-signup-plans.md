# Mobile signup plans

The optional signup popup and Settings → Plans share one catalog and baby-blue
glass card component. Free is $0, Plus is $9.99/month or $99/year, and Team is
$29/month or $299/year with ten people. These match the published web catalog.
Early access remains free without enforced plan quotas. Paid options say
“Coming soon”; this change adds no checkout, entitlement or billing mutation.

The popup shows one plan at a time with monthly/yearly and Free/Plus/Team
selectors. Continue with Free, Skip, Close, outside tap and system Back dismiss
it. The content scrolls independently from the footer. Existing chat, navigation,
onboarding drafts and settings entry points are retained. Static highlights
provide the shiny finish without continuous animation.

Email signup records a pending UI marker that survives email verification.
First OAuth signup is identified from verified user creation and initial sign-in
timestamps (within one minute, account younger than 24 hours). Ordinary returning
accounts are not prompted. This timestamp heuristic is presentation-only, never
an authorization or entitlement decision. Eligibility is remembered locally.

Dismissal is stored by authenticated user ID locally, then synchronized through
the existing self-hosted Supabase Auth user-metadata API. The request captures
and verifies the same account identity; server failures leave dismissal local
and retry on a later mount. The shared `findez_plan_intro_version: 1` marker
also honors web dismissal. The tree-owned modal disappears on account disposal;
late responses cannot reopen it over another account. No schema migration or
server configuration change is needed.

Validation:
- 14 focused widget/store tests passed.
- Full mobile suite: 1,178 passed, one existing optional visual skip.
- Flutter analysis: no issues.
- Six iOS simulator cases passed: popup in both themes at normal/2.6× text,
  annual Team price/member selection, dismissal, and both Settings themes.
- Synthetic HTTP tests cover exact metadata, bearer ownership, foreign receipts,
  offline persistence, returning versus new users and delayed verification.

Simulator tests use synthetic data and do not prove live OAuth/email verification
or physical VoiceOver acceptance. Verify a disposable new account and Settings
on the delivered TestFlight build. Public App Store submission remains held.
Build 145 delivery and CI results are recorded in the separate release receipt.

Delivery: Apple acknowledged TestFlight 1.1.1 (145). All five CI gates passed on
source 4e41564. Signing, device-platform, privacy/config and Apple validation
passed. Apple processing and tester availability were not polled. Public
submission remains held. Receipt: mobile-signup-plans-receipt.json.
