# Admin access TestFlight build98

## October 19 - organization Admin access and beta98

User approved migration072 and a new TestFlight build. The shared directory SQL
now honors effective Organization Owner/Admin access without requiring a separate
workspace membership row. The fix is live for both mobile and web, including
existing installations. The private activation receipt records two corrected
checks, fresh backup, healthy API/database and denied anonymous photo access;
no customer data was changed. Backend PR143 contains the tested correction.

This release increments only mobile version metadata to1.0.9(98), source0dfb9e8.
Native runtime/UI remain build97. Twenty-one workspace/configuration tests pass;
693 previous mobile regressions remain applicable. Signed archive/export, all
31+31 iOS executables,24 privacy manifests and production HTTPS/anon config pass.
Apple acknowledged signed production1.0.9(98), delivery `7d00d31e-465a-4ca2-844b-536721d9a2f3`.
All five CI gates pass (run39382888411), including693 Flutter tests and clean
analysis; the skipped compiled-config gate was separately enabled and passed.
The signed IPA/archive are preserved; SHA256 `3ba1466a8f7d442139227215ec8904c85ca38210faadfb330e4d9cad336af55b`.
TestFlight processing and availability were not polled; physical-device acceptance
remains pending. No public App Store submission was performed.
Artifacts: Documents/FindEZ/AppStore/1.0.9-build98. No public App Store submission
and no testing with the excluded founder account.

