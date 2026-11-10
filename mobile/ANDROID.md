# FindEZ Android development

Android starts from the shared Flutter app submitted as iOS 1.1.2 build 213
(`3ddf927f`). The current lane is `feat/android-foundation`. It reuses the existing
inventory, capture, Ask, onboarding and account flows. Android device acceptance
and Play Store delivery are not complete.

## Build and run

Use Flutter 3.41.0 / Dart 3.11, JDK 17, Android platform/build tools 36 and
NDK 28.2.13676358. The minimum device version is Android 7.0 (API 24), required
by the locked notifications dependency. Install these with Android Studio's SDK
Manager, accept SDK licenses, then check `flutter doctor -v`.

From `mobile/`:

```sh
flutter pub get --enforce-lockfile
cp android-config.example.json .env.android.json
# Fill in the public client configuration locally, never a service-role key.
flutter run -d <android-device-id> --dart-define-from-file=.env.android.json
flutter build apk --debug --dart-define-from-file=.env.android.json
```

The APK is `build/app/outputs/flutter-apk/app-debug.apk`. Debug permits local
HTTP for emulator development; release traffic is HTTPS-only. The application
ID is `com.findez.app`, and the launcher label is FindEZ. App data backup is
disabled to avoid restoring account credentials onto another installation.

Google sign-in needs an Android OAuth client for `com.findez.app` and the
certificate SHA-1, plus `GOOGLE_SERVER_CLIENT_ID` set to the matching web OAuth
client ID. The auth server must allow that token audience. Register debug and
Play signing certificates separately. Without this build value the app explains
that email sign-in is available; native iOS sign-in is unchanged. Account recovery
returns through the existing `io.supabase.flutter://login-callback` allowlist.

## Release signing

Copy `android/key.properties.example` to ignored `android/key.properties` and
provide the upload keystore location and passwords locally. Release builds use
that signing configuration; they never fall back to a debug signing key. Keep
the keystore and production configuration out of git. Configure Play App Signing
and the permanent package identity before the first upload.

```sh
flutter test --no-pub
flutter analyze --no-pub
flutter build appbundle --release --dart-define-from-file=.env.android.json
```

Do not upload until the production configuration check and device acceptance are
complete. The existing `test/release_config_test.dart` supports
`--dart-define=VERIFY_RELEASE_CONFIG=true` with the production defines file.

## Continuous integration

`.github/workflows/android.yml` runs analysis, focused authentication tests and an Android
debug compilation. Its APK uses `.invalid` placeholder endpoints, has no real
credentials and is a compilation artifact, not a functioning signed-in beta.
No release keystore or deployment credentials are required by this workflow.

## Remaining device and service work

- Verify onboarding, email verification/recovery, Google sign-in, account switch
  and sign-out on a real Android device.
- Verify camera/library capture, barcode scanning, microphone permission and
  voice recording, including denied permission and resume from background.
- Verify Back/predictive Back, keyboard insets, edge-to-edge system bars, light
  and dark themes, TalkBack and enlarged text.
- Exercise cold/warm Space, Team and access invitations. Custom schemes are
  registered; verified HTTPS App Links require release-certificate assetlinks
  hosting and are not claimed as shipped.
- Exercise CSV/XLSX SEND intents from Files and Drive. Only supported spreadsheet
  MIME types are advertised. Broad storage access is not requested.
- Android push delivery needs a separate FCM implementation and service setup.
  Existing APNs and iOS local notification code remain iOS-only.
- Confirm Android billing/store-policy handling before Play distribution; existing
  iOS purchase behavior is not evidence of an Android billing integration.
- Audit 16 KB page-size compatibility in the final release bundle and native
  dependencies before Play upload.

No backend, database, iOS release or public store changes are part of this lane.

References: [Flutter Android release guide](https://docs.flutter.dev/deployment/android)
and the locked dependencies' Android setup instructions in the local pub cache.
