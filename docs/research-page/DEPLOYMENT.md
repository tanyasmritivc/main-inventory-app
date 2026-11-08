FIND Research is live at https://www.findez.ai/research.

The existing Research route was replaced directly on the configured self-hosted web service. No preview route, local preview server, staging server, feature flag, Vercel project, or Render project was used. The production deployment and live checks happened before the source commit, as requested.

Deployment details:

- Branch: `feat/research-find`, based on `origin/main` at `1c97e1f4838ee6fbda6ea97ed34fc275cc3b9db0`.
- Source commit: the commit containing this report. Run `git log -1 feat/research-find` for its full hash.
- Merge commit: none. This configured production service uses selective release directories, not a push-to-main deployment. Main predates the currently deployed marketing site. Merging or deploying that old main tree would remove unrelated live work.
- Existing method: copy the current web release, overlay the nine Research-related source/assets, run `npm run build -- --webpack`, then activate that built release through the existing `findez-web` systemd service and its `web-rebuild.conf` WorkingDirectory override.
- Active release: `/home/ubuntu/findez-web-releases/research-find-20261108-final/frontend`.
- Build ID: `4uDWT_KEAqGwcjB2apclW`.
- Build and activation: succeeded. The deployment receipt is in `published.json`.
- The first live pass exposed inherited font styling and navigation prefetch. That release was rolled back to the original service directory, corrected, rebuilt, and replaced by the successful final release.

Scope and preservation:

- The production overlay changed the existing Research page, added its three implementation files and three static assets, and added an optional `prefetch={false}` input to the existing Header and Footer. Only Research passes this input. Other pages keep the previous default behavior, links, and appearance.
- All 517 other existing source and public files retained their original hashes. Environment, package, and configuration hashes remained unchanged. The backend process remained unchanged.
- No backend, API, auth, signed-in app, config, dependency, mobile, or other page files are in this branch's change set. `changed-files.txt` records the exact output of `git diff --name-only main...feat/research-find`.
- Main lacks the current production marketing files. Consequently the Research route and the two existing shared components appear as additions relative to main, although the deployed Research route was replaced in place. The release was built against the existing production source, not against the older main checkout.
- Old files deleted: none. The old Research sections were inline in the replaced route. Shared legacy code was retained.
- Research already appeared in the footer and remains there. It was absent from the top navigation; no top navigation link was added.
- The existing white Research navigation and footer were preserved. They intentionally differ from the supplied prototype's navigation and footer, which were outside the authorized design scope.
- `source/`, `prototype/`, `screens/`, and the original `assets/` are the supplied reference archive. They were not deployed as additional routes. Only the Research content was ported from the readable source.

Live verification:

- Desktop viewport 1440 by 900 and phone viewport 390 by 844 were checked against the supplied screenshots. Captures are under `live/desktop/` and `live/mobile/`. Captures use the browser's device scale, so PNG pixel dimensions can be twice the viewport dimensions.
- Checked the hero outline gathering, scan and four labels, all six pipeline steps and their overlays, the four photo tiles, correction orbit, objective with thin dividers, development status, and contact section.
- Reduced motion was emulated in Chrome: completed outline and labels, visible final content, and static pipeline descriptions. The orbit animation is disabled by the reduced-motion rule. Browser motion emulation was restored afterward.
- The Research console showed no JavaScript errors. Chrome reports the existing server warning `Unrecognized feature: 'browsing-topics'` in the Permissions-Policy header. Server configuration was left unchanged.
- The Research network log contained only the document and same-site static scripts, styles, fonts, logo assets, and optimized static photos. No backend or model calls, analytics calls, or other-route prefetch requests were observed.
- The contact button opened Mail with recipient `info@findez.ai` and subject `FIND`. No email was sent. The displayed address remains plain text.
- The landing page, Solutions, Founders Access, and sign-in page were opened live and their existing layouts and navigation checked. HTTP smoke checks passed for all ten routes recorded in `published.json`.
- Authenticated app verification is limited: the existing Inventory tab's session had expired and reloading redirected to sign-in. No credentials were entered or requested. Signed-in source files were preserved byte for byte, but authenticated workflows were not exercised.
- Only the production build was run. No local preview or local test suite was run.

Rollback uses the existing service directory switch, not a git merge revert because this release has no merge commit. Restore `previous.conf` from `/home/ubuntu/findez-web-releases/research-find-20261108-final/` to `/etc/systemd/system/findez-web.service.d/web-rebuild.conf`, run `systemctl daemon-reload`, and restart `findez-web`. The previous release is `/home/ubuntu/findez-web-releases/scan-wording-20261108/frontend`.
