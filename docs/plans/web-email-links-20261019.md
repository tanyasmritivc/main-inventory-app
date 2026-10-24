# Cross-device email verification repair - October 19, 2026

## Outcome and scope

User reported a password-reset email requested on a computer would not open the
reset flow on an iPhone. Runtime `6d34999` is published; PR132:
https://github.com/tanyasmritivc/main-inventory-app/pull/132

After deployment, the user requested a fresh desktop reset email, opened it on
iPhone and selected Continue. They confirmed: "The new password form opens."
The agent did not change the user's password. Actual password replacement and
old/new password authentication were tested only with an isolated synthetic user.
No mobile source, binary, Apple submission or production database migration changed.

## Cause and behavior

The former Auth email verification redirected to a PKCE authorization code, which
requires a verifier stored by the browser requesting it. The phone did not have
that verifier. Supabase documents this limitation:
https://supabase.com/docs/guides/auth/sessions/pkce-flow#limitations

Five email templates now link to `/auth/confirm` with the one-time token hash in
the URL fragment. The fragment is not sent with the page request and is removed
from history on mount. The page has noindex/nofollow and no-referrer metadata.
An explicit Continue action calls `verifyOtp`; merely fetching/previewing the
page does not consume the proof. A returned session is required, so an already
signed-in unrelated account cannot stand in for successful verification.
Recovery always routes to `/reset-password`; other redirects are constrained to
safe local paths, including invitation/onboarding destinations. Secure email
changes can require both addresses and show the remaining-confirmation message.
The six-digit code option is retained in all templates. Native-app email
recipients can complete the website step and return to sign in in the app.
Google/Apple OAuth still uses PKCE with exactly one explicit code exchange.

Existing sent emails retain their old URLs. Request a fresh email for this fix.

## Validation

- Full website suite: 464 tests in 57 suites passed.
- TypeScript and ESLint for changed runtime/test TypeScript files passed.
- Production-environment webpack build passed.
- Same Auth image as production (`supabase/gotrue:v2.189.0`) tested on a fresh
  private Docker network and empty PostgreSQL database. Captured email delivery
  in an isolated SMTP sink; no real emails or production data used.
- Integration checks passed: PKCE-initiated signup completed without the original
  verifier, fresh-device recovery, password replacement, old-password rejection,
  new-password acceptance, magic link, invitation, two-address email change,
  confirmation/recovery replay rejection, and invalid-proof rejection.
- Component tests verify proof removal, no automatic consumption, explicit
  action, invalid/expired messaging, two-address confirmation and single OAuth
  exchange under React Strict Mode. Redirect-injection cases are covered.
- Published confirmation page inspected in Safari: readable layout and a useful
  invalid-link message. User confirmed physical Gmail-to-iPhone reset-form access.
- No post-activation authentication/template errors observed in the checked log
  interval. Raw credentials, tokens and customer logs were not printed.
- Repository CI run 39336710555 at runtime commit `6d34999`: Web (Jest),
  Backend (Python), API permissions (PostgreSQL), and AI connectors (MCP and
  Actions) passed. The unrelated automatic Mobile (Flutter) job was still
  running at this receipt; it does not edit, build for release or submit the app.

## Deployment and rollback

New web runtime: `/home/ubuntu/findez-web-email-20261019/candidate/frontend`.
Previous runtime: `/home/ubuntu/findez-web-review-compact-20261019/candidate/frontend`.
Twelve runtime files changed; 263 unrelated runtime files preserved. Existing
Next static chunks retained. Source hashes checked before switching only the
systemd working directory. Both public hosts, confirmation page, API docs,
privacy/terms/signin, exact connector bundle and five template hashes verified.

Only five `GOTRUE_MAILER_TEMPLATES_*` URL settings were added to the existing
Supabase Compose override. Full parsed Compose comparison and current-container
environment comparison verified every other setting and the Auth image remained
unchanged. Activated only the Auth service with `--no-deps --pull never` after
publishing the website. Health passed; all original environment settings were
compared again after activation. No JWT/signing keys, OAuth settings, SMTP config,
permissions or customer rows were edited by the deployment.

Private VM receipts in `/home/ubuntu/findez-web-email-20261019/`:
`manifest.json`, `checks.json`, `activation.json`, `auth-config-plan.json`,
`auth-activation.json`. Rollback material: `override.before` for web systemd and
`auth-override.before` for the original Compose override. Auth rollback must
restore its template configuration before removing the new confirmation route.
The exact disposable integration containers/network were removed. Synthetic
receipt retained at `/home/ubuntu/findez-email-auth-qa-20261019/receipt.json`.

The earlier GPU transport/capacity launch conditions are unchanged by this fix.
