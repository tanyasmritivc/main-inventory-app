# Provider signup - web201

Google and Apple signup no longer require typed first/last names. The existing
eligibility and Terms acknowledgment remains required, as do email signup fields.
A provider-only pending signup receipt uses the returned provider metadata for the
saved profile name. Returning Apple sessions retain existing metadata when Apple
does not supply the name again. Missing provider names do not overwrite a stored
name with an empty string. The profile continuation rechecks account identity
before writing the profile, and the shell can display full_name/name metadata.

Validation: TypeScript and changed-file ESLint pass. All 13 auth signup tests pass;
14 focused signup/profile tests pass. The broader two-file run has 26 pass and
three navigation failures already present in the preceding release/CI. Updated
fixtures use the current /worlds destination and current search-parameter hook.
Production build passed on retry after a transient Google font download error.
Only auth-form and app-shell runtime files are overlaid; 546 unrelated files,
configuration and public assets are preserved. No backend or schema changes.

Real Google/Apple authorization on physical devices/browser sessions remains an
acceptance check. The provider fixtures do not certify provider configuration.
Production release provider-signup-20261107 is live; eight routes and public HTTPS
signup returned 200. Receipt: provider-signup201-release.json. PR349.

Exact runtime CI web job: 538 pass / 61 pre-existing failures; no new failure
headings versus the prior deployed release. Ten stale test cases now pass after
updating auth/navigation mocks and destinations. All other four CI jobs passed.
