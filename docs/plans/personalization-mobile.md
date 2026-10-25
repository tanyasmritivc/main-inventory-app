## October 25 — Personalization notification routing (beta139 preparation)

Lane `feat/mobile-personalization` extends existing APNs lifecycle handling and
opens existing authorized item/review sheets. No screen, layout, theme, navigation
or composer redesign. Capability registration prevents older clients receiving the
new destinations. API migration 081/deployment and opt-in are prerequisites; the
notification worker remains off. No real-user notifications were sent.
Verified: 925 full-suite tests (one existing optional visual skip), 28 subsequent
focused lifecycle/destination tests, clean analysis and simulator native build.
Physical APNs/background/terminated acceptance remains unverified. Build139 signed
archive/upload status will be recorded separately after Apple acknowledgment.

## Integration

Changed files: core personalization notification handler, APNs lifecycle bridge,
API capability registration, existing inventory/shell routing, existing review sheet
entry point, AppDelegate category callbacks, two focused test files and build number.
No web/backend source changes in this mobile lane. Server implementation is on
`feat/personalization-engine`, migration 081. Route payloads contain only notification
and recipient IDs; the authenticated destination endpoint authorizes current records.

APNs uses existing entitlements and server credentials. No FCM or web push added.
Real APNs device acceptance must precede server worker activation; mock lifecycle
and sheet tests do not prove physical delivery. Existing Memory and chat controls
are reused. No new settings section or permission prompt was introduced.
