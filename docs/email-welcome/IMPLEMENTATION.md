# Welcome email: approved and enabled

The SMTP relay accepted one test on November 11, 2026 at 20:26 Pacific.
The owner confirmed receipt, approved the design and authorized automatic sending.
Automation was enabled at 2026-11-12T04:42:44.512434+00:00. No existing-user backfill.

## Delivery

* Provider: existing Brevo SMTP at smtp-relay.brevo.com:587, with STARTTLS.
* From: FindEZ <noreply@findez.ai>.
* Reply-To: info@findez.ai.
* Subject: Welcome to FindEZ.
* HTML and plain text: emails/welcome.html and emails/welcome.txt.
* Owner approved keeping Founders Access despite the older account-plan label.
* Live pilot_mode was true; current plan quotas are not enforced.
* Test send result: test-send-receipt.json, SMTP accepted, one recipient.
* Automatic sending is enabled. See activation-receipt.json.

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

## Automatic delivery

The single hook is backend/app/core/auth.py:get_current_user after JWT and active
account verification. It schedules welcome_email.schedule_welcome using FastAPI
BackgroundTasks. Web and iPhone both pass through this backend authentication
path. Sending occurs after the first authenticated app response, not on every
login or immediately on a database insert. Email confirmation and creation time
are checked against authoritative Supabase Auth data before sending.

backend/app/services/welcome_email.py:WELCOME_LAUNCH_AT is set to the deployment
instant above. Accounts created before it are skipped, including existing users
logging in later. No auth settings or environment changes.

The existing email_deliveries table has RLS enabled and a unique
(user_id, idempotency_key) constraint, verified in production. No migration is
needed. A pending welcome-v1 claim is inserted before SMTP; only the worker that
successfully inserts sends. Any prior claim prevents a repeat, including after a
process restart. SMTP has no idempotency support, so failed or ambiguous attempts
are not automatically retried. This avoids duplicates but can leave a failed
welcome unsent. Errors are logged using fixed codes without addresses, exception
text, credentials or message bodies, and never fail authentication.

## Verification and deployment

80 focused welcome-email, JWT security, email service and invitation tests passed.
They cover old/unconfirmed accounts, recipient identity, duplicate/concurrent
claims, SMTP failure, sent-but-audit-failed handling, exact multipart templates,
Reply-To and a single recipient. The public image release had already passed the
production frontend webpack/TypeScript build.

The four-file backend release preserved the live credential-isolation patch,
passed health/database checks and rejected anonymous profile access with 401.
No migration, environment, auth configuration or mobile changes. Deployment was
self-hosted only. See activation-receipt.json and assets-deployment.json.

A real passwordless test signup completed confirmation and app entry. Production
records show one confirmed account, one welcome claim and one sent record
(SMTP accepted). Two subsequent calls to the live helper against that account,
with a send spy to detect an unwanted duplicate, made zero SMTP attempts. See
signup-verification.json and duplicate-verification.json. Actual inbox placement
of the automatic message is not independently verified; the earlier owner test
was received and approved.

## Monochrome signup confirmation

The owner requested monochrome confirmation email styling after seeing the live
signup email. Only frontend/public/auth-email/signup.html was restyled. Neutral
grayscale colors and existing paired monochrome logo assets replace orange and
the colored favicon. Explicit dark-mode styles are included; email clients may
apply their own color transformations. Copy, GoTrue variables and action URLs
are unchanged. Both public hosts return the deployed template bytes; Auth was
restarted to refresh template loading and is healthy with unchanged configuration.
See confirmation-style-receipt.json. A fresh test confirmation was requested for
the same test signup; old delivered emails cannot be restyled.
