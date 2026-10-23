# Native iOS controls — beta 117

User-approved mobile-only extension of beta 116. Apple UIKit supplies standard
interaction and material; Flutter retains inventory logic, authentication and
custom review workflows. No schema, backend, web or connector activation changes.

## Implemented

- Shared UIKit presentation bridge with session tokens, owned Flutter routes,
  cancel/disposal handling, native errors and verified async preference results.
- Chat history: searchable native sheet, saved conversations, new chat, explicit
  deletion confirmation, retry, and retention of a row when deletion fails.
- Settings: native grouped list, Appearance child page, system switches/checkmarks,
  existing preference persistence and profile/legal/support destinations.
- Real UIMenu for the plus menu and inventory overflow. Attach leaves keep their
  existing chat upload paths; only Auto Extract invokes extraction.
- SF Symbols and native glass toolbar buttons on supported iOS; standard older-iOS
  controls and Flutter fallbacks elsewhere. Existing native bottom tabs retained.
- Native simple confirmations, Space name input, sorting and photo-source choices.
- Quieter content surfaces for creation, item-action and capture cards; existing
  details, permissions, uncertainty and action semantics retained.
- Original chat background retained. Google/unfinished connectors stay hidden.

UIKit owns animation, dismissal and accessibility behavior. Sheets use system
medium/large detents. Alerts must retain their UIKit-owned presentation delegate;
replacing it triggers a UIKit assertion. Only list sheet delegates are assigned.
Complex inventory editors, exact-name resource removal, import review and other
product-specific workflows remain Flutter; this is not a wholesale screen rewrite.

## Validation

Full Flutter suite: 816 passed, one optional skip. Subsequently added focused
settings persistence and toolbar lifecycle coverage; all six focused tests pass.
Analysis clean. iOS 26.5 simulator harness uses synthetic
inventory/profile data, never customer writes.

Verified native history loading/search/selection, attachment submenu selection,
plus-menu operation with software keyboard visible, dark/light Appearance changes,
Space input validation/save and destructive-alert cancellation. Initial simulator
alert delegate crash was reproduced, fixed and successfully retested before release.

Run the harness: `flutter run -t tool/native_controls_visual.dart -d <ios-device>`.
It is debug-only and is not the release entry point.

## Manual acceptance on final TestFlight build

1. On Chat, open history: drag between detents, search, open an existing chat;
   reopen and start a new chat. Swipe a disposable test chat, cancel Delete first.
2. Open avatar Settings: navigate Appearance, switch light/dark/system and text
   size, reopen and verify saved selections. Check scanning preference persists.
3. With chat keyboard open, open +. Try Attach > Photo Library/Take Photo/Files;
   ask a question about an attachment. Separately use Auto Extract and review items.
4. Spaces > New Space: empty name cannot save; Cancel creates nothing. Create one
   disposable Space, rename it, verify overflow/sorting and the correct destination.
5. Review a creation card and cancel a delete card; unchanged confirmation rules
   and exact-name resource removal must remain intact.
6. Check VoiceOver focus, large Dynamic Type, Reduce Motion/Transparency, older iOS,
   physical keyboard and phone gestures. These physical/accessibility checks remain
   pending; simulator/host checks do not certify them.

## Delivery

Build 1.1.1 (117). Release and Apple receipt pending until recorded below.
