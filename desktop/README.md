# FindEZ desktop preview

Electron desktop client for the existing hosted FindEZ app. Mac Apple silicon,
Mac Intel and Windows x64 installers. Internet access is required. Version 0.1.0
is a preview: Mac has an ad-hoc integrity signature, not a Developer ID signature
or notarization; Windows is unsigned. Windows runtime acceptance remains pending.
macOS 13+, Windows 10+. No offline inventory database or automatic updater.

## Build

Use Node 24 (minimum 22.12):

```sh
cd desktop
npm ci
node node_modules/electron/install.js # if npm installation scripts were disabled
npm test
npm start
npm run build:mac
npm run build:windows
```

Artifacts are in `desktop/dist`; never commit installers. Generate SHA-256 checksums
for the exact published bytes. The macOS build requires Xcode command-line tools.
Windows NSIS cross-build uses electron-builder's resource editor and uninstaller
reader; no host Wine installation was required for this release. Icon sources in
`build` are the existing approved FindEZ brand, not a new logo.

## Architecture and security

The renderer opens only https://www.findez.ai in a sandbox without Node, preload,
webviews or exposed IPC. Navigation to other HTTPS sites opens the system browser;
file/javascript/OS-command schemes are denied. Camera, microphone and notification
requests require native consent for the exact FindEZ origin. Downloads use a native
save dialog. The session persists in Electron's application profile.

Google/Apple OAuth authorization requests are intercepted only at the configured
Supabase origin. Their existing S256 PKCE challenge is preserved. A random, expiring,
one-use state associates the system-browser redirect with the originating app.
`/desktop/callback` serves standalone script-free HTML linking back through
`findez-desktop://auth/callback`. Only the original desktop session exchanges the
code through the existing `/auth/callback` flow. No access/refresh tokens are put
in the custom protocol. The current Supabase HTTPS redirect allowlist already
covers this callback. Closing the app during OAuth requires starting sign-in again.
Email verification/password reset and actual Google/Apple account completion need
manual end-to-end acceptance before a stable release.

## Acceptance testing

`test/policy.test.cjs` exercises navigation, permission and PKCE validation.
`frontend/src/__tests__/desktop-callback.test.ts` exercises callback HTML and headers.
`test/acceptance.cjs` runs real Electron against the hosted site using disposable QA
accounts and a synthetic BOM that requires eight units against six available.
Provide PLAYWRIGHT_MODULE (or install Playwright outside production dependencies),
FINDEZ_QA_ACCOUNTS (private JSON with accounts[0].email/password/inventory_id),
FINDEZ_QA_CSV and FINDEZ_QA_XLSX. Never use a customer's inventory. It checks browser
OAuth routing, password login, CSV/XLSX comparison, persisted session and offline UI.
Delete disposable accounts and inventory after testing.

## Stable release gates

Obtain a Developer ID Application identity and notarize Mac artifacts; configure
Windows publisher signing. Test installed builds on Intel Mac and Windows, actual
Google/Apple completion, email links, camera, microphone, notifications, downloads,
uninstall/reinstall and protocol association. Use the Help menu to download updates;
this preview does not silently replace binaries.

References: https://www.electronjs.org/docs/latest/tutorial/security/
https://supabase.com/docs/guides/auth/sessions/pkce-flow
https://www.electron.build/v26/docs/features/multi-platform-build/
