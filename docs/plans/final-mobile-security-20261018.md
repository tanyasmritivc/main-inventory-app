# Final submission audit — October 18, 2026

Status: security fixes below are deployed. Mobile build93 hides Plans and is uploaded; physical testing then found the legal-browser launch failure. Build94 is being prepared with system-browser fallback and the Flutter UIScene registration correction. Public App Store submission remains held. This is not an unconditional production-readiness signoff: the GPU transport and native acceptance gates below remain open.

## Deployed security fixes

- Approved migrations 059, 060 and 061 are applied. 059 restricts counter/rate-limit RPCs and cross-user membership probes. 060 repairs new personal-inventory sharing, blocks direct membership forgery, fixes roster recursion and shared-photo boundaries, and scopes Space names per inventory. 061 restricts profile billing/deletion/avatar references to the backend while preserving client signup/profile fields.
- Each migration passed a fresh complete production restore in a network-isolated container, repeated application, positive/negative SQL permission tests and unchanged counts/full-row hashes across all 87 public/auth/storage tables. Approval and activation receipts are retained privately on the server. No customer-data rewrite.
- JWT validation now requires issuer, audience, subject, expiry and issued-at claims; only HS256/ES256/RS256 are accepted with the appropriate keys. Replaced python-jose with patched PyJWT. Backend dependencies updated to audited patched versions.
- Avatar signing/deletion validates the exact profile owner's path. Checkout access uses current, exact item/Space permissions, including view/edit and immediate revocation; matching Space names do not grant access.
- Personal document upload reads are bounded to 25 MB and validate extension, declared MIME and image/text/PDF signatures. Active team attachment formats are stored as application/octet-stream. Profile photo reads are bounded to 5 MB. Blank Chat messages return 422 before inference.
- Backend trusts forwarded headers only from the local proxy and observed private ingress address (127.0.0.1 and 192.168.1.60). A live forged-X-Forwarded-For probe was rejected, preserving trusted client identity for rate limits. A loopback-only listener was tested but the public ingress could not reach it; automatic rollback preserved service, and the existing 0.0.0.0:8000 binding remains. Security logs use the resolved peer, preventing client-supplied IP prefixes from overriding it.
- Native Sign in with Apple uses a fresh SHA256 nonce. Account deletion forwards fresh native Apple authorization; the deployed Edge function exchanges/revokes Apple authorization before Auth deletion and preserves data on failure. Matching Apple key was located and verified without printing its contents.
- Both website AASA routes include workspace and general invitation links. API docs/API-key UI and Terms/Privacy fixes from the earlier release audit remain deployed.

## Validation evidence

| Area | Completed evidence | Remaining acceptance |
| --- | --- | --- |
| Backend | 1,093 Python tests + 10 subtests; real signed HS/ES/RS JWT negative cases; pip check; 61 local runtime/test-tool packages with zero OSV findings | An advisory database result is not proof of no vulnerabilities |
| Production deployment | Separate candidate venv; real QA auth/health tests before activation; hash-checked overlays preserving unrelated files; rollback copies; live HTTPS/API/database healthy | GPU configuration deliberately unchanged |
| Permissions/sharing | Real second account: view read/edit denied, editor write/checkout/return, removal/revocation immediately denies inventory/history/photos; direct membership insert denied | Native invitation handoff still needs final-device tap acceptance |
| Profiles/documents | Real client profile upsert works; tier/is_pro/avatar forgery returns 403; spoofed uploads rejected; normal text upload/open/delete passes | Physical picker/permission variants are separate gates |
| Deletion | Disposable email account actually deleted through production Edge; old API token rejected afterward; real account untouched | Fresh native Apple sign-in/revocation round trip requires user interaction; unit/cryptographic checks do not replace it |
| Web | 392 tests in 50 suites in aggregate after restoring unchanged excluded fixture; TypeScript, scoped lint, production candidate build pass; production dependency audit zero | Device Safari-to-app handoff pending |
| Mobile build 92 | 655 tests plus separately enabled production config gate, clean analysis; signed archive/export, 31 device Mach-O files each, 24 privacy manifests, Apple validation and upload acknowledgment | Superseded by build 93 for user-requested Plans hiding; camera/barcode/mic untested by user |
| Physical iPhone build 92 | Install/launch, retained login, QA inventory, review confirmation, tab cycles, Find rows, typed Ask grounded answer, profile/settings, dark/light and larger/default text | Mirroring scroll control required raising its window; resolved during build93 checks |
| Simulator | Login, QA inventory, limited-library photo, FIND extraction/Review persistence, crop/original gallery, edit cancel, project chooser | Simulator is not camera/microphone/push/provider acceptance |
| Apple listing | Version 1.0.8 draft exists; dedicated review account login/workspace read succeeds; contact/credentials present; six iPhone and six iPad screenshots; HTTPS privacy/support URLs present | Draft review notes updated to 1.0.8 with current navigation and hidden Plans; credentials/contact preserved. Privacy labels/age-rating answers and screenshot accuracy need final owner review |

## Owner GPU/security work before public launch

The app-to-API and API-to-auth/storage public endpoints use HTTPS. The remaining unencrypted hop is the API-to-FIND GPU processing endpoint: photos/job data and any bearer credential on that HTTP connection can be observed or altered in transit. This audit preserves it under the earlier instruction not to change GPU configuration. App Store acceptance does not remove that exposure. Treat this as a public-launch blocker.

0. Restrict the API origin port 8000 at the network/firewall to the actual ingress proxy. Local nginx points to loopback, but the active public ingress did not reach a loopback-only listener during rehearsal. Confirm that routing before changing the bind address; keep public access through HTTPS. The deployed forwarded-header trust allows only local nginx and the observed private ingress proxy, excluding arbitrary remote peers.
1. Put the FIND service behind a valid-certificate HTTPS reverse proxy or a private authenticated encrypted tunnel; restrict the inference listener to the proxy/private network and the authorized API host. Keep authentication on submit/status/result/image endpoints.
2. Change the backend FIND base URL to that protected endpoint and turn off the insecure-HTTP override. Verify certificate/hostname validation and prohibit HTTP fallback. Rotate any inference credential previously sent over public HTTP after the protected path is in place.
3. Run an actual nonsensitive camera/library scan through submit, polling, result, crop/original download, Review and save. Test timeouts, rejected credentials, oversized images, concurrent jobs, cancellation, cleanup and capacity. Monitor GPU memory/queue latency/error rate, disk/job retention, and recovery after process restart. Set bounded retention and avoid customer image/token logging.
4. Review classification quality with a representative labeled set: the sample scan misidentified one visible wire as an XT60 connector. Preserve uncertainty/Review rather than claiming perfect recognition; masks/training-quality correction persistence remains separate unfinished GPU/model work.

## Native acceptance still required

On the final installed build: camera capture/cancel/denied permission; barcode recognition; Ask microphone input; Google and Apple login; Apple-account deletion with a disposable provider account; background notification and cold tap; fresh password-recovery link; Photos share-extension handoff and warm/cold universal links; offline/interrupted upload recovery; VoiceOver. No missing result is counted as a pass. Camera, barcode and microphone were explicitly requested from the user, who said they had not tested yet.

Build 92 upload receipt: ee3eaf5b-c3ab-44df-86e1-dbbb296e69b2. Processing and tester availability were not polled, per standing instruction. Artifact directory: Documents/FindEZ/AppStore/1.0.8-build92. Build93 Apple acknowledgment: e0c6dcdc-fef2-4311-95ae-69c3c5645c18, IPA SHA256 f36ffed392dbeaa10ca860b540b038d1644f538e409faf67c6ecc75d19be5360. Physical install/retained login/QA home/Plans hidden pass. Build94 will supersede93 after fixing the legal-browser failure.

## Apple review notes — updated in the unsubmitted 1.0.8 draft

The dedicated review account contains sample inventory only. Use Sign-In Information credentials. Choose Personal, then the sample inventory. Home shows summaries; Capture supports photo extraction and barcode scanning; Ask supports text and photos; Find opens Spaces and inventory items. The account control opens profile, settings, documents/notes, notifications and lent items.

Version 1.0.8 includes organization/workspace/inventory navigation, recipient-confirmed sharing, private photos and crop/original galleries, uncertain-result Review, grounded Chat and explicit confirmation before proposed item changes. Opening an invitation does not grant membership; the recipient must choose Join and current permissions apply.

Plans and paid-plan promotion are hidden in this build. No subscription purchase or payment checkout is enabled. Account deletion is available in Account → Settings → Account Settings. Apple users confirm Apple authorization before deletion so it can be revoked.

## Sources and private receipts

Apple current review requirements: https://developer.apple.com/app-store/review/guidelines/ and https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion. Approval remains Apple's decision.

Server receipts: `/home/ubuntu/findez-final-security-20261018`, `findez-final-sharing-20261018`, `findez-final-profile-20261018`, `findez-final-runtime-20261018`, `findez-backend-security-20261018`. Local sanitized test outcomes and private sessions are under `/private/tmp/findez-final-audit` (not committed). QA writes were confined to the explicitly created Release QA inventory and disposable account; Workshop was untouched. QA inventory retained for final hardware checks; test shares revoked and disposable second account deleted.

CI: all five jobs passed on API run39185570323 and web run39185606600. PRs127 (API),128 (web),129 (mobile). Proxy hardening receipt includes the passed real forged-IP check in `proxy/ingress.json`; loopback-only binding remains a documented infrastructure task.
