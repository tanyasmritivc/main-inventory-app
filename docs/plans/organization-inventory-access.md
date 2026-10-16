# Organization, workspace and inventory access

## Audit and scope

Production schema inspected read-only on 2026-10-15. `teams` and
`team_memberships` already represent collaboration workspaces. Migration 043
stores explicit inventory IDs on items, Spaces, documents and history. It does
not provide organizations or per-inventory membership: all inventories currently
inherit the workspace role. Reuse the existing workspace tables and routes.

## Model and policy

- Organization: company, household or team administration; separate membership.
- Workspace: existing Team entity, optionally associated with an organization.
  Organization membership grants no implicit workspace data access.
- Inventory: independent collection within one workspace. Personal remains a
  simple supported scope without an organization.
- Access: workspace owner/admin administer all its inventories; other members
  inherit an explicitly displayed default or receive an inventory-specific role.
  Restricted inventories require a grant. `none` explicitly denies membership.
  Removing workspace membership immediately invalidates every narrower grant.
- Roles shown to users: owner, admin, editor, viewer. Existing mentor/member
  storage values map to admin/editor without rewriting existing memberships.
- Physical locations: a workspace-owned tree. An inventory explicitly attaches
  a location; the same physical location can serve multiple inventories. Legacy
  Spaces retain their identities and become optional location attachments.
- Audit: actor, time, scope and changes for access and physical-record changes.
  Recorded moves never imply physical confirmation.

## Execution order

1. Add organization and explicit access tables with private RLS and transactional
   audited management functions. Preserve existing rows and legacy inheritance.
2. Enforce inventory policy on scoped routes, older application routes and
   authenticated database access; verify cache and revocation behavior.
3. Add organization directory, workspace overview and inventory access screens;
   retain contextual navigation and the direct Personal path.
4. Add explicit physical location links and scoped overview/activity.
5. Exercise Acme's October client project and FTC Robotics with different users,
   inventories and denied paths in disposable fixtures, including legacy routes.
6. Validate the migration against production schema and a disposable restored
   database, compare original records and permissions, then release with backup
   and rollback receipts. No production demo records or automatic reparenting.

## Migration rules

Existing Teams stay independent workspaces. Organizations are opt-in; do not
invent organization relationships. Existing inventory access stays `legacy`.
New collections default to workspace view access, with explicit edit grants.
Organization owners may administer the organization, but must be assigned to a
workspace to see its contents. Workspace ownership is always recoverable.

## Acceptance

Client reviewers cannot discover internal inventories, metrics, documents or
activity. A robotics member can edit Components but only view Tools. Revocation
applies to direct IDs, old Team/Space paths, cached searches and database access.
Move and quantity changes retain actor/timestamp; private chats remain private.
