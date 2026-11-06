# Charcoal dark background — build190

## Requested behavior

Use ElevenLabs’ charcoal page background throughout FindEZ dark mode. Pixel
sampling of IMG_3072.PNG and the supplied 11:36:47 PM reference confirms #111111
(RGB17,17,17); FindEZ Ask, Spaces and More screenshots use #000000.

## Implementation

The shared BrandColors.night token is #111111. AppTheme already maps legacy
opaque black/near-black page colors to this token, including nested inventories,
chat, loading, review and profile routes. WorldShell, retained-tab paint layers,
the inventory Spaces directory and ScrollGlass now use AppColors.background
instead of bypassing it with black. This also prevents black seams during tab
transitions and at scroll edges.

Light mode, text, elevated cards, native Chats/Settings sheets, camera/media,
QR print colors, shadows and scrims retain their existing colors. No backend,
web, data or feature behavior changes.

## Validation and delivery

Full 1,293 Flutter tests passed with one existing skip; analysis is clean. Native
simulator review confirmed #111111 on dark Ask, Spaces and More;
light mode retained its original background. Native Chats/Settings renderer,
profile and appearance sources match build189. Five CI gates passed at the exact
runtime commit. Signed production target lib/main.dart, archive/export platform,
signatures, privacy manifests and production configuration verified. Apple
validation and upload succeeded. See charcoal-dark-background190-release.json.

Processing/tester availability and physical-device appearance acceptance remain
pending. No processing polling or public App Store submission changes.
