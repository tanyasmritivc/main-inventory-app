# Chat import organization scope

The main Ask attachment menu passed an organization-bound API client to a
picker that enumerated every account workspace. It now reads that world’s
editable inventory directory. Personal is a separate world. The picker validates
the directory world and freshly checks the selected inventory’s organization
before requesting Spaces. Changing client context clears destinations and ignores
late results. Existing inventory-bound and intentionally unscoped entry points
keep their previous scope.

Implementation: `mobile/lib/features/scan/connector_destination_page.dart`.
Regression tests: `mobile/test/import_destination_scope_test.dart`.

Validation: 13 focused tests passed, all 1,390 Flutter tests passed with one
existing skip, and analysis was clean. The production archive/export each passed
33 iOS-device executable checks, strict signing, 27 privacy manifests, embedded
production configuration and application entitlement checks. No live customer
inventory was changed during tests. Physical-device acceptance is unverified.

CI initially selected a newer stable SDK, introducing deprecations in unchanged
files. The workflow now uses Flutter 3.41.0, matching the production build SDK.

Apple rejected the original 1.1.3 package because that version is already
approved and closed. The final package is 1.1.4 (221), verified by Apple
Transporter. The command-line client had local resource/network errors, so the
existing signed-in Transporter app is used for delivery. Upload status is recorded
in `mobile221-release.json`; verification alone is not delivery.

Web was fixed separately in PR391, commit40b14181, and deployed to the existing
self-hosted server. Its scoped tests, lint, production build and CI web suite passed.
That branch’s unchanged backend original-field test and floating mobile SDK CI
have separate failures recorded in its ACTIVE_WORK entry.

Apple acknowledged delivery of 1.1.4 (221) at9:07PM on November12.
All five CI checks passed on runtime a8bc0b24, run43368941194.
Processing and tester availability remain pending; no public submission.
