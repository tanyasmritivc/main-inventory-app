# CAD Intelligence Phase 0 validation receipt

Date: 2026-11-10. Branch: `docs/cad-intelligence-phase0`.
Audit base: `17632a92024a986cb08dcfb795ba518fd9897ee9`.
First platform: Fusion 360, explicitly confirmed by Tanya.

## Scope and evidence

This delivery consists of the root technical plan, this receipt, guarded draft
SQL and its README, and concise project-context entries. Production application
code, mobile, existing inventory schema and deployment configuration are unchanged.
No migration was executed and no CAD integration was implemented.

Read-only inspection covered the repository conventions and relevant routes,
repositories, authorization, stock writers, FIND/catalog services, web shell,
testing and deployment boundaries. Live inspection checked deployed source drift,
service working directories/interpreter, and public-schema metadata. No customer
inventory rows, credentials or CAD files were retrieved.

Public-schema metadata SHA256:
`7c5f252b676abef9aed159d274355093bf87e55736a1fda959f0dbe0cdf6ceaf`.
The complete schema dump is deliberately not committed. Production uses
PostgreSQL 17.6 and backend Python 3.12.3 at the time of inspection.

Live/local hash comparisons confirmed the Project Kit service/routes, auth,
catalog service and checkout route. Live item repository and inventory-scope
overlays were compared separately: authenticated reads bypass stale process cache,
legacy purchase sources normalize, and Space chat retains stricter filters and
write boundaries. The plan records these differences rather than assuming the
audit branch is a complete deployment source.

Official Autodesk and Onshape references are linked at the relevant claims in
the technical plan. API documentation review is not an authenticated provider
integration test. Undocumented quotas, cloud Fusion query contracts and native
highlighting behavior are not claimed as verified capabilities.

## Checks completed

- Draft SQL parsed as 34 statements using `pglast 8.7` in an isolated temporary
  directory; all three PL/pgSQL bodies also parsed. No project dependency changed.
- Proposed public-table names do not collide with the inspected live schema.
  Existing public FK targets and UUID types were checked against schema metadata.
- Draft defines nine new tables and one allocation view. It adds no column to an
  existing relation. The allocation view reads existing Project Kit reservations.
- Draft is outside `backend/supabase/migrations`, starts with an unconditional
  exception, and ends in `ROLLBACK`. It is not a deployable migration.
- The canonical illustrative JSON example parses. New plan/draft/receipt files
  use ASCII text; local Markdown links resolve.
- Documentation-only changed-path review and `git diff --cached --check` passed
  before commit.

Parser success checks syntax, not catalog resolution, trigger behavior, privileges,
RLS, transaction correctness or compatibility with the deployed PostgreSQL 17.6
runtime. The parser uses a newer PostgreSQL grammar. Dynamic SQL policy creation
and existing helper semantics still require a disposable-database rehearsal.

## Checks not performed or claimed

- No migration application, rollback rehearsal, RLS execution or concurrent stock
  transaction tests. The draft intentionally stops before execution.
- No Fusion installation, desktop login, assembly extraction, palette rendering,
  real BOM comparison or Windows/macOS host acceptance.
- No authenticated Onshape OAuth, BOM, configuration or rate-limit test.
- No CAD runtime, API, frontend or mobile test suite exists from this delivery.
  Existing application suites were not rerun for documentation-only changes.
- No deployment, TestFlight build, App Store change or production inventory write.

## Required next acceptance evidence

Use a permissioned real robotics assembly with independently checked quantities,
the team's supported Fusion build/OS/configurations, and an explicitly selected
FindEZ inventory. Prove nested/repeated component counts and authorized inventory
comparison first. Preserve unknown metadata and dirty revision state.

Before enabling allocation/consumption, prove shared locking and stock invariants
across CAD, existing kits, checkouts, direct quantity changes and other writers.
Before promoting SQL, implement the missing immutable publication, service-side
authorization, credential/session handoff and deletion contracts and rehearse the
reviewed migrations on a disposable database.
