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
plus inbox dismiss/menu/clear. Physical-device APNs and production API activation
remain pending. Backend PR332 contains the reviewed migration and delivery policy.

Until the policy API is deployed, the app retains the legacy inbox and hides the
new preferences entry. Existing phone thresholds remain saved locally; background
phone-local alerts are retired in this build. Production rollout should accompany
this build after explicit database approval. Recap/cleanup/re-engagement and
scheduled reminders are unavailable and remain off.

## Delivery

Apple acknowledged TestFlight **1.1.2 (193)**, runtime
`3ce1959f9e1adbc25deddf0f50c1c735da63cd7d`, delivery
`66387503-b2f4-4fb2-b6a8-cece838b0cb7`.
[PR333](https://github.com/tanyasmritivc/main-inventory-app/pull/333) and all five
[CI jobs](https://github.com/tanyasmritivc/main-inventory-app/actions/runs/42250147908)
passed. Signed archive/export verification and Apple validation passed. Receipt:
`notification-mobile193-release.json`. Processing/tester availability were not
polled; no public App Store submission. Production activation requires explicit
database authorization and actual APNs/device acceptance remains pending.
