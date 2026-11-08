# Signup and welcome flow - build201

Google and Apple are available in the mobile email signup view as well as the
provider chooser. Provider signup requires the existing eligibility acknowledgment
but obtains the name from the provider instead of requiring typed first/last names.
Apple's first-authorization name is persisted to auth metadata and the profile;
Google's display name is saved to the profile. Email validation is unchanged.

The permission gate now lives inside the authenticated account boundary. It asks
for iOS notification consent only when iOS has no recorded decision. The announcement
gate waits for the permission future and resumed lifecycle before claiming/presenting
an eligible campaign. APNs registration runs separately so a network failure cannot
block the welcome sheet. Existing campaign timing, verified allowances and dismissal
receipts remain authoritative. Signing out retires the gate and prevents late registration.

Closing the plan sheet exits the native Settings action instead of looping back to
Settings. Review and Low quantity are text-only #F6F8F9 pills with 44pt minimum touch
targets and accessible selected state. Their actions are preserved.

No main chat, extraction, inventory import, backend, database or public App Store
changes. The web provider-signup companion is a separate branch/PR.

Validation: provider-name fixtures; delayed Allow/Deny and inactive/resumed permission
sequencing; plan close navigation; dark/light Space controls. Analysis clean; full Flutter suite 1,336 pass / 1 skip; 16 native simulator checks pass.
Four screenshots retained and dark/light inspected. All five exact-commit CI jobs passed (42430591240). Signed production package
and Apple validation passed. Apple acknowledged TestFlight 1.1.2 (201), delivery
a6dba605-93b6-495a-b0da-db76b7cc1fe0. Processing/tester availability were not polled.

Device acceptance remains required for real Google/Apple authorization, fresh-install
iOS permission choices, welcome dismissal and VoiceOver. Synthetic tests do not certify
provider configuration or APNs delivery. Release receipt: mobile201-release.json.
