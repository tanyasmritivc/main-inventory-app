# Compact native organization menu correction

Build215 used a grouped UIKit table in the organization popover. On the user's
phone its blank section headers and footers created large bands and made the
menu unnecessarily tall. This correction uses one plain native table section,
zero header/footer spacing, consistent icon columns, regular 16-point system text
and content-sized height. The width is bounded to 340 points and screen edges.
Dynamic Type still wraps text and the menu remains scrollable when needed.

Every existing row ID and action is preserved, including organization selection,
Personal, New organization and Review invitation. Other native sheets, account
permissions, chat and scanning behavior are unchanged. The synthetic preview now
includes a long organization name for visual verification.

Validation: all 1,375 Flutter tests passed with one existing skip; analyzer clean.
Native iPhone16e simulator checks passed in light and dark mode at standard and
accessibility-large text sizes. Organization/Personal switching, selection check,
creation open/cancel, invitation navigation and outside dismissal were inspected.
No customer account or data was used. Physical device acceptance remains pending.

Apple acknowledged signed TestFlight 1.1.3 (216), delivery
`471fcc9c-67ca-4b41-b20a-fdb229d2f735`. All five CI checks passed for runtime
`27bfcb067f1f579815e954993a35ea59f7333510`. Processing/tester availability are
pending, not polled. Public submission is unchanged. See `mobile216-release.json`.
