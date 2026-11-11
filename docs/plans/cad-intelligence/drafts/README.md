# Unapplied CAD schema proposal

These files are design artifacts, not deployable migrations. They deliberately
live outside `backend/supabase/migrations`. No database has executed them.

`001_cad_foundation.sql` specifies additive relations, foreign keys, indexes,
strict read policies and reference guards using the live 2026-11-10 schema.
An unconditional exception at the start and ROLLBACK at the end prevent accidental
application. Do not remove those guards until a separately reviewed implementation
and migration rehearsal are authorized.

It creates no inventory column, stock writer, provider client, credential vault or
desktop authentication flow. `inventory_allocations` is a read projection over
existing kit reservations, not another reservation table. All new writes are
backend-only; stock operations remain disabled.

Promotion requires:

1. Recheck live schema drift and relation/function privileges.
2. Implement and test actor authorization inside service-only write RPCs, immutable
   snapshots/analyses, exact retry receipts, connection ownership and current roles.
3. Add the expiring desktop handoff and CAD-specific encrypted-secret storage
   contracts after selecting/reviewing the existing commerce security pattern.
4. Complete the shared-stock transaction work specified in the main plan; no new
   CAD-only reservation function may bypass existing kit/check-out writers.
5. Test account/inventory purge, archive, reservation release and shared custody.
6. Replay approved migrations on a disposable database with concurrency/RLS tests.
   Parsing SQL and checking foreign-key target types do not prove runtime safety.

The SQL reflects a proposed v1 storage choice: definition/occurrence graphs are
bounded JSONB within immutable snapshots; individually indexed BOM lines support
matching and pagination. Graph integrity, completeness, unit conversion and source
identity require the canonical validator described in the main plan.
