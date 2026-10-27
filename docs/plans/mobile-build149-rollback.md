# Restore mobile build149 behavior

The user requested reverting everything from build150 to the previous build. Runtime source `7da9f724eb5b7b3f9212eaaa0d085ed69e6a0d0d` restores the entire mobile tree from `ca3a43a` (build149 runtime `6044eb0`). The only mobile difference is `pubspec.yaml`: build149 becomes build151 so TestFlight can accept the replacement.

The earlier onboarding, plus-menu capture and chat behavior are restored. Build150's Personal/Team setup, new Scan controls, preview invitation, camera/review/session implementation and related tests are removed. Historical build150 receipts remain as delivery records. No production service, database, web application or customer data changed.

## Verification

- Source comparison confirms only the build number differs from build149.
- Exact-source CI run40460187327: all five gates passed. Mobile: 1,190 tests passed, one existing skip; analysis clean.
- The local serial test run was interrupted after disk exhaustion. CI completed the full suite on the exact source. Only regenerable checkout/Xcode build caches were cleared; saved releases were preserved.
- Signed archive and IPA each contain 34 verified device binaries; strict signing passes. All 26 privacy manifests, purpose strings and production HTTPS/anon configuration pass.
- Rollback simulator build151 is installed on iPhone17Pro; its app data is preserved and the simulator was returned to its prior shut-down state.
- IPA and archive preserved in the build151 release directory. Apple delivery status is recorded in the release receipt.

Physical-device acceptance remains unverified. This is a beta rollback, not a public App Store submission.

Apple acknowledged TestFlight1.1.1(151), delivery `ee9a130a-e4d9-42db-98a7-0d376e128ed1`. Processing/tester availability is pending and not polled. PR260 is closed; replacement PR261 records the rollback.
