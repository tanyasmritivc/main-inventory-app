# Deployment completed — November 15

Backend/database and web are live, authorized by the user's “deploy”. Final
receipt: `organisation-spaces-release-20261115.json`. The validation/access blocks
in the preparation history below are resolved. Final lifecycle and RLS checks
passed, including the current production ownership/ACL restore. Existing people,
roles, all 25 Spaces and 2,294 items were preserved by live assertions.

Mobile 223 archive failed due to insufficient Mac disk space; no TestFlight upload.
All prior host tests remain valid. Build/upload resumes once sufficient space is
available; do not remove other tasks' artifacts. No public App Store changes.

Rollback: private activation backup and exact source manifest in the release root.
Restore only the API files recorded in `rollback-api` and the preceding web
WorkingDirectory if an app rollback is needed. Preserve any later enrichment UI
release. Do not restore the old database snapshot over customer writes. Migration
087 is additive; a schema rollback requires a reviewed forward plan.

The live API source was merged with production, not copied blindly from the old
feature branch. Exact merged code, before/after manifests, tests and logs remain
in the private release directory. No production Git reset/pull or source-wide
replacement occurred. The previously published enrichment feature flag is enabled.

---

# Organisations and Spaces — 2026-11-15

## Requested behavior

Only Organisations and their Spaces appear in the working hierarchy. Everyone in
an organisation can view every Space. Keep enrolled people, existing roles, IDs,
item records, media, invitations and histories. Editing rights remain as before.

## Implementation

- API checkout: `findez-org-spaces-api`, branch `feat/organisation-spaces-api`, base `0e530e33`; migration 087, canonical
  organisation directory/Space creation, membership viewer floor, first-run setup,
  AI Space/item transactions, and organisation-wide source selection.
- Web checkout: `findez-org-spaces-web`, branch `feat/organisation-spaces-web`, base `dda161d8`; flat Space cards,
  organisation/Space onboarding and capture/import/tools, legacy-link redirects,
  no workspace/inventory selection in the normal flow.
- Mobile checkout: `findez-org-spaces-mobile`, branch `feat/organisation-spaces-mobile`, base `88a70d3e`; flat Space directory,
  People management, direct Space capture/import selection, auth/session/history
  continuity and compatible existing onboarding drafts.
- New Personal organisation mapping keeps the `personal` chat-world alias.
  Standalone teams become organisations with their same IDs and members.
- Compatibility tables remain in storage. This is deliberately not a destructive
  item/table rewrite. SQL snapshots assert that existing enrolments are retained.
- Organisation deletion preview includes direct Spaces. Optional legacy commerce
  and recognition dependencies may only be ignored when no rows reference the
  target inventory; otherwise the existing deletion guard still rejects deletion.

- Shared organisations create private compatibility team storage when needed, so
  the established ownership/account-deletion custody path preserves Space/item IDs.
  Personal keeps its original internal storage and sharing semantics. Private,
  sole-member Personal organisations are cleaned inside the existing Auth deletion
  transaction; shared ownership still blocks identity deletion pending handoff.
  Personal ownership cannot transfer to another person's account/history.
- Explicit organisation departure/removal clears its hidden assignments and keeps
  shared storage under the organisation owner; migration itself never invokes this
  cleanup or removes any enrolled person.
- Internal function grants account for postgres-owned routines installed by
  supabase_admin; private helpers remain unavailable to authenticated clients.
- Authority locks include the canonical organisation before locking its storage.
- Lazy Personal mapping also attaches prior personal content for users who become
  active after the original migration.

## Completed checks

- Backend: 153 initial affected tests, plus 133 collaboration/removal/world tests.
  One old admin-demotion assertion was updated: demotion now retains viewer access;
  removing the person from the organisation revokes access. Its two-test suite passes.
- Web: all 92 suites / 687 tests pass; final production Webpack build and TypeScript
  pass; later settings/organisation tests 26 pass; changed-file lint has no errors (existing non-blocking warnings).
- Mobile: full suite 1,393 passed, 1 skipped; later People/organisation tests 36 pass; final `flutter analyze --no-pub` clean.
  No new native archive, device acceptance or Apple upload is claimed.
- Network-isolated copy of production: existing 21 organisation memberships,
  15 team memberships and 1 explicit inventory grant retained, with all prior roles;
  all 25 Space rows and 2,294 item rows identical. Existing readable permission
  pairs were retained. Member read, outsider denial, write denial, duplicate names,
  quotas and revocation passed. Later checks also reached successful atomic AI
  Space/item creation + retry and first-run setup + retry.
- Snapshot: 9 original organisations, 11 teams (5 standalone), 110 compatibility
  inventories (93 personal). Four valid standalone teams were promoted. One team
  with a missing owner and no active members remains untouched. Fifty orphan
  inventories / 69 orphan items are retained, not reassigned. Sixty-four active
  users receive Personal organisation mappings.

## Outstanding verification and access block

The final SQL rehearsal stopped at the pre-existing unreviewed-dependency guard
when exercising organisation deletion. The final migration adds a conservative
empty-dependency branch and the SQL test checks both blocked deletion with legacy
connector records and successful deletion when absent. These final changes, plus the last shared-custody, private account-deletion,
authority-lock, departure/removal and late-activation additions have NOT been runtime-verified. Their patch anchors and cascade definitions match the
saved live schema. Do not describe the complete migration as fully verified.

SSH currently fails DNS inside the sandbox. An elevated SSH request was rejected:
`sandbox_approval: false` / `rules: false`. Local PostgreSQL also cannot connect to
its socket or attach shared memory. Do not work around these restrictions through
another execution service. Restore permitted test-server access to finish.

## Exact continuation

1. Reinspect production and coordinate with the separate enrichment/migration-086
   task before any rollout. No blanket git pull/reset: the deployed checkout has
   unrelated changes. Preserve its staging directories and release evidence.
2. Private isolated rehearsal directory:
   `/home/ubuntu/findez-organisation-spaces-20261115`; container
   `findez-org-spaces-qa-20261115`, database `orgspaces`. It uses `--network none`,
   Supabase PostgreSQL 17.6.1.136, with cron disabled. Never use production for fixtures.
3. Restore `before.dump` into a fresh `orgspaces` as `supabase_admin` with
   `--no-owner --no-privileges`. The only previously accepted restore differences
   were pg_net not being preloaded (no outbound networking). Do not use the earlier
   incorrectly restored `postgres` database.
4. Upload final migration to container `/tmp/087.sql`; upload final
   `backend/tests/sql/organization_spaces.sql` and execute with ON_ERROR_STOP.
   Check the complete output, including final deletion/rollback, ownership-transfer, departure/removal and Auth-deletion assertions. Also verify
   existing production function ownership/privileges against the rehearsal restore.
   Repeat application of 087 to verify replay on the clean tested state.
5. Confirm all previous role/enrolment/item/Space assertions and the new deletion
   assertions pass. Save a private rehearsal receipt without customer records.
6. Obtain explicit approval for the reviewed production database migration, as
   required by AGENTS.md. Take a fresh private backup; apply only reviewed 087,
   then narrow API and web overlays preserving current production changes. Rollback
   application code from a prepared exact file manifest; do not erase new customer
   writes by restoring an old data snapshot automatically.
7. Smoke-test login, org switch, member read-only access, Space creation, capture,
   import, AI confirmed action/retry, People/invitations and old links. Verify new
   data created after the original snapshot and no enrolment changes.
8. Build and upload a new signed TestFlight build after backend activation and
   adequate local disk. Resolve the latest build number first. Stop at Apple's
   upload acknowledgement; public App Store submission remains separate.

## Delivery constraints

Local commits only until repository push automation is confirmed not to create
prohibited Vercel previews (the existing November 13 constraint). Production remains
self-hosted. No deployment, production DB mutation, user messaging or Apple upload occurred
for this task. Native archive generation also needs more than the current ~1.3 GiB
free disk. Do not remove other tasks' artifacts to make room.
