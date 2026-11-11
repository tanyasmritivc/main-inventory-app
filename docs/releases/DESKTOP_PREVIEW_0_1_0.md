# FindEZ desktop 0.1.0 preview

Scope: downloadable Electron clients for Mac Apple silicon, Mac Intel and Windows
x64, with a public `/desktop` page and a standalone `/desktop/callback` route.
Existing FindEZ accounts, inventory, CAD comparison and backend are reused.
No mobile, database, inventory quantity or authentication-provider configuration changes.

## Validation

- Six desktop policy tests and twelve frontend callback/auth tests pass.
- Focused frontend lint and production Next.js build pass.
- Desktop dependency audit: zero known advisories at release check.
- Actual Electron on Apple silicon: renderer sandbox enabled, context isolation
  enabled, Node unavailable in page, password sign-in with disposable account,
  Google S256 PKCE routing to system browser, CSV and XLSX file imports/comparisons
  (8 required, 6 covered, 75%), session persistence after restart, offline recovery.
- Packaged Apple silicon app opened and showed live FindEZ sign-in and native menus.
- Mac ad-hoc signatures verified recursively. Bundled sources checked in both Mac
  and Windows packages. Windows NSIS installer and uninstaller generated successfully.
- SHA-256 hashes accompany the downloads; uploaded files checked against local bytes.
- Callback tested over HTTP for no-store, restrictive CSP, and validated
  custom-protocol link. Global Next headers required an explicit route override. The public Caddy edge
  sets Referrer-Policy: same-origin; the standalone document also sets a
  no-referrer meta policy so callback codes are not sent as navigation referrers.

## Deployment

Production frontend copied from the exact active release:
`/home/ubuntu/findez-cad-sheets-20261111/candidate-v2/frontend`.
Final release: `/home/ubuntu/findez-desktop-20261111/candidate-v2/frontend`.
Only `src/app/desktop/**`, the `/desktop/callback` header block and public installers
are added. Existing commerce, CAD, navigation, landing and auth changes preserved.
No production backend deployment.

Files:
- FindEZ-0.1.0-mac-arm64.dmg
- FindEZ-0.1.0-mac-x64.dmg
- FindEZ-0.1.0-win-x64.exe
- SHA256SUMS.txt

Installers are served from `/downloads/desktop/`. Direct-download Mac builds have
local ad-hoc integrity signing, not an Apple Developer ID/notarization; Windows
builds have no publisher signature. The download page discloses OS warnings and
provides the browser alternative. No auto-update service is configured.

## Remaining acceptance

Actual Windows/Intel Mac installation and runtime; real Google/Apple completion;
email verification/reset links; physical camera, mic and notification delivery;
installer/uninstaller/protocol association on clean machines. A stable release
requires Developer ID + notarization and Windows publisher signing. Do not describe
this preview as App Store-ready or fully device-tested.

## Rollback

Remove only `/etc/systemd/system/findez-web.service.d/zzzzzzz-desktop.conf`, reload
systemd and restart findez-web to restore its previous working directory. Do not
reset the shared production checkout or alter backend services. Downloads and the
OAuth return endpoint will no longer be available after rollback.

## Published checksums

```text
83bc320e4d9d90608435e49efd9a60f70a15ea7f158fd6d9a467181415726d8c  FindEZ-0.1.0-mac-arm64.dmg
dd460347b455972dd7ed12561bd82f5940cf3deef54e29c31f774f161378df6b  FindEZ-0.1.0-mac-x64.dmg
b9dd93bfa0f24778904d0b409f410a417cd0c716ec472920c07ed09e08767952  FindEZ-0.1.0-win-x64.exe
```

Disposable QA accounts and synthetic stock removed after acceptance.
