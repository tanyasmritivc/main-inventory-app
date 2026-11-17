# World Settings entry - build 225 pending

Branch: feat/organisation-spaces-mobile. Runtime change is limited to
mobile/lib/features/world/world_shell.dart and profile/account_menu.dart plus
profile/native_account_menu.dart. Version 1.1.5+225 prepared. Full mobile Dart
analysis passed; focused native-account/World-shell/World-page tests failed to
start because the sandbox denies loopback socket creation. SDK write restrictions
and Terminal computer-control rejection were observed; do not report tests as
passing or build 225 as uploaded.

Run ../scripts/prepare-world-settings-testflight.command from the Command Center.
It runs analysis and the full suite, then archives/exports using the existing
private production configuration. It does not upload. Logs go to
../.world-private/mobile225. Verify signatures, architectures/platforms, privacy
manifests, release configuration and bundle/extension version before uploading
with the existing Apple Transporter flow. Adapt ../.world-private/mobile224/
verify-package.py to 225; never reuse its signatures receipt. Stop at Apple upload
acknowledgment; no public App Store submission and no Git push. Record receipt.
A physical iPhone should show no header World entry, expose Settings > World,
open in landscape and return to portrait with existing inventory refreshed.
