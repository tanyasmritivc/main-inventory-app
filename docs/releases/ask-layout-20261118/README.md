# Ask layout correction - published November 17, 2026 local

The floating Space Ask panel inherited the desktop shell's full-viewport minimum
height. Its form could sit beneath the clipped panel. The desktop rule now applies
only to full-page chat, without overriding its own bounded viewport rules. The
panel header and footer do not shrink, while its content/transcript can shrink and
scroll. The input and send control remain inside the visible panel.

The empty-state caption is plain theme text (white in dark mode), without the
shiny span. The full-page composer is capped at 600px instead of filling the
710px chat column. Its existing shape, border, background, animation and controls
remain. Contextual input uses the panel's available width. No scope, prompt,
permission, API or stored-data changes.

## Checks

- 23 focused chat, Markdown, stream and UI tests passed.
- 16 browser cases passed: full-page and contextual chat, light/dark, 1920x960,
  1280x720, 390x844 and 375x500. Actual shared desktop shell styles are loaded.
- Empty and 24-row answered states checked input/send bounds, caption color,
  absence of shimmer, narrowed main width and page-scroll stability. Synthetic
  auth/data only; no customer conversation was sent. Browser page errors checked.
- Representative screenshots were inspected. These checks use Chrome; no claim
  of a signed-in Safari session or physical mobile keyboard acceptance.
- Production webpack build and TypeScript passed. Changed-file lint: zero errors,
  three existing warnings. Full application suites were not rerun for this layout
  correction; their previously documented unrelated failures remain.
- Live source hashes and public CSS hashes matched; public routes resolved to
  HTTP200 (protected routes redirect to sign-in for anonymous requests).

## Deployment

Built from the active header release, preserving 539 unrelated source files.
Active: /home/ubuntu/findez-ask-layout-20261118/frontend
Build: Of98YQCy0nw3xuaYaOAOY
Previous: /home/ubuntu/findez-header-20261117/frontend
The activation receipt records the systemd override. Remove that override and
reload/restart findez-web to restore the previous release. Old static chunks are
retained for open browser tabs. No backend, database, mobile or landing-content
change; no Git push. Browser fixture is documentation only, never deployed.
