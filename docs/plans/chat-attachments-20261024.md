# Chat attachments and quicker page entry

User explicitly approved the nav bar's current motion: do not change it. Keep
RetainedTabTransition.duration at 340ms for its existing nav indicator consumer;
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
selected photo bytes, with 64px thumbnail, accessible replace label and Remove.
Typing retains the photo; send uses the same photo/request. Regular uploads stay
ordinary chat attachments, and Auto Extract remains explicit.

Checks: 67 focused tests and 847 full host tests passed (1 optional skip), Flutter
analysis clean. Two native integration checks passed in light/dark mode. Manual
iOS 26.5 simulator QA verified custom root/context menus, native Attach choices,
Photo Library selection and a thumbnail retained alongside a typed prompt. Native
Attach owns its touch gestures; the Flutter row cannot dismiss the source menu
underneath it. Physical iPhone acceptance remains separate.

Final regression checks: the complete 847-test host suite passed again with one
optional skip; 67 focused checks plus two menu lifetime checks passed. CI run
40074291896 passed all five jobs on 4389b88. The signed package was built from
e6e748c; the only subsequent source change is chat_source_menu_test.dart. Private
source-equivalence.json records that runtime code and the validated IPA hash are
unchanged. Archive and export each passed all 32 iOS executable checks, strict
signing, 24 privacy manifests and production HTTPS configuration. Apple validation
passed. Apple acknowledged upload of 1.1.1 (122), delivery `be073265-056e-4e33-b8f3-c8b9e4e453a9`.
Processing/tester availability were not polled. Artifacts are preserved privately
under `Documents/FindEZ/AppStore/1.1.1-build122`. No public App Store submission.

Manual acceptance:
1. Switch Ask/Spaces/More. Content enters quickly; nav motion stays as before.
2. Tap +. Root and context/tool submenus use the compact FindEZ menu.
3. Tap Attach. Only here should the native three-option picker appear. Dismiss it
   without selecting, reopen, and choose Photo Library or Choose Files.
4. Attach a photo, type a question: its thumbnail stays visible before Send.
   Remove and replace it, then send. Check this on both a fresh and existing chat.
5. Auto Extract should still enter the explicit extraction workflow. Regular
   photo attachment must not start extraction or send before the user presses Send.
