# Direct web app entry

The root-level `frontend/middleware.ts` was outside the `src/app` convention and was not executing in the deployed build. Auth routes rendered the form even when cookies already held a valid session. The replacement is `frontend/src/proxy.ts`, the Next.js 16 convention beside the app directory.

Verified returning sessions on `/`, `/signin` and `/signup` redirect to `/worlds` (or their safe explicit destination). The existing WorldEntry chooses the authorized remembered organization or Personal chat. Landing prompts remain editable chat drafts; invitation and password recovery flows retain their existing destinations. Auth-loop destinations normalize to `/worlds`. Redirects are private/no-store and retain refreshed session cookies. Password sign-in and immediate-session signup open a fresh document, avoiding pre-login router cache. Email verification is still required when Auth returns no session. All server page and API authorization remains in place. Layouts, backend, mobile and database are unchanged.

## Verification

- 595 Jest tests across 82 suites passed, including 51 focused auth/landing checks.
- TypeScript passed; ESLint: zero errors, 52 existing warnings.
- Self-hosted production webpack build passed with the real configuration.
- 26 staged route checks passed, including current favicon assets.
- 13 HTTP session checks passed with one disposable account: homepage/signin/signup bypass; prompt and invitation preservation; auth-loop prevention; authenticated entry; public anonymous pages; protected anonymous entry; expired-cookie refresh; use of the refreshed cookies on the next request. The account was deleted, with no customer records used.
- Compiled `.next/server/middleware.js` is present. Next.js 16's Node proxy can leave `sortedMiddleware` empty, so HTTP behavior, not that array alone, is the acceptance check.

Deployed to the self-hosted server after all five CI gates passed. All 13 session checks passed again over public HTTPS, with the second disposable account deleted. Chrome confirmed homepage, signin and signup each open the existing Personal chat directly. See `web-auth-entry-receipt.json`. Google/Apple provider UI was not exercised; the existing callback code and its automated tests are unchanged. Sessions remain host-scoped as before; no cookie domain or auth-provider configuration was changed.

Reference: https://nextjs.org/docs/app/api-reference/file-conventions/proxy
