# Codex prompt: switch the mobile app to the Petals logo

Before you run this, copy the whole `findez-brand-kit-v4` folder into the repo at `mobile/design/brand-v4/`.

Then paste everything below the line into Codex from the repo root.

---

MOBILE (FLUTTER) ONLY. Replace every FindEZ logo in the iOS app with the new Petals logo, set the new app icon, and make sure the theme matches. The source is `mobile/design/brand-v4/`. Read `BRAND.md` there first.

## Scope (strict)

- Do NOT touch backend/, frontend/, the Supabase schema, env files, CI or deploy config.
- Change only logos, the app icon, the launch screen and theme tokens. Do not change screens, copy or logic.
- Work on a new branch `mobile-brand-v4`. Do not push.

## Logo

1. Copy `mobile/design/brand-v4/logo/` to `mobile/assets/brand/`, replacing older files, and register `assets/brand/` in `pubspec.yaml`.
2. Replace every in-app logo:
   - auth, onboarding (including the onboarding 3D page if it draws a logo), drawer or sidebar header, empty states, settings and about;
   - any loading screen that shows the logo.

   Rules:
   - Render the SVGs with `flutter_svg`. Add it only if it is missing.
   - Use `findez-wordmark.svg` with the name, or `-white` on dark backgrounds.
   - Use `findez-mark.svg` alone, or `findez-mark-white.svg` on orange.
   - Below 32pt, use `findez-mark-small.svg`.
3. Remove old logos, including inline SVG strings and CustomPainters. Search for:
   - `A4.5 4.5`;
   - `27.25 35.25`;
   - "Item ring";
   - echo or ring logo widgets.

## App icon

- Set the iOS app icon from `findez-app-icon.png`: 1024×1024, a white mark on orange, with no transparency.
- If the project uses `flutter_launcher_icons`, point `image_path` at that file, keep `remove_alpha_ios: true` and regenerate.
- Otherwise, replace every size in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`, as listed in its `Contents.json`, resized from the 1024 file.

## Launch screen

- If the launch screen shows a logo: use `findez-mark-white.png` centred on orange (#E8590C), matching the app icon.
- If the launch screen is plain white, use `findez-mark.png` centred instead.
- Keep the mark at about 96pt.

## Theme

- Compare the app theme against `theme/findez_theme.dart` and `theme/tokens.json`, and update values that differ:
  - orange #E8590C
  - orange-ink #C2410C
  - orange-tint #FFE8DA
  - ink #111112
  - baby blue #A9D6F5
  - blue-tint #EEF6FD
  - night #0B0B0D
- Fonts: Plus Jakarta Sans and Geist Mono, through `google_fonts`.

## Check before you finish

- `flutter analyze` passes with no new warnings.
- On the iOS simulator, the home screen icon is the white petals on orange, and the launch screen, auth, onboarding and settings show the new logo.
- No old logo remains: `git grep -n "A4.5 4.5" mobile/`, `git grep -n "27.25 35.25" mobile/` and `git grep -in "item ring" mobile/` return nothing in app code.
- Commit on `mobile-brand-v4`. List the files changed and the icon sizes generated.
