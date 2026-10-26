# Photo drafts above chat

Auto Extract scans into a nonmodal preview above the existing composer. The same durable capture is handed to chat for a typed correction; no generated prompt is inserted. The preview uses the existing destination, edit and save controls. A chat "save it" invokes that same confirmed save path, with duplicate-tap protection and no silent retry after failure. Successful saves move the receipt into chat. Ordinary attachments stay staged until Send and allow an empty caption.

API dependency: migration 084 and backend runtime 874b537 add preview_only without changing older clients. Scanning uses the scan allowance, not an extra chat allowance.

Validation: Flutter analysis is clean; 46 focused tests pass, including save retry/failure, retained draft on stream failure, caption and image-only send, preview-to-chat handoff, and keyboard layout. Four iOS simulator integration cases pass using synthetic APIs. Native Attach menu selection is exercised through its callback because Flutter test taps cannot synthesize UIKit menus. Physical camera/library and on-device network acceptance remain unverified. Full suite and release gates recorded in the delivery receipt.

Build 142 supersedes 141; no App Store submission is authorized by this release.
