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

## Release checks still pending
Signed archive/export and Apple validation/upload; exact-source CI; App Review metadata and selected build; final submission receipt. Physical camera/library/voice permission denial, APNs background/terminated delivery, third-party sign-in, and physical VoiceOver acceptance are not established by simulator tests. TESTING.md requires physical acceptance before public submission. Do not claim those checks passed or that Apple approval is guaranteed.
