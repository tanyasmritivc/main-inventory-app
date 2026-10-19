# Personal sharing correction — migration 060

Status: approved by the user and applied to production on October 18 at 23:36 UTC.
Migration SHA-256: `e907bf7cbdd75dde8833a4b6ef631b6fc89c95cb0df25375be73dd9bd8e1fba6`.

The final live cross-account test reproduced HTTP 400 when a new recipient tried
to join a valid Shared Space in a newly created personal inventory. New personal
inventories use `workspace` mode, but the permission fence treated that mode as
Team-only access. The owner could create and preview a link that nobody could join.

The proposed migration:

- Restores the existing owner/Shared Space checks for personal inventories in
  `workspace` mode without explicit inventory grants. Restricted personal
  inventories, explicit No access, and every Team inventory remain fenced.
- Removes direct client mutation privileges on `team_shares` and `team_members`.
  Joining, editing and revoking continue through authenticated backend routes.
  This closes a direct membership-insertion path that bypassed invitation codes.
- Breaks recursive roster RLS using a caller-bound ownership helper. Authenticated
  members retain their own membership reads; owners retain roster reads.
- Binds shared photo delivery to the same inventory, active unexpired share and
  current membership. Matching Space names in another inventory cannot grant
  photo access. Anonymous/direct Storage access remains blocked.
- Replaces an obsolete owner-wide Space name index with case-insensitive uniqueness
  within each inventory. Two personal inventories can each contain a Shelf;
  duplicate Shelf names in the same owner's inventory remain rejected.

No customer rows are rewritten. The three existing functions, one new caller-bound
helper, roster policy, table privileges and one index change are transactional.

Validation: a fresh production backup restored into a Docker container with
`network=none`; migration applied twice; positive/negative SQL controls passed.
They cover new personal sharing, Team and restricted boundaries, explicit No
access, same-name photo isolation, expired/revoked shares, member removal,
client write denial, nonrecursive owner/member reads and retained owner item
reads. Counts and content hashes remained identical for all 87 restored tables.
Private server receipt: `/home/ubuntu/findez-final-sharing-20261018/rehearsal.json`.

Activation took a fresh backup and verified permissions and index metadata.
Live cross-account tests pass for view/edit joins, denied viewer writes, member
removal, immediate read revocation, rejected revoked-code reuse and rejected
revoked-editor writes. Photo bytes and temporary account deletion checks continue.
The live test uses only the dedicated release QA inventory and a disposable
account; the user's Workshop data and personal account are not deleted.
