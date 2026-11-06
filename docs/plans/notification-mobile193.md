# Notification mobile193

Adds server-backed notification preferences and actionable inbox controls using
existing native presentation. Settings/Chats rendering and navigation are unchanged.
Permissions are requested on explicit phone-alert opt-in, not app launch.

Phone-only stock thresholds import when the inventory is next opened online;
server edits/clears override older local copies. A failed explicit threshold save
keeps the last confirmed value. No inventory quantity or shared reorder field is
changed. Uncoordinated local alerts are retired so server caps govern new pushes.

Validation: 1,304 Flutter tests passed, one existing skip; analyzer clean. Native
preferences reviewed in both appearances, initial load and quiet-hour selection,
plus inbox dismiss/menu/clear. Physical-device APNs remains pending. Backend PR332
is activated after user approval, with live API acceptance passing.

The policy API and new preferences entry are now active. Existing phone thresholds
import when the inventory opens online; phone-local alerts are retired. Server push
remains disabled pending device acceptance. Recap/cleanup/re-engagement and
scheduled reminders are unavailable and remain off.

## Delivery

Apple acknowledged TestFlight **1.1.2 (193)**, runtime
`3ce1959f9e1adbc25deddf0f50c1c735da63cd7d`, delivery
`66387503-b2f4-4fb2-b6a8-cece838b0cb7`.
[PR333](https://github.com/tanyasmritivc/main-inventory-app/pull/333) and all five
[CI jobs](https://github.com/tanyasmritivc/main-inventory-app/actions/runs/42250147908)
passed. Signed archive/export verification and Apple validation passed. Receipt:
`notification-mobile193-release.json`. Processing/tester availability were not
polled; no public App Store submission. The user approved production activation;
API/inbox runtime `a2d16cf4f079154de57b8471c36100f4f33b5084` is live. Actual APNs/device
acceptance remains pending and push stays off. No new binary is needed for activation.
