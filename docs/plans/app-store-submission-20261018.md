# App Store submission: 1.0.8 (95)

The user explicitly requested answering Apple's submission questions, using
`findez-appstore-screenshots-2.zip`, and submitting to Apple. This supersedes the
earlier hold on public App Review submission, without authorizing automatic release.

Apple accepted submission `6750f743-3f1c-4fe7-afd2-f45950394c98` at
2026-10-19 02:43:27.786 UTC (October 18, 7:43 PM Pacific). Both the version and
submission are `WAITING_FOR_REVIEW`. Safari independently displays iOS 1.0.8 as
Waiting for Review. The selected build is 95, delivery
`375271f5-080e-429c-9054-8b42518280df`, source `ca5c195`. Release type remains
`MANUAL`; approval will not automatically publish it.

## October 19 reconciliation after interruption

The user superseded the first iPad ZIP with findez-ipad-screenshots-2.zip. Seven
2064x2752 RGB PNGs were verified and uploaded, in order, with matching checksums
and Apple Complete state. The previous six iPad assets were backed up. Original
submission 6750f743-3f1c-4fe7-afd2-f45950394c98 was withdrawn to unlock metadata;
replacement 8e8db653-097f-4da8-b5f9-e3853519ce85 reached READY_FOR_REVIEW before
the turn was interrupted. At that point the iPhone set and other metadata matched.

When work resumed October19, a preservation guard rejected resubmission because
the iPhone assets had changed outside this operation. No overwrite or submission
mutation followed. Fresh Apple reads show version1.0.8/build95 is READY_FOR_SALE,
all observed review submissions are COMPLETE, and a later submission
cf2b12c3-7243-492e-b7e7-e2d5f57573b6 exists. The released iPad set contains five
images and does not match this seven-file ZIP. Those later changes were not made
by this operation and were preserved. Do not claim that the seven promotional
iPad images are the currently released set. This observation supersedes the
historical Waiting for Review state below.

Private receipts: submission-20261018/ipad-update-v2, including the supplied
manifest, original-asset backups, completed-upload receipt, queued review and
current-release-observation.json. No binary was rebuilt for screenshots.

## Submitted information

- All seven supplied iPhone PNGs, in numerical order, uploaded without edits.
  Each is 1320 x 2868, RGB without transparency. Apple marked all seven Complete;
  source checksums and ordering match. The prior iPhone assets were backed up.
  The existing six native iPad screenshots remain unchanged. The supplied iPhone
  assets are promotional compositions and were not described as new native captures.
- Saved 808-character public release notes and 3,426-character review notes covering
  onboarding, organization boundaries, capture/Review, original/crop galleries,
  Chat proposals and confirmation, invitations, private photos, account deletion,
  optional permissions, and the absence of payment checkout in build 95.
- Answered the four previously raised AI questions: third-party-developed models
  with inference operated for FindEZ, no embedded inference weights, optional
  Apple Speech processing, and separate opt-in external assistant integrations.
  No assertion that every internal network hop is encrypted was made.
- Preserved the existing dedicated sample reviewer credentials and review contacts.
  Verified the sample account can sign in and read its authorized workspace.
  No customer inventory or membership changes were made for QA.
- Published privacy declarations for the existing eight data types plus Device ID,
  Search History, Other Diagnostic Data and Environment Scanning. The four additions
  are used for app functionality, linked to identity, and not used for tracking.
  Safari confirms all twelve types with no unfinished setup prompts.
- Set the age-rating override to 13+ to match existing account eligibility and Terms.
  Applied Apple's definition of direct user-to-user messaging: Ask is AI-only and
  collaboration has structured tasks/files, without a user messaging channel.
  Messaging, broad public UGC distribution and social media are false. Existing
  other content descriptors are preserved. Build 95 declares no non-exempt encryption.
- Preserved app price, subscription/payment configuration, content-rights declaration,
  public availability and existing ratings. No agreement, banking or tax changes.

Private screenshots, hashes, full answers, before/after metadata, credential-free
login result, asset upload receipts and final submission receipt are retained in
`Documents/FindEZ/AppStore/submission-20261018`. API keys, reviewer credentials and
private contact fields are excluded from this repository receipt.

## Verification and remaining release work

The exact already-uploaded build was selected; no source or binary changed.
Completed build-95 validation and CI are reused. This documentation-only receipt
does not require another binary or repeat of completed regressions.

Review is pending, not approved or publicly released. The infrastructure findings
and outstanding physical acceptance in `final-mobile-delivery-20261018.md` remain
open, including the API-to-FIND transport/origin work. Submission is not an
unconditional production-readiness or security signoff. Preserve manual release
while those release decisions remain outstanding.
