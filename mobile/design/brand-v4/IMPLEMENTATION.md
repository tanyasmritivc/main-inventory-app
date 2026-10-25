# Petals brand v4 — mobile

Local branch: `mobile-brand-v4`. No push, deployment or TestFlight upload. The latest supplied brand prompts explicitly require local-only work.

Updated the shared SVG wordmark (light/dark), canonical brand assets, 3D onboarding logo geometry, iOS app icons, native launch artwork, background tokens and bundled Plus Jakarta Sans/Geist Mono font registration. Existing screens, copy, routes, extraction and authentication logic are unchanged.

The icon generator ran with an iOS-only temporary config, then the existing catalog manifest was preserved (including its dark appearance slot). All 26 entries are opaque RGB and match their declared dimensions. Generated pixel sizes: 20, 29, 40, 50, 57, 58, 60, 72, 76, 80, 87, 100, 114, 120, 144, 152, 167, 180, 1024. Launch images: 96, 192, 288.

Google Fonts was raised to compatible 7.1.0 for Geist Mono support. Static 400/500/600 fonts are bundled for offline loading. Existing font aliases remain available. Semantic status foregrounds retain their established accessible colors; the seven requested brand colors match exactly.

Validation: flutter analyze reports no issues. Full suite: 900 passed, 3 failed, 1 skipped; all 3 failures were repaired in test setup (asset binding initialization and waiting for scrolling), and all 25 tests in the affected files then passed. Brand/theme focused suite: 17 passed; onboarding cases passed in the combined run. Simulator debug build succeeded; visually checked onboarding Petals, auth wordmark and the installed orange/white icon in App Library. Native launch storyboard compiled, but its brief display was not separately captured. No physical-device or signed-in settings acceptance run was performed; settings has no existing logo to replace.

The 3D scene retains its existing movement and shelf behavior; only the logo geometry/material was replaced. Canonical supplied files are retained in design/brand-v4. Runtime SVG metadata was removed for Flutter compatibility, and equivalent comma-separated arc coordinates avoid false positives from the requested old-logo search. No old geometry remains in lib/assets/ios. Historical reference documents were not rewritten.

## Files changed

- `mobile/assets/brand/findez-app-icon-120.png`
- `mobile/assets/brand/findez-app-icon-180.png`
- `mobile/assets/brand/findez-app-icon-dark-120.png`
- `mobile/assets/brand/findez-app-icon-dark-180.png`
- `mobile/assets/brand/findez-app-icon-dark.png`
- `mobile/assets/brand/findez-app-icon-dark.svg`
- `mobile/assets/brand/findez-app-icon-light-120.png`
- `mobile/assets/brand/findez-app-icon-light-180.png`
- `mobile/assets/brand/findez-app-icon-light.png`
- `mobile/assets/brand/findez-app-icon-light.svg`
- `mobile/assets/brand/findez-app-icon.png`
- `mobile/assets/brand/findez-app-icon.svg`
- `mobile/assets/brand/findez-favicon-16.png`
- `mobile/assets/brand/findez-favicon-32.png`
- `mobile/assets/brand/findez-favicon.png`
- `mobile/assets/brand/findez-favicon.svg`
- `mobile/assets/brand/findez-icon.svg`
- `mobile/assets/brand/findez-mark-black.png`
- `mobile/assets/brand/findez-mark-black.svg`
- `mobile/assets/brand/findez-mark-small.svg`
- `mobile/assets/brand/findez-mark-white.png`
- `mobile/assets/brand/findez-mark-white.svg`
- `mobile/assets/brand/findez-mark.png`
- `mobile/assets/brand/findez-mark.svg`
- `mobile/assets/brand/findez-wordmark-white.png`
- `mobile/assets/brand/findez-wordmark-white.svg`
- `mobile/assets/brand/findez-wordmark.png`
- `mobile/assets/brand/findez-wordmark.svg`
- `mobile/assets/brand/jpeg/findez-app-icon-dark.jpg`
- `mobile/assets/brand/jpeg/findez-app-icon-light.jpg`
- `mobile/assets/brand/jpeg/findez-app-icon.jpg`
- `mobile/assets/brand/jpeg/findez-logo-mark-black.jpg`
- `mobile/assets/brand/jpeg/findez-logo-mark-white.jpg`
- `mobile/assets/brand/jpeg/findez-logo-wordmark-black.jpg`
- `mobile/assets/brand/jpeg/findez-logo-wordmark-white.jpg`
- `mobile/assets/fonts/brand/GeistMono-Medium.ttf`
- `mobile/assets/fonts/brand/GeistMono-Regular.ttf`
- `mobile/assets/fonts/brand/GeistMono-SemiBold.ttf`
- `mobile/assets/fonts/brand/PlusJakartaSans-Medium.ttf`
- `mobile/assets/fonts/brand/PlusJakartaSans-Regular.ttf`
- `mobile/assets/fonts/brand/PlusJakartaSans-SemiBold.ttf`
- `mobile/assets/onboarding/onboarding_world.html`
- `mobile/design/brand-v4/BRAND.md`
- `mobile/design/brand-v4/CODEX_PROMPT_MOBILE.md`
- `mobile/design/brand-v4/CODEX_PROMPT_WEB.md`
- `mobile/design/brand-v4/brand-preview.png`
- `mobile/design/brand-v4/logo/findez-app-icon-120.png`
- `mobile/design/brand-v4/logo/findez-app-icon-180.png`
- `mobile/design/brand-v4/logo/findez-app-icon-dark-120.png`
- `mobile/design/brand-v4/logo/findez-app-icon-dark-180.png`
- `mobile/design/brand-v4/logo/findez-app-icon-dark.png`
- `mobile/design/brand-v4/logo/findez-app-icon-dark.svg`
- `mobile/design/brand-v4/logo/findez-app-icon-light-120.png`
- `mobile/design/brand-v4/logo/findez-app-icon-light-180.png`
- `mobile/design/brand-v4/logo/findez-app-icon-light.png`
- `mobile/design/brand-v4/logo/findez-app-icon-light.svg`
- `mobile/design/brand-v4/logo/findez-app-icon.png`
- `mobile/design/brand-v4/logo/findez-app-icon.svg`
- `mobile/design/brand-v4/logo/findez-favicon-16.png`
- `mobile/design/brand-v4/logo/findez-favicon-32.png`
- `mobile/design/brand-v4/logo/findez-favicon.png`
- `mobile/design/brand-v4/logo/findez-favicon.svg`
- `mobile/design/brand-v4/logo/findez-mark-black.png`
- `mobile/design/brand-v4/logo/findez-mark-black.svg`
- `mobile/design/brand-v4/logo/findez-mark-small.svg`
- `mobile/design/brand-v4/logo/findez-mark-white.png`
- `mobile/design/brand-v4/logo/findez-mark-white.svg`
- `mobile/design/brand-v4/logo/findez-mark.png`
- `mobile/design/brand-v4/logo/findez-mark.svg`
- `mobile/design/brand-v4/logo/findez-wordmark-white.png`
- `mobile/design/brand-v4/logo/findez-wordmark-white.svg`
- `mobile/design/brand-v4/logo/findez-wordmark.png`
- `mobile/design/brand-v4/logo/findez-wordmark.svg`
- `mobile/design/brand-v4/logo/jpeg/findez-app-icon-dark.jpg`
- `mobile/design/brand-v4/logo/jpeg/findez-app-icon-light.jpg`
- `mobile/design/brand-v4/logo/jpeg/findez-app-icon.jpg`
- `mobile/design/brand-v4/logo/jpeg/findez-logo-mark-black.jpg`
- `mobile/design/brand-v4/logo/jpeg/findez-logo-mark-white.jpg`
- `mobile/design/brand-v4/logo/jpeg/findez-logo-wordmark-black.jpg`
- `mobile/design/brand-v4/logo/jpeg/findez-logo-wordmark-white.jpg`
- `mobile/design/brand-v4/theme/findez-theme.css`
- `mobile/design/brand-v4/theme/findez_theme.dart`
- `mobile/design/brand-v4/theme/tailwind.findez.js`
- `mobile/design/brand-v4/theme/tokens.json`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@1x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@2x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@1x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@2x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@1x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@2x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-Dark-1024.png`
- `mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png`
- `mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png`
- `mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png`
- `mobile/ios/Runner/Base.lproj/LaunchScreen.storyboard`
- `mobile/lib/core/app_theme.dart`
- `mobile/lib/core/ui/app_colors.dart`
- `mobile/lib/core/ui/app_typography.dart`
- `mobile/lib/core/ui/findez_wordmark.dart`
- `mobile/pubspec.lock`
- `mobile/pubspec.yaml`
- `mobile/test/appearance_controller_test.dart`
- `mobile/test/brand_theme_test.dart`
- `mobile/test/memory_page_test.dart`
- `mobile/tool/prepare_brand_icon.dart`

Repository state notes in `.agents/ACTIVE_WORK.md`, `.agents/CURRENT_STATE.md` and `.agents/DECISIONS.md` are also updated.

## Release — October 25

The user subsequently authorized TestFlight delivery. Apple accepted 1.1.1 (133), including chat-first onboarding and Petals branding, after all five CI jobs passed. See testflight-receipt.json. Apple processing and tester availability remain pending/unverified. All 24 v5 screenshots are staged (screenshots-v5-receipt.json); public App Store submission remains held.
