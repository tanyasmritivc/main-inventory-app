# Mobile loading and motion follow-up

Mobile only, `fix/mobile-loading-motion`, based on TestFlight 158. Release 159.

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

Validation: 1,225 Flutter tests passed with one existing skip, clean analysis and
22 native iOS simulator checks passed. These cover ten UIKit Ask layouts (both
themes, compact/tablet widths, larger text and keyboard), eight navigation/composer
checks and four real-loading/retained-page checks using Flutter navigation controls.
All five exact-source CI jobs passed in run 41004563323 for `f8f49e4`.

The initial package was rejected by the local platform check for a cached simulator
framework. A clean device rebuild passed all 34 archive and export executable
checks, strict signing, 26 privacy manifests, production configuration and SF Pro
packaging checks. Apple validation passed. The signed IPA/archive and screenshots
are preserved under `Documents/FindEZ/AppStore/1.1.1-build159`.

Apple acknowledged TestFlight 1.1.1 (159), delivery
`8a2b819a-f10f-46d5-9d5c-7e6921b17539`. Processing/tester availability is pending and
was not polled. PR276 is isolated from main. Physical-device motion/VoiceOver
acceptance remains unverified. No web, backend, API or schema change.
See `mobile-loading-motion-receipt.json`.
