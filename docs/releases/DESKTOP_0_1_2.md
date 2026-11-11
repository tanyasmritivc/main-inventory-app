# FindEZ desktop 0.1.2

Corrects direct-download Mac distribution and the desktop layout. The hosted web
app stays at its desktop breakpoint (1000x640 minimum, 1280x860 initial window).
Onboarding retains its existing responsive page and 720x560 minimum; leaving
onboarding restores the desktop minimum. Copyright and package publisher metadata
now read AI Robots Inc., as confirmed by the user.

## Validation

- Six desktop navigation, permission and PKCE policy tests pass.
- Actual Electron with disposable accounts: password login, CAD sidebar at minimum
  window size, onboarding window exception, and restoring desktop constraints pass.
- Download-page focused lint and exact production-overlay webpack build pass.
- Windows executable company and copyright resources verified; runtime pending.
- All disposable QA accounts, synthetic stock and local test credentials removed.
- Both final Mac apps pass recursive strict codesign verification and Gatekeeper
  (`accepted`, `Notarized Developer ID`). Both DMGs have validated stapled tickets.
- Native Apple silicon launch and About panel verify 0.1.2 and the corrected copyright.
- Published checksums match server bytes; public page and all three installer URLs
  return HTTP 200. Production service is healthy.

## Signing

A Developer ID Application certificate was created with explicit user approval for
the existing Vinod Rex Apple team. Its private key remains on this Mac, outside git.
Apple certificate identity remains the account holder; application copyright and
publisher metadata use AI Robots Inc. No account migration or company enrollment
change was performed.

0.1.1 was signed, accepted by Apple and verified by Gatekeeper, then superseded
before linking it from the download page to incorporate the copyright correction.
0.1.2 must independently pass notarization. The DMG is a notarized, stapled container;
the enclosed app carries Developer ID signing. Assess the app with Gatekeeper,
not the unsigned container's primary signature.

## Deployment and rollback

Candidate /home/ubuntu/findez-desktop-signed-20261111/frontend is copied from
/home/ubuntu/findez-footer-plans-20261111/frontend, preserving its newer landing
page, CAD and commerce work. Only the desktop download page and installers change.
No backend, database, authentication provider or mobile changes.

The prior footer-plans release remains available for rollback. No automatic
desktop updater is configured; download the latest installer and replace the app.
User data remains in the existing Electron profile.

## Remaining acceptance

Windows publisher signing and Windows/Intel hardware runtime; real provider login,
email links, camera, microphone and notification delivery remain separate manual
acceptance. This is a desktop preview, not a Mac App Store submission.

## Final receipt

Apple notarization Accepted:
- Intel: 91bac169-1be4-4e29-8b75-5c5ef9721dda
- Apple silicon: 9a2c544c-2f65-4c1c-b2fe-20a3af5df726

Activated /home/ubuntu/findez-desktop-signed-20261111/frontend through
/etc/systemd/system/findez-web.service.d/zzzzzzzzzz-desktop-signed.conf.
All unrelated source files were byte-compared with the prior active release.
To roll back, remove only this override, reload systemd and restart findez-web.
The prior desktop installers remain available at their versioned paths.

Final SHA-256 (after stapling):

```text
5e9ba0d9973ae3c5e366610199285318cfa9c087690ec2b7f80404c9a15c2f18  FindEZ-0.1.2-mac-arm64.dmg
7484548f9525ffc4b354e12f8f21c7d77a7e07eef2035831839ccf07f4061aff  FindEZ-0.1.2-mac-x64.dmg
c0a490f106db5e433c1436b9b15ffa04818c65e8b0241136d1a20e090f2f1e0a  FindEZ-0.1.2-win-x64.exe
```
