# Chat attachments and quicker page entry

User explicitly approved the nav bar's current motion: do not change it. Keep
RetainedTabTransition.duration at340ms for its existing nav indicator consumer;
pageDuration=150ms controls only page opacity. NativeBottomTabs, world_shell and
the Swift NativeTabs implementation are unchanged. Reduce Motion remains immediate.

The root + menu was accidentally native for all choices. WorldComposer now uses
the Flutter trigger to open chat_source_menu. That existing compact menu renders
Auto Extract, Attach, Inventory tools and Add context consistently with FindEZ.
NativeChatMenuButton is only a transparent native anchor over the Attach row;
its UIMenu contains only Photo Library, Take Photo and Choose Files. Its native
accessibility label is Attach. Context/import/barcode remain in the FindEZ menu.

The active world conversation rendered a text-only Photo attached row, unlike
the landing/legacy composers. All three now use one image preview backed by the
selected photo bytes, with64px thumbnail, accessible replace label and Remove.
Typing retains the photo; send uses the same photo/request. Regular uploads stay
ordinary chat attachments, and Auto Extract remains explicit.

Checks:67 focused tests and847 full host tests passed (1 optional skip), Flutter
analysis clean. Native Attach menu integration/manual visual QA and signed build122
receipts will follow. Physical iPhone acceptance remains separate.

Manual acceptance:
1. Switch Ask/Spaces/More. Content enters quickly; nav motion stays as before.
2. Tap +. Root and context/tool submenus use the compact FindEZ menu.
3. Tap Attach. Only here should the native three-option picker appear. Dismiss it
   without selecting, reopen, and choose Photo Library or Choose Files.
4. Attach a photo, type a question: its thumbnail stays visible before Send.
   Remove and replace it, then send. Check this on both a fresh and existing chat.
5. Auto Extract should still enter the explicit extraction workflow. Regular
   photo attachment must not start extraction or send before the user presses Send.
