# Permissions, collection and deletion

## Implemented local pilot

The CLI accepts only `owned` or `synthetic` source types. Each selected asset
must appear by SHA256 in a current, unrevoked local grant covering the requested
purpose. Training additionally requires verified labels and independent-human
or synthetic label origin. This is a single-operator assertion file, not an
authenticated consent service. Someone with local write access can alter it.

No user inventory is imported automatically. No existing setting is reinterpreted
as consent. Dataset review does not create a permission grant.

## Proposed production design - not implemented or deployed

The first production collector should default off. Its enabling change will need
separate review, database authorization and deployment authorization.

### Consent

Store a separate, versioned grant with:

- Authenticated principal and organization, permitted asset scope, purpose and
  policy version; affirmative acceptance time and expiry/withdrawal time.
- Exact grant revision and authority basis. Personal ownership is not inferred
  from possession of a shared inventory link or team membership.
- Clear optional UI explaining use, retention and withdrawal. Account memory,
  ordinary app use and accepting an invitation do not imply training consent.

For an initial rollout, exclude shared/organization content until authorized
owner roles and rights over member-contributed photos are specified. A workspace
administrator's access to inventory does not automatically grant all training
rights. Do not make consent a condition of ordinary inventory use.

### Candidate collection

An eligible candidate needs:

- Source asset ID/hash and access scope; current consent ID/revision.
- Original prediction, exact model/config hashes, original-image dimensions,
  orientation and crop/mask transforms.
- Correction type, original and corrected values, authenticated actor/time.
- Label origin and applicable model-output restrictions.
- Review state, review history, retention deadline and deletion state.

Check permission server-side before copying data. Recheck at review, export and
job start. Never accept a client-provided `eligible=true`. Split provenance and
access controls must survive every derived crop/mask/export.

Use a durable outbox or equivalent atomic event record for eligible collection.
Make processing idempotent by source/correction/grant revision. Persist approved
artifacts before FIND's temporary job deletion. A timeout or collection failure
must not break ordinary capture; retry within a short retention window.
Do not preserve every customer's raw inference output "just in case."

Recheck permission after staging and before publishing a candidate, because
withdrawal can race with a worker. Missing permission, unavailable policy state,
expired ownership/access or unavailable provenance must fail closed.

### Verification

Candidates begin unverified. A correction to an item name is not a verified
mask, OCR transcription or proof of physical identity. Review each label type.
Exclude unreviewable images and uncertain answers rather than inventing labels.
Preserve `model_assisted` origin through human review.

### Withdrawal and retention

1. Advance the authoritative grant revision and mark it withdrawn.
2. Immediately exclude it from candidate access, exports and new job leases.
3. Find linked candidates, source copies, crops, masks, snapshots and queued jobs
   through a lineage index. Mark them unavailable before asynchronous deletion.
4. Cancel queued jobs; stop or quarantine affected running jobs and outputs
   under the documented policy.
5. Delete controlled copies, expire signed URLs/caches and record bounded
   backup-retention behavior. Record deletion completion/failure for retries.
6. Identify already-trained checkpoints affected by the grant. Withdrawal does
   not automatically remove a sample's influence from weights. Decide and
   document whether retraining, checkpoint retirement or another response is
   required; never promise instant machine unlearning.

Keep only the minimum non-content audit record needed to prove the decision.
Encrypt stored datasets and transport; use purpose-specific access roles.

### Required production tests

- Cross-account and cross-organization access denial.
- Shared content, missing consent and forged client consent denied.
- Expiry/revocation races before and after staging/export/job leasing.
- Ownership changes, organization membership loss and asset deletion.
- Idempotent retries and recovery after a worker crashes mid-copy/delete.
- No orphaned exports; permission recheck on every job start.
- Collection failure never blocks normal capture.
- Retention of raw source, derivatives, logs, backups and checkpoints reconciled.

## Why this is a separate milestone

We can test local data preparation without collecting anyone else's information.
A production collector requires authenticated authority, revocation races,
retention operations and real storage integration. Copying the local ledger
into production would bypass those requirements. This document makes the next
implementation concrete without claiming that customer collection is ready.
