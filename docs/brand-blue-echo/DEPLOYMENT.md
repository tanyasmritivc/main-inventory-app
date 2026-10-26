# Self-hosted brand deployment

Runtime: `ccb15ac80a37438ca5b6726aac6a8e1cbc4337ed`, PR182.
Build ID: `E_0tL8htuWZYnnxCVcbL1`.
Service: `findez-web` on the existing self-hosted VM. No Vercel deployment.
Active directory: `/home/ubuntu/findez-web-releases/brand-blue-echo-icons-20261023/frontend`.

The first scoped branding release preserved 341 unrelated source/public files.
The icon-cache follow-up preserved 364. Each candidate verified touched-file
baseline hashes, built with the existing private production configuration, checked
route status parity and exact asset bytes, then switched only the web service's
WorkingDirectory. The backend PID stayed unchanged. Prior release directories and
systemd drop-in backups remain available for rollback.

Validation:
- 61 Jest suites, 472 tests passed.
- TypeScript passed; production webpack build passed.
- ESLint: 0 errors, 52 existing warnings. Follow-up layout lint passed.
- All five CI jobs passed on final runtime: run 40062624865.
- Public homepage, signup, signin, pricing, API docs, privacy, terms, robots and
  sitemap returned 200. Unauthenticated workspaces retained its 307 redirect.
- ICO, 96px PNG, SVG favicon, touch icon, social/organization logo and legacy SVG
  URL matched deployed source bytes over HTTPS.
- Chrome visually confirmed the new header wordmark and new tab icon after reload.
- Initial remote build hit a transient Google font-loader error; inspected current
  official font URLs and retried successfully before activation.

Manual check: reload findez.ai, inspect the browser tab/header, then open signin
and pricing. Search-engine favicon changes depend on recrawl; no immediate search
result update or Search Console indexing request is claimed.
