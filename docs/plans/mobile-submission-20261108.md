# Mobile submission preparation - November 8, 2026

Baseline: delivered TestFlight 1.1.2 (212), runtime `27679f39`.
Candidate: 1.1.2 (213), branch `audit/mobile-submission213`.

## Scope

Audit mobile workflows and native presentation, verify the production package,
and prepare the next App Store version. The user additionally requested removal
of Search options from the Add to chat popup. Its native menu and short submenus
now omit search; all eleven action IDs, dismissal-before-dispatch and restricted
Space attachments remain. Chat history search and actual content pickers retain
their search. Scan requests, main chat, the white photo sweep, rotating tips,
current scan functions are preserved. The follow-up gives native loading blocks a
muted rose gradient in both themes and changes only the light native scan panel
from white to soft #EEF0F3. Its dark panel, white photo sweep, actual progress,
Stop, tips, reduced-motion and lifecycle behavior remain unchanged.

No public review submission or release is authorized by this preparation task.
Use synthetic fixtures for mutation tests and read-only customer navigation.

## Repeatable checks

From `mobile/`, use the commands in `mobile-launch-audit-20261108.md` for the full
host suite, analyzer, primary/extended native workflows, native scan and Space
layouts. Additionally run these sequentially on an isolated iOS simulator:

```sh
flutter drive --driver=test_driver/store_screen_audit.dart --target=integration_test/store_screen_audit_test.dart -d IOS_DEVICE --no-pub
flutter test integration_test/onboarding_v5_test.dart -d IOS_DEVICE --no-pub
flutter test integration_test/chat_attachment_menu_test.dart -d IOS_DEVICE --no-pub
flutter test integration_test/welcome_sequence_test.dart -d IOS_DEVICE --no-pub
```

The screen matrix covers 35 existing pages in both themes at phone, iPad and
320pt/2.6x text sizes. Its historical onboarding fixture is complemented by the
current onboarding-v5 suite. Flutter render-tree captures exclude UIKit controls
and system keyboards; inspect native source-menu captures separately. Initial
new-note captures were blank during native keyboard presentation and are not
accepted as visual evidence. The synthetic viewport now converts native keyboard
pixels to logical points. Replay those six cases with
`--dart-define=STORE_SCREEN_FILTER=new-note` on the screen-matrix command. The
separate Documents suite verifies note editing, Save, failed writes and Back.

Private logs, screenshots and credentials are kept outside the repository at
`projects/findez-submission213-private`. Credentials must never enter this plan.

## Submission preparation

Initial App Store inspection found public version 1.1.1 / build166 and no draft
for 1.1.2. A nonpublic 1.1.2 draft is now PREPARE_FOR_SUBMISSION with MANUAL release.
Corrected review instructions describe current Ask/Spaces/Add navigation and
FindEZ transcription; dedicated review credentials were retained. Release notes
are staged. Source copies: `mobile213-review-notes.txt`, `mobile213-whats-new.txt`.
Existing screenshots and pricing are preserved. The listing's old navigation
screenshots need refreshing before submission; they were not silently replaced.

Dedicated review sign-in, authenticated inventory directory, backend/database
health, support, privacy, terms and associated-domain document returned HTTP200.
No inventory writes were made. An HTTP200 alone does not prove each provider or
deep-link action works on a physical device.

Apple's preparation requirements used for this audit:
[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/),
[complete review information](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/),
and [account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/).
These require working review access and accurate listing/privacy information;
passing automation does not guarantee approval.

## Evidence status

- Screen matrix: 210 cases passed; native runner also reports setup/teardown.
- Physical iPhone 13 Pro, installed build212: Ask-to-Spaces navigation, live Space
  contents, item sheet and imported-detail scrolling inspected. Mirroring then
  disconnected when the phone became active. This is baseline smoke evidence,
  not final build213 acceptance.
- Full host suite: 1,368 passed, one existing skip; analysis clean. The two changed
  fixtures additionally passed 219 host cases.
- Primary native workflow suite: 177 passed. Extended: 171 passed, one host-only
  skip. Source menu, welcome sequence, eight scan cases and four Space-chat cases
  passed. Native rose shimmer and softer light panel screenshots were inspected.
- Onboarding initially failed three native cases because synthetic DPR inflated
  keyboard insets. Fixture conversion and settling corrected this; all nine native
  cases passed on replay. No runtime signup behavior was changed.
- Six focused new-note native layout cases passed after the fixture correction;
  phone light and iPad dark captures now show the editor and Save control and were
  visually inspected. System keyboard pixels are excluded from render-tree PNGs.
- Build213 was uploaded and acknowledged by Apple, delivery
  `002b26d4-0960-4db9-9a8c-14b89e68818b`. Runtime `bfd5e112`, five CI jobs passed
  (42554623319). Production configuration, strict signatures, 33 device binaries
  each in archive/export and 27 privacy manifests verified; Apple validation passed.
  Processing and tester availability were not polled. Initial failures and replay
  logs are retained privately; failed runs are not counted as passes.
- Physical camera, microphone, Google/Apple authorization, APNs, VoiceOver and
  lock-screen scan/chat continuation must be distinguished from synthetic tests.

## Final submission gate

Before public submission, select the final processed candidate, confirm final
TestFlight acceptance on the designated device, review the current listing and
privacy answers, and obtain explicit authorization to submit. Keep manual release.
