# Welcome email: test delivered, automation awaiting approval

The SMTP relay accepted one test on November 11, 2026 at 20:26 Pacific.
Inbox arrival and visual approval are for the owner to confirm. No customer
welcome emails have been enabled or backfilled.

## Delivery

* Provider: existing Brevo SMTP at smtp-relay.brevo.com:587, with STARTTLS.
* From: FindEZ <noreply@findez.ai>.
* Reply-To: info@findez.ai.
* Subject: Welcome to FindEZ.
* HTML and plain text: emails/welcome.html and emails/welcome.txt.
* Owner approved keeping Founders Access despite the older account-plan label.
* Live pilot_mode was true; current plan quotas are not enforced.
* Test send result: test-send-receipt.json, SMTP accepted, one recipient.
* Automatic sending remains disabled and the backend draft has not been deployed.

## Links and assets

* Open FindEZ: https://www.findez.ai/worlds. Anonymous visitors go to sign-in.
* CAD: https://www.findez.ai/cad-intelligence, confirmed live.
* Email preferences: https://www.findez.ai/settings/account, the allowed account
  settings fallback. It is not a provider unsubscribe endpoint.
* Privacy, App Store, Discord and Instagram retain the supplied URLs.
* Public images live below https://www.findez.ai/email/welcome/: logo-light.png,
  logo-dark.png, welcome-hero.gif, start-snap.png, start-ask.png, start-cad.png
  and mark.png. See assets-verification.json for all seven full URLs and hashes.
* Original images were copied byte-for-byte, including the animated GIF.
* Dark-mode styles, paired logos, layout, wording and existing links are retained.

## Disabled automation draft

The single hook is backend/app/core/auth.py:get_current_user after JWT and active
account verification. It schedules welcome_email.schedule_welcome using FastAPI
BackgroundTasks. Web and iPhone both pass through this backend authentication
path. Sending occurs after the first authenticated app response, not on every
login or immediately on a database insert. Email confirmation and creation time
are checked against authoritative Supabase Auth data before sending.

backend/app/services/welcome_email.py:WELCOME_LAUNCH_AT is None. Only after the
owner says "turn it on" should it be set to the actual deployment instant and the
backend deployed. Accounts created before that instant are skipped, including
existing users logging in later. No auth settings or environment changes.

The existing email_deliveries table has RLS enabled and a unique
(user_id, idempotency_key) constraint, verified in production. No migration is
needed. A pending welcome-v1 claim is inserted before SMTP; only the worker that
successfully inserts sends. Any prior claim prevents a repeat, including after a
process restart. SMTP has no idempotency support, so failed or ambiguous attempts
are not automatically retried. This avoids duplicates but can leave a failed
welcome unsent. Errors are logged using fixed codes without addresses, exception
text, credentials or message bodies, and never fail authentication.

## Verification and deployment

47 focused welcome-email and JWT security tests passed. They cover disabled
scheduling, old/unconfirmed accounts, recipient identity, duplicate and concurrent
claims, SMTP failure, sent-but-audit-failed handling, exact multipart templates,
Reply-To and a single recipient. Production frontend webpack/TypeScript passed.

Only the seven public images were deployed, through the existing guarded
self-hosted findez-web release switch. 632 unrelated files were preserved.
No website screens, auth UI, mobile, backend runtime or configuration changed.
No Vercel or Render deployment. See assets-deployment.json.

Before activation: recheck live backend source, preserve concurrent work, set the
rollout instant, complete backend release checks, deploy the hook/helper and
repository-root emails directory together, then validate one newly created test
account and a repeated sign-in. Existing accounts must remain excluded.
