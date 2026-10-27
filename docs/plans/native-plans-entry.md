# iPhone Plans entry correction — October 25, 2026

The previous plan comparison existed in Flutter ProfilePage, while the iPhone
profile button routes through showAccountMenu to showNativeAccountMenu. That
separate UIKit model had no Plans row, so the feature was unreachable there.

The native model now includes Plans directly below Notifications. Selecting it
opens the existing PlansPage. Back returns to native Settings and Close returns
to the originating screen. The row is independent of the paused legacy-promotion
flag. Prices, five-person Team capacity, entitlements and disabled purchases are
unchanged; alternative Team capacities remain proposals awaiting user selection.

Validation:
- Flutter analyze: no issues.
- Six focused tests passed, including selecting the platform-native menu, Plans
  navigation and return in both themes.
- Actual iPhone 17 Pro / iOS 26.5 simulator verification used AccountButton with
  synthetic account data and the real UIKit bridge: profile → Settings → Plans
  → Back → Settings → Close, in light and dark mode.
- The interactive harness is integration_test/native_plans_preview.dart. The
  production build uses lib/main.dart and production configuration.
- All five CI jobs passed for runtime 9031c9cec09629c706de28a6592e8de099054e02
  (run 40230657021).

Physical-device acceptance is unverified. No public App Store submission.

## Delivery

Native navigation regression and actual UIKit simulator checks passed in light/dark. Apple accepted TestFlight 1.1.1 (136), runtime `9031c9cec09629c706de28a6592e8de099054e02`, delivery `3f71608d-1261-40c7-afbf-8610d5956d1e`. All five CI jobs passed (40230657021); signing, 34 device executables per archive/export, privacy/config and Apple validation passed. Processing/tester availability not polled; physical-device acceptance unverified. No public App Store submission. Details: `docs/plans/native-plans-entry.md`; receipt: `docs/plans/native-plans-entry-receipt.json`.
