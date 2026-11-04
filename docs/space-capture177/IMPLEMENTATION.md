# Space capture, galleries and clean scanning — build177

The November3 screenshots supersede the scan texture and header behavior in175/176. The photo scan stage now has a smooth gradient around the original photo and a plain white sweep; no risograph texture follows the line. Extraction, review selection, confirmation and saving remain on the existing path.

Space navigation/counts/status pills collapse together, leaving search and sort under the status area. The full-width blur dissolves into scrolling content using the existing ScrollGlass treatment. It no longer leaves an empty navigation band or hard rectangular edge.

Right-swipe Edit and tapping an item open the same inline-editable SpaceQuickView. The sheet loads the existing item-photo collection, offers multiple library selection or camera capture, and pages through photos. Tapping opens the full, uncropped image with swipe paging and zoom. Existing API permissions/context assertions remain; partial upload failures retain completed photos and show an error. Camera selection remains one photo per capture, and additional photos can be added repeatedly.

Inline editors scroll into view, hide the unrelated Move/Ask footer while active, omit character counters and keep Save/Cancel beside the input. The sheet uses the available height above the keyboard without subtracting the safe area twice. Unsaved drafts and pending writes retain dismissal protection.

Space plus offers camera, library, spreadsheet and barcode directly. It skips the redundant photo-source sheet and opens the spreadsheet picker immediately. The Space-chat composer passes its active context and anchor into these actions, so routes open above that chat and cancellation returns to it. Main Ask routing/composer behavior is unchanged.

Latest typography instruction: regular native SF Pro everywhere, including AI Markdown headings. Standard body/form/control text uses16pt; deliberate captions and larger headings/hero values retain their sizes. System scaling and other accessibility preferences remain. This supersedes176’s semibold AI-heading exception. No custom text-font assets are bundled.

## Verification and delivery

Checks and native screenshots are recorded at completion. Fixtures use synthetic data, not customer inventory. Native iOS simulator checks cover Light/Dark/System, collapsing headers, photos, inline edits, keyboard layout, direct capture, scoped Ask, read-only access and large text. Camera/file-picker tests use controlled plugin results; physical camera, VoiceOver and touch acceptance remain unverified.

No backend, web, database or public App Store submission change. Existing self-hosted web delivery remains intact. Private production configuration, signing material and binary receipts stay outside the repository in `projects/findez-space177-private`.
