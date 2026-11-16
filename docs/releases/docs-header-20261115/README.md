# Documentation header alignment

Fixed /docs/api and /docs/cad only. Disabled auto-hide for their main navigation,
made its background opaque, aligned the 72px desktop toolbar below it, and moved
sticky navigation and section anchor offsets beneath both bars. Mobile toolbar
uses normal flow at top:0 with wrapping controls. The public CAD marketing page
and shared marketing chrome implementation were not changed.

## Validation and deployment

Seven targeted documentation tests and changed-file ESLint passed. The guarded
production-source Next.js webpack build passed, including TypeScript. Only
api-docs.module.css, api-docs.tsx and cad-docs.tsx changed in production.
Live CSS/HTML verified over HTTPS for both routes. Safari visual checks passed
at 1440x900 and 390x900; desktop anchor links clear the header and sidebar labels
remain visible. Responsive preview was exited after testing.

Self-hosted findez-web now uses
/home/ubuntu/findez-docs-header-20261115/frontend.
Build: wZ90T3Yc7qgaL43VuZwwj.
Previous: /home/ubuntu/findez-cad-docs-20261115/frontend.
Server receipt.json and activation.json record source guards and activation.
Existing public assets were hardlinked; the disposable webpack compiler cache
was moved to the new build to avoid unnecessary disk usage. Old static assets
were retained for already-open tabs. No Vercel or Render deployment. Local commit
was not pushed to avoid an automatic external hosting preview.
