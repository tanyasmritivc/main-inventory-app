# Web settings and access audit - October 19, 2026

Status: web fixes published. Shared Admin migration072 awaits explicit approval.

## Behavior

- People names and bounded role selectors use separate columns; narrow web widths
  place controls below identity. Long names and emails remain readable.
- Organization Settings is a visible navigation destination. Organization and
  Workspace settings expose rename, role/owner details, membership, tasks/files,
  access, transfer, leave and existing keep/move/delete flows according to role.
- Authenticated email verification is independent of editable profile contact
  email. Verified accounts receive no prompt. Unverified accounts get a dismissible
  session prompt and explicit resend/check actions; cooldown and errors are visible.
- Permission refresh handles role-change events and removes stale data on denial.
  Workspace Tasks/Files no longer depend on unrelated endpoint availability.
  Failed invite delivery is not reported as success; file links reject unsafe schemes.
- No native app or customer Dashboard layout changes. Backend 072 separately fixes
  the endpoint shared by web and mobile; organization administrators need no
  duplicate workspace membership. Viewers and cross-organization isolation remain.

## Verification

- Browser fixture bundles actual React components with synthetic auth/API transport;
  30 scenarios across 1440/768/390 widths, Light/Dark: readable member names, no
  horizontal overflow, settings links/rename dialogs, admin opening inventory,
  revocation clearing entries, verification resend and server-confirmed status.
  Screenshots inspected. Chromium tested; Safari/device acceptance not claimed.
- Isolated GoTrue v2.189.0 and local SMTP sink: settings resend link, fresh-device
  signup confirmation, replay rejection, recovery/new-password, magic link,
  two-address email change, invite and invalid proof rejection. No real email sent.
- Production dependency audit: zero reported vulnerabilities. Full developer-tool
  audit reports 25 transitive advisories; automatic suggested major downgrades were
  not applied. This is not a claim of a complete security certification.
- Final suite/type/lint/build/CI and publication receipts recorded below when done.

## Boundaries

No founder account used for testing. No customer test writes. Existing production
agent-management overlays must be preserved during release. Unauthenticated links
and redirect checks do not prove real inbox delivery or every customer journey.

## Delivery receipt

- Source `2afb817`, PR142. All five CI gates passed (run39380122467).
- 493 web tests/62 suites with coverage; types, changed-file lint and preserved
  production-configured build passed.
- 43 candidate route/auth checks and 30 Chromium component fixture cases passed.
- Web activated at /home/ubuntu/findez-web-settings-20261020/candidate/frontend;
  22 reviewed files changed, 267 unrelated runtime files preserved. Both public
  hosts verified after activation. No database/native changes in this release.
- Admin migration072 is ready in PR143 (455f97d), all CI gates passed
  (run39380135827). Read-only live preflight passed. Approval is still pending;
  do not report the Admin denial fixed in production until that migration applies.
