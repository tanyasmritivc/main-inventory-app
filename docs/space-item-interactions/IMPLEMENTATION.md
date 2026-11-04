# Space item interactions

Build target 1.1.2 (174), branch `feat/space-item-interactions`, stacked on released Space polish build173. This implements the user's follow-up interaction requests before the remaining photo-scan and web Founding Access packages.

Item info edits supported fields by tapping their value, with inline Save/Cancel, server-confirmed updates, draft retention on failure, duplicate-write protection and guarded dismissal. The bottom Edit button is removed. Part number leads item titles with stored description below; the existing seven sort comparators are verified against the displayed title and date/quantity semantics. Original imported fields, date-added and AI confidence remain source metadata. Alert thresholds use the existing account-local preference save.

The item Ask button is opaque light grey. Existing photos open the full image with a fade and contain/zoom; missing photos offer the existing camera/library picker and upload. Review and Low quantity are plain grey stadium buttons with their original actions. Review is visible when its count is unknown; zero low stock remains hidden as in build173.

The Space status/control header and pinned search now use a full-width uniform blur, including the status area. An initial native screenshot exposed an excessive gradient falloff; the corrected header was checked again on iOS with 298 rows.

Custom slide-up sheets use coordinated downward dragging and accessible dismissal. Existing native modal sheets retain their built-in swipe gesture. Review and item drafts still require Save/Discard or Keep editing, and pending writes cannot be abandoned. Close controls outside the main Ask are removed; editor Cancel, confirmation choices and the fading full-screen photo viewer remain distinct actions.

Space Ask uses a separate inventory client carrying a selected Space ID. The companion backend validates that boundary and supplies scoped history, reads and writes. It must be deployed before this binary. Main ChatPage, main composer, model UI, scrolling, attachments and world routing are unchanged. Three shared chat-file edits are narrowly conditional: the inventory popup loses its Close icon, and history/feedback hide Close only for a Space client. Main Ask keeps its existing controls. Photo source defaults remain unchanged in main Ask.

Validation: full Flutter regression suite, clean analyzer, 21 native iOS scenarios and an additional corrected-header pass. Seven sort cases, failed inline saves, dirty swipe protection, photo viewer/source selection, permissions and a separate Space-client boundary are covered. Native screenshots use synthetic data and a bundled photo. Physical iPhone camera/library, VoiceOver and hands-on smoothness remain unverified. Release/CI receipts will be recorded after upload; no public App Store submission.

The screenshots referenced as Image #1 through Image #9 were not attached to the conversation; implementation follows the supplied written requirements.

Delivery: Apple acknowledged 1.1.2 (174), runtime `2312c0af9bf7b945c9212db61f74a34e20d6cca7`, delivery `3209d1a0-bb6a-464d-9580-29acfa9ede12`. All five CI jobs passed on that exact runtime (41751956906). 1,341 Flutter tests passed with one existing skip. Signed archive/export verified 33 device executables each, strict signatures, 27 privacy manifests, production configuration and Apple validation. Companion Space-chat backend is deployed and real HTTPS verification passed. Processing and tester availability are pending; physical-device acceptance remains unverified. See `testflight174-receipt.json`.
