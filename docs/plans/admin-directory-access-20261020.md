# Organization Admin workspace directory access

Status: user-approved migration 072 is live for web and mobile.

The route-level workspace lookup recognized inherited organization administration,
but migration 046's directory RPC required a physical team_memberships row for
list/access-request reads. 068 changed effective role inheritance without updating
these two guards. 072 uses findez_workspace_role in both places. No data updates,
new permissions or client-specific workarounds are introduced.

Both mobile hierarchy_page.dart and web workspace-directory.tsx call this shared
endpoint. No native binary changes are required. Organization Owner/Admin can
open all child inventories including restricted/hidden entries; ordinary members
still need workspace membership and permitted inventory access.

Validation: full disposable PostgreSQL suite, concurrent revocations (zero
unauthorized writes), role fixture including banned/removed/demoted Admin,
HTTP-to-real-SQL route test with synthetic identities, migration replay, and a
fresh isolated production restore. The pre-fix denial reproduced; after migration
all 90 restored tables retain identical row counts and value hashes. Private photos
remain private. No production customer records mutated during testing.

Private rehearsal receipt: /home/ubuntu/findez-admin-directory-20261020/rehearsal.json.
Database activation requires explicit user authorization, fresh backup and a live
function hash guard. Preserve migration071 and all unrelated live API overlays.

CI receipt: all five gates pass on 455f97d (run39380135827), PR143. Live read-only
activation preflight passes. Guarded script is /tmp/findez-directory-activate.py
on the VM. User approved activation and requested a TestFlight build. A fresh
backup and function-drift guards passed; both effective-role guards are installed.
Service-only RPC grants and private image protection pass. API/database return
200 and anonymous image requests return401. No customer data was updated.
Private activation receipt: /home/ubuntu/findez-admin-directory-20261020/activation.json.
Web settings2afb817 is live independently. Requested beta98 is being prepared.
