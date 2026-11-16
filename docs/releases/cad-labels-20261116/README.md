# CAD website consistency correction

November16 UTC, November15 local. User requires related documentation, versions,
downloads and installation instructions to remain consistent throughout the site.
Audit verified all eight download hrefs and ZIP0.3.1, but found two preview-folder
labels (static markup and animated runtime) and stale0.2.1 docs search metadata.
Three text substitutions correct those labels. Legacy names remain only in
explicit historical/troubleshooting explanations. Public page layout/copy and
ZIP/backend/mobile/schema are unchanged.

Scoped lint, three documentation tests, diff checks and production-configured
build passed. Self-hosted release /home/ubuntu/findez-cad-labels-20261116/frontend,
build55xOfOnCM5xKskWPpi2j9, based on findez-world-buttons-20261116. Three-module
hash guard preserves unrelated source; all public assets hardlinked unchanged.
Live static/animated folder labels, docs search keyword, eight versioned download
URLs, ZIP hash, docs/API health and public page HTML verified. No Vercel/Render
or git push. One inactive CAD compiler cache was removed to provide build space;
runtime/rollback files retained. Previous-service.conf and activation receipt are
in the server release; verify no newer release before restoring that service
configuration, daemon-reloading and restarting findez-web.

ZIP0.3.1 SHA256:
bba16d75a4fcd181261f0a9d0bd428a04eb85024442e56add7b8cdcfa388f5e0

Updated roadmap tracker to reflect actual Windows installation/sign-in evidence,
current AI search/design-question dispatch, model picker and remaining scope.
The full roadmap remains incomplete; no new CAD capability is claimed by this
website correction.
