# Chat-first Flutter onboarding

Historical v1 implementation. Superseded locally by [sample onboarding v2](../onboarding-v2/IMPLEMENTATION.md); v2 has not been pushed or released.

Local branch: `feat/chat-onboarding`. Not pushed or released.

The native first-run flow now offers Snap, Type and Describe before signup. Type
and Describe parse/generate a local list and answer local questions offline. The
Keep sheet follows the first matched answer after 1.9 seconds. Existing permanent
sessions bypass the trial. The supplied HTML prototype is reference-only; only
its standalone 3D scene is loaded in a transparent WebView behind Flutter UI.

## Data and auth

- Versioned SharedPreferences draft retains items, explicit quantity edits, spots,
  photo path, selected auth method and save receipts across restarts.
- Apple and Google use the existing native provider flows. The installed Supabase
  SDK supports `linkIdentityWithIdToken`, used for anonymous provider conversion.
  Known linking conflicts/disabled linking fall back to ordinary provider login.
  Email uses existing signup, verification, recovery and sign-in logic.
- Anonymous signin is attempted only when taking a photo. If disabled or rejected,
  keep the photo, explain that an account is needed, and resume after auth. No
  Supabase configuration was changed; production anonymous enablement is unverified.
- A photo extracted under a different account is re-extracted after normal signin
  rather than transferring account-bound preview credentials. Unique matching
  items retain explicit quantity edits. Already-answered trials resume saving.
- Save uses the current Personal-inventory and Confirm Items bulk APIs, stable
  per-draft item request IDs and full receipt validation. Partial/lost responses
  retain the draft for safe retry. Claimed drafts cannot be replayed by another
  account. Clear only after saved-Space context reaches Ask; show the save toast.
- The current repository has persistent Spaces, contrary to the prompt's stale
  schema description. Use its existing get-or-create Space API and item location;
  no backend/schema change. No supported sub-location field exists on the item
  save model, so spots remain local rather than inventing a field.

## Visual behavior and limits

- Exact supplied templates, intro/options and chat/Keep copy; Flutter item rows,
  inline quantity controls, local chips and answers. Existing mascot and fonts.
- Camera brackets, orange shutter and flash; existing extraction/image processing
  endpoint. Unknown counts remain unknown. The extraction model exposes no
  detection boxes, so the photo bubble does not fabricate boxes.
- WebView is local, transparent, zoom-disabled and navigation-blocked after its
  initial document load. Props queue until World.ready. Errors/timeouts hide it
  without stopping the trial. No whole-prototype embedding.
- Reduce Motion freezes the supplied scene (including its idle motion), disables
  shimmer/pulse/row transitions and keeps the complete flow usable. Native view
  replacement supports accessibility changes while mounted.
- The supplied shelf has 12 blocks. Longer typed lists retain every item; the
  decorative shelf displays up to 12. No data is silently truncated.
- Legacy Option A widgets remain for existing replay/prepared-draft callers and
  compatibility tests; first-run no longer asks for structure names.

## Files

- `lib/features/onboarding/chat_onboarding_{page,draft,world,camera,save,gate}.dart`
- `assets/onboarding/{onboarding_world.html,templates.json}`
- `lib/main.dart`, `lib/features/auth/auth_page.dart`
- `lib/features/chat/chat_page.dart`, `lib/features/world/world_shell.dart`,
  `lib/features/workspaces/inventory_context_host.dart` (saved-Space handoff)
- `pubspec.yaml`, `pubspec.lock`, `ios/Podfile.lock` (camera and WebView)
- `test/chat_onboarding_test.dart`, `integration_test/chat_onboarding_test.dart`,
  existing launch/legacy-auth expectations, `tool/chat_onboarding_visual.dart`
- This document, supplied reference HTML and `.agents` project-state notes.

Paths above are relative to `mobile/` unless explicitly stated otherwise.

## Validation

- `flutter analyze --no-pub`: no issues.
- Final focused host suite: 44 passed (onboarding, launch, auth and legacy replay).
- iOS simulator integration suite: all 17 passed, including local paths, photo
  success/401/offline/cancellation, auth-to-save-to-Ask, ownership, lost/partial
  save receipts and explicit edits across photo re-extraction.
- Broad host suite: 901 passed, one optional skip, one old headline expectation
  failed. Corrected that expectation; its entire 14-case file passed in the final
  focused run. The subsequently added photo regression passed there as well.
- `git diff --check`: clean. Existing empty PlaceGeist/PlaceGeistMono font warnings
  and SVG metadata warning predate this change; no analyzer warnings introduced.

Native integration uses
synthetic auth/extraction/API peers, not production accounts. Manual iPhone 17 Pro
(iOS 26.5) checks inspected intro, 3D shelf, list editing, local answers and Keep.
All three reference paths were inspected in Chrome at 390×844. Reduce Motion was
verified in iOS Settings and the scene remained still. Simulator camera opens the
custom frame and shows a readable unavailable-camera fallback.

Live camera capture, production extraction accuracy, real Apple/Google consent,
anonymous account linking and physical-device acceptance require device testing;
no production accounts, data or settings were changed during these checks.
