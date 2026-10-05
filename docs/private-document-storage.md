# Private document storage

## Scope and compatibility

Migration 038 changes only the `documents` bucket. Personal files retain
`<user UUID>/...` paths, Team files retain `teams/<team UUID>/...`, and stored
objects, note paths and bucket size/MIME settings are not deleted or rewritten.
Personal and Team clients already use their authenticated open endpoints for
downloads. The latest mobile client requests a fresh URL on each open; old cached
public thumbnails may need refreshing. Upload response shapes remain unchanged.

The backend validates both owned records/current membership and their scoped
storage paths before signing or deleting. No direct authenticated Storage policy
is needed: service-role operations stay behind those APIs. Documents do not inherit
the `supabase_storage_public` image setting. Opening returns `private, no-store`.
Signed URLs remain bearer capabilities until the configured expiry (default one
hour). Revocation prevents new URLs, not an unexpired URL or a downloaded copy.

## Before deployment

1. Pass backend and disposable PostgreSQL CI, including migration idempotency and
   denial under a deliberately broad old policy. Do not run test fixtures on prod.
2. Inspect the dirty production checkout. Compare the four backend file hashes
   to the exact base commit before selective replacement. Preserve unrelated work;
   do not pull/reset or deploy a whole checkout.
3. Read only bucket metadata, `storage.objects` RLS/policies and aggregate counts
   for personal/Team paths outside their expected prefixes. Investigate nonzero
   counts before tightening access. Never print customer object paths or secrets.
4. Verify personal/Team client open endpoints and the live signed URL host/TTL.
   Keep FIND, image flags, billing and environment-file hashes unchanged.

## Deployment and verification

Back up the four changed backend files, migration file and prior bucket/policy
metadata to a private rollback directory. Apply only
`backend/supabase/migrations/038_private_documents.sql` with `ON_ERROR_STOP=1`
before starting the dependent backend code. The transaction fails if the bucket
does not exist or Storage RLS is disabled. Copy only reviewed files and restart
the backend, not the web/mobile or unrelated services.

Verify service/database health. With disposable test accounts/files only: signed
owner and Team-member open/download work; anonymous public-object requests fail;
an unrelated account cannot open/delete; revoked Team membership cannot get a new
URL; failed storage deletion preserves the record. Check saved note reopening and
account isolation in the final mobile/web clients before release. Delete only
task-created test records/files afterward. Never join or mutate a real workspace.

## Recovery and remaining risks

On API regression, restore only the backed-up source and restart. The old backend
already supports signed document opening, so prefer leaving document privacy on.
If Storage policy itself causes a verified compatibility incident, restore the
exact pre-change policy metadata under explicit approval; do not silently make
customer files public as a rollback shortcut. Objects are retained throughout.

This lane does not privatize `item-images`, validate processor/log/backup retention,
finish account-deletion coverage, publish legal drafts or close physical/native
release checks. No Apple upload/submission is authorized by this deployment.
