# Space capture, galleries and clean scanning — build177

The November3 screenshots supersede the scan texture and header behavior in175/176. The photo scan stage now has a smooth gradient around the original photo and a plain white sweep; no risograph texture follows the line. Extraction, review selection, confirmation and saving remain on the existing path.

Space navigation/counts/status pills collapse together, leaving search and sort under the status area. The full-width blur dissolves into scrolling content using the existing ScrollGlass treatment. It no longer leaves an empty navigation band or hard rectangular edge.

Right-swipe Edit and tapping an item open the same inline-editable SpaceQuickView. The sheet loads the existing item-photo collection, offers multiple library selection or camera capture, and pages through photos. Tapping opens the full, uncropped image with swipe paging and zoom. Existing API permissions/context assertions remain; partial upload failures retain completed photos and show an error. Camera selection remains one photo per capture, and additional photos can be added repeatedly.

Inline editors scroll into view, hide the unrelated Move/Ask footer while active, omit character counters and keep Save/Cancel beside the input. The sheet uses the available height above the keyboard without subtracting the safe area twice. Unsaved drafts and pending writes retain dismissal protection.

Space plus offers camera, library, spreadsheet and barcode directly. It skips the redundant photo-source sheet and opens the spreadsheet picker immediately. The Space-chat composer passes its active context and anchor into these actions, so routes open above that chat and cancellation returns to it. Main Ask routing/composer behavior is unchanged.

Latest typography instruction: regular native SF Pro everywhere, including AI Markdown headings. Standard body/form/control text uses16pt; deliberate captions and larger headings/hero values retain their sizes. System scaling and other accessibility preferences remain. This supersedes176’s semibold AI-heading exception. No custom text-font assets are bundled.

## Verification and delivery

1,364 Flutter tests passed (one existing skip), analyzer clean. 58 native iOS checks passed: 32 Space cases, 12 typography/chat cases, 8 scan-card cases, 2 dynamic keyboard cases and 4 final header/large-text cases. Twelve native verification screenshots are retained in verification/. The final search height now grows with system text scaling; its full text line is asserted in tests. Threshold saving was also exercised with the native notification permission denied. Fixtures use synthetic data, not customer inventory. Native iOS simulator checks cover Light/Dark/System, collapsing headers, photos, inline edits, keyboard layout, direct capture, scoped Ask, read-only access and large text. Camera/file-picker tests use controlled plugin results; physical camera, VoiceOver and touch acceptance remain unverified.

No backend, web, database or public App Store submission change. Existing self-hosted web delivery remains intact. Private production configuration, signing material and binary receipts stay outside the repository in `projects/findez-space177-private`.

Apple acknowledged TestFlight 1.1.2(177), delivery 22a7a085-2082-4627-9dfa-66e16d7eef66. Processing/tester availability pending and unpolled. All five exact-source CI gates passed (run 41782391061). Signed archive/export passed device-platform, strict-signature, privacy, production-configuration and font-packaging checks; Apple validation passed. Source 9a2d6c65b494de78aedbde01bcc57393d49d6980. See testflight177-receipt.json.
