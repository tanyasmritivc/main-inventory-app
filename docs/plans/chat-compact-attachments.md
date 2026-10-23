# Compact chat attachments — beta 113

The Lovable screenshots supplied October 22 define the size/navigation reference.
The composer uses a 19-point light native plus, preserving its 48-point hit target.
The plus becomes X while a 248-point anchored menu is open. Search filters actual
choices; context/inventory submenus stay in the same panel with Back. Four root
choices: Auto Extract, Attach, Inventory tools, Add context.

Attach opens a separate native vertical Photo Library / Take Photo / Choose Files
menu on iOS 17.4+. Earlier iOS versions and other platforms use the compact Flutter
submenu; camera/library/file pickers remain the existing system integrations.
Native dismissal restores the root-menu button behavior. The background does not
receive accidental taps through the menu.

Ordinary photo selection stays in the composer until Send. Empty text no longer
implies extraction. Choose Files accepts supported image files alongside existing
text documents. Only Auto Extract sets the extraction flag and starts immediately.
Stable request IDs accompany photo requests so retained-image retries can reuse
the same user turn. Requires companion API branch fix/chat-direct-vision-api-20261022.

Validation: focused chat/shell tests 56 pass; search/back/native routing tests
2 pass; clean Flutter analysis. The iOS 26.5 simulator preview verifies dark/light
appearance, search, nested Back, native attachment presentation, Photo Library
callback and subsequent reopening of the root menu. The synthetic preview does
not test actual camera permissions or physical-device photo selection. Full mobile
suite and signed beta release are tracked in the release receipt.

No claim is made that the broader FindEZ product roadmap is complete.
