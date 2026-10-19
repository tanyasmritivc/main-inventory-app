# Website UI polish — October 19, 2026

Status: published and visually verified on findez.ai and www.findez.ai. Runtime
commits `dc8ae89`, `f8a6b2b`, `b7d5a13` and `54ed135`. No mobile source, binary, App Store or
production database changes. This extends the [website launch audit](web-launch-audit-20261019.md).

## Changes

- Navigation now uses Home, Items and Spaces consistently. The Items page has one
  primary Add items action and a secondary New Space action; Spaces keeps New Space
  primary. A compact accessible category selector replaces the wall of category
  buttons. Clearing it restores the complete inventory.
- Item table columns have bounded widths, wrapping and concise headings. Inventory
  totals use a two-column layout on narrow screens so all four totals are visible.
- Capture names the destination with Save to, uses plain import-method labels, and
  wraps all five methods into visible rows on narrow screens. The selected method
  exposes its pressed state to assistive technology.
- Workspace directory heading duplication and excessive nested padding are removed.
  Background permission refresh keeps existing rows visible instead of repeatedly
  replacing them with a loading screen. Access denial still clears inaccessible
  content. An expired session directs users to sign in instead of leaving Loading.
- Settings cards use meaningful subheadings (Personal details, Theme, API access,
  Support and legal, Account management) instead of repeating the page title.
- Documents use readable types such as PDF, correct singular/plural counts, wrapping
  filenames and compact actions with consistent row borders. Review now says
  Confirm and save and explains what needs checking.
- Following the user's screenshot feedback, Review is a compact queue with 56px
  thumbnails and 25 rows per page. One correction panel expands at a time, with
  a bounded photo, editable fields and a separate evidence disclosure. Drafts
  survive closing rows, switching rows and pagination; failed saves retain the
  correction. No capture is saved or dismissed by opening it. The existing API
  loads up to 100 captures per batch; when more are pending, the UI states that
  limit and offers Refresh after processing the current batch. No backend or
  database pagination changes were introduced.
- Checkout failures have explicit recovery rather than an empty-state success.
  Future due dates are displayed as dates rather than negative relative times.
- Landing copy describes photograph, review, save and ask about saved things.
  Vague model-improvement messaging is replaced with concrete shared-inventory
  copy. Existing brand assets and the established visual design remain.

## Approved server repair

The 670-item Home overview exposed a PostgREST 414 failure when the checkout query
put 200 authorized item IDs into one URL. The user explicitly approved the tested
repair in PR130. It uses 50-ID batches, preserving exact permissions, pagination,
filters and global ordering. Only that backend route was published, with a backup
and health check. The same existing inventory then loaded successfully in Safari.
No customer records were changed by this final UI pass.

## Validation and deployment

- Website: 54 suites / 431 tests passed, including category filtering, session
  recovery, background refresh, checkout error recovery and compact Review
  pagination/draft preservation. TypeScript, scoped ESLint, production build
  and live narrow-screen verification also passed.
- Backend exception: 1,103 tests plus 10 subtests passed; 43 focused checkout,
  scope and security tests passed. A synthetic 670-item case verifies bounded
  encoded URLs and exact permitted IDs; pagination and empty visibility covered.
- Every isolated website candidate passed TypeScript, scoped ESLint and webpack
  production build before activation. All public-host route and connector package
  hash checks passed. Existing unrelated runtime files and cached chunks remain.
- Safari visual review: desktop and 390px/820px responsive views. Checked Home,
  Items, Spaces, Capture, Ask, Documents, Review, directory, Profile, Developer,
  API-key management and landing during this pass. Final changed layouts were
  rechecked after publication, including all Capture methods, PDF row actions,
  short table headings and all four totals. The compact Review list and expanded
  correction panel were also verified live on desktop and at 390px; no customer
  capture was confirmed, changed or dismissed. Category selection/clear was exercised
  against the existing 670-item inventory. Desktop mode was restored afterward.
- Latest CI: runtime `54ed135` passed all five gates in run 39333092847.
  Preceding runtime `b7d5a13` passed all five gates in run 39332332200.
  The earlier `dc8ae89` passed all five gates. Automatic repository Flutter checks
  do not edit, rebuild for distribution or submit the mobile app.

Active service: `/home/ubuntu/findez-web-review-compact-20261019/candidate/frontend`.
Private release receipts are in `/home/ubuntu/findez-web-ui-20261019`,
`/home/ubuntu/findez-web-ui-final-20261019`,
`/home/ubuntu/findez-web-ui-totals-20261019`,
`/home/ubuntu/findez-web-review-compact-20261019`, and
`/home/ubuntu/findez-web-checkout-20261019`. Each activation checked source hashes,
retained the previous release/configuration and rolled back on failed health.
The totals release preserved 272 unrelated runtime/public files; the Review
release preserved 272 and added one scoped stylesheet.

## Remaining launch gate

The API-to-FIND processing connection is still HTTP under the earlier instruction.
It needs HTTPS or a private encrypted tunnel, restricted exposure, the insecure
HTTP override disabled, credential rotation after protection, and end-to-end
load/recovery checks. One direct natural-language search exceeded a 45-second
client deadline. The main audit records dependency and acceptance limits. UI
polish and passing regressions are not an external penetration-test certification
or evidence that every browser, hardware path and third-party host was exercised.
