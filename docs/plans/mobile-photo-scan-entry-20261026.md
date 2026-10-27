# Mobile photo Scan entry and onboarding

Scope: mobile only, branch `feat/mobile-scan-entry-onboarding`, candidate 1.1.1 (150).

Personal or Team comes before existing Apple/Google/email authentication. Personal opens Ask. Team creates an organization using durable existing organization/workspace/inventory provisioning, then a single-choice referral question before entering its organization. Older retained setup drafts still recover through the existing gate. The plans introduction follows setup.

Ask has a monochrome Scan pill beside the mic and a bundled first-scan invitation with corner brackets and a slow sweep. The preview does not request camera access. Scan opens Take Photo with Photo Library as the other mode. Photos use the existing extraction API, editable review, explicitly confirmed save and receipt-specific Undo. The first invitation is dismissed after a confirmed save; saved-name suggestions are account/world-scoped and expire after three uses. Typing shows Send. Plus-menu Auto Extract remains first; camera/library attachments start extraction while retaining typed text. Spaces have scoped Scan access.

The user explicitly removed live Scan Frames and Auto-add after the live provider benchmark. There is no periodic camera capture, frame-quality detector or automatic item saving. The existing photo extraction provider, API, schema and web app are unchanged. A crowded sample photo took 62.5 seconds, returned partial detections after provider failures, and required review. This is not instant tracking.

## Verification

- Complete mobile regression suite: 1,209 passed, one existing skip.
- Final photo-only focused suite: 20 passed, including separate unknown/non-Latin detections.
- iOS simulator: 23 checks passed, including onboarding, save/retry/Undo, denial, cancellation, light/dark and 2.6x text. Camera and API responses in these flow tests are fixtures.
- No customer inventory was created or changed by these tests. Live model benchmark used a bundled sample and disabled storage/inventory writes.
- Final analysis, exact-source CI, signed device archive/export verification and Apple validation/upload are recorded with the delivery receipt.

Physical iPhone acceptance remains required for camera permissions and real capture, photo-library cancellation, OAuth, VoiceOver and background/resume behavior. Simulator testing cannot establish real camera performance or production recognition accuracy. Public App Store submission remains held.
