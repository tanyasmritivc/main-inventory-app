# LEGAL-001: Public Privacy Policy and Terms review

## Scope and location

Web legal pages/content only; `/private/tmp/findez-legal-review`, branch
`feat/public-legal-review`, based on `19da889`. Do not merge/deploy the review
drafts or submit/upload to Apple. Other mobile/release work remains preserved.

## Completed

- User confirmed AI Robots Inc/California, 13+ with guardian permission and
  public contact `info@findez.ai`. Later clarification supersedes the earlier
  training answer: FindEZ does not currently train on customer photos/chats/
  documents; training is a future possibility only. Drafts distinguish requested
  feature processing from training and require separate explicit opt-in for any
  future program. Provider-wide no-training is not independently verified.
- Privacy (12 sections) and Terms (16 sections) drafted against inspected
  application behavior and official Apple/California/FTC references.
- Original outlined SVG, responsive contents menu, accessible anchors/contact,
  print layout, draft banner/revised date and noindex/canonical metadata.
- Read-only live checks: existing policy routes are anonymous HTTPS 200; four
  legal source hashes match the base. Public document/item-image buckets and
  private profile bucket verified; no customer files opened or settings changed.
- All 144 web tests, TypeScript, production Webpack build, anonymous local HTML
  metadata and diff checks pass. Safari desktop/390pt section navigation and
  Privacy print preview checked; no print/file sent. No backend/mobile change.
- No-current-training clarification follow-up passes all 145 web tests (12 legal
  regressions), TypeScript, production Webpack build, generated legal HTML
  statement/draft/noindex checks and diff checks. No new visual/native/live-policy
  certification; drafts and Apple remain held.

## Remaining and blockers

Current provider/downstream training uses, countries/contracts,
tracking/business practices, full file/deletion/backup coverage, audience and
applicable jurisdictional duties require verification and counsel review. No
postal address supplied; do not invent one or promise lawsuit immunity.
Future training categories/operators, consent, withdrawal, retention and effects
on trained models must be resolved before any future training feature is offered;
no training control or data-use change was implemented in this web-copy lane.

Current storage/public URLs and FIND HTTP are security limitations. Fixes must
be separately authorized/scoped and tested; don't silently flip bucket flags or
change FIND. Mobile embeds older legal text and auth acceptance is not verified;
align approved policies/links/required consent in a separate mobile/auth lane.

## Exact continuation

1. Read `docs/legal-publication.md` and current source/git state; obtain the
   missing provider/data-practice facts and counsel review before removing any
   review marker. Do not restore the superseded current-training assertion.
2. Resolve actual practices and necessary separately scoped changes, then obtain
   prospective policy/Terms approval and any required notice/consent plan.
3. Follow the documented selective publication/rollback sequence. The production
   VM checkout is dirty: do not pull/reset or deploy this branch wholesale.
4. Repeat web checks, anonymously verify public effective pages, then align mobile
   policy presentation and App Store disclosures. Apple remains held until a new
   explicit user instruction.
