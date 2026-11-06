# Navigation and extraction cancellation - build 192

Mobile-only update requested November 6. The existing native UITabBar holds Ask,
a center plus action with no visible label, and Spaces. The plus retains the
existing direct camera/Photos callback; it never becomes a selected destination.
The three More links (Documents and notes, Workspaces, Account settings) move
into a compact section of the scrollable Spaces page, including loading/error
states. Existing destinations and new-Space behavior remain intact.

Closing unfinished extraction retires its request generation, cancels the stream,
clears preview state and tells the shell whether a conversation remains. Empty
chat returns to the normal home with navigation and header controls. Existing
messages and typed text remain; a completed draft still uses Keep draft in chat.
No backend, data, scan pipeline, camera UI, native Settings/Chats or theme changes.

Validation: 1,294 Flutter tests passed (one existing skip); analysis is clean.
15 iOS simulator flow checks passed, including both themes, narrow/large text,
keyboard layout and cancellation with empty/existing chat. Actual UIKit taps
verified both destinations and repeated center-plus actions; light/dark native
bar and compact Spaces screenshots were reviewed. Native camera, Chats/Settings
and theme source files match build191. Physical camera and VoiceOver acceptance
remain pending. All five exact-source CI gates passed. Signed TestFlight 1.1.2 (192) validated
and upload acknowledged by Apple. Processing/tester availability remain pending,
not polled. See navigation-scan-return192-release.json.
