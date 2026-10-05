# Privacy and Terms publication review

## Status

October 4, 2026: **review drafts, not effective or deployed**. Worktree
`/private/tmp/findez-legal-review`, branch `feat/public-legal-review`, based on
`19da889`. This is a web-only lane. Apple uploads/submission remain held. No
backend, storage, FIND transport, mobile, schema or account changes are included.

Existing public pages already return anonymous HTTPS 200:

- <https://www.findez.ai/privacy>
- <https://www.findez.ai/terms>

The published legal source matches this branch's pre-change base byte-for-byte.
Production is the existing self-hosted Next.js service, not a new hosting account.
The VM checkout is dirty. Do not pull/reset it, replace its checkout or deploy
this draft branch wholesale. Hosting a policy does not establish compliance or
prevent claims. Use qualified counsel for the operator's actual markets.

## Confirmed by the user

- Operator: AI Robots Inc, incorporated in California.
- Accounts: 13+, with adult permission/supervision for minors.
- The user corrected their earlier training answer: FindEZ **does not currently
  use customer photos, chats or documents to train models**. Training is a future
  possibility, not present practice or a feature authorized by this update.
  This is the operator's declaration; upstream/downstream provider practices
  remain independently unverified. Feature processing and account storage still
  occur and are not described as "no data use."
- Public contact supplied: `info@findez.ai`. No postal address was supplied;
  do not invent one. Determine with counsel whether a mailing address or other
  representative contact is required for the intended markets/platform terms.
- October 5: the operator confirms AI Robots Inc operates both FIND and the
  language-model gateway, but retention is not confirmed. This is not verification
  of underlying hosting/model infrastructure, logs, backups or downstream uses.
  The user corrected the contact email again to `info@findez.ai`; it remains an
  email, not a business mailing address. No postal address is fabricated.

## Facts and publication blockers

| Topic | Evidence / limitation | Required before effective publication |
|---|---|---|
| Training | User clarified no current FindEZ training on customer photos/chats/documents; the prior answer concerned future plans. Inspected app source exposes inference routes, not a training implementation; source cannot certify processor practices. Drafts separate feature processing from training and do not grant future training permission. | Independently verify provider/downstream permitted uses before publishing a broader no-training assurance. Any future program needs identified categories/operators/purposes, separate explicit opt-in, withdrawal, retention and deletion/model-unlearning handling before launch. Declining optional training must not block ordinary app use. Do not authorize a future or undisclosed past use through this draft. |
| Processor protection | Owner confirms AI Robots Inc operates FIND and the language-model gateway; no OpenAI application runtime dependency/fallback. Retention and underlying hosting/model/downstream arrangements remain unconfirmed. | Verify processing countries, underlying services, equal protection/permitted use, retention/deletion and any required third-party-AI consent. Operating the gateway is not evidence that there is no independent underlying service. |
| File privacy | Read-only live `storage.buckets` query: `documents` and `item-images` public; `profile-photos` private. Signed document API URLs do not make the underlying public bucket private. No actual customer files were opened for this check. | Fix in a separate storage/access lane with migration/URL compatibility and cross-account tests, or disclose the actual limitation. A policy cannot substitute for appropriate security. Do not flip bucket settings without verifying existing clients. |
| Transport | Existing server-to-FIND hop is HTTP and was explicitly preserved at the user's instruction. Public policy/site endpoints have HTTPS/HSTS. | Do not claim all transfers encrypted. Any TLS/private-route change requires a separate authorized lane; no configuration was changed here. |
| Deletion | `delete-user` removes many rows, documents and item-image objects but does not explicitly remove the profile-photo bucket or all nested Team-document objects. Processor deletion/backup propagation is not verified. | Verify deployed function, cascades, profile/Team files, processor records and backup restoration behavior. No immediate/all-copies deletion promise. Actual fixes require a separately scoped backend/storage lane. |
| Retention | Notification UI window 14 days; invitation account pointer expires after 30 days. Actual backup/log/provider schedules unknown. | Establish lawful schedules and operational deletion; a UI display window is not an erasure schedule. Do not invent deadlines. |
| Minors | 13+ rule confirmed; no verified under-13 parental-consent flow. Source lacks a verified age/guardian gate. School/robotics audience can matter independently of policy wording. | Counsel reviews actual audience, COPPA/student privacy and guardian acceptance. A school invitation is not proof of lawful consent. |
| Tracking/sale | Source has auth cookies, functional local storage and no evident ad-tracker SDK. Business sales/sharing and deployed tags cannot be certified from source. | Confirm deployed analytics, cookies, sale/sharing and relevant opt-out-signal obligations; use truthful disclosures. |
| Rights/contact | `info@findez.ai` already used in product; response operations and geographic markets unknown. | Confirm monitored request/appeal inbox, verification/security workflow, applicable legal bases, transfers, representatives and statutory response deadlines. |
| Terms acceptance | Existing auth forms do not establish versioned clickwrap acceptance in this audit. Mobile still embeds older August 30 policies, including OpenAI references. | Approved terms need conspicuous pre-account access and legally reviewed acceptance/notice. Sync or link mobile content in a separate mobile lane; do not fabricate saved consent or broaden a data-processing license to cover undisclosed training. |
| Liability / Apple | Draft retains existing $100-or-12-month-fees cap, narrows organization indemnity, protects mandatory rights, and adds no arbitration/class waiver. No custom Apple EULA filed by this work. | Counsel reviews enforceability, payments/refunds, operator details and Apple license terms. Confirm App Store privacy labels independently; publishing text does not correct metadata automatically. |

## Draft design and verification

- Existing `/privacy` and `/terms` route names retained. No authentication needed.
- Original supplied outlined SVG, exact monochrome/Signal artwork, readable
  neutral page, mobile section menu, desktop contents, skip link, section targets,
  contact links and print stylesheet. No advertising or new analytics added.
- Persistent draft notice, revised date (not effective date), noindex/nofollow
  preview metadata and explicit unresolved markers. Keep these until review is
  complete; do not publish unresolved text as the current policy.
- Run `npm --prefix frontend test -- --runInBand`, TypeScript checks and a
  production build. Inspect narrow/desktop layout and print behavior, section
  links and no-session access. Tests are not a legal or physical-device audit.

Completed October 4 validation:

- All 20 web suites / 144 tests pass, including 11 new legal-page regressions.
- `tsc --noEmit --incremental false` and `git diff --check` pass.
- Production build passes with `npm run build -- --webpack`, using placeholder
  public Supabase values, not real credentials. The worktree reuses installed
  dependencies via a symlink; default Turbopack rejects that outside-root link.
  Existing Google font downloads required network permission. No project
  bundler/dependency/configuration changes were made to address these local
  environment constraints.
- Local production `/privacy` and `/terms` return anonymous 200 HTML; draft
  notice, contact, noindex/nofollow and absolute canonical metadata verified.
- Safari desktop Privacy and 390x844 Privacy/Terms inspected. Desktop AI anchor
  and expandable mobile file-limitations anchor work. Privacy print preview
  contains the draft notice and six pages of text, without navigation clutter;
  preview canceled, no file saved or print sent. This is not every-browser,
  every-print-page or physical-device certification.

No-current-training clarification follow-up:

- The user's later answer supersedes the original training assertion in the
  Privacy/Terms draft and coordination records. It does not authorize a training
  feature, a provider-wide assurance or effective publication.
- All 20 web suites / 145 tests (12 legal regressions), TypeScript, production
  Webpack build with placeholder values and diff checks pass. Both generated
  legal HTML pages contain the corrected no-current-training statement and
  separate future opt-in requirement, retain draft/noindex and omit the old
  assertion. Layout/assets/routes are unchanged; prior visual checks are not
  presented as a new physical-device or live-policy audit.

## Publication sequence once facts and approval are available

1. Resolve every `REVIEW REQUIRED` marker against actual practice and counsel's
   review. Obtain approval for any new contractual/data-use choice; implement
   separately required consent/security/deletion behavior before claiming it.
2. Preserve a copy of the currently effective policies. Set a real prospective
   effective date, remove draft notice/noindex, and issue required user notices
   and acceptance requests. Do not treat publication as retroactive consent.
3. Commit/push one reviewed web lane, run all relevant CI, and selectively stage
   approved files only after deployed base hashes still match. Back up the exact
   existing legal files and build artifacts for rollback. Build and atomically
   promote the reviewed web output without dropping unrelated VM changes.
4. Verify both www/apex HTTPS destinations without cookies: 200 HTML, correct
   policy/date/operator, no redirect to auth, working contact/TOC/cross-links,
   canonical metadata and preserved unrelated site routes. Add/remove no other
   production services or domains.
5. Update mobile policy presentation and add hosted links/appropriate pre-auth
   access in a separate lane; verify approved text, accessibility and any
   required versioned acceptance. Do not submit/upload to Apple without the
   user's new instruction. Later confirm App Store policy URL and privacy labels
   match actual runtime behavior.

## Primary references checked

- [Apple App Review Guidelines, 5.1.1 and 5.1.2](https://developer.apple.com/app-store/review/guidelines/): policy access, retention/deletion, provider protection and explicit permission for applicable third-party sharing/AI.
- [California Business and Professions Code 22575](https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=22575.): collection/disclosure categories, request process, changes, effective date and tracking disclosures.
- [FTC consumer privacy guidance](https://www.ftc.gov/business-guidance/privacy-security/consumer-privacy): policies must match actual privacy promises and operations.
- [FTC AI privacy commitments](https://www.ftc.gov/policy/advocacy-research/tech-at-ftc/2024/01/ai-companies-uphold-your-privacy-confidentiality-commitments?page=1): undisclosed incompatible reuse cannot be repaired by quietly rewriting terms.
- [FTC COPPA compliance plan](https://www.ftc.gov/business-guidance/resources/childrens-online-privacy-protection-rule-six-step-compliance-plan-your-business): applicability depends on actual audience/knowledge; covered services need notice, verified consent, parent rights and security/retention measures.
- [Apple Standard EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/): applies when no custom license is provided; do not claim a custom license is filed merely because web terms exist.

These references guide a draft, not a certification of California, COPPA, GDPR,
CCPA/CPRA or worldwide compliance. Applicability depends on facts and operations.
