# Mobile App Store audit — October 25, 2026

Scope: existing mobile release 1.1.1(142), public-review submission authorized by the user, manual release retained. Safari is the browser for manual review.

## Verified fixes
- Structured/malformed API errors cannot crash the shared message formatter. Server/internal/transport errors stay behind friendly messages; explicit validation and session-expiry messages remain useful.
- Checkout load failures show a Retry state instead of falsely claiming no checked-out items.
- Legal fallback and board error states scroll at large text sizes. Shared-inventory role labels move into More on narrow/large-text layouts, preserving access to permission information.
- No navigation redesign. Build incremented to 143.

## Executed verification
- Final full Flutter host suite: 1,156 passed, one existing skip; no failures. Log /private/tmp/findez-store-host-verified.log.
- Flutter analyze: no issues (/private/tmp/findez-store-analysis-verified.log).
- Primary native audit: initial 165 passed, four native-dialog selector failures; three affected groups retested after test-only Flutter presentation override: 79 passed. Production UIKit unchanged.
- Extended native workflows: 168 passed, one existing host-only skip.
- New 35-page matrix: both themes, phone/tablet/320px text-scale 2.6: 210 cases passed. Native wrapper reports 212 including setup/teardown. 140 native Flutter render-tree captures reviewed; fixtures intentionally cover empty and unavailable states, not every possible user state. Captures at /private/tmp/findez-store-native-visual. Earlier platform screenshots captured the runner splash and were rejected; corrected captures use the actual rendered boundary.
- Error/capture/checkout/legal regressions included in the final suite. Test matrix explicitly loads bundled product fonts rather than Ahem metrics.
- Separate backend lane: migration085 rehearsed twice against a disposable production-schema clone and applied after verified backup, preserving grants. Live disposable-account tests passed default-on memory/opt-out, GLM draft quantity edit without early save, save retry with one item, canonical quantity mutation idempotency, inventory deletion, and account/behavioral-data deletion.
- Separate web lane: updated privacy notice deployed from 92a9d66; 26 route checks, five CI gates. Apple privacy disclosures updated to reflect account-linked personalization and feedback/usage analytics; no tracking.

## Build 143 delivery and review status
Apple validated and processed 1.1.1 (143), source b09509632fc575f93d43bb705d07473ef3ef358a, delivery 4aeeb1d5-57b2-4fd5-a5bf-cc940643302c. All five exact-source CI gates passed. Both archive and export passed 34 device executable checks; strict signature, 26 privacy manifests, and production configuration were verified. All 24 screenshot checksums match the supplied v5 package. Review notes and privacy disclosures are staged; version remains PREPARE_FOR_SUBMISSION with MANUAL release, not publicly submitted.

The user reported physical camera/library/voice denial, Apple/Google sign-in, VoiceOver, logout/relogin, and foreground/background/closed notification taps passed on their latest TestFlight build. This is user-reported acceptance, not an automated device result. The subsequent physical screenshots revealed an extraction keyboard/layout defect; submission remains on hold while that fix is delivered.

## October 26 extraction keyboard follow-up (build 144 candidate)
- Start extraction in focused chat so the organization header and bottom navigation do not compete with the conversation controls.
- Keep the composer outside the bounded preview region. Preview content scrolls independently; its header/close control stays visible. One understated preview surface replaces nested cards and repeated titles/destination buttons.
- Offer Hide keyboard while focused, preserve typed text on dismissal, and use one scrolling input line while the keyboard is visible. Retain multiline input and expanded display when dismissed.
- Show one actual scan status; remove the competing progress bar/send spinner. Stop cancels the pending stream without clearing the typed prompt.
- Restore existing response controls in the world-chat viewport. Failed photo-only retry retains bytes and request identity; successful regeneration uses the saved response reference without duplicating its prompt.
- Full mobile suite: 1,167 passed, one existing skip. Native iOS: 11 focused photo retry/scan/keyboard cases passed, including 320/390 widths, both themes, and text scale 1/2.6. Eight render-tree screenshots preserved at /private/tmp/findez-extraction-native-visual. Native fixture safe areas are explicitly set so synthetic DPR1 does not incorrectly inherit device-pixel insets. These captures exclude platform keyboard/UIKit overlays; geometry/hit testing verifies Flutter controls above the keyboard inset.
- Current follow-up is mobile only. No server runtime/configuration or production database changes were made for it. Candidate build upload and final analysis receipt will be recorded after packaging. Do not publicly submit until the user resumes the held submission.
