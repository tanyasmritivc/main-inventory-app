# Email presentation refresh - October 19, 2026

## Scope and result

User requested invitation-email UI improvements without changing functions, then
selected "All account emails and sharing invitations." Published runtime patch
`ab9ba26`, PR133: https://github.com/tanyasmritivc/main-inventory-app/pull/133

Updated eight existing HTML templates: signup confirmation, password recovery,
magic link, account invitation, email change, shared Space, Team/workspace and
consent-based organization/workspace/inventory access invitations. Added current
FindEZ logo/wordmark, a consistent warm neutral background and white content card,
readable spacing, orange action buttons, and clear existing verification codes.
Email-safe presentation tables and inline styles use a fluid 560px maximum card.
Critical text and actions remain usable with remote images blocked. The only
image is the existing public favicon, with no recipient tracking identifier.

## Preserved behavior

Visible message wording and action URLs compare exactly before/after (apart from
the added FindEZ brand header on sharing emails). All five Auth template
placeholders and their order are unchanged. The three Python files have identical
ASTs after masking their HTML expressions; interpolated expressions are also
identical, preserving HTML escaping. Subjects, recipients, plain-text alternatives,
message IDs, SMTP delivery, permission checks, expiry, acceptance, code generation,
return values and failure handling are untouched. Cross-device email verification
from the prior release is preserved. No mobile, Next page, API contract, database,
security configuration or customer-data changes.

## Validation

- 44 existing focused email/consent/team-invitation tests passed on the PR branch.
- 1,063 tests plus 10 subtests passed in a detached worktree of the current API
  base `11f79c9` with only this HTML patch applied. This preserves the existing
  team-join error-handling change absent from the web branch's older API source.
- Exact source/hash guards and the AST comparison passed again against the live
  production API before activation.
- All five new Auth templates rendered through isolated GoTrue v2.189.0 and a
  private SMTP sink. Fresh-device signup, recovery, magic link, invitation,
  two-address email change, password replacement and replay/invalid-proof checks
  passed. No production data or real recipient email used in this rehearsal.
- Synthetic browser previews inspected at 390px and 700px; account and access
  invitation layouts are readable with working line wrapping and visible CTAs.
- Published five static template bytes verified on findez.ai and www.findez.ai.
- API `/health`, `/health/db` and the Auth container health passed after activation.
- Native Gmail, Outlook and other mail-client rendering was not independently
  checked. Existing inbox messages retain their original HTML.
- All five CI gates passed on runtime `ab9ba26` in run 39338571429: Backend,
  Web, API permissions, AI connectors and Mobile (Flutter tests). No Flutter
  release build or Apple action was performed.

## Deployment

Only eight files were replaced using before/after hashes, rollback copies and
atomic replacement. The backend candidate was produced by applying the HTML-only
patch to the current API base, preserving its already-deployed Team join fix.
426 unrelated Python, web source and public files were compared and preserved.
The existing web build and service directory remain
`/home/ubuntu/findez-web-email-20261019/candidate/frontend`; static files are
served directly, so no Next build or web restart was needed for these HTML assets.
The backend and Auth services were refreshed to load the presentation changes;
Auth configuration was hashed before/after and is identical.

Private release receipts/backups:
`/home/ubuntu/findez-email-design-20261019/activation.json`, `snapshot.json`,
`candidate/manifest.json`, `before/` and `auth-config-hash`.
Rollback restores only the eight backed-up files and refreshes the same services.
Isolated Auth receipt:
`/home/ubuntu/findez-email-style-auth-qa-20261019/receipt.json`.
Disposable QA containers/network were removed after successful checks.
