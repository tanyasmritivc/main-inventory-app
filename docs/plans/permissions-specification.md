# User-supplied permission specification

Extracted from FindEZ_AI_Roles_and_Permissions_Specification.docx supplied October 17, 2026. This is the requested target policy, not a claim of deployed behavior.

FindEZ AI — Roles & Permissions Specification

Proposed target policy for implementation

Scope: Organization → Workspaces → Inventories → Spaces and Items. Purpose: define consistent, enforceable permissions across FindEZ AI. These are proposed implementation rules, not a statement that the current application already enforces them.

1. Resource hierarchy and principles

Organization → Workspaces → Inventories → Spaces and Items

Dashboard, Scan, and Chat operate on the selected inventory.

Tasks and Files belong to the workspace.

Account/profile settings are independent of organization permissions.

Organization membership alone does not grant access to every workspace.

Workspace access does not automatically grant access to every restricted inventory.

UI visibility is not authorization: backend APIs, direct URLs, search, and Chat must enforce the same permissions.

2. Organization-level roles

Roles: Owner, Admin, Member

Permission | Owner | Admin | Member

View organization details | Yes | Yes | Yes

Invite organization members | Yes | Yes | No

Remove organization members | Yes | Yes | No

Promote someone to Organization Admin | Yes | No | No

Transfer organization ownership | Yes, with safeguards | No | No

Create workspaces | Yes | Yes | No

Rename organization | Yes | No | No

Delete organization | Yes | No | No

View workspace list | All in organization | All in organization | Only accessible workspaces

Automatically access every workspace | No | No | No

Automatically access every inventory | No | No | No

Manage own profile/account | Yes | Yes | Yes



Organization safeguards

Keep at least one Organization Owner.

Prevent an Owner from removing or demoting themselves if that would leave no Owner.

Require explicit confirmation for ownership transfer.

Organization Admins cannot promote themselves to Owner.

Organization membership alone does not grant workspace or inventory access.

3. Workspace-level roles

Roles: Owner, Admin, Editor, Viewer

Permission | Owner | Admin | Editor | Viewer

Open workspace | Yes | Yes | Yes | Yes

Rename workspace | Yes | No | No | No

Delete workspace | Yes | No | No | No

Invite/assign workspace members | Yes | Yes | No | No

Change Editor/Viewer roles | Yes | Yes | No | No

Grant Workspace Admin | Yes | No | No | No

Transfer workspace ownership | Yes | No | No | No

Create inventories | Yes | Yes | No | No

Rename/delete inventories | Yes* | Yes* | No | No

Change inventory access | Yes | Yes | No | No

View and create workspace tasks | Yes | Yes | Yes | View only

Edit workspace tasks | Yes | Yes | Yes | No

Delete own task | Yes | Yes | Yes | Only if creator and task policy allows

Delete another person’s task | Yes | Yes | No | No

Upload workspace files | Yes | Yes | Yes | No

View/download workspace files | Yes | Yes | Yes | Yes

Delete own uploaded file | Yes | Yes | Yes | No

Delete another person’s file | Yes | Yes | No | No

Manage workspace settings | Yes | Yes | No | No

Automatically access restricted inventory contents | No | No | No | No



* Workspace Owners/Admins can administer inventory records, including rename/delete and access assignments, without automatically receiving permission to view the contents of a restricted inventory.

Workspace safeguards

Only the Workspace Owner can transfer ownership.

Workspace Admins cannot promote themselves to Owner.

Keep at least one Workspace Owner.

Apply task and file deletion rules consistently in the UI and backend.

4. Inventory-level roles

Roles: Owner, Admin, Editor, Viewer, No access

Permission | Owner | Admin | Editor | Viewer | No access

Open inventory | Yes | Yes | Yes | Yes | No

View items and spaces | Yes | Yes | Yes | Yes | No

Search inventory / ask Chat questions | Yes | Yes | Yes | Yes | No

Add items manually | Yes | Yes | Yes | No | No

Edit item details / quantities | Yes | Yes | Yes | No | No

Delete individual items | Yes | Yes | Yes | No | No

Save scans and imports | Yes | Yes | Yes | No | No

Create spaces | Yes | Yes | Yes | No | No

Rename spaces | Yes | Yes | Yes | No | No

Delete spaces | Yes | Yes | No | No | No

Change inventory access / assign roles | Yes | Yes | No | No | No

Rename inventory | Yes | Yes | No | No | No

Delete inventory | Yes | Yes | No | No | No

Manage inventory settings | Yes | Yes | No | No | No

View inventory activity/history | Yes | Yes | Yes | Yes | No



Inventory safeguards

Space deletion is Owner/Admin-only because it can affect multiple items.

Before deleting a space, show how many items it contains and require confirmation.

Define and clearly communicate whether deleting a space moves or deletes its items.

Inventory deletion requires confirmation and a clear explanation of whether contents are deleted, archived, or retained under the data-retention policy.

No access must block inventory discovery and content access through normal UI, search, Chat, APIs, and direct URLs.

5. Default inventory-role inheritance

Workspace role | Default inventory role

Owner | Owner

Admin | Admin

Editor | Editor

Viewer | Viewer



This fixes the Editor → Viewer inconsistency. A Workspace Editor should remain an Editor in newly created inventories with inherited access. They should become a Viewer only if an authorized person deliberately assigns Viewer access.

Inherited access: the inventory role follows the mapping above and updates when the workspace role changes.

Custom access: an explicit inventory assignment overrides the inherited role and remains until an authorized person changes it.

An explicit inventory-level No access overrides inherited content access.

6. Permission evaluation order

Account status: a suspended or disabled account cannot access protected resources.

Organization membership: the user must belong to the organization containing the resource, subject to any explicitly supported external-sharing policy.

Workspace membership: the user must have workspace access.

Inventory access mode: inherited access uses the mapped workspace role; custom access uses the explicit inventory assignment.

Action permission: the effective role determines whether the requested operation is allowed.

Workspace Owners/Admins may manage inventory administration and access assignments, but should not automatically see restricted inventory contents. They must be explicitly granted content access before viewing that inventory. They can use the permitted access-management flow to change assignments.

7. Feature-specific enforcement

Feature | Rule

Dashboard | Uses selected inventory’s effective role; Viewer can view, Editor/Admin/Owner can perform permitted changes.

Scan | Viewer may inspect without saving; Editor/Admin/Owner can save scans and create items.

Chat | All roles with content access can ask questions; data-changing commands require permission for the requested action.

Search | Return only results from inventories the user can access.

Tasks | Follow workspace-level task permissions.

Files | Follow workspace-level file permissions.

Profile/account | Independent of organization/workspace roles.

Organization/workspace selectors | Show only resources the user is permitted to discover.

Direct URLs and API calls | Enforce the same authorization as the UI; hiding a button is insufficient.



Example: A Viewer may ask, “How many M4 screws are left?” if they can view the inventory. A Viewer asking “Delete the empty bins” must be denied.

8. Ownership, removal, and destructive-action safeguards

Every organization and workspace must retain at least one Owner.

Ownership transfers require explicit confirmation.

Admins cannot grant themselves Owner status.

Editors cannot change access permissions or grant themselves a higher role.

Removing a workspace member revokes inherited inventory access immediately. Custom access must also be revoked or explicitly reviewed so it cannot leave unintended access behind.

Deleting a workspace or inventory requires a confirmation screen that explains scope and consequences.

Permission changes must take effect across UI, backend, and APIs without requiring a manual refresh.

Permission-denied actions should show a clear message rather than navigating unpredictably.

9. Implementation checklist

Create one centralized permission policy for each resource level.

Implement workspace-to-inventory default role mapping.

Distinguish inherited access from custom inventory assignments.

Enforce explicit No access across UI, backend, search, and Chat.

Make space deletion Owner/Admin-only.

Align inventory rename/delete and access-management rules.

Enforce task and file permissions consistently.

Audit every button, menu, route, and direct API operation.

Add tests for every role and inheritance combination.

Test role changes, member removal, ownership transfer, and restricted inventories.

10. Acceptance tests

A Workspace Editor receives Editor access to a new inventory when access is inherited.

An authorized inventory Admin can explicitly assign Viewer access, and that override is respected.

A workspace role change updates inherited inventory roles but does not silently overwrite custom assignments.

A Viewer cannot add, edit, delete items, save scans, or change spaces.

An Editor can add/edit items and create/rename spaces but cannot delete spaces or manage inventory access.

Only inventory Owner/Admin can rename/delete an inventory or manage its access.

A user with No access cannot see inventory contents through UI, search, Chat, direct URLs, or APIs.

A workspace administrator cannot read restricted inventory contents without explicit content access.

Removing a workspace member immediately removes their inherited access and does not leave unintended custom access.

Task and file permissions behave consistently across UI and backend.

An organization/workspace cannot be left without an Owner.

Destructive actions clearly explain consequences and require confirmation.

Implementation note

This is the recommended target policy. Before deployment, reconcile it with existing database constraints, organization/workspace membership models, and any external-sharing feature. Enforce authorization server-side and add regression tests before removing existing checks.

