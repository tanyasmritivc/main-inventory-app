## October 21 — Chat polish and unified capture delivery

Lane: fix/mobile-chat-workspace-flows-20261021, build1.1.0(105).
Chat scrolls across the full viewport beneath measured, fading glass overlays.
The composer has suggestion chips; send/backend-ack/first-visible-reply haptics
are discrete. Suggested Space chips select and save immediately (user-selected
behavior); inline links still navigate and duplicate confirmation remains.
Spreadsheet and barcode actions now create chat drafts before destination choice,
with resumable large import saves. The plus menus open immediately, Appearance
starts collapsed, and the chat header has a notification bell. Board notifications
open the team board, while historical accepted/expired invitations are read-only.

Validation: 753 Flutter tests passed plus enabled production configuration check;
20 native iOS simulator cases passed with preserved light/dark previews. Static
analysis is clean. No customer QA writes or test pushes. Physical haptic feel,
camera/barcode capture and APNs receipt need real-device acceptance. Signed105
archive/upload is pending; public App Store submission is not authorized here.
API dependency is PR157, with no migration and separate guarded activation.

Native previews are preserved privately under Documents/FindEZ/AppStore/1.1.0-build105/previews.
The initial final test attempt exhausted local disk; only generated Flutter/Xcode
caches were cleared. The subsequent complete suite passed. Release upload must
stop at Apple's acknowledgment without polling processing/group availability.
