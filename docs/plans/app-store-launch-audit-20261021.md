# App Store 1.1.0 launch audit

User authorized comprehensive testing and public submission. Candidate build 111
extends build 110 with a scrollable restock count dialog: native iOS exposed an
84px overflow at 320pt width, 2.6 text scale and an open keyboard. Title, form and
actions now scroll together, preserving validation and single submission.

## Completed evidence

| Area | Result |
|---|---|
| Flutter host suite | 788 passed; default production-config test skipped and run separately with real release defines |
| Static analysis | No issues |
| Primary native iOS matrix | 228 unique checks passed; 15 obsolete Flutter menu selectors corrected and covered in a 29-case follow-up, not counted twice |
| Extended native iOS matrix | 161 passed; one host-only package-file test skipped, still included in host suite |
| Backend suite | 1,311 passed plus 10 subtests |
| Web suite against deployed runtime snapshot | 495 passed in 62 suites |
| MCP | 29 tests and standalone bundle test passed; generated tool/Actions contracts checked |
| Disposable PostgreSQL | Migration chain and row-level permissions passed; concurrent catalog writes, permission revocation and duplicate confirmation passed |
| Migration076 | Approved, backed up, rehearsed twice with all 91 tables preserved, applied to production; fail-closed unknown dependency guard retained |
| Live HTTPS authorization/deletion | Disposable identities only; read/write keys, scopes, role revocation, human deletion confirmation, stale previews, foreign denial and cleanup passed |
| Live import/photo/documents | CSV imported once with selected destination; typo photo proposal confirmed once; quantity and primary-photo semantics retained; document upload/edit/link/open/delete and denial passed; QA data cleaned |
| Real app launch | Actual Chat shell loaded using dedicated App Review account on iPhone simulator |
| Store screenshots | Nine numbered iPhone originals from user-supplied `findez-appstore-v9.zip` uploaded and checksum verified; five existing iPad assets preserved; all COMPLETE |

The extended matrix covers documents, onboarding, organization/place creation,
inventory actions, resource permissions, restock, notifications, memory, scan
review, imported item details, profile, invitations and auth session restoration.
Native integration uses synthetic APIs; the separate HTTPS journeys exercise the
actual deployed service and configured model. Neither is presented as the other.

Private raw logs use `/tmp/findez-launch110-*` and `/tmp/findez-launch111-*`.
Server receipts are under `/home/ubuntu/findez-launch110-sql/` and the
`findez-launch076-release-20261021` / `findez-launch076-rehearsal-20261021` folders.
Signed packaging, Apple receipts and screenshot inventory are preserved privately
under `Documents/FindEZ/AppStore/1.1.0-build 111` and `submission-20261021`.

## Physical checks and limits

The user permitted only opening/canceling native controls on the personal account.
Build110 plain plus, compact UIKit root/Attach menus, Apple Photos picker and Files
picker were opened/canceled without selecting media or changing records. Camera
opening failed recoverably in iPhone Mirroring, where Apple documents camera and
microphone unavailability (https://support.apple.com/en-us/120421).

Actual physical capture, microphone recording, background APNs and VoiceOver have
not been passed by this audit. Simulator and mocked notification checks do not
claim physical delivery. No founder-account mutations were made.

## Release boundary

Build 111 must target `lib/main.dart` with production-only defines, contain no
QA review credentials, pass device-platform/signature/privacy checks and Apple
validation, and be the build selected for submission. Preserve the user's uploaded
screenshots. A validated upload alone is not a public submission; record Apple's
review submission acknowledgment separately.

## Build 111 delivery

Runtime `b23670e`, PR169, all five CI gates passed on run39729342206.
Apple validated and acknowledged build 111, delivery
`2e964179-f15c-4c4c-91c5-68f9ce5f3804`. Both archive and export contain 32 verified
iOS device executables; strict signatures, 24 privacy manifests and production-only
configuration passed. The debug review harness/credentials are excluded.
IPA SHA256: `6edb7adf35d76fdb91c1329802414a9f552094c0bf24360b797aafae2d149501`.
Apple processed build 111 as VALID. Final reviewer sign-in, authorized workspace
read, all screenshot checksums and six public/service URLs passed. Submitted at
2026-10-22T05:56:50Z; Apple acknowledged WAITING_FOR_REVIEW for version1.1.0
and build111. Submission ID:`3eef3590-11b3-4d75-85cd-fce87b1bf45d`.
Release remains AFTER_APPROVAL; this receipt does not claim Apple approval or
public availability. Nine v9 iPhone images and five retained iPad images are COMPLETE.
