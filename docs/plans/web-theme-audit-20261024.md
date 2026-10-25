# Web theme and interface audit — October 24

Scope: Next.js only. Reproduced the dark chat plus-menu contrast failure on the
signed-in live site; reviewed appearance, memory, Spaces and notifications without
customer writes. Local previews use fictional data and are not release routes.

## Corrections

- Portaled menus/dialogs inherit dark foreground and surface tokens, including
  legacy aliases. Native selects, autofill and focus colors follow the theme.
- Theme hydration is stable. Restricted storage no longer crashes appearance
  controls; in-session fallback, OS changes and cross-tab preferences work.
  Agent approvals and inventory access requests receive the prepaint theme.
- Shared dialogs have padding despite the legacy reset, fit the viewport and
  scroll. Dialogs and nested menus sit above mobile navigation.
- Long notification filenames wrap; unread dots remain visible in dark mode.
- Sidebar initials stay centered, directory hover and overdue text use theme
  colors, and New Space actions use the existing primary-button styling.
- Memory controls use themed borders, the personalization checkbox spans its
  row, and empty message/list containers do not add blank gaps.
- Muted text tokens meet 4.5:1 contrast on the tested panel/page/raised surfaces.

## Validation

566 tests across 79 suites pass, including eight new theme/storage/hydration and
contrast regressions. TypeScript passes. Full lint has zero errors and 53 existing
warnings. Compile-only webpack build passes with synthetic configuration/font
fixtures; that output must never be deployed. The deployment is rebuilt with
production configuration on the server.

Native Chrome inspection: local real-component plus menu and nested context
menu, dark/light dialogs, 390px viewport, and 350px-high dialog scrolling to Done;
long notification wrapping and unread marker; full fictional-data inventory,
Space creation dialog, appearance and memory settings. Actual inventory writes,
payments, extraction/model quality and exhaustive browser/device coverage are
outside this UI audit. A missing photo fixture initially caused the isolated QA
app to error; the fixture was corrected, not shipped as an application change.

Release status: awaiting exact-commit CI and guarded production staging. Preserve
the active chat-pip release, its source snapshot and the unrelated VM checkout.
