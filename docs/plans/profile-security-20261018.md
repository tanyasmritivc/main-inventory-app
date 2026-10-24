# Profile write security — October 18, 2026

Migration 061 applied with explicit user approval at 2026-10-19 01:08:09 UTC (October 18 local). Live privilege checks passed; a real disposable-account PostgREST signup upsert succeeded, while is_pro/tier/avatar_path updates returned 403.
SHA-256: `5f759fcf03ce3e61b529cf3058d2cb3eb0fe7a99f25ea29409618c5c95fd1b31`.

The existing authenticated profile grants allowed a user to change their own billing entitlements and private avatar object reference directly through PostgREST. The candidate retains native/web signup upserts and presentation edits (id, display_name, first_name, last_name, profile_role, organization, contact_email, avatar_color), while restricting billing, deletion scheduling and avatar storage references to the backend. Backend photo routes additionally validate the exact owner path before signing or deleting it.

A fresh complete production backup was restored into a network-isolated disposable PostgreSQL container. Applying 061 twice passed: authenticated entitlement/avatar forgery rejected; existing signup upsert and profile presentation update succeeded; backend photo/entitlement writes succeeded. All 87 existing public/auth/storage tables retained identical row counts and full-row hashes. The container was removed; private backup and receipt remain on the server at `/home/ubuntu/findez-final-profile-20261018`.

No customer data rewrite. AGENTS.md requires explicit user authorization before production database changes. Runtime regression suite: 1,092 passed. The separate backend candidate also tightens JWT claims, checkout item permissions, document payload validation and dependency versions. GPU settings are unchanged.
