# Mobile loading and motion follow-up

Mobile only, `fix/mobile-loading-motion`, based on TestFlight 158. Preparing 159.

Navigation no longer covers mounted content with a generic skeleton. Retained tabs
keep their drafts and scroll positions, respond immediately, and fade from .94 to 1
over 160 ms without translation. The tab indicator completes in 100 ms. Route fades
use 160 ms and retain Flutter's iOS edge-back detector. Reduce Motion skips fades.
FadeTransition updates paint without rebuilding the page tree on each frame.

Real data loaders remain; Space, item, history, document and board-shaped
placeholders reflect their pending content. No fixed loading delay is introduced.
New-chat chips have opaque gray fills, no border, surface tint, shadow or elevation.
Default text changes from .96 to 1.04 (about 8%); saved size choices and system scaling
remain supported. The existing native SF Pro and regular-weight policy remain.

Validation and TestFlight delivery pending. No web, backend, API or schema change.
