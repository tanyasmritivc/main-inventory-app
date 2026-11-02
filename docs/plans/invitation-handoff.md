# Invitation links and codes

Web lane fix/web-invitation-handoff-20261017, base ee1a684.
Access invitation codes now survive email signup using the existing private
metadata handoff, with explicit review still required. The review offers the
installed-app custom-scheme link, plus an account-bound Save invitation for app
action. Save failures remain visible and do not accept membership. An accepted
receipt must match the preview and action. Destinations are built from the known
scope/resource, never an arbitrary redirect. Legacy workspace/Space acceptance
also confirms target IDs and uses shared light/dark appearance variables.

Keep Team-only AASA and public App Store availability unchanged: public build17
is older than the access-invitation handler. Current beta users can use the
installed-app link; everyone can accept on web. Do not claim that the App Store
transfers an invitation, or that a widget test proves deferred installation.

All 331 Jest tests (45 suites) pass with coverage, including new access metadata,
receipt, canonical destination and save checks. TypeScript and changed-file lint
pass. A production webpack build with the actual private live configuration and
fonts passes. The sandboxed Turbopack runner stalled and was stopped; the normal
production compiler/build is used for this release. No schema or membership
changes on publication. Runtime files match active release base hashes.
Publication and visual review receipts follow after activation.

Guarded publication succeeded at2026-10-18 01:15UTC. Runtime7a0998f is content
identical to rebased0b49cd4, on compatibility parent46ced29. PR100 passes all
five gates, run39086417222. The current release is
/home/ubuntu/findez-web-releases/invitation-handoff-20261017/frontend. Candidate
and live invitation routes, backend/database health and exact runtime file hashes
pass;245 unrelated web source files are preserved. Safari visually verifies
access/workspace unavailable-code presentation in light and dark. The original
light preference is restored and the temporary review tab closed. No invitations
or memberships were created/accepted for live QA. Private rollback/activation
receipt: /home/ubuntu/findez-invitation-release-20261017.
