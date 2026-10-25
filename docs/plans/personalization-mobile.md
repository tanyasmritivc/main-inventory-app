## October 25 — Personalization routing delivered to TestFlight139 (PR224)

Apple acknowledged 1.1.1 (139), runtime `d7cfb0590c41a69ff528d6b4d1b06365b3a6a818`,
delivery `c0eb1702-45ea-425c-96c9-118ae45fcba3`. All five exact-source CI gates
passed (40244305919). Signed archive/export each verified 34 device executables,
strict signing, 26 privacy manifests, production configuration and Apple validation.
Processing/tester availability were not polled. Physical APNs acceptance remains
unverified. No public App Store submission. No existing UI layout/navigation changes.
API PR223/migration081 remain undeployed; personalized dispatch stays disabled.
Receipt: `docs/plans/personalization-mobile-receipt.json`.

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
