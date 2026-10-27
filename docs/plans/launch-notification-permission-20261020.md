# Automatic notification permission on opening FindEZ

The user requested Apple's notification permission prompt automatically when the
app opens. The mobile root now mounts LaunchNotificationPermission before the
authentication gate. After the first active frame, it requests alert, badge and
sound authorization only when iOS reports notDetermined. A background launch
waits for resume and schedules a frame. No additional permission explainer is
inserted. Existing Allow/Don't Allow choices remain in iOS Settings.

Authorization is separate from APNs registration: signed-out launches request
permission without server calls; an allowed signed-in session reconnects through
the existing account/generation-protected registration. Native permission errors
do not block the app. The Notifications screen retains its Enable/Settings retry.
No backend, web, schema, inventory or customer data changes are included.

Branch: fix/mobile-launch-notification-permission-20261020.
Build: 1.1.0 (103). Delivery is pending validation.

## Validation

18 targeted Flutter cases pass, including concurrent requests, durable decisions,
first frame, background/resume, signed-out no-write, denial, errors, disposal and
sign-out. Full Flutter:727 pass,one configuration test skipped; analysis is clean. The native
iOS26.2 test passed: notDetermined, Apple alert, Allow, authorized, and no second
prompt after gate recreation or another native request. Screenshot and logs are
preserved under Documents/FindEZ/AppStore/1.1.0-build103. Signed-release checks
are pending while the user's subsequent chat presentation/latency feedback is implemented.
The opt-in native integration test uses a signed-out synthetic API and the real
AppDelegate permission channel. No founder/customer account is used. Physical
first-open acceptance and real background push delivery are not yet verified.
