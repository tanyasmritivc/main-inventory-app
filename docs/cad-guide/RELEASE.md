# CAD Intelligence guided setup

Deployed November 11, 2026 to https://findez.ai/cad and https://findez.ai/docs/cad.

## What changed

The inventory picker now gives a clear first step. The comparison page separates
Autodesk Fusion from CSV/Excel, explains preparation and the next upload action,
and keeps setup, sample-design instructions, troubleshooting, and email support
within reach. Installation instructions include the inner-folder layout and the
new Fusion Run toggle. The public guide also explains export, spreadsheet mapping,
result statuses, and shared data.

Five frontend runtime files changed. Existing upload API handlers, comparison,
shortage export, result rendering, inventory access, and authentication behavior
are preserved. No backend, mobile, dependency, environment, or database changes.

## Deployment

Built using the current self-hosted release and its installed dependencies.
Preserved the parallel Connections deployment. Production webpack build, TypeScript,
and prerendering passed. The build used IPv4 preference for font requests after
IPv6/default network retries stalled the first attempt. No font/config files changed.
Activated the existing findez-web service with a rollback-capable health check.
598 unrelated frontend files were preserved. See deployment.json.
No Vercel, Render, staging server, or local preview was used.

## Verification

• Live authenticated Safari inventory selection and CAD page rendering checked.
• Selected inventory, both source choices, disabled empty-file comparison,
  upload field, inline setup summary, and help links present in the live UI.
• Public guide returns 200 and includes all nine documentation sections.
• Fusion ZIP and CSV template return 200 with their expected content types.
• Source comparison confirms upload/compare/export handlers and results unchanged.
• git diff --check passed; new documentation has no em or en dashes.

Safari automation timed out while expanding the installation details and remained
unresponsive on reconnect. Phone layout, expanded accordion, source-button switching,
and a fresh uploaded-file comparison were not completed in this pass. Responsive
CSS is included, but no physical-phone or Fusion execution claim is made.
The private desktop screenshot is retained outside the repository because browser
chrome and the signed-in app contain personal account information.
