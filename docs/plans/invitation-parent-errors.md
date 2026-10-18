# Workspace code prerequisites

Backend lane fix/api-invitation-parent-errors-20261017, base a65d601.
Legacy six-character workspace codes retain the existing database requirement:
organization membership must already be accepted. Check the parent before writing
workspace membership and give an actionable organization-invitation message.
A concurrent parent constraint failure returns 422 instead of a generic 500.
Existing roles, idempotent joining, access invitation consent and all database
grants are unchanged. No migration, GPU change or customer write is required.

All 833 backend tests and 10 subtests pass; 34 focused invitation tests include
wrong/expired/rotated codes, role preservation, recipient consent and the new
parent prerequisite/race cases. Source hashes match both live files before change.
Publication preserves every unrelated Python source with rollback copies and
checks health, database health and unauthenticated invitation denial. Publication
receipt and CI results follow after activation. Real email delivery, physical
acceptance and App Store deferred installation are not established by these tests.

Guarded publication succeeded at 2026-10-18 01:15 UTC. Runtime source e16ab58
was rebased without runtime changes to 7221f00 on the explicit compatibility
parent a38c7bb (reviewed AnyIO fixture/Memory ink fixes). PR99 has all five gates
passing, run39097239026. Health and database health are200; all eight combined
invitation file hashes match reviewed candidates. All three unauthenticated
invitation entry points reject access.90 unrelated Python and245 web source
files are preserved. No migration/customer write. Rollback copies and activation
receipt: /home/ubuntu/findez-invitation-release-20261017.
