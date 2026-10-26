# Workspace hub and inventory discoverability

Phase 1 keeps organizations for administration, workspaces for collaboration and
inventories for physical records and inventory AI. Workspace Overview links to
its Inventories, Tasks (existing Board), Files, People, Locations, Activity and
Settings. Personal stays a direct, simple inventory directory. Inventory navigation
remains scoped; returning to the parent workspace preserves stable IDs.

A separate directory projection exposes only name, approved short description and
access status to current workspace members. Counts appear only with content access.
Default visibility is workspace-wide; managers may hide an inventory from members
without access. Hidden resources do not appear in directory search, summaries or
access-request previews. Content reads/writes, AI, documents, locations and exports
continue to use the current inventory role, regardless of directory visibility.

A current member may explicitly request viewer access to a discoverable inventory.
Pending requests grant nothing. A current inventory administrator may approve only
that requested viewer role or decline; requester may cancel. Approval rechecks
workspace membership, resource parent and current role transactionally. Replay must
not restore revoked access; decisions are audited. No unsolicited membership grants
or real request/invitation notifications are sent during QA.

Overview uses existing assigned board tasks/deadlines, permission-filtered activity
and accessible inventories. No invented discussion, announcement or calendar data.
Shared physical locations never imply access to their inventory contents. Workspace
files remain separate from inventory documents.

Phase 2: discussions/threads/mentions, richer tasks and inventory links, grounded
workspace AI, calendar and scheduled checks. Phase 3: groups, enterprise audit,
integrations, automations, reporting and organization-wide authorized search.

Validate with fictional Acme client-project and FTC robotics fixtures: complete
directory vs hidden entries, direct-ID denial, no forbidden counts/photos/locations,
viewer requests/approval/cancel/replay/revocation, current admin checks and account
switching. Rehearse additive schema against a private restored production copy and
compare every original row and policy before release.
