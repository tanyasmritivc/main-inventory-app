# Sample onboarding v2

Branch: `feat/onboarding-sample-scan`. The user subsequently authorized TestFlight
upload; preparing 1.1.1 (138). No public App Store submission. Mobile only; no backend, web, schema, environment or deployment changes.

## Behavior

- Bundled workbench photo and seven detections demonstrate scanning without a
  network request, camera permission, account or anonymous session. The sample is
  clearly labelled. Detection boxes and model answers come from bundled JSON.
- Native Flutter renders the flow; only the supplied Petals 3D scene uses WebView.
  Scan, staggered rows, editable counts, local questions, found state and Keep
  follow the reference. Keep appears 2.2 seconds after the first matched answer.
  Ask another question resumes the list and does not re-open signup automatically.
- Type/Describe stay local, persist across restarts, and use the existing stable
  request IDs and save receipts after auth. Existing signed-in users skip the trial.
- Sample signup never saves demo items or creates a sample Space. It lands on Ask
  and shows an account-scoped orange camera cue. First camera tap consumes the cue,
  even if capture is cancelled; retrying onboarding cannot re-arm it.
- Apple (iOS), Google and email reuse existing auth. Removed the obsolete trial
  camera page, anonymous identity linking and post-login preview re-extraction.
- Reduce Motion honors both Flutter disableAnimations and native iOS reduceMotion,
  including changes while mounted. The scene, scan, Pip and pulses stay still.

## Deliberate changes from the supplied reference

The user requested less copy and broader relevance. The sample is called “A
workbench”; the supplied photo and truthful detections remain unchanged. Describe
shows Home, Dorm room, Kitchen, Workshop, Lab and Closet in a compact wrap. Student
and dorm keywords have their own template, and workshop/lab examples are broader.
The Type example uses phone chargers, notebooks and spare keys. Responses use
“Found 7 items. Tap a number to edit.” and “Now ask where something is.” Box labels
show short object names without confidence percentages; crowded top labels are
separated. Existing Pip assets and fonts are reused.

## Files

- `mobile/lib/features/onboarding/`: updated page, draft, gate and saver; new
  `sample_scan.dart`; removed obsolete `chat_onboarding_camera.dart`.
- `mobile/assets/onboarding/`: Petals scene, sample JPG/JSON, broader templates.
- `mobile/lib/core/first_camera_hint.dart`, `features/chat/chat_page.dart`,
  `features/world/world_composer.dart`: one-time real-camera handoff.
- `mobile/lib/features/auth/auth_page.dart`: sample copy, shared Google mark,
  removal of onboarding-only anonymous linking.
- Host and iOS integration onboarding tests; reference artifacts and context docs.

## Verification

- `flutter analyze`: no issues.
- Final focused host suite: 26 tests passed, including native Reduce Motion changes,
  offline sample flow, model/location/count answers, one-time Keep, auth handoff,
  zero sample API writes, save retries, account isolation, camera cue cancellation,
  Home/Dorm/Lab matching and 320/390/1024-width layouts.
- Broader suite earlier in this task: 914 tests passed, one optional visual skipped;
  the final accessibility/copy changes were covered by the focused suite.
- Manual iPhone 17 Pro / iOS 26.5 preview: intro and Petals scene, sample scan,
  answers, Keep, Ask another question, Google logo and six wrapped space choices.
  iOS Reduce Motion was enabled, verified with a still scene and instant scan,
  then restored to its original off setting.
- Final iOS integration suite: all 26 cases passed on iPhone 17 Pro / iOS 26.5,
  including all three paths, auth/save handoffs, reduced motion and layouts.

Production OAuth, physical-device camera capture and real-account saving were
not exercised. Auth/save handoffs use test transport and identities; no customer
data was changed. Offline behavior is verified through bundled assets and zero
transport calls, without disabling the Mac's network. The existing WebGL fallback
keeps the UI working if the decorative scene cannot load.
