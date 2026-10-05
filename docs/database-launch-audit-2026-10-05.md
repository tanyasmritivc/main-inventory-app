# Production database launch audit

Verified on 2026-10-05 at 23:17 UTC against the running self-hosted PostgreSQL
container `supabase-db`, database `postgres`. The systemd backend's environment
points to `http://localhost:18000` with a `service_role` credential. No credential
values, customer identities, or inventory contents were printed or saved.

**Release result: the workspace rebuild is blocked.** The existing backend is
healthy, but the new workspace schema is absent and the committed migration 038
does not preserve access to existing data. This was a read-only audit, not a
production migration or a workspace acceptance test.

## Schema evidence

| Object | Production result | Source migration |
|---|---|---|
| `public.workspaces` | Absent | `038_workspaces.sql` |
| `public.workspace_members` | Absent | `038_workspaces.sql` |
| `public.item_relationships` | Absent | `036_mobile_memory_foundation.sql` |
| `items.container`, `items.reorder_point` | Absent | `036_mobile_memory_foundation.sql` |
| `items.identity_confirmed`, `items.named_by` | Absent | `037_item_identity_status.sql` |
| `public.bins`, `items.bin_id` | Present, including a validated foreign key | `013_bin_locations.sql` |
| `items.workspace_id` | Present, references `teams(team_id)` | Existing integration schema |
| `spaces.workspace_id`, `bins.workspace_id` | Absent | `038_workspaces.sql` |
| `item_events.quantity_before`, `quantity_after`, `cause` | Absent | `036_mobile_memory_foundation.sql` |

The claim that `items.bin_id` does not exist is incorrect. The rebuild's three
specific migration files have not reached this production schema. This audit
cannot establish whether they have ever run against another database.

## Existing-data transition risks

Production contains 965 items, 13 Spaces, five Teams, seven Team memberships, and
three linked Team Spaces. There are 402 items with a null `workspace_id` and 563
with an existing Team ID. There are also 338 items without `space_id`.

Migration 038 creates empty workspace and membership tables. Its only membership
creation trigger applies to newly inserted workspaces. It neither creates existing
users' personal workspaces nor maps Teams, memberships, Spaces, or items into the
new model. The lazy personal-workspace creation in
`backend/app/api/routes/workspaces.py` also does not backfill inventory.

It replaces ownership policies on nine tables with workspace membership policies.
Consequently, ordinary authenticated user SELECTs would lose their existing
visibility after an otherwise successful application of the migration as written.
This conclusion follows from the SQL; the migration was not executed in this
audit. Creating a personal workspace later would still leave its existing items
unassigned. The retained API-key policies are a separate authorization path.

The new item foreign key references `workspaces`, replacing the existing Team
foreign key. `NOT VALID` skips checking existing rows; it does not create the
missing parent records or preserve a valid transition for future writes. Existing
Team IDs must be reconciled with the new workspace IDs without breaking scoped
integration keys, Team Space synchronization, or older clients.

Additional live data requires explicit reconciliation:

- 69 items have `user_id` values absent from `auth.users`.
- One Team has an owner absent from `auth.users`.
- Two Team memberships reference users absent from `auth.users`.
- Thirteen active legacy `team_shares` and two legacy share memberships exist.
- No existing non-null item workspace references an unknown Team, and no non-null
  item Space reference points to an unknown Space.

The orphan records must be investigated before a backfill that references Auth
users. This audit did not classify them as test data, delete them, or reassign
ownership. Legacy Shared Spaces and newer Team memberships have different scopes;
giving every legacy share member access to an owner's entire personal workspace
would widen access and must not be used as a shortcut.

## Direct SQL authorization check

The live database reports `service_role.rolbypassrls = true` and
`authenticated.rolbypassrls = false`. The deployed backend's Supabase client uses
the service-role key. API successes therefore cannot establish RLS correctness.

Two existing Auth users with inventory were selected internally. Each SELECT ran
with `SET LOCAL ROLE authenticated`, that user's `request.jwt.claim.sub`, and
ordinary authenticated JWT claims. Only aggregate counts were returned. Both
sessions ran in a read-only transaction ending with `ROLLBACK`.

| User alias | Visible items | All owned items visible | Foreign items visible |
|---|---:|---|---:|
| Existing user A | 610 | Yes | 0 |
| Existing user B | 267 | Yes | 0 |

This proves current ownership RLS for these two users. It does not verify signed
token authentication, shared-workspace co-member reads, viewer/editor writes, or
third-user workspace isolation. Those gates remain open because the new tables
and policies are absent.

## Deployment drift

The production checkout is on `main` at `98597c3` with substantial local changes.
Neither the new `workspaces.py` route nor `item_relationships_repo.py` exists there.
Do not replace this checkout with the rebuild branch.

Production has unrelated local migration files with the same numeric prefixes:

- `036_capture_reviews.sql`
- `037_ask_answer_context.sql`
- `038_private_documents.sql`

`capture_reviews` is present in the database. Numeric prefix alone cannot identify
which migration ran. No application migration ledger was found; Auth, Storage,
Realtime, and Supabase Functions maintain their own separate ledgers. Future
deployment must inventory exact filenames and contents and reconcile numbering.

`/health` and `/health/db` returned healthy. The backup status reports a successful
2026-10-05 02:30 UTC backup; its restoration was not tested by this audit. Current
mobile source falls back to legacy user-scoped inventory when `/workspaces` fails,
so the absent workspace schema is not proof that today's app cannot open. It does
block acceptance of the workspace rebuild and dependent backend writes.

## Required work before shipping workspace behavior

1. Preserve current accounts, inventory IDs, owners, Team associations, and legacy
   share permissions. Resolve the orphan owners and migration filename collisions.
2. Implement an explicit, reviewed personal and Team backfill, with compatible
   defaults and synchronization for old clients and scoped integrations. Do not
   replace ownership RLS until the assigned data and memberships are complete.
3. Restore a fresh production backup into a disposable database and execute the
   exact transition there. Compare row counts, IDs, ownership, linked Spaces, and
   legacy access before and after; validate all replacement foreign keys.
4. Prove direct SELECTs as two co-members and a third isolated user using
   authenticated role and each user's claims. Separately verify their own signed
   JWTs through the user-scoped database interface, viewer write rejection,
   cross-workspace write rejection, old-client saves, and API-key regressions.
5. Apply the proven transition to production with a fresh restore-tested backup
   and a rollback plan. Reload PostgREST, verify schema and direct-user isolation,
   then deploy dependent backend code while preserving unrelated VM changes.

No production schema, data, services, or App Store build was changed by this audit.
