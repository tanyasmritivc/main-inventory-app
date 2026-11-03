# Explicit extraction confirmation

The photo extractor marks every GLM result `needs_review`. Previously chat Save
interpreted that as mandatory queue routing, even after a person checked the draft.
The additive `confirm_items` boolean on the existing capture-save endpoint lets an
explicit Add to Space action accept those observations. It defaults to false for
existing clients. Missing quantities still block saving until explicitly supplied.

The choice is frozen when the draft changes to saving, alongside its destination
and stable per-item request IDs. Partial retries and old clients cannot switch the
same capture between Review and stock. Original model evidence is unchanged in the
saved draft. Authorization, duplicate confirmation, limits, receipt reconciliation,
and selected-item checks use the existing save path. No schema migration.

Validation: all 1,448 backend tests and 10 subtests passed locally. 69 targeted
capture, route and receipt tests passed locally. Current production-source staging
runs 66 relevant checks; three legacy first-turn streaming mocks are incompatible
with the already-deployed separate final-response stream and fail unchanged on the
baseline. Only two production Python files are patched, with hash-checked baseline,
rollback copies, service health verification and an unchanged-source audit.

Mobile build167 consumes this contract in a separate implementation lane. Existing
Review entries are not migrated; no public API-key scope changes.

Deployment completed November 2: the running service restarted successfully,
health returned 200, and the source audit confirms only the two intended files
changed. Rollback copies are retained on the server. PR295 is a draft.
