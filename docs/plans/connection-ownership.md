# Connections ownership correction

Status: candidate prepared; no production migration or activation has occurred.
Branch: feat/connection-ownership. Worktree: projects/findez-amazon-history.

## Change

Personal connections are owned by owner_user_id. Organization connections are owned by organization_id and administered by current organization owners/admins. actor_id is retained as nullable creator attribution, not the organization's access boundary. Inventory selection is removed from the new website workflow. Old inventory-bound API contracts remain for legacy clients/Gmail.

Migration: backend/supabase/migrations/20261111_commerce_ownership.sql, after both existing commerce and purchase-email migrations. Actual production columns/FKs were inspected read-only on November 11 and match the prerequisites. RLS and service-only privileges remain. Organization mutations lock the membership row and connection, then recheck access. Disconnect never bypasses organization membership. Private connections remain inaccessible to organization admins.

The migration retains all connection IDs and source records. Non-Gmail connections with current inventory editing permission become Personal; no records become organization-visible automatically. Revoked and Gmail connections retain their previous boundary. Creator deletion removes personal records but preserves organization records; organization deletion cascades its connections. New imports reuse an existing matching owner destination. Existing separate historical sources are not merged.

No item, space, stock, deployment configuration, mobile or provider-enablement changes are part of this candidate.

## Website integration

Source component and contract changes cover Settings, Profile, inventory-side navigation, legacy bookmarks, upload/preview/save, OAuth handoff and callback owner verification. scripts/commerce_ownership_overlay.py patches newer live files conservatively: world navigation retains the organization, Tools exposes Connections before inventory creation, and the existing AI-assistant docs link is relabeled to avoid confusing it with merchant connections. Unrelated current CAD/auth/download UI is preserved. The overlay is idempotent and refuses unexpected source text.

Instructions are embedded in the page and documented in docs/guides/connections.md. Physical ownership remains a manual inventory add/edit workflow; there is no automatic reconciliation claim.

## Validation

- Full backend suite: 1,689 tests plus 10 subtests passed. The focused ownership suite contains 14 tests.
- 47 focused web tests passed (scope selection, upload, merchant callbacks and legacy Gmail contracts).
- TypeScript and changed-file lint passed.
- Production-mode webpack build of the current live source with the scoped overlay passed locally. Runtime production environment must still be used for the deployment build; this local build is not a distributable release artifact.
- Disposable local PostgreSQL: original commerce/Gmail tests plus migration twice, record preservation, private/team isolation, membership revocation during import, service-only RPC grants, creator deletion, organization deletion and revoked-access preservation passed.
- Browser checks on actual components with synthetic API fixtures: import without inventory, preview/save/view records, owner switching clears private data, unauthorized organization link blocked, mobile 390px no overflow, dark desktop. These are UI acceptance checks, not production end-to-end acceptance.

## Activation (approval pending)

AGENTS.md explicitly requires authorization for production database changes. After approval:

1. Recheck effective findez-web WorkingDirectory and backend source hashes. Live base at preparation: /home/ubuntu/findez-amazon-history-20261111/frontend. Do not overwrite unrelated later changes.
2. Take a fresh private database backup, protect its permissions, and record commerce counts/IDs privately. Check no migration is running. Preserve the old runtime and source files. Never commit backups or environment values.
3. Stage exact current live web source in a new release directory; apply the guarded overlay. Use the existing production build environment and dependencies. Build successfully and verify only intended source files changed. Disk was 99% full (about 632 MB free); use only regenerable build caches or a separate build location, never remove arbitrary releases or database files.
4. Quiesce commerce writers during migration/activation. Apply the reviewed SQL with ON_ERROR_STOP in its transaction. Verify ownership constraints, RLS, functions and record counts before restarting dependent code. Notify PostgREST to reload schema if needed.
5. Overlay only backend/app/api/routes/commerce.py and backend/app/services/commerce/repository.py against verified originals. Preserve all unrelated runtime files/configuration and the existing purchase-import flag.
6. Activate the staged web release and restart the backend. Verify health and database health, anonymous denial and real synthetic-account Personal and Organization preview/save/read/delete. Confirm new Personal users need no inventory and a second account cannot read personal records. Remove all synthetic QA resources afterward.
7. Record deployed hashes, acceptance results and updated guide status, commit/push the receipt.

Rollback: preserve and restore the previous runtime source/config only after assessing the migrated records. Do not blindly drop owner columns or replay the whole database backup over unrelated writes. A code-only rollback to inventory-only UI cannot display new owner-scoped records. Prefer a forward fix or a targeted, reviewed restoration using the private pre-migration connection mapping with writes stopped.
