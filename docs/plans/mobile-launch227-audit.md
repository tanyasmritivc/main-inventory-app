# Mobile launch audit — 1.1.5 (227)

The user authorized a thorough mobile audit, bug fixes and public App Review
submission, retaining the existing App Store screenshots. This supersedes the
earlier TestFlight-only stopping point for this release. Keep the existing
automatic-after-approval release setting and reviewer credentials.

## Findings and changes

- Organization Space Ask still used the old Space-only API. It now uses the
  organization ID from the authorized inventory context for chat and history.
  The label explains that accessible Spaces in that organization are searched.
  Personal Spaces retain their Space-only endpoint. Main Ask is unchanged.
- Space file parsing remains scoped to the originating Space; parsed evidence is
  supplied to the organization question. Space photo questions do not enable
  extraction. Account/inventory retirement still invalidates pending clients.
- Markdown strong emphasis was forced to normal weight, including by the shared
  typography adapter. Answer emphasis now explicitly uses semibold after font
  adaptation. Four compact-screen, light/dark and enlarged-text checks cover
  actual Markdown tables and emphasis.

## Evidence recorded so far

- Baseline: 1,404 Flutter tests passed, one existing release-config skip.
- Updated full host suite: 1,410 passed, one release-config skip.
- Four added answer-format tests and the production-config test: all five passed.
  This explicitly runs the configuration gate skipped by the generic suite.
- Final analyzer: no issues.
- Broad iOS simulator audit and final native regression audit: pending completion.
- Dedicated Apple review login, inventory-workspaces read, API/database health,
  privacy, terms, support and universal-link association endpoints: HTTP 200.
- Draft 1.1.5 created; all seven iPhone and seven iPad screenshots preserved with
  matching ordered filenames, checksums and sizes. No new screenshots uploaded.
- Paired iPhone currently runs build 225. Candidate-device acceptance is pending.

The first formatting regression failed because `AppTypography.styleOf` overwrote
the weight; the final check passes after applying emphasis after that adapter.
An initial focused command named a nonexistent test file; a later focused runner
stalled. Neither is counted as passing. The sequential full host suite completed.

Private logs and Apple metadata are in `projects/findez-launch227-private`.
No customer inventory was changed by automated fixtures. No backend migration or
deployment is part of this mobile change. Final packaging and submission receipts
will be added after the remaining gates complete.
