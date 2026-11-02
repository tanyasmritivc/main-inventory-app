# Inline voice composer — implementation

Branch: `feat/voice-in-composer`, based on build163 source and its delivery receipt. Initially completed locally. The user subsequently authorized pushing and uploading TestFlight build164; see the release receipt for delivery status. Physical iPhone microphone acceptance is left to the user, as requested.

## Behavior

The Ask composer grows in place, dims the headline/suggestions and displays real microphone levels and elapsed time. A speech pause of about 1.2 seconds ends recording. The existing batch Whisper request completes before the transcript appears and a full two-second auto-send countdown begins. Send can finish recording early; tapping the transcript cancels automatic sending and opens editing. Cancel preserves the original typed draft. Silent/empty recordings send nothing; denied access shows the requested inline Settings instruction. Backgrounding, hidden tabs, new chats and changed API/account contexts cancel pending work. Existing normal chat, source selection and explicit inventory review/save remain in use.

Light/dark colors, 136→178pt growth, the specified animation curve, Inter voice text, mono timer and a filling send ring follow the reference. Large text grows the panel and scrolls the transcript; Reduce Motion removes growth/blur. The duration label is local chat presentation and is not persisted in historical server messages under the unchanged API contract. No partial words are fabricated for the batch-only provider.

## Validation

- Full Flutter suite: 1,249 passed, one pre-existing skip.
- Two added tab/API cancellation checks passed after the full run.
- Final focused voice/chat checks: 18 passed after native-review alignment adjustments.
- Final `flutter analyze --no-pub`: no issues.
- Native iOS simulator: eight flow/layout checks passed, followed by four final layout checks after increasing the large-text editor height. Twelve final screenshots retained and reviewed across both themes.
- Physical microphone, noise threshold, permission prompt and real voice acceptance: user to check.

The native audit uses synthetic recorder data. Its snapshots render real Flutter UI with the bundled fonts, including a 320pt accessibility viewport and a normalized 300pt keyboard inset. QA screenshots are in `qa/`; they are development evidence, not App Store screenshots.

The TestFlight164 release updates voice privacy wording to distinguish build163's explicit Send flow from build164's countdown. Physical-device acceptance remains with the user.

## Changed files

Production mobile:
- `mobile/lib/features/chat/voice_composer_session.dart` — inline recording/edit/countdown state.
- `mobile/lib/features/chat/voice_composer_panel.dart` — status, waveform, timer, editor and send ring.
- `mobile/lib/features/chat/voice_capture.dart` — reusable meter interface and structured failure state over existing transport.
- `mobile/lib/features/chat/chat_page.dart` — composer integration, context cancellation and message duration.
- `mobile/lib/features/chat/ask_answer_view.dart` — voice label on user messages.
- `mobile/lib/features/world/world_composer.dart` — animated inline surface and permission feedback.
- `mobile/lib/features/chat/voice_recording_overlay.dart` — removed unused dialog.
- `mobile/pubspec.yaml` — scoped voice Inter font and license.

Verification:
- `mobile/test/voice_composer_test.dart`
- `mobile/test/ask_page_test.dart`
- `mobile/test/fluid_surfaces_test.dart`
- `mobile/test/flutter_test_config.dart`
- `mobile/integration_test/voice_composer_audit_test.dart`

Documentation:
- `docs/voice-v1/` — supplied brief, HTML, image, walkthrough, this receipt and native QA captures.
- `TESTING.md`
- `.agents/ACTIVE_WORK.md`, `.agents/CURRENT_STATE.md`, `.agents/DECISIONS.md`
