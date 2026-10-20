# Account deletion with shared contributions

Status: implemented and tested; migration 071 and the API cleanup overlay are
prepared, not activated. Production database changes require explicit approval.

The user reported the `SHARED_RECORDS` blocker and specified that only
organization ownership should require transfer before account deletion.
No customer account is used for QA, particularly the excluded founder account.

## Behavior

- Organization Owners must transfer ownership first. Auth deletion rechecks this
  even if an earlier preparation succeeded.
- Shared contributions no longer block Admin, Editor or Viewer account deletion.
- A BEFORE DELETE hook on `auth.users` preserves shared content in the same
  transaction as identity deletion. An Auth/FK error rolls every change back.
  Preflight alone records a cleanup manifest and changes no content or ownership.
- Organization workspaces owned by the departing user pass to the organization
  Owner. Independent shared workspaces pass to a remaining accepted member,
  preferring Owner, Admin, Editor, Viewer, then earliest membership. Unshared
  private workspaces are removed with the account.
- Existing inventory IDs and shared items, tasks, files and photo paths remain.
  Space/bin custody transfers to the surviving inventory owner to prevent their
  Auth CASCADE foreign keys from erasing shared descendants.
  Historical duplicate names receive a stable ID suffix only when custody would
  otherwise collide; both records and linked items remain, item locations follow
  renamed Spaces, and the original/new names are recorded in the access audit.
- Historical creator UUIDs remain attribution only; the profile, login,
  memberships, private inventory/history and private documents/reviews are removed.
  Created API keys are revoked. Shared content does not become personal data of
  an unrelated account.
- Task assigner and invite issuer triggers honor Auth's SET NULL after identity
  removal instead of resurrecting a deleted-user FK.
- File cleanup now also protects workspace document references and structured
  Chat photo references. It waits for confirmed identity deletion, retains a
  retryable receipt, and never deletes still-referenced objects.

Existing web/mobile clients use the unchanged `delete-user` contract. No new
binary, Dashboard/UI change, or user-account deletion is part of activation.

## Evidence

- Full Python suite: 1,145 passed and 10 subtests passed.
- All five CI test jobs pass on `e5e7f4de7daebb6909b1d75a8cf5e24c6a151987`,
  run `39374088077` (PostgreSQL, Python, web, Flutter, connectors). Draft PR 141.
  The retired Vercel preview integration fails separately; it is not the deployed
  backend/web service and is not used for this release.
- Full fresh composed PostgreSQL suite, including replay of 071, passed.
- Synthetic Admin/Editor/Viewer journeys exercise the actual Auth DELETE,
  shared Spaces/bins/items/events/documents/tasks, private content, membership
  revocation, photo authorization, workspace transfer and standalone retention.
- Forced Auth FK failure leaves all content/ownership intact; cleanup is blocked.
- Former organization Owner can delete after transfer; stale preflight cannot
  bypass newly acquired ownership; cleanup retry is safe.
- Private, network-isolated fresh production restore: all 90 original tables'
  values unchanged by migration/replay; item-images remains private. Synthetic
  deletion scenarios pass on the real schema as well.
- The staged API file preserves the live `clean_agent_files` function and agent
  cleanup retry jobs, which are absent from this branch. Six cleanup tests pass
  against that exact staged file.

Private release preparation is under
`/home/ubuntu/findez-account-delete-20261020`. The local production-compatible
overlay is `/private/tmp/findez-account-candidate-cleanup.py`. No production
schema, runtime or customer data has been changed by this task.

## Activation

After explicit approval, take a fresh backup, verify source/function hashes and
the restore receipt, apply 071 atomically, install only the reviewed cleanup
overlay and restart the API. Verify health, DB connectivity and anonymous-access
denial. Do not run destructive QA against real user accounts.

Apple upload and end-user/device deletion acceptance are not claimed.
