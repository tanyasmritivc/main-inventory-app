# Recipient-approved membership

Released October 15 in PR #79, runtime `8592a4d`, migration 045. Backend and web
are live; validation and rollback receipts are recorded in CURRENT_STATE.md.

New organization and workspace members, and workspace members newly granted a
restricted inventory, must accept an invitation before access exists. Existing
memberships remain intact. Existing member role changes and revocation retain
their current authorization rules.

1. Add a pending invitation record, with one resource scope, requested role,
   sender, normalized recipient email, hashed random code, expiry and status.
2. Provide recipient-only preview and Accept/Decline, plus sender listing and
   cancellation. Verify email ownership, current sender permissions, parent
   membership and expiry inside the acceptance transaction. Record the decision.
3. Replace immediate-add controls with Invite and show pending invitations
   separately from accepted members. Keep failed drafts and disclose email
   delivery failure; never present an invitation as granted access.
4. Send the existing transactional email service a review link and code. Add
   recipient notifications and a code entry/review page. Loading a link, signing
   in and marking a notification read never accept an invitation.
5. Validate with isolated PostgreSQL and HTTP fixtures: wrong recipient,
   unverified email, forwarded codes, decline, expiry, cancellation, revoked
   sender, changed parent, replay, concurrent decisions and no access before
   acceptance. Run web, backend and all five release gates, rehearse the additive
   migration on a restored production copy, and deploy without modifying existing
   memberships or sending customer invitations as probes.

The existing Space/Team share-code flow already requires an explicit Join action
and remains compatible. New organization invitation links use the web review page
on every device; no new native deep-link association is required.
