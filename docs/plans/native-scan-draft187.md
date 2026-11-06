## November 5 — Native Scan and simpler draft destinations187

Branch `fix/space-flow-native-scan` adds the system circular plus/Scan menu beside the native tabs, reusing Auto Extract. Spaces new-Space selection uses an opaque native grouped inventory picker with concise names and subtitles only for ambiguous duplicate names. More contains only Documents and notes, Workspaces and Account settings. A server-bound creation proposal appears in the existing item draft as Create Space & save items; a successful creation remains selected if saving needs retry. Duplicate empty Choose a Space controls are removed. This depends on the backend saved-photo/draft-flow fix.

Validation: 1,288 Flutter tests passed, one existing skip; clean analysis; two native creation/retry tests passed. Real UIKit menu/picker taps and dark/light visual checks use synthetic data. Build187 packaging/upload pending. Physical TestFlight and VoiceOver acceptance remain unverified. Public App Store unchanged.

The debug-only tool/native_tabs_visual.dart harness never loads accounts or inventories. Production builds target lib/main.dart. Native popup colors are explicitly opaque for the new inventory picker, avoiding the low-contrast iOS26 sheet background; other native sheets retain their existing presentation.
