# Organization agents and Chat Spaces — October 19, 2026

Status: migrations 062–066, API and website are deployed. Live verification found one approval rejection compatibility issue; tested follow-up migration 067 awaits explicit production approval. Do not describe the deletion workflow as release-verified yet.

## User-authorized behavior

Chat can create a named Space in the selected inventory when explicitly requested. Current role and owner Space allowance are enforced; repeated requests reuse an existing same-name Space. The configured model has successfully called this tool and created a real record in the isolated database.

A newly issued organization-bound API key can discover workspaces/inventories/Spaces, create and rename resources, move Spaces within a workspace, create/attach physical locations, invite people, change/revoke access, cancel invitations, and change inventory access policies. Item reads, writes and imports continue through the existing API. Inventory IDs disambiguate repeated Space names. Actor permissions and inventory restrictions still apply.

Existing keys retain their original scope. New permissions are separate opt-ins: structure:read/write/delete, members:read/write, items:delete. org:read/write apply to item operations inside the bound organization; they do not imply management or deletion.

Permanent deletion requires a 15-minute saved preview and an explicit confirmation by the signed-in human key owner on FindEZ. The owner must type the exact name. API keys cannot confirm. The server checks current key/actor/resource authority, expiry, and unchanged contents atomically. Concurrent confirmations reuse one receipt. A workspace must first have no inventories, linked Spaces or physical locations. Account deletion, billing, ownership transfer, document uploads, API-key administration and cross-organization attachment are not delegated.

No mobile source, build, submission, model routing or GPU transport changes.

## Production migration review

- 062: service-only, atomic, scoped Space creation and authority locking.
- 063: nullable api_keys.organization_id and organization-bound access checks. Existing values are not rebound or broadened. Current inventory roles remain enforced.
- 064: service-only management RPCs and api_agent_operations, storing retry-safe operation receipts.
- 065: service-only approval/confirmation RPCs, api_agent_delete_approvals and durable api_agent_file_deletions. Only the user-session HTTP route can confirm. Recorded files are cleaned only when owned and unreferenced.
- 066: explicit inventory identity in item insertion/query results, preserving legacy key behavior.

Fresh read-only production backup restored into a network-disabled PostgreSQL container. All five migrations applied twice. Both permission suites passed. Original columns, row counts and value digests across **all 87 original public/auth/storage tables were unchanged**. Three new tables were added. All pre-existing keys retain null organization_id. Private storage buckets remain private. Evidence retained privately on the server at /home/ubuntu/findez-agent-management-20261019/final-preservation.json; the backup and customer data remain on that server.

## Validation completed

- Backend and generated API contract: 1,145 tests and 10 subtests passed.
- Isolated restored DB: all 15 management actions; pending invitation consent, all three access levels, role changes/removal, cancellation; cross-organization/legacy/read-only denial; duplicate Space names across inventories; item creation/query isolation; expiry, stale previews, wrong account/name, revoked key, direct RPC restrictions, deletion and durable cleanup.
- Real concurrency: simultaneous management and Chat Space creation each save once; simultaneous confirmation deletes once with one receipt; a request queued behind key revocation is denied.
- Real configured Chat model: created Model QA Shelf in an isolated synthetic inventory and returned its confirmed result. No customer content was sent in this test.
- MCP SDK: 15 tools, exact HTTP contracts, private Bearer authentication, validation, safe upstream failures, no direct confirmation tool. Standalone downloadable extension passed.
- Web key/approval/auth guard tests passed, including account changes, expiry/revocation, exact-name confirmation, uncertain decisions and receipt validation.
- ESLint: zero errors; 51 pre-existing/consistent warnings, mainly image and ref conventions.

## Release verification

Combined SQL fixture and all four concurrency suites passed. All 58 web suites / 473 tests passed. Local production build passed with synthetic public build configuration; production candidate is built separately with the existing private configuration. Browser previews verified desktop and 390px phone layouts, exact-name gating, cancellation, and read-only key defaults. Commit/push, CI, approved migrations 062–066 and guarded API/web deployment are complete. See the live verification and 067 follow-up below.

The web branch now contains the already-deployed API runtime baseline from 11f79c9 plus the deployed email HTML overlay. It also records already-applied migration 058 from the release API branch. Earlier release branches had diverged; this synchronizes the tested runtime sources for one coherent feature PR. It does not introduce mobile changes or reapply historical production migrations.

Rollback: restore prior API/web source/build if needed. The additive tables/column can remain; do not discard approvals/audit receipts or restore an entire database over subsequent customer activity. The updated RLS retains the old key contract.

Approval requirement: AGENTS.md states, “Public App Store submission and production database changes still require explicit authorization.” Approval requested here applies only to production migrations 062–066.

## Live deployment and follow-up migration 067

Runtime 305e3e0 is deployed. Guarded deployment retained unrelated source and prior web static chunks. Fresh production backup is retained at /home/ubuntu/findez-agent-management-20261019/release/database-before.dump. All five CI gates passed: https://github.com/tanyasmritivc/main-inventory-app/actions/runs/39353836855. PR: https://github.com/tanyasmritivc/main-inventory-app/pull/134. Published connector bytes and both API health endpoints pass. Mobile source was not changed; CI's existing Flutter job ran automatically.

Live HTTPS synthetic tests passed new organization key issuance, read-only and same-owner cross-organization denials, workspace/inventory/Space creation, duplicate request receipts, item create/read/update with inventory identity, membership role change/removal, and denial of API-key or wrong-account confirmation. Disposable accounts, keys and organizations were cleaned after each run; no invitation email was sent.

The wrong-name rejection exposed a PostgREST v14.12 compatibility defect: deliberately raising SQLSTATE 40001 makes its transaction runner retry indefinitely. The same risk applies to stale previews. The SQL safety condition blocks deletion, but the HTTP response times out. Official explanation: https://supabase.com/docs/guides/troubleshooting/high-cpu-and-infinite-transaction-retries-when-using-custom-error-codes-in-rpc-functions-77326b .

**Migration 067 changes only that one function's business-conflict error from 40001 to 23514**, which the existing API already maps to HTTP 409. The function text was compared before/after in the isolated restored database: no other behavior changed. No table or customer-data update, privilege change, or new capability. Migration replay and the full management SQL suite pass. A copy of the exact production PostgREST binary ran inside the network-isolated restore: wrong-name rejection returned in 0.086s, stale-preview rejection in 0.041s, and correct-name confirmation deleted the synthetic empty workspace. Private evidence: /home/ubuntu/findez-agent-management-20261019/067-rehearsal.json.

067 requires separate approval under the same AGENTS.md production-database rule. Once approved: back up, apply only 067, finish all four live deletion types and key-revocation checks, then record cleanup. Claude/ChatGPT host-application acceptance is distinct from the passed MCP SDK, Actions contract and published-artifact tests; users must update their installed extension/Actions schema and create a new opt-in organization key.

Further live verification on the deployed 062–066 version passed valid human-confirmed deletion for item, Space, inventory and empty workspace, polling confirmed receipts, and immediate API-key revocation. The wrong-name and stale-preview rejection remains pending 067. All synthetic accounts/resources from these runs were removed.
